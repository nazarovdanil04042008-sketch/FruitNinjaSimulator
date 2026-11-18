--!nonstrict
-- Tiny event bus for quest progress. Gameplay services call QuestBus.Fire(player, kind, amount)
-- and RewardService listens - so no service has to require RewardService (no circular requires).
-- Kinds: "Slice", "EarnCoins", "Combo5", "Golden", "Hatch", "Train", "Boss", "Build"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local QuestBus = {}
QuestBus.Progress = Signal.new() -- (player, kind, amount)

function QuestBus.Fire(player: Player, kind: string, amount: number?)
	QuestBus.Progress:Fire(player, kind, amount or 1)
end

-- Not a service: Init/Start exist so it can sit in the Services folder safely.
function QuestBus.Init() end
function QuestBus.Start() end

return QuestBus
