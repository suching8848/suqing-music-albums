local M, C = SQMusic, SQMusic.Catalog
local player = FIXTURE_PLAYER
local albumType
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom and #C.artists[info.artist].tracks >= 3 then albumType = fullType; break end
end
local album = player:getInventory():AddItem(instanceItem(albumType))
local state = M.state(album)
local fullA, fullB = C.tracks[state.tracks[1]].cassette, C.tracks[state.tracks[2]].cassette
local a = player:getInventory():AddItem(instanceItem(fullA))
local b = player:getInventory():AddItem(instanceItem(fullB))
local context = fixtureContext()
fire("OnFillInventoryObjectContextMenu", 0, context, {a, b})
local option = context:find("UI_SQM_Merge")
check(option and not option.notAvailable, "owned matching songs offer merge")
option.callback(option.target)
check(FIXTURE_LAST_MODAL and FIXTURE_LAST_MODAL.text:find(a:getName(), 1, true), "confirmation lists selected source")
equal(#ISTimedActionQueue.queued, 0, "opening confirmation consumes nothing and queues nothing")
FIXTURE_LAST_MODAL.callback(nil, {internal = "NO"})
equal(#ISTimedActionQueue.queued, 0, "cancel confirmation queues no action")
check(M.owned(player, a) and M.owned(player, b), "cancel preserves selected sources")
FIXTURE_LAST_MODAL.callback(nil, {internal = "YES"})
equal(#ISTimedActionQueue.queued, 1, "confirmed merge queues one timed action")
local exchange = ISTimedActionQueue.queued[1]
check(exchange:isValid(), "queued merge valid")
check(M.owned(player, a) and M.owned(player, b), "queued action has not consumed anything")
exchange.action = {setActionAnim = function() end}
exchange:start(); exchange:update(); exchange:stop()
check(M.owned(player, a) and M.owned(player, b), "cancelled timed action preserves sources")
local actual = SQMusicExchangeAction:new(player, "merge", {a, b})
check(actual:complete(), "timed action completes merge")
local total = player:getInventory():getItems():size()
check(actual:complete(), "repeat completion reports cached success")
equal(player:getInventory():getItems():size(), total, "repeat completion cannot duplicate output")
local movedA = player:getInventory():AddItem(instanceItem(fullA))
local movedB = player:getInventory():AddItem(instanceItem(fullB))
local movedAction = SQMusicExchangeAction:new(player, "merge", {movedA, movedB})
player:getInventory():DoRemoveItem(movedB)
equal(movedAction:complete(), false, "completion revalidates moved material")
check(M.owned(player, movedA), "revalidation failure leaves other material")
local protected = player:getInventory():AddItem(instanceItem(fullB)); protected:setFavorite(true)
local blocked = fixtureContext()
fire("OnFillInventoryObjectContextMenu", 0, blocked, {movedA, protected})
check(blocked:find("UI_SQM_Merge").notAvailable, "favorite disables merge menu option")

-- Containers without ordinary source media are no longer augmented.
local targets = {MusicStoreCDs = true, MusicStoreOthers = true, ElectronicStoreMusic = true, LivingRoomShelf = true, BedroomDresser = true}
local before = {}
for name, expectedWeight in pairs(targets) do
    local items = ProceduralDistributions.list[name].items
    equal(items[1], "Base.Existing", "existing loot item retained")
    near(items[2], 3.5, "existing loot weight retained")
    local seen, totalWeight = {}, 0
    for i = 3, #items, 2 do
        local kind = items[i]; local info = C.albumsByType[kind]
        check(info and not info.custom, "loot only supplies premade carriers")
        check(not seen[kind], "no duplicate loot carrier"); seen[kind] = true
        totalWeight = totalWeight + items[i + 1]
    end
    near(totalWeight, 0, "no albums added where ordinary music cannot spawn")
    before[name] = #items
end
check(M.installLoot(), "reinstall loot succeeds")
for name, count in pairs(before) do equal(#ProceduralDistributions.list[name].items, count, "loot install idempotent") end
equal(#ProceduralDistributions.list.Untouched.items, 2, "unrelated distribution untouched")
equal(ProceduralDistributions.list.Untouched.items[2], 9.25, "unrelated weight untouched")
print("ASSERTIONS=" .. tostring(CHECKS))
return true
