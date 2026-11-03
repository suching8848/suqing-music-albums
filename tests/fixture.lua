-- Controlled Java/audio/world boundaries. Production modules are loaded separately.
CHECKS = 0
function check(value, message)
    CHECKS = CHECKS + 1
    assert(value, message or ("check " .. tostring(CHECKS)))
end
function equal(actual, expected, message)
    check(actual == expected, (message or "equality") .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end
function near(actual, expected, message)
    check(math.abs(actual - expected) < 0.00001, message)
end
function deepEqual(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function tableCount(value) local count = 0; for _ in pairs(value) do count = count + 1 end; return count end

function require(name) return true end
function getText(key, ...) return key end
function ZombRand(a, b) return b and a or 0 end
function instanceof(value, name)
    return type(value) == "table" and (value._class == name or value._classes and value._classes[name]) or false
end
function getActivatedMods() return {contains = function() return true end} end
FIXTURE_MISSING_ITEMS = {}
function getScriptManager()
    return {FindItem = function(_, fullType)
        if FIXTURE_MISSING_ITEMS[fullType] then return nil end
        if FIXTURE_REGISTERED_ITEMS and not FIXTURE_REGISTERED_ITEMS[fullType] then return nil end
        return {getFullName = function() return fullType end}
    end}
end
function isClient() return false end
function isServer() return false end
function getTimestampMs() return FIXTURE_TIME or 0 end
function getTimestamp() return (FIXTURE_TIME or 0) / 1000 end
function getGameTime() return {getWorldAgeHours = function() return (FIXTURE_TIME or 0) / 3600000 end} end
function getCore() return {getOptionSoundVolume = function() return 10 end} end
function getPlayer() return FIXTURE_PLAYER end
function getSpecificPlayer() return FIXTURE_PLAYER end

function javaList(values)
    local list = {_values = values or {}}
    function list:size() return #self._values end
    function list:get(index) return self._values[index + 1] end
    function list:add(value) table.insert(self._values, value); return true end
    function list:contains(value) for _, x in ipairs(self._values) do if x == value then return true end end return false end
    function list:remove(value)
        if type(value) == "number" then return table.remove(self._values, value + 1) end
        for i, x in ipairs(self._values) do if x == value then table.remove(self._values, i); return true end end
        return false
    end
    return list
end

Events = {}
for _, name in ipairs({"OnGameBoot", "OnGameStart", "OnCreatePlayer", "OnTick", "OnPlayerUpdate", "OnFillInventoryObjectContextMenu", "OnFillWorldObjectContextMenu", "OnServerCommand", "OnClientCommand", "OnObjectAboutToBeRemoved", "OnLoad", "OnInitGlobalModData", "OnSave", "OnDisconnect", "OnPlayerDeath", "OnEquipPrimary", "OnEquipSecondary", "OnPreDistributionMerge", "OnDistributionMerge", "OnPostDistributionMerge"}) do
    local handlers = {}
    Events[name] = {handlers = handlers, Add = function(fn) table.insert(handlers, fn) end,
        Remove = function(fn) for i = #handlers, 1, -1 do if handlers[i] == fn then table.remove(handlers, i) end end end}
end
function fire(name, ...)
    if Events[name] then for _, fn in ipairs(Events[name].handlers) do fn(...) end end
end

AUDIO = {private = {}, character = {}, world = {}, addSound = {}, commands = {}, broadcasts = {}}
local function freshNowPlaying()
    local result = {}
    setmetatable(result, {__newindex = function(target, key, value)
        if value ~= nil then table.insert(AUDIO.broadcasts, {key = key, value = value}) end
        rawset(target, key, value)
    end})
    return result
end
local function emitter(kind)
    local object = {_handles = {}, _next = 0}
    function object:playSoundImpl(name, target)
        self._next = self._next + 1
        self._handles[self._next] = name
        table.insert(AUDIO[kind], {name = name, target = target, handle = self._next})
        return self._next
    end
    function object:playSound(name) return self:playSoundImpl(name) end
    function object:isPlaying(id)
        if type(id) == "string" then for _, sound in pairs(self._handles) do if sound == id then return true end end return false end
        return self._handles[id] ~= nil
    end
    function object:stopSound(id) self._handles[id] = nil end
    function object:stopAll() self._handles = {}; self.stopAllCalls = (self.stopAllCalls or 0) + 1 end
    function object:setVolume(id, volume) self.volume = volume end
    function object:set3D(id, value) self.spatial = value end
    function object:setVolumeAll(value) self.volume = value end
    function object:setPos(x, y, z) self.x, self.y, self.z = x, y, z end
    function object:tick() end
    return object
end
function fixtureEmitter(kind) return emitter(kind) end
local manager = {}
function manager:PlaySound(name, loop, volume)
    local handle = {name = name, loop = loop, volume = volume, playing = true}
    function handle:isPlaying() return self.playing end
    function handle:stop() self.playing = false end
    function handle:setVolume(value) self.volume = value end
    table.insert(AUDIO.private, handle)
    return handle
end
function getSoundManager() return manager end
function manager:StopMusic() self.musicStopped = true end
function manager:playUISound(name) return 0 end
function getCell() return {getVehicles = function() return {toArray = function() return {} end} end} end
function addSound(source, x, y, z, radius, volume)
    table.insert(AUDIO.addSound, {source = source, x = x, y = y, z = z, radius = radius, volume = volume})
end
function sendClientCommand(...) table.insert(AUDIO.commands, {...}) end
function sendServerCommand(...) table.insert(AUDIO.commands, {...}) end
function transmitModData() end
local modData = {}
ModData = {getOrCreate = function(key) modData[key] = modData[key] or {}; return modData[key] end,
    get = function(key) return modData[key] end, transmit = function() end}
ModData.getOrCreate("trueMusicData").now_play = freshNowPlaying()

local nextID = 1000
function fixtureInventory(owner)
    local inventory = {_class = "ItemContainer", _owner = owner, _items = {}}
    function inventory:isInCharacterInventory(character) return self._owner == character end
    function inventory:getItems() return javaList(self._items) end
    function inventory:getParent() return self._owner end
    function inventory:getType() return "inventory" end
    function inventory:AddItem(item)
        if type(item) == "string" then item = instanceItem(item) end
        if FIXTURE_ADD_FAIL and FIXTURE_ADD_FAIL(item, self) then return nil end
        item._container = self; table.insert(self._items, item); return item
    end
    function inventory:DoRemoveItem(item)
        if FIXTURE_REMOVE_FAIL and FIXTURE_REMOVE_FAIL(item, self) then error("injected removal failure") end
        for i, value in ipairs(self._items) do
            if value == item then table.remove(self._items, i); item._container = nil; return end
        end
    end
    inventory.Remove = inventory.DoRemoveItem
    inventory.removeItemOnServer = inventory.DoRemoveItem
    function inventory:contains(item) for _, value in ipairs(self._items) do if value == item then return true end end return false end
    function inventory:getItemById(id) for _, value in ipairs(self._items) do if value:getID() == id then return value end end end
    function inventory:containsID(id) return self:getItemById(id) ~= nil end
    return inventory
end

function instanceItem(fullType)
    if FIXTURE_CREATE_FAIL == fullType then return nil end
    nextID = nextID + 1
    local item = {_class = "InventoryItem", _fullType = fullType, _id = nextID, _data = {}, _condition = 73,
        _name = fullType, _favorite = false, _equipped = false, _worn = false}
    function item:getID() return self._id end
    function item:getFullType() return self._fullType end
    function item:getType() return self._fullType:match("[^.]+$") end
    function item:getModule() return self._fullType:match("^[^.]+") end
    function item:getModData() return self._data end
    function item:hasModData() return tableCount(self._data) > 0 end
    function item:getContainer() return self._container end
    function item:isInPlayerInventory() return self._container and self._container._owner == FIXTURE_PLAYER or false end
    function item:getName() return self._name end
    function item:setName(name) self._name = name end
    function item:getDisplayName() return self._name end
    function item:isCustomName() return self._customName or false end
    function item:setCustomName(value) self._customName = value end
    function item:isFavorite() return self._favorite end
    function item:setFavorite(value) self._favorite = value end
    function item:isEquipped() return self._equipped end
    function item:isWorn() return self._worn end
    function item:getCondition() return self._condition end
    function item:setCondition(value) self._condition = value end
    function item:getConditionMax() return 100 end
    function item:getWeight() return 0.1 end
    function item:getActualWeight() return 0.1 end
    function item:getWorldItem() return nil end
    return item
end
InventoryItemFactory = {CreateItem = instanceItem}
function sendAddItemToContainer() end
function sendRemoveItemFromContainer() end

function fixturePlayer()
    local player = {_class = "IsoPlayer", _data = {}, _emitter = emitter("character")}
    player._inventory = fixtureInventory(player)
    function player:getInventory() return self._inventory end
    function player:getModData() return self._data end
    function player:getEmitter() return self._emitter end
    function player:getUsername() return "OfflineFixture" end
    function player:getPlayerNum() return 0 end
    function player:getX() return 10 end
    function player:getY() return 20 end
    function player:getZ() return 0 end
    function player:getVehicle() return nil end
    function player:isDead() return false end
    function player:getPrimaryHandItem() return self._primary end
    function player:getSecondaryHandItem() return self._secondary end
    function player:getWornItems() return javaList({}) end
    function player:Say(message) self._lastSpeech = message end
    function player:SetVariable(key, value) self._variables = self._variables or {}; self._variables[key] = value end
    function player:setMetabolicTarget(value) self._metabolic = value end
    function player:setIsFarming(value) self._farming = value end
    return player
end

function fixtureDevice(fullType, player)
    local device = instanceItem(fullType)
    device._classes = {InventoryItem = true, Radio = true}
    device._class = "Radio"
    local data = {_on = true, _battery = true, _power = 1, _volume = 0.6, _headphones = 0,
        _emitter = emitter("world")}
    function data:getIsTurnedOn() return self._on end
    function data:setIsTurnedOn(value) self._on = value end
    function data:getHasBattery() return self._battery end
    function data:getPower() return self._power end
    function data:getDeviceVolume() return self._volume end
    function data:setDeviceVolume(value) self._volume = value end
    function data:getHeadphoneType() return self._headphones end
    function data:getEmitter() return self._emitter end
    function data:playSound(name, volume) return self._emitter:playSoundImpl(name) end
    function data:getBattery(inventory) self._battery = false; self._power = 0 end
    function data:addBattery() self._battery = true; self._power = 1 end
    function data:addHeadphones() self._headphones = 0 end
    function data:addHeadphonesToInventory() self._headphones = -1 end
    function data:getIsBatteryPowered() return true end
    function data:canBePoweredHere() return self._gridPower or false end
    function data:getMediaType() return 0 end
    function data:isIsoDevice() return false end
    function data:setChannelRaw(value) self._channel = value end
    function data:setNoTransmit(value) self._noTransmit = value end
    function data:getParent() return device end
    function device:getDeviceData() return data end
    function device:transmitModData() end
    if player then player:getInventory():AddItem(device) end
    device:getModData().tcmusic = {deviceType = "InventoryItem", isPlaying = false, mediaSlots = {}, activeMediaSlot = 1}
    return device, data
end

function resetAudio()
    for key in pairs(AUDIO) do AUDIO[key] = {} end
    ModData.getOrCreate("trueMusicData").now_play = freshNowPlaying()
end
function assertPrivate(label)
    equal(#AUDIO.character, 0, label .. ": no character emitter playback")
    equal(#AUDIO.world, 0, label .. ": no world emitter playback")
    equal(#AUDIO.addSound, 0, label .. ": no zombie sound calls")
    equal(tableCount(ModData.getOrCreate("trueMusicData").now_play), 0, label .. ": no now_play publication")
    equal(#AUDIO.broadcasts, 0, label .. ": no transient now_play publication")
end

TCMusic = {WalkmanPlayer = {["Tsarcraft.TCWalkman"] = "tsarcraft_music_01_62"},
    ItemMusicPlayer = {["Tsarcraft.TCBoombox"] = "tsarcraft_music_01_0"}, WorldMusicPlayer = {}, VehicleMusicPlayer = {}}
GlobalMusic = {}
FIXTURE_PLAYER = fixturePlayer()
Metabolics = {LightDomestic = "LightDomestic"}
SystemDisabler = {setEnableAdvancedSoundOptions = function() end}
ISLogSystem = {logAction = function() end}
local queue = {resetQueue = function() end, onCompleted = function() end}
ISTimedActionQueue = {queued = {}, getTimedActionQueue = function() return queue end,
    add = function(action) table.insert(ISTimedActionQueue.queued, action) end}
