-- Run after the full production playback suite in a fresh Kahlua process that
-- deliberately omits the optional legacy headphone compatibility patch.
local P, M, C = SQMusic.Playback, SQMusic, SQMusic.Catalog
local player = FIXTURE_PLAYER
check(not ISTCBoomboxAction._codexHeadphones4221, "minimal combination excludes optional headphone patch")
local device, power = fixtureDevice("Tsarcraft.TCWalkman", player)
power._headphones = -1
local earbuds = player:getInventory():AddItem(instanceItem("Base.Earbuds"))
local source = earbuds:getContainer()
local inserted, ejected = 0, 0
function power:addHeadphones(item, container)
    equal(item, earbuds, "upstream passes the selected original headphone item")
    equal(container, source, "upstream passes the exact native source container")
    check(container:contains(item), "headphones still owned before native transfer")
    container:DoRemoveItem(item)
    self._headphones = 0
    inserted = inserted + 1
end
function power:addHeadphonesToInventory(inventory)
    equal(inventory, player:getInventory(), "native eject targets character inventory")
    check(self._headphones >= 0, "headphones installed before eject")
    inventory:AddItem(instanceItem("Base.Earbuds"))
    self._headphones = -1
    ejected = ejected + 1
end
local function action(mode, item)
    return ISTCBoomboxAction:new(mode, player, device, item)
end
resetAudio()
action("AddHeadphones", earbuds):performAddHeadphones()
equal(inserted, 1, "minimal combination installs headphones exactly once")
check(not source:contains(earbuds), "native installation consumes the original headphones")
local carrier
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom then
        carrier = player:getInventory():AddItem(instanceItem(fullType))
        if M.state(carrier) then break end
    end
end
check(carrier and M.state(carrier), "supported collection exists without optional patch")
action("AddMedia", carrier):performAddMedia()
check(P.play(device, player), "minimal combination plays the collection")
for _ = 1, 15 do fire("OnTick") end
check(#AUDIO.private > 0, "minimal combination creates local audio")
assertPrivate("minimal combination playing")
local before = player:getInventory():getItems():size()
action("RemoveHeadphones"):performRemoveHeadphones()
equal(ejected, 1, "minimal combination returns headphones exactly once")
equal(player:getInventory():getItems():size(), before + 1, "no duplicate or lost headphone on eject")
equal(P.isPlaying(device), false, "upstream unplug with collection bridge stops local session")
equal(P.play(device, player), false, "unplugged Walkman cannot start")
assertPrivate("minimal combination unplugged")
print("ASSERTIONS=" .. tostring(CHECKS))
return true
