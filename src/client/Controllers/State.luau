--!nonstrict
-- Client-side copy of the player's profile (read-only mirror of the server) + helpers to call server actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local Formulas = require(Shared.Util.Formulas)

local UI = script.Parent.Parent.UI
local UIKit = require(UI.UIKit)
local Effects = require(UI.Effects)

local State = {}

State.Profile = nil :: any
State.Derived = nil :: Formulas.Derived?
State.Changed = Signal.new() -- (profile, previousProfile)

local actionRemote: RemoteFunction
local busy = false

local function apply(profile: any)
	if type(profile) ~= "table" then
		return
	end
	local previous = State.Profile
	State.Profile = profile
	State.Derived = Formulas.Compute(profile)
	State.Changed:Fire(profile, previous)
end

-- Calls a server action. Shows the server's message as a toast. Returns ok, message, extra.
-- silent = true suppresses the success toast (errors are always shown).
function State.Action(name: string, silent: boolean?, ...: any): (boolean, string?, any)
	local args = table.pack(...)
	local ok, success, message, extra = pcall(function()
		return actionRemote:InvokeServer(name, table.unpack(args, 1, args.n))
	end)
	if not ok then
		UIKit.Toast("Connection problem, please try again.", "error")
		return false, "error", nil
	end
	if success then
		if not silent and message and message ~= "" then
			UIKit.Toast(message, "success")
		end
	elseif message then
		UIKit.Toast(message, "error")
	end
	return success == true, message, extra
end

-- Same as Action but prevents double-submits (e.g. spam-clicking a buy button).
function State.Purchase(name: string, ...: any): boolean
	if busy then
		return false
	end
	busy = true
	local ok = State.Action(name, false, ...)
	busy = false
	if ok then
		Effects.Play("Purchase")
	end
	return ok
end

function State.Init()
	actionRemote = Net.Function("Action")
	Net.Event("DataChanged").OnClientEvent:Connect(apply)
	task.spawn(function()
		local ok, profile = pcall(function()
			return Net.Function("GetData"):InvokeServer()
		end)
		if ok and profile and not State.Profile then
			apply(profile)
		end
	end)
	Net.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		UIKit.Toast(text, kind)
	end)
	Net.Event("StatPopup").OnClientEvent:Connect(function(stat: string, amount: number)
		Effects.StatPopup(stat, amount)
	end)
end

-- Yields until the first profile arrives.
function State.WaitForProfile(): any
	while not State.Profile do
		task.wait(0.1)
	end
	return State.Profile
end

return State
