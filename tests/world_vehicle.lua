local M, P, C = SQMusic, SQMusic.Playback, SQMusic.Catalog
local player = FIXTURE_PLAYER
fire("OnGameStart"); fire("OnCreatePlayer", 0, player)
local function ticks(n) for i = 1, n or 1 do fire("OnTick") end end
local function action(device, mode, item, slot) return ISTCBoomboxAction:new(mode, player, device, item, slot) end
local albumType
for fullType, info in pairs(C.albumsByType) do
    if info.kind == "cassette" and not info.custom and #C.artists[info.artist].tracks >= 4 then albumType = fullType; break end
end
local prototype = M.state(instanceItem(albumType))
local singleType = C.tracks[prototype.tracks[1]].cassette
local function owned(fullType) return player:getInventory():AddItem(instanceItem(fullType)) end
local function insert(device, item, slot)
    local call = action(device, "AddMedia", item, slot)
    check(call:isValidAddMedia(), "upstream accepts target device and media")
    call:performAddMedia(); check(not M.owned(player, item), "actual carrier consumed on insertion")
end

-- Leaving a native single playing in slot 1 must not be interrupted by slot 2.
local box, boxPower = fixtureDevice("Tsarcraft.TCBoombox", player); boxPower._headphones = -1
insert(box, owned(singleType), 1)
action(box, "TogglePlayMedia"):performTogglePlayMedia()
check(box:getModData().tcmusic.isPlaying, "native single is playing before inactive insert")
local existing = player:getModData().tcmusicid
insert(box, owned(albumType), 2)
check(box:getModData().tcmusic.isPlaying, "inactive collection insert preserves native playing flag")
check(player:getEmitter():isPlaying(existing), "inactive insert preserves native emitter")
action(box, "RemoveMedia", nil, 2):performRemoveMedia()
check(box:getModData().tcmusic.isPlaying, "inactive collection eject preserves native playing flag")
action(box, "TogglePlayMedia"):performTogglePlayMedia()
resetAudio()

-- Establish the real upstream world tick's closed-over local emitter table.
local world, worldPower = fixtureWorldDevice(10, 20, 0)
insert(world, owned(singleType), 1)
action(world, "TogglePlayMedia"):performTogglePlayMedia()
ticks(100)
check(tableCount(ModData.getOrCreate("trueMusicData").now_play) > 0, "native world broadcast established")
local emitter = worldPower:getEmitter()
local oldStops = emitter.stopAllCalls or 0
action(world, "RemoveMedia", nil, 1):performRemoveMedia()
insert(world, owned(albumType), 1)
AUDIO.world = {}
check(P.play(world, player), "world collection takeover accepted")
ticks(100)
equal(#AUDIO.world, 0, "pending takeover waits for upstream cleanup")
equal(P.getState(world).index, 1, "pending state is not mistaken for song end")
check((emitter.stopAllCalls or 0) > oldStops, "real upstream closure cleaned old emitter before new playback")
ticks(30)
equal(#AUDIO.world, 1, "one new world handle starts after drain interval")
equal(P.getState(world).index, 1, "startup grace does not skip first track")
ticks(220)
equal(#AUDIO.world, 1, "later upstream ticks cannot stop and restart collection")
equal(P.getState(world).index, 1, "later upstream ticks do not advance an active song")
check(#AUDIO.addSound > 0, "world external speaker retains zombie sound events")
P.stop(world)

local pending = fixtureWorldDevice(11, 20, 0)
insert(pending, owned(albumType), 1)
AUDIO.world = {}
check(P.play(pending, player)); ticks(20)
check(P.step(pending, 1)); equal(P.getState(pending).index, 2, "pending manual skip updates index")
P.stop(pending); ticks(150)
equal(#AUDIO.world, 0, "stopping pending takeover prevents later audio start")

-- Real server command handler runs only when the queued command is flushed.
local car, carPower, vehicle = fixtureVehicle(67)
local function custom(i, j)
    local a = owned(C.tracks[prototype.tracks[i]].cassette)
    local b = owned(C.tracks[prototype.tracks[j]].cassette)
    local item = M.merge(player, {a, b}); check(item, "collected carrier prepared")
    return item
end
local first = custom(1, 2)
local original = M.copy(M.state(first))
insert(car, first)
equal(#COMMAND_QUEUE, 1, "vehicle insertion queues real command")
check(P.getState(car) and deepEqual(P.getState(car), original), "state retained before asynchronous command delivery")
flushCommands()
check(deepEqual(P.getState(car), original), "state retained after native queued handler")
check(P.play(car, player)); ticks(130)
check(P.isPlaying(car), "vehicle collection remains playing after native cleanup")
equal(carPower._channel, 100, "vehicle tape playback selects native media channel")
local count = player:getInventory():getItems():size()
action(car, "RemoveMedia"):performRemoveMedia()
local returned = player:getInventory():getItems():get(count)
check(returned and deepEqual(M.state(returned), original), "vehicle eject preserves owned tracks and source records")
flushCommands()
equal(car:getModData().tcmusic.mediaItem, nil, "native queued eject clears carrier")
equal(tableCount(car:getModData().tcmusic.sqmusicSlots), 0, "vehicle eject clears old sidecar")
local second = custom(3, 4)
local nextState = M.copy(M.state(second))
insert(car, second); flushCommands()
check(deepEqual(P.getState(car), nextState), "same carrier type insertion cannot inherit previous custom song list")
check(not deepEqual(P.getState(car), original), "new custom collection differs from ejected collection")
count = player:getInventory():getItems():size()
action(car, "RemoveMedia"):performRemoveMedia(); flushCommands()
check(deepEqual(M.state(player:getInventory():getItems():get(count)), nextState), "second vehicle custom round trip exact")

-- Autosave leaves live playback running; ordinary save data contains no handles.
local private, privatePower = fixtureDevice("Tsarcraft.TCWalkman", player)
insert(private, owned(albumType))
resetAudio(); check(P.play(private, player)); ticks(15)
local handle, played = AUDIO.private[#AUDIO.private], #AUDIO.private
fire("OnSave"); ticks(15)
check(P.isPlaying(private) and handle:isPlaying(), "autosave does not stop current music")
equal(#AUDIO.private, played, "autosave does not restart track")
local serialized = nativeRoundTrip(private:getModData().tcmusic)
equal(serialized.isPlaying, false, "saved native playing flag stays paused")
assertPrivate("autosave private route")
P.stopAll()
print("ASSERTIONS=" .. tostring(CHECKS))
return true
