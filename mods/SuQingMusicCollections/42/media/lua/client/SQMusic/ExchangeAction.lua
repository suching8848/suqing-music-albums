require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "SQMusic/Core"

SQMusicExchangeAction = ISBaseTimedAction:derive("SQMusicExchangeAction")

function SQMusicExchangeAction:isValid()
    if isClient() or isServer() then return false end
    if self.operation == "merge" then return SQMusic.canMerge(self.character, self.items) end
    return SQMusic.canSplit(self.character, self.items[1])
end

function SQMusicExchangeAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function SQMusicExchangeAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function SQMusicExchangeAction:perform()
    ISBaseTimedAction.perform(self)
end

function SQMusicExchangeAction:complete()
    if self.finished then return self.succeeded end
    self.finished = true
    local ok, reason
    if self.operation == "merge" then ok, reason = SQMusic.merge(self.character, self.items)
    else ok, reason = SQMusic.split(self.character, self.items[1]) end
    if not ok then self.character:Say(getText("UI_" .. (reason or "SQM_ExchangeFailed"))) end
    self.succeeded = ok ~= nil and ok ~= false
    return self.succeeded
end

function SQMusicExchangeAction:new(player, operation, items)
    local o = ISBaseTimedAction.new(self, player)
    o.operation, o.items = operation, {}
    for i, item in ipairs(items) do o.items[i] = item end
    o.stopOnWalk, o.stopOnRun = true, true
    o.maxTime = 40 + #items * 5
    return o
end
