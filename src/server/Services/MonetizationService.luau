--!nonstrict
-- Robux store (game passes + developer products) and redeemable codes.
-- IDs live in Config/Monetization.luau (0 = not set up yet -> safely skipped).
--
-- Game passes are re-checked with Roblox on every join and after an in-game purchase, then stored in
-- profile.Passes so Formulas (shared with the client) can apply the bonuses.
-- Developer products use ProcessReceipt with the receipt id stored in the profile, so a product is
-- never granted twice even if Roblox retries the callback.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local ActionService = require(script.Parent.ActionService)
local ProgressionService = require(script.Parent.ProgressionService)
local EquipmentService = require(script.Parent.EquipmentService)
local EggService = require(script.Parent.EggService)
local RewardService = require(script.Parent.RewardService)

local MonetizationService = {}

local function passesChanged(player: Player)
	DataService.Replicate(player)
	ProgressionService.ApplyCharacterStats(player)
	EquipmentService.Refresh(player, false)
	local profile = DataService.Get(player)
	player:SetAttribute("VIP", profile and profile.Passes.VIP == true or false)
end

local function refreshPasses(player: Player, profile: any)
	for _, pass in Monetization.Passes do
		if pass.PassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.PassId)
			end)
			if ok then
				profile.Passes[pass.Id] = owns or nil
			end
		end
	end
	passesChanged(player)
end

local function grantProduct(player: Player, profile: any, productKey: string): string
	if productKey == "CoinsSmall" or productKey == "CoinsMedium" or productKey == "CoinsLarge" then
		local coins = math.floor(Monetization.CoinPackBase[productKey] * (1 + profile.Level * 0.35) * (1 + profile.Rebirths))
		ProgressionService.AddCoins(player, coins)
		return "+" .. Format.Short(coins) .. " coins"
	elseif productKey == "HatchAll" then
		local n = EggService.HatchAllNow(player)
		return "Hatched " .. n .. " eggs"
	elseif productKey == "LuckBoost" then
		profile.Boosts.Luck = math.max(profile.Boosts.Luck or 0, os.time()) + 30 * 60
		DataService.Replicate(player)
		return "3x Luck for 30 minutes"
	end
	return ""
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local profile = DataService.WaitFor(player, 15)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if table.find(profile.Receipts, info.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		local product
		for _, p in Monetization.Products do
			if p.ProductId == info.ProductId and p.ProductId > 0 then
				product = p
			end
		end
		if not product then
			warn("[MonetizationService] Unknown product id " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, result = pcall(grantProduct, player, profile, product.Id)
		if not ok then
			warn("[MonetizationService] Grant failed: " .. tostring(result))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(profile.Receipts, info.PurchaseId)
		DataService.Replicate(player)
		task.spawn(DataService.SaveNow, player)
		ProgressionService.Notify(player, "💎 Thank you! " .. product.DisplayName .. ": " .. result, "success")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local profile = DataService.Get(player)
		for _, pass in Monetization.Passes do
			if pass.PassId == passId and profile then
				profile.Passes[pass.Id] = true
				passesChanged(player)
				ProgressionService.Notify(player, "💎 " .. pass.DisplayName .. " unlocked! Thank you for supporting the game!", "rare")
			end
		end
	end)

	ActionService.Register("RedeemCode", function(player, profile, text: any)
		if type(text) ~= "string" or #text > 30 then
			return false, "Invalid code."
		end
		local code = text:upper():gsub("%s", "")
		local reward = Monetization.Codes[code]
		if not reward then
			return false, "That code doesn't exist."
		end
		if reward.Expires > 0 and os.time() > reward.Expires then
			return false, "That code has expired."
		end
		if profile.RedeemedCodes[code] then
			return false, "You already used this code."
		end
		profile.RedeemedCodes[code] = true
		return true, "🎟️ Code " .. code .. ": " .. RewardService.Give(player, profile, reward)
	end)
end

function MonetizationService.Start()
	DataService.ProfileLoaded:Connect(function(player, profile)
		task.spawn(refreshPasses, player, profile)
	end)
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile then
			task.spawn(refreshPasses, player, profile)
		end
	end
end

return MonetizationService
