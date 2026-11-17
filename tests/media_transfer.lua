local player, P, M, C = FIXTURE_PLAYER, SQMusic.Playback, SQMusic, SQMusic.Catalog
local inventory = player:getInventory()
local queued = ISTimedActionQueue.queued
local function noop() end
local function yes() return true end
local function no() return false end
player.hasTrait, player.isWearingAwkwardGloves, player.isTimedActionInstant = no, no, no
function player:getJoypadBind() return -1 end
function player:getCurrentSquare() return nil end

local function configureContainer(container, kind)
    function container:getType() return kind end
    container.isVehicleSeat, container.isInside = no, no
    container.isExistYet, container.isRemoveItemAllowed, container.isItemAllowed = yes, yes, yes
    container.hasRoomFor, container.setDrawDirty, container.setHasBeenLooted = yes, noop, noop
    container.getPutSound, container.removeItemOnServer = noop, nil
    return container
end
configureContainer(inventory, "inventory")
local function carrier(fullType, source)
    local item = source:AddItem(instanceItem(fullType))
    item.isHumanCorpse, item.getIsCraftingConsumed, item.setJobDelta = no, no, noop
    function item:getWorldItem() return self.worldItem end
    function item:setWorldItem(worldItem) self.worldItem = worldItem end
    return item
end
local function request(panel, item, slot)
    panel:addMedia({item}, slot)
    return table.remove(queued, 1)
end
local function performTransfer(action)
    check(action.Type == "ISInventoryTransferAction", "B42 native inventory action")
    action.action = {stopTimedActionAnim = noop, setLoopedAction = noop}
    action.getNotFullFloorSquare = noop -- destination is the player's inventory
    action:perform()
end

local walkToSource, walkToDevice, adjacent = 0, 0, true
local floorSquare, deviceSquare = {}, {}
luautils = {
    walkToContainer = function(_, playerNum)
        equal(playerNum, player:getPlayerNum(), "correct player walks to container")
        walkToSource = walkToSource + 1
        adjacent = false
        return true
    end,
    walkAdj = function(character, square, keepActions)
        equal(character, player, "correct player walks to floor or device")
        check(keepActions, "keep the existing timed action queue")
        if square == floorSquare then
            walkToSource = walkToSource + 1
            adjacent = false
        else
            equal(square, deviceSquare, "device walk targets the original boombox")
            check(not adjacent, "device walk calculated after going to the floor or container")
            walkToDevice = walkToDevice + 1
            adjacent = true
        end
        return true
    end,
}
getSpecificPlayer = function() return player end
fire("OnGameStart")
local albumType, singleType, vinylType
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom then albumType = fullType; break end
end
for fullType, info in pairs(C.byItem) do
    if not singleType and info.kind == "cassette" and info.available ~= false then singleType = fullType end
    if not vinylType and info.kind == "vinyl" and info.available ~= false then vinylType = fullType end
end
check(albumType and singleType and vinylType, "real registered cassette album, single and vinyl")
local device = fixtureDevice("Tsarcraft.TCBoombox", nil)
device._classes = {IsoObject = true}
device:getModData().tcmusic.deviceType = "IsoObject"
function device:getSquare() return deviceSquare end
function device:getX() return 10 end
function device:getY() return 20 end
function device:getZ() return 0 end
device:getDeviceData():getEmitter().stopAll = noop
function device:getSprite() return {getName = function() return "FixtureBoombox" end} end
TCMusic.WorldMusicPlayer.FixtureBoombox = GlobalMusic[singleType:match("[^.]+$")]
local panel = setmetatable({player = player, device = device, deviceType = "IsoObject", isBoombox = true}, {__index = TCRWMMedia})
local function slots() return TCMusic.getBoomboxMediaSlots(device:getModData().tcmusic) end

local floor = configureContainer(fixtureInventory(nil), "floor")
local album = carrier(albumType, floor)
local worldItem = {getSquare = function() return floorSquare end}
album:setWorldItem(worldItem)
local removals = 0
function floorSquare:transmitRemoveItemFromSquare(actual)
    equal(actual, worldItem, "same floor object removed")
    removals = removals + 1
end
function floorSquare:removeWorldObject(actual) equal(actual, worldItem, "same ground object removed locally") end
local saved = M.copy(M.state(album))
saved.index, saved.mode = 2, "one"
check(M.setState(album, saved), "retain non-default album state")

local direct = ISTCBoomboxAction:new("AddMedia", player, device, album, 1)
direct:perform()
equal(slots()[1], nil, "unowned direct action cannot write a slot")
equal(album:getWorldItem(), worldItem, "unowned direct action cannot remove world object")
check(floor:contains(album), "unowned direct action cannot remove carrier")

local pickup = request(panel, album, 1)
equal(#queued, 0, "insertion waits for completed transfer")
equal(walkToDevice, 0, "no early device walk")
performTransfer(pickup)
equal(removals, 1, "one native ground removal")
equal(album:getWorldItem(), nil, "native transfer clears world reference")
check(M.owned(player, album), "same album transferred, with its data")
equal(walkToDevice, 1, "walk back to the device after floor transfer")
local insert = table.remove(queued, 1)
equal(insert.secondaryItem, album, "upstream insertion receives exact original album")
insert:perform()
check(not M.owned(player, album), "album is consumed once")
check(deepEqual(P.getState(device, 1), saved), "album data preserved on device")
insert:perform()
check(deepEqual(P.getState(device, 1), saved), "replaying stale action does not change state")

local before = inventory:getItems():size()
ISTCBoomboxAction:new("RemoveMedia", player, device, nil, 1):perform()
equal(inventory:getItems():size(), before + 1, "ejection returns exactly one copy")
check(deepEqual(M.state(inventory:getItems():get(before)), saved), "ejection retains album state")

local external = configureContainer(fixtureInventory(nil), "counter")
local single = carrier(singleType, external)
inventory.hasRoomFor = no
performTransfer(request(panel, single, 2))
equal(#queued, 0, "failed pickup never inserts")
check(external:contains(single), "failed pickup preserves the source item")
inventory.hasRoomFor = yes
performTransfer(request(panel, single, 2))
table.remove(queued, 1):perform()
equal(slots()[2], single:getType(), "external regular cassette uses upstream placement")
equal(P.getState(device, 2), nil, "regular cassette has no album sidecar")
check(not external:contains(single) and not inventory:contains(single), "external single consumed once")

local bag = configureContainer(fixtureInventory(player), "bag")
local nested = carrier(singleType, bag)
local originalWalk = panel.doWalkTo
panel.doWalkTo = yes -- already adjacent, with no pickup or movement needed
local walks = walkToSource
request(panel, nested, 3):perform()
panel.doWalkTo = originalWalk
equal(walkToSource, walks, "player's nested bag uses existing direct action")
equal(slots()[3], nested:getType(), "nested cassette inserted")
check(not bag:contains(nested), "nested item removed once")

local vinylDevice = fixtureDevice("Fixture.VinylPlayer", player)
TCMusic.ItemMusicPlayer["Fixture.VinylPlayer"] = GlobalMusic[vinylType:match("[^.]+$")]
local vinylPanel = setmetatable({player = player, device = vinylDevice, deviceType = "InventoryItem"}, {__index = TCRWMMedia})
local record = carrier(vinylType, external)
local vinylPickup = request(vinylPanel, record)
vinylPanel.device = fixtureDevice("Fixture.Replacement", player)
performTransfer(vinylPickup)
equal(#queued, 0, "repurposed UI cannot insert into a different device")
check(M.owned(player, record), "picked-up record stays in inventory after UI change")
vinylPanel.device = vinylDevice
request(vinylPanel, record):perform()
equal(vinylDevice:getModData().tcmusic.mediaItem, record:getType(), "regular vinyl insertion still uses upstream")
check(not M.owned(player, record), "vinyl consumed once")
