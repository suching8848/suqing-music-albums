local P, M, C = SQMusic.Playback, SQMusic, SQMusic.Catalog
local player = FIXTURE_PLAYER
resetAudio()
fire("OnGameStart") -- optional headphone fix, when loaded, installs before playback
fire("OnCreatePlayer", 0, player) -- real upstream music tick registers
local function ticks(n) for i = 1, n or 1 do fire("OnTick") end end
local function action(device, mode, item, slot)
    return ISTCBoomboxAction:new(mode, player, device, item, slot)
end
local function insert(device, item, slot)
    local a = action(device, "AddMedia", item, slot)
    check(a:isValidAddMedia(), "upstream accepts actual carrier type")
    a:performAddMedia()
    check(not M.owned(player, item), "real upstream insertion consumes actual carrier")
end
local function lastAudio() return AUDIO.private[#AUDIO.private] end
local albumType
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom and #C.artists[info.artist].tracks >= 3 then albumType = fullType; break end
end
check(albumType, "playlist fixture selected from real catalog")
local album = player:getInventory():AddItem(instanceItem(albumType))
local baseState = M.state(album)
local sourceType = C.tracks[baseState.tracks[1]].cassette

-- All valid old singles, including after-talk, use only the local 2D path.
local walkman, power = fixtureDevice("Tsarcraft.TCWalkman", player)
for fullType, info in pairs(C.byItem) do
    if info.kind == "cassette" then
        resetAudio()
        walkman:getModData().tcmusic.mediaItem = fullType:match("[^.]+$")
        if info.available == false or not info.privateSound then
            equal(P.play(walkman, player), false, "unavailable old single fails closed")
            equal(#AUDIO.private, 0, "bad alias never submitted")
        else
            check(P.play(walkman, player), "old single local playback: " .. fullType)
            equal(lastAudio().name, info.privateSound, "private alias selected")
            equal(lastAudio().loop, false, "whole track is not native-looped")
            ticks(110)
            assertPrivate("old single " .. fullType)
            P.stop(walkman)
        end
        assertPrivate("old single final " .. fullType)
    end
end

walkman:getModData().tcmusic.mediaItem = nil
resetAudio()
insert(walkman, album)
check(P.getState(walkman), "sidecar captured through real upstream action")
equal(P.getState(walkman).tracks[1], baseState.tracks[1], "first song retained")
check(P.play(walkman, player), "collection starts privately")
ticks(15)
check(P.step(walkman, 1), "manual next")
equal(P.getState(walkman).index, 2, "manual next updates current index")
check(P.select(walkman, 3), "click-select")
equal(P.getState(walkman).index, 3, "selected index")
check(P.setMode(walkman, "one"), "single repeat selected")
ticks(15); lastAudio().playing = false; ticks(1)
equal(P.getState(walkman).index, 3, "natural single repeat keeps index")
check(P.isPlaying(walkman), "single repeat restarts private handle")
assertPrivate("collection controls and natural repeat")

action(walkman, "StopMedia"):performStopMedia()
local stoppedCount = #AUDIO.private
ticks(150)
equal(P.isPlaying(walkman), false, "manual stop remains stopped")
equal(#AUDIO.private, stoppedCount, "manual stop cannot trigger natural auto-next")
assertPrivate("manual stop")
check(P.play(walkman, player)); ticks(15)
action(walkman, "RemoveHeadphones"):performRemoveHeadphones()
ticks(150)
equal(P.isPlaying(walkman), false, "removing headphones stops")
equal(P.play(walkman, player), false, "headphoneless Walkman cannot play")
power._headphones = 0
check(P.play(walkman, player)); ticks(15)
action(walkman, "ToggleOnOff"):performToggleOnOff()
ticks(150)
equal(P.isPlaying(walkman), false, "power-off stops")
power._on = true
check(P.play(walkman, player)); ticks(15)
action(walkman, "RemoveBattery"):performRemoveBattery()
ticks(150)
equal(P.isPlaying(walkman), false, "battery removal stops")
power._battery, power._power, power._on = true, 1, true
check(P.play(walkman, player)); ticks(15)
player:getInventory():DoRemoveItem(walkman)
ticks(150)
equal(P.isPlaying(walkman), false, "discarded Walkman stops")
assertPrivate("all Walkman stop reasons")
player:getInventory():AddItem(walkman)

-- Native table serialization plus real upstream eject/reinsert preserves data.
P.getState(walkman).mode = "shuffle"
P.getState(walkman).index = 2
local expected = M.copy(P.getState(walkman))
walkman._data.tcmusic = nativeRoundTrip(walkman._data.tcmusic)
equal(P.isPlaying(walkman), false, "loaded device has no audio session")
local before = player:getInventory():getItems():size()
action(walkman, "RemoveMedia"):performRemoveMedia()
equal(player:getInventory():getItems():size(), before + 1, "exactly one carrier ejected")
local restored = player:getInventory():getItems():get(before)
equal(restored:getFullType(), albumType, "actual album item returned")
check(deepEqual(M.state(restored), expected), "ejected album exact state preserved")
insert(walkman, restored)
check(deepEqual(P.getState(walkman), expected), "reinsert retains all playlist metadata")
assertPrivate("serialized eject and reinsert")

-- Hand-authored legacy schema-1 collected state retains old artist/source data
-- through the real insertion/ejection bridge and can still split precisely.
action(walkman, "RemoveMedia"):performRemoveMedia()
local legacy = player:getInventory():AddItem(instanceItem("SQMusic.CassetteCustom"))
local legacyState = {schema = 1, artist = baseState.artist, kind = "cassette", origin = "collected",
    tracks = {baseState.tracks[1], baseState.tracks[2]}, index = 2, mode = "loop", sources = {
        {fullType = C.tracks[baseState.tracks[1]].cassette, condition = 41, name = "legacy-a", customName = true, modData = {legacyFixture = 1}},
        {fullType = C.tracks[baseState.tracks[2]].cassette, condition = 42, name = "legacy-b", customName = true, modData = {legacyFixture = 2}},
    }}
check(M.setState(legacy, nativeRoundTrip(legacyState)), "legacy collected carrier initialized")
insert(walkman, legacy); check(P.play(walkman, player)); ticks(15); P.stop(walkman)
walkman._data.tcmusic = nativeRoundTrip(walkman._data.tcmusic)
before = player:getInventory():getItems():size()
action(walkman, "RemoveMedia"):performRemoveMedia()
local legacyBack = player:getInventory():getItems():get(before)
check(deepEqual(M.state(legacyBack), legacyState), "legacy collected state survives native device round trip without migration")
check(M.split(player, legacyBack), "legacy ejected collection still splits")
for marker = 1, 2 do
    local found = 0
    for _, item in ipairs(player:getInventory()._items) do if item:getModData().legacyFixture == marker then found = found + 1 end end
    equal(found, 1, "legacy source metadata restored exactly once")
end

local mixedSingles, mixedAuthors = {}, {}
for fullType, info in pairs(C.byItem) do
    if info.kind == "cassette" and info.artist and info.available ~= false and not mixedAuthors[info.artist] then
        mixedAuthors[info.artist] = true
        local item = player:getInventory():AddItem(instanceItem(fullType))
        item:getModData().mixedFixture = #mixedSingles + 1
        mixedSingles[#mixedSingles + 1] = item
        if #mixedSingles == 3 then break end
    end
end
local mixedCarrier = M.merge(player, mixedSingles); check(mixedCarrier, "three-author carrier created for device round trip")
local mixedExpected = M.copy(M.state(mixedCarrier))
equal(mixedExpected.artist, "Mixed", "mixed descriptor is stable")
insert(walkman, mixedCarrier); check(P.play(walkman, player)); ticks(15); P.stop(walkman)
walkman._data.tcmusic = nativeRoundTrip(walkman._data.tcmusic)
before = player:getInventory():getItems():size()
action(walkman, "RemoveMedia"):performRemoveMedia()
local mixedBack = player:getInventory():getItems():get(before)
check(deepEqual(M.state(mixedBack), mixedExpected), "three-author songs and source records survive inserted save/eject")
check(M.split(player, mixedBack), "ejected mixed collection splits")
for marker = 1, 3 do
    local found = 0
    for _, item in ipairs(player:getInventory()._items) do if item:getModData().mixedFixture == marker then found = found + 1 end end
    equal(found, 1, "each mixed artist source restored exactly once")
end
assertPrivate("legacy and mixed real device round trips")

-- Four physical slots can hold four copies of the same album with distinct state.
local box, boxPower = fixtureDevice("Tsarcraft.TCBoombox", player)
boxPower._headphones = -1
local states = {}
for slot = 1, 4 do
    local item = player:getInventory():AddItem(instanceItem(albumType))
    local state = M.state(item); state.index = slot <= #state.tracks and slot or 1
    state.mode = slot % 2 == 0 and "loop" or "order"
    states[slot] = M.copy(state)
    insert(box, item, slot)
end
for slot = 1, 4 do check(deepEqual(P.getState(box, slot), states[slot]), "independent state for slot " .. slot) end
box._data.tcmusic = nativeRoundTrip(box._data.tcmusic)
for slot = 4, 1, -1 do
    local count = player:getInventory():getItems():size()
    action(box, "RemoveMedia", nil, slot):performRemoveMedia()
    local item = player:getInventory():getItems():get(count)
    check(item and deepEqual(M.state(item), states[slot]), "four-slot native eject state " .. slot)
end
equal(tableCount(box:getModData().tcmusic.sqmusicSlots), 0, "all slot sidecars cleared after eject")

-- Managed public collection still uses an external emitter and zombie sound calls.
resetAudio()
local loud = player:getInventory():AddItem(instanceItem(albumType))
insert(box, loud, 1)
check(P.play(box, player), "public collection starts")
ticks(110)
check(#AUDIO.character > 0, "ordinary carried boombox retains external emitter")
check(#AUDIO.addSound > 0, "ordinary boombox retains zombie sound events")
equal(#AUDIO.private, 0, "ordinary speaker uses no private route")
P.stop(box)

-- An untouched native single on a non-managed boombox still follows upstream.
resetAudio()
action(box, "RemoveMedia", nil, 1):performRemoveMedia()
local single = player:getInventory():AddItem(instanceItem(sourceType))
insert(box, single, 1)
action(box, "TogglePlayMedia"):performTogglePlayMedia()
check(#AUDIO.character > 0, "native single boombox delegates to upstream playback")
check(tableCount(ModData.getOrCreate("trueMusicData").now_play) > 0, "native ordinary speaker retains upstream broadcast record")
action(box, "TogglePlayMedia"):performTogglePlayMedia()
P.stopAll()
print("ASSERTIONS=" .. tostring(CHECKS))
return true
