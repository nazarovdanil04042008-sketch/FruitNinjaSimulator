--!nonstrict
-- Player-to-player trading of creatures and coins.
--
-- Flow: TradeRequest -> (target) TradeRespond(accept) -> both edit offers with TradeSetOffer ->
-- both press TradeReady -> both press TradeConfirm -> the server re-validates everything and swaps
-- atomically, then saves both profiles immediately.
--
-- Anti-scam / anti-dupe rules:
--   * Any change to either offer clears both Ready and Confirm flags (no last-second swaps).
--   * Confirm is only possible when both players are Ready, and there is a short lock after
--     the last change before confirming is allowed.
--   * At execution every creature must still be owned, coins must still be available and both
--     inventories must have room - otherwise the trade is cancelled and nothing moves.
--   * Traded creatures get a new uid on the receiving side; the sender loses theirs in the same step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EquipmentService = require(script.Parent.EquipmentService)

local TradeService = {}

local MAX_CREATURES_PER_SIDE = 9
local INVITE_TIMEOUT = 30
local CONFIRM_LOCK = 3 -- seconds after the last change before Confirm is accepted

type Offer = { Creatures: { string }, Coins: number }
type Trade = {
	A: Player,
	B: Player,
	Offers: { [Player]: Offer },
	Ready: { [Player]: boolean },
	Confirmed: { [Player]: boolean },
	ChangedAt: number,
	Done: boolean,
}

local trades: { [Player]: Trade } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> requester -> time
local lastRequest: { [Player]: number } = {}
local remotes: { [string]: RemoteEvent } = {}

local function partnerOf(trade: Trade, player: Player): Player
	return trade.A == player and trade.B or trade.A
end

local function offerView(owner: Player, offer: Offer): any
	local profile = DataService.Get(owner)
	local list = {}
	for _, uid in offer.Creatures do
		local entry = profile and profile.Creatures[uid]
		if entry then
			table.insert(list, { Uid = uid, Id = entry.Id })
		end
	end
	return { Creatures = list, Coins = offer.Coins }
end

local function push(trade: Trade)
	for _, player in { trade.A, trade.B } do
		local partner = partnerOf(trade, player)
		remotes.TradeUpdate:FireClient(player, {
			PartnerName = partner.DisplayName,
			PartnerUserId = partner.UserId,
			Mine = offerView(player, trade.Offers[player]),
			Theirs = offerView(partner, trade.Offers[partner]),
			MyReady = trade.Ready[player] == true,
			TheirReady = trade.Ready[partner] == true,
			MyConfirmed = trade.Confirmed[player] == true,
			TheirConfirmed = trade.Confirmed[partner] == true,
			ConfirmIn = math.max(0, CONFIRM_LOCK - (os.clock() - trade.ChangedAt)),
		})
	end
end

local function close(trade: Trade, reason: string, completed: boolean)
	if trade.Done then
		return
	end
	trade.Done = true
	for _, player in { trade.A, trade.B } do
		if trades[player] == trade then
			trades[player] = nil
		end
		if player.Parent then
			remotes.TradeClosed:FireClient(player, reason, completed)
		end
	end
end

local function resetFlags(trade: Trade)
	table.clear(trade.Ready)
	table.clear(trade.Confirmed)
	trade.ChangedAt = os.clock()
end

local function countCreatures(profile: any): number
	local n = 0
	for _ in profile.Creatures do
		n += 1
	end
	return n
end

local function validOffer(profile: any, offer: Offer): boolean
	if offer.Coins < 0 or offer.Coins > profile.Coins then
		return false
	end
	for _, uid in offer.Creatures do
		if not profile.Creatures[uid] then
			return false
		end
	end
	return true
end

local function transfer(from: Player, to: Player, fromProfile: any, toProfile: any, offer: Offer)
	for _, uid in offer.Creatures do
		local entry = fromProfile.Creatures[uid]
		fromProfile.Creatures[uid] = nil
		local index = table.find(fromProfile.EquippedCreatures, uid)
		if index then
			table.remove(fromProfile.EquippedCreatures, index)
		end
		local newUid = DataService.NewUid(to, "c")
		toProfile.Creatures[newUid] = { Id = entry.Id, Obtained = os.time() }
		toProfile.Discovered[entry.Id] = true
	end
	fromProfile.Coins -= offer.Coins
	toProfile.Coins += offer.Coins
end

local function execute(trade: Trade)
	local a, b = trade.A, trade.B
	local pa, pb = DataService.Get(a), DataService.Get(b)
	if not pa or not pb or not a.Parent or not b.Parent then
		close(trade, "A player left.", false)
		return
	end
	local oa, ob = trade.Offers[a], trade.Offers[b]
	if not validOffer(pa, oa) or not validOffer(pb, ob) then
		close(trade, "Trade cancelled: the offered items changed.", false)
		return
	end
	if countCreatures(pa) - #oa.Creatures + #ob.Creatures > GameConfig.MaxCreatureInventory
		or countCreatures(pb) - #ob.Creatures + #oa.Creatures > GameConfig.MaxCreatureInventory then
		close(trade, "Trade cancelled: a creature inventory would be full.", false)
		return
	end
	-- Swap (no yields between these lines, so the swap is atomic on this server)
	transfer(a, b, pa, pb, oa)
	transfer(b, a, pb, pa, ob)
	for _, player in { a, b } do
		DataService.Replicate(player)
		ProgressionService.ApplyCharacterStats(player)
		EquipmentService.Refresh(player, false)
	end
	close(trade, "Trade complete! 🤝", true)
	task.spawn(DataService.SaveNow, a)
	task.spawn(DataService.SaveNow, b)
end

function TradeService.Init()
	for _, name in { "TradeInvite", "TradeUpdate", "TradeClosed" } do
		remotes[name] = Net.Event(name)
	end

	ActionService.Register("TradeRequest", function(player, _profile, targetUserId: any)
		if type(targetUserId) ~= "number" then
			return false, "Invalid player."
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or target == player then
			return false, "That player isn't here."
		end
		if not DataService.Get(target) then
			return false, "That player is still loading."
		end
		if trades[player] then
			return false, "Finish your current trade first."
		end
		if trades[target] then
			return false, target.DisplayName .. " is already trading."
		end
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 4 then
			return false, "Wait a moment before sending another request."
		end
		lastRequest[player] = now
		invites[target] = invites[target] or {}
		invites[target][player] = now
		remotes.TradeInvite:FireClient(target, player.UserId, player.DisplayName)
		return true, "Trade request sent to " .. target.DisplayName .. "."
	end)

	ActionService.Register("TradeRespond", function(player, _profile, fromUserId: any, accept: any)
		if type(fromUserId) ~= "number" then
			return false, "Invalid request."
		end
		local from = Players:GetPlayerByUserId(fromUserId)
		local list = invites[player]
		local sentAt = from and list and list[from]
		if list and from then
			list[from] = nil
		end
		if not from or not sentAt or os.clock() - sentAt > INVITE_TIMEOUT then
			return false, "That trade request expired."
		end
		if accept ~= true then
			ProgressionService.Notify(from, player.DisplayName .. " declined your trade.", "info")
			return true, "Declined."
		end
		if trades[player] or trades[from] then
			return false, "One of you is already trading."
		end
		local trade: Trade = {
			A = from,
			B = player,
			Offers = { [from] = { Creatures = {}, Coins = 0 }, [player] = { Creatures = {}, Coins = 0 } },
			Ready = {},
			Confirmed = {},
			ChangedAt = os.clock(),
			Done = false,
		}
		trades[from] = trade
		trades[player] = trade
		push(trade)
		return true, "Trading with " .. from.DisplayName .. "!"
	end)

	ActionService.Register("TradeSetOffer", function(player, profile, creatureUids: any, coins: any)
		local trade = trades[player]
		if not trade then
			return false, "You're not trading."
		end
		if type(creatureUids) ~= "table" or #creatureUids > MAX_CREATURES_PER_SIDE then
			return false, "You can offer up to " .. MAX_CREATURES_PER_SIDE .. " creatures."
		end
		if not ActionService.IsInteger(coins, 0, 1e15) or coins > profile.Coins then
			return false, "You don't have that many coins."
		end
		local list, seen = {}, {}
		for _, uid in creatureUids do
			if type(uid) ~= "string" or seen[uid] or not profile.Creatures[uid] then
				return false, "Invalid creature in offer."
			end
			seen[uid] = true
			table.insert(list, uid)
		end
		trade.Offers[player] = { Creatures = list, Coins = coins }
		resetFlags(trade)
		push(trade)
		return true, ""
	end)

	ActionService.Register("TradeReady", function(player, _profile, ready: any)
		local trade = trades[player]
		if not trade then
			return false, "You're not trading."
		end
		trade.Ready[player] = ready == true
		table.clear(trade.Confirmed)
		push(trade)
		return true, ""
	end)

	ActionService.Register("TradeConfirm", function(player)
		local trade = trades[player]
		if not trade then
			return false, "You're not trading."
		end
		local partner = partnerOf(trade, player)
		if not trade.Ready[player] or not trade.Ready[partner] then
			return false, "Both players must press Ready first."
		end
		local wait = CONFIRM_LOCK - (os.clock() - trade.ChangedAt)
		if wait > 0 then
			return false, string.format("Check the offer carefully! Confirm in %.0fs.", math.ceil(wait))
		end
		trade.Confirmed[player] = true
		if trade.Confirmed[partner] then
			execute(trade)
		else
			push(trade)
		end
		return true, ""
	end)

	ActionService.Register("TradeCancel", function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " cancelled the trade.", false)
		end
		return true, ""
	end)
end

function TradeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, player.DisplayName .. " left the game.", false)
		end
		invites[player] = nil
		lastRequest[player] = nil
		for _, list in invites do
			list[player] = nil
		end
	end)
end

return TradeService
