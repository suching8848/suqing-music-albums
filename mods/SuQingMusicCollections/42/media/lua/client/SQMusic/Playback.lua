require "SQMusic/Core"
require "RadioCom/ISTCBoomboxAction"

-- All audio handles are session-local. Only carrier descriptors and playlist
-- choices enter ModData; no Java object/audio handle is serialized.
SQMusic.Playback = SQMusic.Playback or {}
local P = SQMusic.Playback
local sessions = {}
local drained = {}
local ejectContext
local installed = false
local tick = 0

local function music(device)
    if not device then return nil end
    local data = device:getModData()
    return data and data.tcmusic
end

local function boombox(device)
    return device and TCMusic.isBoomboxDevice(device)
end

local function walkman(device)
    local data = music(device)
    return data and data.deviceType == "InventoryItem" and TCMusic.WalkmanPlayer[device:getFullType()] ~= nil
end

local function slotFor(device, slot)
    local data = music(device)
    return boombox(device) and (slot or data.activeMediaSlot or 1) or 1
end

local function carrierFor(device, slot)
    local data = music(device)
    if not data then return nil end
    if boombox(device) then return TCMusic.getBoomboxMediaSlots(data)[slotFor(device, slot)] end
    return data.mediaItem
end

local function fullType(kind)
    if not kind then return nil end
    if kind:find("%.") then return kind end
    local catalog = SQMusic.Catalog
    if catalog and catalog.albumsByType and catalog.albumsByType["SQMusic." .. kind] then return "SQMusic." .. kind end
    return "Tsarcraft." .. kind
end

local function isCollection(kind)
    local catalog = SQMusic.Catalog
    return kind and catalog and catalog.albumsByType and catalog.albumsByType[fullType(kind)] ~= nil
end

local function mediaEntry(device, slot, create)
    local data = music(device)
    local carrier = carrierFor(device, slot)
    if not data or not carrier then return nil end
    local index = slotFor(device, slot)
    data.sqmusicSlots = data.sqmusicSlots or {}
    local saved = data.sqmusicSlots[index]
    if saved and saved.carrierType == carrier then return saved end
    if create and isCollection(carrier) then
        local item = TCMusic.createMediaItem(carrier)
        local state = item and SQMusic.state(item)
        if state then
            saved = { carrierType = carrier, fullType = fullType(carrier), state = SQMusic.copy(state) }
            data.sqmusicSlots[index] = saved
            return saved
        end
    end
    return nil
end

function P.getState(device, slot)
    local entry = mediaEntry(device, slot, true)
    return entry and entry.state
end

function P.isManaged(device)
    local data = music(device)
    local headphones = data and data.deviceType == "InventoryItem" and device:getDeviceData():getHeadphoneType() >= 0
    return sessions[device] ~= nil or walkman(device) or headphones or isCollection(carrierFor(device)) or P.getState(device) ~= nil
end

function P.isPlaying(device)
    return sessions[device] ~= nil
end

local function transmit(device)
    local data = music(device)
    if not data then return end
    if data.deviceType == "IsoObject" then device:transmitModData()
    elseif data.deviceType == "VehiclePart" then device:getVehicle():transmitPartModData(device) end
end

local function clearPublicRecord(device, character)
    local data = music(device)
    if not ModData or not data then return end
    local global = ModData.getOrCreate("trueMusicData")
    if not global or not global.now_play then return end
    if data.deviceType == "IsoObject" then
        global.now_play["#" .. device:getX() .. "-" .. device:getY() .. "-" .. device:getZ()] = nil
        return
    end
    if not character or data.deviceType ~= "InventoryItem" then return end
    local key = character:getUsername()
    local entry = global.now_play[key]
    if entry and entry.itemid == device:getID() then global.now_play[key] = nil end
end

function P.stop(device)
    local session = sessions[device]
    if session then
        if session.audio then session.audio:stop()
        elseif session.emitter and session.handle then session.emitter:stopSound(session.handle) end
        clearPublicRecord(device, session.character)
        sessions[device] = nil
    end
    local data = music(device)
    if data then data.isPlaying = false end
end

local function privateDevice(device)
    local data = music(device)
    return walkman(device) or (data and data.deviceType == "InventoryItem" and device:getDeviceData():getHeadphoneType() >= 0)
end

local function sounds(device)
    local state = P.getState(device)
    if state then return SQMusic.sound(state) end
    local catalog = SQMusic.Catalog
    local entry = catalog and catalog.byItem and catalog.byItem[fullType(carrierFor(device))]
    if entry and entry.available ~= false then return entry.sound, entry.privateSound end
    return nil, nil
end

local function canPlay(device, character)
    local data = music(device)
    local power = device and device:getDeviceData()
    if not data or not power or not carrierFor(device) or not power:getIsTurnedOn() then return false end
    if not ((power:getIsBatteryPowered() and power:getPower() > 0) or power:canBePoweredHere()) then return false end
    if walkman(device) and power:getHeadphoneType() < 0 then return false end
    if data.needSpeaker and not data.connectTo then return false end
    if data.deviceType == "InventoryItem" and (not character or character:isDead() or not device:isInPlayerInventory()) then return false end
    if data.deviceType == "IsoObject" and not device:getSquare() then return false end
    if data.deviceType == "VehiclePart" and not device:getVehicle() then return false end
    return true
end

local function volumeFor(session)
    local volume = session.device:getDeviceData():getDeviceVolume()
    if session.kind == "VehiclePart" then
        local vehicle = session.device:getVehicle()
        local player = session.character or getPlayer()
        if player and player:getVehicle() == vehicle then return volume, false end
        return volume * (session.windowsOpen and 0.6 or 0.2), true
    end
    return volume * 0.4, true
end

local function fail(device, character, message)
    P.stop(device)
    if character and character.Say then character:Say(message) end
    print("[SuQingMusic] " .. message)
    return false
end

local function beginAudio(session)
    local device = session.device
    local manager = getSoundManager()
    if manager.StopMusic then manager:StopMusic() end
    if session.kind == "VehiclePart" then device:getDeviceData():setChannelRaw(100) end
    if session.private then
        session.audio = manager:PlaySound(session.privateSound, false, 1.0)
        if not session.audio then return false end
        session.audio:setVolume(device:getDeviceData():getDeviceVolume() * 0.4)
    else
        if session.kind == "InventoryItem" then session.emitter = session.character:getEmitter()
        elseif session.kind == "VehiclePart" then session.emitter = device:getVehicle():getEmitter()
        else session.emitter = device:getDeviceData():getEmitter() end
        if not session.emitter then return false end
        session.handle = session.emitter:playSoundImpl(session.sound, nil)
        if not session.handle or session.handle == 0 then return false end
        local volume, spatial = volumeFor(session)
        session.emitter:setVolume(session.handle, volume)
        session.emitter:set3D(session.handle, spatial)
    end
    session.started = tick
    return true
end

function P.play(device, character)
    if isClient() or isServer() then return false end
    character = character or getPlayer()
    if not canPlay(device, character) then return false end
    local data = music(device)
    if data.isPlaying then drained[device] = nil end
    local sound, privateSound = sounds(device)
    local private = privateDevice(device)
    if not sound or (private and not privateSound) then
        return fail(device, character, getText("UI_SQMusic_MissingTrack"))
    end
    P.stop(device)
    if data.deviceType == "InventoryItem" then
        for other, session in pairs(sessions) do
            if session.kind == "InventoryItem" and session.character == character then P.stop(other) end
        end
        -- Remove any pre-existing native single-track session before changing
        -- ownership. New private playback never creates an emitter or now_play.
        local playerData = character:getModData()
        if playerData.tcmusicid then
            character:getEmitter():stopSound(playerData.tcmusicid)
            playerData.tcmusicid = nil
        end
        local global = ModData.getOrCreate("trueMusicData")
        if global and global.now_play then global.now_play[character:getUsername()] = nil end
    end
    local session = {device = device, character = character, kind = data.deviceType, private = private, sound = sound, privateSound = privateSound, started = tick}
    -- True Music's old tick sees no public record/isPlaying and cannot attempt
    -- to play the collection's physical item ID as if it were one audio file.
    data.isPlaying = false
    clearPublicRecord(device, character)
    sessions[device] = session
    if not private and session.kind ~= "InventoryItem" and not drained[device] then
        -- Upstream keeps closed-over emitter tables for up to 100 ticks. Let
        -- its normal cleanup finish before starting a new handle on that device.
        session.pending = tick + 110
    elseif not beginAudio(session) then
        return fail(device, character, getText("UI_SQMusic_PlaybackFailed"))
    end
    transmit(device)
    return true
end

function P.step(device, direction)
    local state = P.getState(device)
    if not state or not SQMusic.advance(state, direction or 1, false) then return false end
    local session = sessions[device]
    local character = session and session.character or getPlayer()
    local playing = session ~= nil
    P.stop(device)
    transmit(device)
    if playing then return P.play(device, character) end
    return true
end

function P.select(device, index)
    local state = P.getState(device)
    if not state or type(index) ~= "number" or index < 1 or index > #state.tracks then return false end
    state.index = math.floor(index)
    state.shuffleBag = nil
    state.history = nil
    local session = sessions[device]
    local character = session and session.character or getPlayer()
    local playing = session ~= nil
    P.stop(device)
    transmit(device)
    if playing then return P.play(device, character) end
    return true
end

function P.setMode(device, mode)
    if mode ~= "order" and mode ~= "loop" and mode ~= "one" and mode ~= "shuffle" then return false end
    local state = P.getState(device)
    if not state then return false end
    if not SQMusic.setMode(state, mode) then return false end
    transmit(device)
    return true
end

local function windowsOpen(vehicle)
    for _, id in ipairs({"WindowFrontLeft", "WindowFrontRight", "WindowMiddleLeft", "WindowMiddleRight", "WindowRearLeft", "WindowRearRight", "Windshield", "WindshieldRear"}) do
        local part = vehicle:getPartById(id)
        if part and (not part:getInventoryItem() or (part:getWindow() and part:getWindow():isOpen())) then return true end
    end
    return false
end

local function publicNoise(session)
    if session.private then return end
    local device = session.device
    local power = device:getDeviceData()
    local object = device
    local radius = 25
    if session.kind == "InventoryItem" then object = session.character
    elseif session.kind == "VehiclePart" then
        object = device:getVehicle()
        session.windowsOpen = windowsOpen(object)
        radius = session.windowsOpen and 30 or 10
    end
    addSound(nil, object:getX(), object:getY(), object:getZ(), radius * power:getDeviceVolume(), 1)
end

function P.update()
    if not getPlayer() then P.stopAll(); return end
    tick = tick + 1
    for device, session in pairs(sessions) do
        if not canPlay(device, session.character) or privateDevice(device) ~= session.private then
            P.stop(device)
        elseif session.pending then
            if tick >= session.pending then
                session.pending = nil
                drained[device] = true
                if not beginAudio(session) then fail(device, session.character, getText("UI_SQMusic_PlaybackFailed")) end
            end
        else
            music(device).isPlaying = false
            local playing = session.audio and session.audio:isPlaying() or (session.emitter and session.emitter:isPlaying(session.handle))
            if not playing and tick - session.started < 10 then
                -- FMOD can report false briefly while an Ogg stream is opening.
            elseif not playing then
                local state = P.getState(device)
                local character = session.character
                P.stop(device)
                if state and SQMusic.advance(state, 1, true) then
                    P.play(device, character)
                elseif boombox(device) and music(device).autoplay then
                    local data = music(device)
                    local nextSlot = TCMusic.getNextBoomboxMediaSlot(data, data.activeMediaSlot)
                    if nextSlot and nextSlot ~= data.activeMediaSlot then
                        TCMusic.setBoomboxMediaSlot(data, nextSlot)
                        P.play(device, character)
                    end
                end
            else
                local volume, spatial = volumeFor(session)
                if session.audio then session.audio:setVolume(volume)
                else session.emitter:setVolume(session.handle, volume); session.emitter:set3D(session.handle, spatial) end
                if tick % 50 == 0 then publicNoise(session) end
            end
        end
    end
end

function P.stopAll()
    for device in pairs(sessions) do P.stop(device) end
    drained = {}
end

function P.pauseSaved(character)
    if not character or isClient() or isServer() then return end
    local function pauseInventory(container)
        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if P.isManaged(item) then
                local data = music(item)
                if data then data.isPlaying = false end
                clearPublicRecord(item, character)
            end
            if item.getInventory then pauseInventory(item:getInventory()) end
        end
    end
    pauseInventory(character:getInventory())
end

local function install()
    if installed or isClient() or isServer() then return end
    installed = true
    local Action = ISTCBoomboxAction
    local oldFullType = TCMusic.getMediaFullType
    TCMusic.getMediaFullType = function(carrier)
        if isCollection(carrier) then return fullType(carrier) end
        return oldFullType(carrier)
    end
    local oldCreate = TCMusic.createMediaItem
    TCMusic.createMediaItem = function(carrier)
        local item
        if isCollection(carrier) then item = instanceItem(fullType(carrier)) else item = oldCreate(carrier) end
        if item and ejectContext and ejectContext.carrierType == carrier then
            SQMusic.setState(item, ejectContext.state)
        end
        return item
    end

    local addMedia = Action.performAddMedia
    function Action:performAddMedia()
        local item = self.secondaryItem
        local state = item and SQMusic.state(item)
        local captured = state and SQMusic.copy(state)
        local carrier = item and item:getType()
        local container = item and item:getContainer()
        local allowed = self:isValidAddMedia()
        addMedia(self)
        local data = music(self.device)
        local vehicleCommitted = data and data.deviceType == "VehiclePart" and container and not container:contains(item)
        if allowed and captured and (vehicleCommitted or carrierFor(self.device, self.mediaSlot) == carrier) then
            data.sqmusicSlots = data.sqmusicSlots or {}
            data.sqmusicSlots[slotFor(self.device, self.mediaSlot)] = {carrierType = carrier, fullType = item:getFullType(), state = captured}
            if vehicleCommitted then data.mediaItem = carrier end
            if slotFor(self.device, self.mediaSlot) == slotFor(self.device) then data.isPlaying = false end
            transmit(self.device)
        end
    end

    local removeMedia = Action.performRemoveMedia
    function Action:performRemoveMedia()
        local device = self.device
        local index = slotFor(device, self.mediaSlot)
        local saved = mediaEntry(device, index, true)
        local active = index == slotFor(device)
        local playing = P.isPlaying(device)
        if active and (saved or walkman(device)) then P.stop(device) end
        local previous = ejectContext
        ejectContext = saved
        local data = music(device)
        local autoplay = data.autoplay
        if saved and not active then data.autoplay = false end
        local ok, failure = pcall(removeMedia, self)
        ejectContext = previous
        data.autoplay = autoplay
        if not ok then error(failure) end
        if saved and carrierFor(device, index) ~= saved.carrierType then
            music(device).sqmusicSlots[index] = nil
            transmit(device)
        end
        if active and playing and boombox(device) and music(device).autoplay and carrierFor(device) then P.play(device, self.character) end
    end

    local toggle = Action.performTogglePlayMedia
    function Action:performTogglePlayMedia()
        if P.isManaged(self.device) then
            if P.isPlaying(self.device) then P.stop(self.device) else P.play(self.device, self.character) end
        else drained[self.device] = nil; toggle(self) end
    end
    local start, stop = Action.performStartMedia, Action.performStopMedia
    function Action:performStartMedia()
        if P.isManaged(self.device) then if not P.isPlaying(self.device) then P.play(self.device, self.character) end else start(self) end
    end
    function Action:performStopMedia()
        if P.isManaged(self.device) then P.stop(self.device) else stop(self) end
    end
    local validStart, validStop = Action.isValidStartMedia, Action.isValidStopMedia
    function Action:isValidStartMedia()
        if P.isManaged(self.device) then return not P.isPlaying(self.device) and canPlay(self.device, self.character) end
        return validStart(self)
    end
    function Action:isValidStopMedia()
        if P.isManaged(self.device) then return P.isPlaying(self.device) end
        return validStop(self)
    end
    local changed = Action.performChangeMedia
    function Action:performChangeMedia(direction)
        if P.isManaged(self.device) then
            local playing = P.isPlaying(self.device)
            P.stop(self.device)
            local data = music(self.device)
            local nextSlot = direction < 0 and TCMusic.getPreviousBoomboxMediaSlot(data, data.activeMediaSlot) or TCMusic.getNextBoomboxMediaSlot(data, data.activeMediaSlot)
            if nextSlot then TCMusic.setBoomboxMediaSlot(data, nextSlot) end
            if playing then P.play(self.device, self.character) end
        else changed(self, direction) end
    end

    -- The existing headphone patch retains ownership of item/battery transfers.
    -- These wrappers only own our audio handles and never replace its inventory operations.
    for _, method in ipairs({"performToggleOnOff", "performRemoveBattery", "performRemoveHeadphones"}) do
        local original = Action[method]
        Action[method] = function(action)
            if P.isManaged(action.device) then P.stop(action.device) end
            return original(action)
        end
    end
    local setVolume = Action.performSetVolume
    function Action:performSetVolume()
        if P.isManaged(self.device) then
            if self:isValidSetVolume() then self.deviceData:setDeviceVolume(self.secondaryItem) end
        else setVolume(self) end
    end
    local whenPlaying = Action.actionWhenPlaying
    function Action:actionWhenPlaying()
        if P.isManaged(self.device) then music(self.device).isPlaying = false; return end
        return whenPlaying(self)
    end
    local addHeadphones = Action.performAddHeadphones
    function Action:performAddHeadphones()
        local playing = P.isPlaying(self.device)
        if playing then P.stop(self.device) end
        addHeadphones(self)
        if playing then P.play(self.device, self.character) end
    end
    if TCRWMMedia then
        local mediaName, mediaNameForType = TCRWMMedia.getMediaName, TCRWMMedia.getMediaNameForType
        function TCRWMMedia:getMediaNameForType(carrier)
            if isCollection(carrier) then
                local item = instanceItem(fullType(carrier))
                return item and item:getDisplayName() or nil
            end
            return mediaNameForType(self, carrier)
        end
        function TCRWMMedia:getMediaName(device)
            device = device or self.device
            local state = P.getState(device)
            if state then
                local id = state.tracks[state.index]
                local track = SQMusic.Catalog.tracks[id]
                local title = SQMusic.trackTitle(id)
                if SQMusic.isMixed(state) and track then title = title .. " - " .. SQMusic.artistName(track.artist) end
                return title
            end
            return mediaName(self, device)
        end
        local prompt = TCRWMMedia.getAPrompt
        function TCRWMMedia:getAPrompt()
            if self.device and P.isManaged(self.device) then return P.isPlaying(self.device) and self.textStop or self.textPlay end
            return prompt(self)
        end
        local update = TCRWMMedia.update
        function TCRWMMedia:update()
            update(self)
            if self.device and P.isManaged(self.device) then
                local playing = P.isPlaying(self.device)
                if self.toggleOnOffButton then self.toggleOnOffButton:setTitle(playing and self.textStop or self.textPlay) end
                if self.transportButtons then
                    self.transportButtons[2]:setEnable(not playing and canPlay(self.device, self.player))
                    self.transportButtons[3]:setEnable(playing)
                end
                if playing and self.lcd then self.lcd:setText(self:getMediaText()); self.lcd:setDoScroll(true) end
            end
        end
    end
    -- Old native Walkman sessions can have saved broadcast records. A new game
    -- session always starts paused; discard stale playback IDs, retaining media.
    P.pauseSaved(getPlayer())
    print("[SuQingMusic] single-player playback bridge installed; personal audio uses local 2D aliases.")
end

P.install = install
Events.OnGameStart.Add(install)
Events.OnTick.Add(P.update)
Events.OnCreatePlayer.Add(function(_, character) P.pauseSaved(character or getPlayer()) end)
if Events.OnDisconnect then Events.OnDisconnect.Add(P.stopAll) end
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(function(character)
    for device, session in pairs(sessions) do if session.character == character then P.stop(device) end end
end) end
