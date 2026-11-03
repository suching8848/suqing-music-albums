local M, C = SQMusic, SQMusic.Catalog
check(type(C) == "table" and type(C.tracks) == "table", "production catalog loaded")

local albumCount = 0
local sampleFullType, sampleInfo
for fullType, info in pairs(C.albumsByType) do
    local item = instanceItem(fullType)
    if not info.custom then
        albumCount = albumCount + 1
        local state = M.state(item)
        check(state ~= nil, "premade state: " .. fullType)
        equal(state.artist, info.artist, "premade artist")
        equal(state.kind, info.kind, "premade physical medium")
        equal(state.origin, "premade", "premade provenance")
        local seen = {}
        for _, id in ipairs(state.tracks) do
            check(not seen[id], "no duplicate premade track: " .. id); seen[id] = true
            local track = C.tracks[id]
            check(track and C.byItem[track[info.kind]], "premade track references real catalog source")
            equal(C.byItem[track[info.kind]].artist, state.artist, "no cross-artist premade songs")
            check(M.available(id, info.kind), "premade track source installed")
        end
        equal(#state.sources, 0, "premade has no decomposable owned sources")
        local restored = nativeRoundTrip(state)
        check(deepEqual(restored, state), "premade state native binary serialization")
        local player = fixturePlayer(); player:getInventory():AddItem(item)
        equal(M.canSplit(player, item), false, "premade cannot create singles through splitting")
        if info.kind == "cassette" and #state.tracks >= 3 and not sampleFullType then
            sampleFullType, sampleInfo = fullType, info
        end
    end
end
check(albumCount > 0, "premade albums exist")
check(sampleFullType, "same-artist three-track cassette sample available")

local prototype = M.state(instanceItem(sampleFullType))
local first, second, third = prototype.tracks[1], prototype.tracks[2], prototype.tracks[3]
local firstType, secondType = C.tracks[first].cassette, C.tracks[second].cassette
local function sources(player)
    return player:getInventory():AddItem(instanceItem(firstType)), player:getInventory():AddItem(instanceItem(secondType))
end
local player = fixturePlayer()
FIXTURE_PLAYER = player
local a, b = sources(player)
a:setName(nativeExpectedText("custom.source")); a:setCustomName(true); a:setCondition(43)
a:getModData().preserved = {text = "中文 & text", sequence = {1, 2, 3}, flag = true}
check(M.canMerge(player, {a, b}), "owned same-artist singles merge")
equal(M.canMerge(player, {a, a}), false, "same object cannot be counted twice")
local duplicate = player:getInventory():AddItem(instanceItem(firstType))
equal(M.canMerge(player, {a, duplicate}), false, "duplicate song cannot be counted twice")
player:getInventory():DoRemoveItem(duplicate)
a:setFavorite(true); equal(M.canMerge(player, {a, b}), false, "favorite protected"); a:setFavorite(false)
a._equipped = true; equal(M.canMerge(player, {a, b}), false, "equipped protected"); a._equipped = false
local vinyl = player:getInventory():AddItem(instanceItem(C.tracks[second].vinyl))
equal(M.canMerge(player, {a, vinyl}), false, "different media rejected")
player:getInventory():DoRemoveItem(vinyl)
for _, info in pairs(C.byItem) do
    if info.artist ~= sampleInfo.artist and info.kind == "cassette" then
        local other = player:getInventory():AddItem(instanceItem(C.tracks[info.id].cassette))
        check(M.canMerge(player, {a, other}), "different artists accepted in the same medium")
        player:getInventory():DoRemoveItem(other)
        break
    end
end

-- Version 1.1 mixes real held singles, and old schema-1 carriers stay usable.
local mixedPlayer = fixturePlayer()
local selected, artists = {}, {}
for fullType, info in pairs(C.byItem) do
    if info.kind == "cassette" and info.artist and info.available ~= false and not artists[info.artist] then
        artists[info.artist] = true
        selected[#selected + 1] = mixedPlayer:getInventory():AddItem(instanceItem(fullType))
        if #selected == 3 then break end
    end
end
equal(#selected, 3, "three artists available for mixed carrier")
local mixed = M.merge(mixedPlayer, selected)
check(mixed, "three-artist merge succeeds")
local mixedState = M.state(mixed)
equal(mixedState.artist, "Mixed", "mixed state uses stable ASCII sentinel")
check(M.isMixed(mixedState), "mixed status derives from actual tracks")
equal(M.commonArtist(mixedState), nil, "mixed tracks have no sole author")
equal(#mixedState.sources, 3, "mixed carrier stores all actual source records")
M.setState(mixed, nativeRoundTrip(mixedState))
check(M.canSplit(mixedPlayer, mixed), "mixed carrier survives native save round trip")
local insertion = 0
FIXTURE_ADD_FAIL = function(item)
    if item:getFullType() ~= "SQMusic.CassetteCustom" then insertion = insertion + 1; return insertion == 2 end
    return false
end
equal(M.split(mixedPlayer, mixed), false, "mixed split insertion failure rolls back")
FIXTURE_ADD_FAIL = nil
equal(mixedPlayer:getInventory():getItems():size(), 1, "failed mixed split retains only carrier")
check(M.owned(mixedPlayer, mixed), "failed mixed split retains original carrier")
check(M.split(mixedPlayer, mixed), "mixed split safe retry")
equal(mixedPlayer:getInventory():getItems():size(), 3, "mixed split restores exactly three singles")
for _, original in ipairs(selected) do
    local found = 0
    for _, item in ipairs(mixedPlayer:getInventory()._items) do if item:getFullType() == original:getFullType() then found = found + 1 end end
    equal(found, 1, "each artist's actual single restored once")
end

local oldPlayer = fixturePlayer()
local oldCarrier = oldPlayer:getInventory():AddItem(instanceItem("SQMusic.CassetteCustom"))
local oldState = {schema = 1, artist = sampleInfo.artist, kind = "cassette", origin = "collected",
    tracks = {first, second}, index = 2, mode = "loop", sources = {
        {fullType = firstType, condition = 51, name = "Old Source A", customName = true, modData = {old = true}},
        {fullType = secondType, condition = 52, name = "Old Source B", customName = true, modData = {old = true}},
    }}
check(M.setState(oldCarrier, nativeRoundTrip(oldState)), "old schema-1 state accepted without migration")
equal(M.state(oldCarrier).artist, sampleInfo.artist, "old author field unchanged")
check(not M.isMixed(M.state(oldCarrier)), "old single-author collection derived correctly")
check(M.canSplit(oldPlayer, oldCarrier), "old schema-1 remains splittable")
check(M.split(oldPlayer, oldCarrier), "old schema-1 exact split succeeds")
equal(oldPlayer:getInventory():getItems():size(), 2, "old split restores source count")
local alienInventory = fixtureInventory(fixturePlayer())
player:getInventory():DoRemoveItem(b); alienInventory:AddItem(b)
equal(M.merge(player, {a, b}), nil, "moved source rejected at completion")
check(M.owned(player, a), "failed moved-source merge leaves first source")
alienInventory:DoRemoveItem(b); player:getInventory():AddItem(b)
local merged = M.merge(player, {a, b})
check(merged ~= nil and M.owned(player, merged), "merge result owned")
check(not M.owned(player, a) and not M.owned(player, b), "successful merge consumes actual sources")
local state = M.state(merged)
equal(state.origin, "collected", "collected provenance")
equal(#state.tracks, 2, "only actually held songs enter collection")
equal(state.tracks[1], first, "first selected source retained")
equal(state.tracks[2], second, "second selected source retained")
equal(#state.sources, 2, "both source records saved")
check(deepEqual(nativeRoundTrip(state), state), "collected state and exact source records binary round trip")
M.setState(merged, nativeRoundTrip(state))
check(M.canSplit(player, merged), "serialized collection remains splittable")
check(M.split(player, merged), "collection splits")
equal(M.split(player, merged), false, "repeating split cannot duplicate source items")
equal(player:getInventory():getItems():size(), 2, "exactly two sources returned")
local returned
for i = 0, player:getInventory():getItems():size() - 1 do
    local item = player:getInventory():getItems():get(i)
    if item:getFullType() == firstType then returned = item end
end
check(returned ~= nil, "first source type restored")
equal(returned:getCondition(), 43, "source condition restored")
check(nativeAssertUTF8(returned:getName(), "custom.source"), "custom Unicode source name restored")
check(returned:isCustomName(), "custom-name flag restored")
check(deepEqual(returned:getModData().preserved, a:getModData().preserved), "source nested metadata restored")

-- Invalid/failed transactions exercise production code, not a reimplementation.
local p2 = fixturePlayer(); local c, d = sources(p2)
FIXTURE_ADD_FAIL = function(item) return item:getFullType() == "SQMusic.CassetteCustom" end
equal(M.merge(p2, {c, d}), nil, "refused carrier insertion fails")
FIXTURE_ADD_FAIL = nil
check(M.owned(p2, c) and M.owned(p2, d), "refused insertion consumes nothing")
local once = true
FIXTURE_REMOVE_FAIL = function(item) if item == d and once then once = false; return true end end
equal(M.merge(p2, {c, d}), nil, "mid-merge removal error fails")
FIXTURE_REMOVE_FAIL = nil
check(M.owned(p2, c) and M.owned(p2, d), "mid-merge failure restores originals")
equal(p2:getInventory():getItems():size(), 2, "failed merge leaves no duplicated result")
local custom = M.merge(p2, {c, d}); check(custom, "retry after rollback succeeds")
local calls = 0
FIXTURE_ADD_FAIL = function(item)
    if item:getFullType() ~= "SQMusic.CassetteCustom" then calls = calls + 1; return calls == 2 end
    return false
end
equal(M.split(p2, custom), false, "mid-split insertion refusal fails")
FIXTURE_ADD_FAIL = nil
check(M.owned(p2, custom), "failed split retains carrier")
equal(p2:getInventory():getItems():size(), 1, "failed split removes partial outputs")
check(M.split(p2, custom), "split can safely retry")
equal(p2:getInventory():getItems():size(), 2, "safe retry returns exact originals")

-- Playback ordering is the production state machine.
local function queue(mode)
    local s = M.newState(sampleInfo.artist, "cassette", "premade", {first, second, third})
    check(M.setMode(s, mode), "valid mode accepted")
    return s
end
local order = queue("order")
check(M.advance(order, 1, true)); equal(order.index, 2)
check(M.advance(order, 1, true)); equal(order.index, 3)
equal(M.advance(order, 1, true), false, "order stops at album end"); equal(order.index, 3)
local loop = queue("loop"); loop.index = 3
check(M.advance(loop, 1, true)); equal(loop.index, 1, "album loop wraps")
local one = queue("one"); one.index = 2
check(M.advance(one, 1, true)); equal(one.index, 2, "single repeat stays at selected song")
check(M.advance(one, 1, false)); equal(one.index, 3, "manual next works in single repeat")
local shuffle = queue("shuffle")
for round = 1, 8 do
    local seen = {}
    for position = 1, 3 do
        if not (round == 1 and position == 1) then check(M.advance(shuffle, 1, true), "shuffle advances") end
        check(not seen[shuffle.index], "shuffle cycle contains each song once, round=" .. round)
        seen[shuffle.index] = true
    end
end
check(deepEqual(nativeRoundTrip(shuffle), shuffle), "shuffle bag and history survive native serialization")
equal(M.setMode(shuffle, "bad-mode"), false, "invalid playback mode rejected")
print("ASSERTIONS=" .. tostring(CHECKS))
return true
