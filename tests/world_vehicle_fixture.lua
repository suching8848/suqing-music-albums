VEHICLES, WORLD_SQUARES, COMMAND_QUEUE = {}, {}, {}
function getVehicleById(id) return VEHICLES[id] end
function getSquare(x, y, z) return WORLD_SQUARES[x .. ":" .. y .. ":" .. z] end
function getCell()
    return {getVehicles = function()
        return {toArray = function() local values = {}; for _, v in pairs(VEHICLES) do values[#values + 1] = v end; return values end}
    end}
end
function getNumActivePlayers() return 1 end
function IsoObjectNew() return {} end
IsoObject = {new = IsoObjectNew}
function sendClientCommand(player, module, command, args)
    AUDIO.commands[#AUDIO.commands + 1] = {player, module, command, args}
    COMMAND_QUEUE[#COMMAND_QUEUE + 1] = {player, module, command, args}
end
function flushCommands()
    local pending = COMMAND_QUEUE; COMMAND_QUEUE = {}
    for _, entry in ipairs(pending) do fire("OnClientCommand", entry[2], entry[3], entry[1], entry[4]) end
end
function fixtureWorldDevice(x, y, z)
    local device, power = fixtureDevice("Tsarcraft.TCBoombox")
    device._class, device._classes = "IsoRadio", {IsoRadio = true, IsoWaveSignal = true}
    device:getModData().tcmusic.deviceType = "IsoObject"
    function device:getX() return x end
    function device:getY() return y end
    function device:getZ() return z end
    function device:getSprite() return {getName = function() return "tsarcraft_music_01_62" end} end
    local square = {getObjects = function() return javaList({device}) end}
    function device:getSquare() return square end
    WORLD_SQUARES[x .. ":" .. y .. ":" .. z] = square
    power._headphones = -1
    return device, power
end
function fixtureVehicle(id)
    local device, power = fixtureDevice("Base.RadioBlack")
    device._class, device._classes = "VehiclePart", {VehiclePart = true}
    device:getModData().tcmusic.deviceType = "VehiclePart"
    local vehicle = {_emitter = fixtureEmitter("world")}
    function vehicle:getId() return id end
    function vehicle:getSqlId() return id end
    function vehicle:getEmitter() return self._emitter end
    function vehicle:getPartById(part) if part == "Radio" then return device end end
    function vehicle:transmitPartModData() self.transmissions = (self.transmissions or 0) + 1 end
    function vehicle:updateParts() end
    function vehicle:getX() return 10 end
    function vehicle:getY() return 20 end
    function vehicle:getZ() return 0 end
    function device:getVehicle() return vehicle end
    function device:getInventoryItem() return {_fullType = "Base.RadioBlack", getFullType = function(self) return self._fullType end} end
    function device:getSquare() return nil end
    VEHICLES[id] = vehicle
    power._headphones = -1
    return device, power, vehicle
end
