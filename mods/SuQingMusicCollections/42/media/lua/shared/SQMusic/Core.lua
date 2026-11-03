require "SQMusic/Catalog"
require "SQMusic/Text"

SQMusic = SQMusic or {}
local M = SQMusic
local C = M.Catalog
M.schema = 1
M.modes = { order = true, loop = true, one = true, shuffle = true }

function M.copy(value, seen, depth)
    local kind = type(value)
    if kind ~= "table" then
        if kind == "string" or kind == "boolean" or (kind == "number" and value == value) then return value end
        return nil
    end
    depth = depth or 0
    if depth > 20 then return nil end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(key) == "string" or type(key) == "number" then result[key] = M.copy(child, seen, depth + 1) end
    end
    seen[value] = nil
    return result
end

local function carrierInfo(item)
    return item and C.albumsByType[item:getFullType()]
end

function M.available(id, kind)
    local track = C.tracks[id]
    local fullType = track and track[kind]
    local info = fullType and C.byItem[fullType]
    return track and track.available ~= false and info and info.available ~= false
        and getScriptManager():FindItem(fullType) ~= nil
end

-- Structural validation preserves missing track IDs for safe ejection after a
-- music-pack update. Missing sounds stop playback; they never erase the album.
function M.valid(state)
    return type(state) == "table" and state.schema == M.schema
        and (state.kind == "cassette" or state.kind == "vinyl")
        and (state.origin == "premade" or state.origin == "collected")
        and type(state.artist) == "string" and type(state.tracks) == "table"
        and #state.tracks > 0 and type(state.index) == "number"
        and state.index >= 1 and state.index <= #state.tracks
        and state.index == math.floor(state.index) and M.modes[state.mode] == true
end

function M.newState(artist, kind, origin, tracks)
    return { schema = M.schema, artist = artist, kind = kind, origin = origin,
        tracks = M.copy(tracks), index = 1, mode = "order", sources = {} }
end

function M.setState(item, state)
    local info = carrierInfo(item)
    if not info or not M.valid(state) or info.kind ~= state.kind
        or (not info.custom and info.artist ~= state.artist) then return nil end
    item:getModData().sqMusic = M.copy(state)
    return item:getModData().sqMusic
end

function M.onCreateAlbum(item)
    local info = carrierInfo(item)
    if not info or info.custom or item:getModData().sqMusic then return end
    local artist = C.artists[info.artist]
    local ids = {}
    for _, id in ipairs(artist and artist.tracks or {}) do
        if M.available(id, info.kind) then ids[#ids + 1] = id end
    end
    if #ids > 0 then M.setState(item, M.newState(info.artist, info.kind, "premade", ids)) end
end

function M.state(item)
    if not carrierInfo(item) then return nil end
    if not item:getModData().sqMusic then M.onCreateAlbum(item) end
    local state = item:getModData().sqMusic
    return M.valid(state) and state or nil
end

function M.sound(state)
    if not M.valid(state) then return nil end
    local track = C.tracks[state.tracks[state.index]]
    local info = track and C.byItem[track[state.kind]]
    if not info or track.available == false or info.available == false then return nil, nil end
    return info and info.sound, info and info.privateSound
end

function M.commonArtist(state)
    if not M.valid(state) then return nil end
    local common
    for _, id in ipairs(state.tracks) do
        local track = C.tracks[id]
        if not track or not track.artist then return nil end
        if common and common ~= track.artist then return nil end
        common = track.artist
    end
    return common
end

function M.isMixed(state)
    return M.valid(state) and M.commonArtist(state) == nil
end

function M.title(state)
    local common = M.commonArtist(state)
    local name = common and M.artistName(common) or getText("UI_SQM_CustomAlbum")
    return name .. " - " .. getText("UI_SQM_TrackCount", tostring(#state.tracks))
end

function M.setMode(state, mode)
    if not M.valid(state) or not M.modes[mode] then return false end
    state.mode, state.shuffleBag, state.history = mode, nil, nil
    return true
end

function M.advance(state, direction, natural)
    if not M.valid(state) then return false end
    direction = direction and direction < 0 and -1 or 1
    local count = #state.tracks
    if state.mode == "one" and natural then return true end
    if state.mode == "shuffle" and direction > 0 then
        local bag = state.shuffleBag
        if not bag then
            bag = {}
            for i = 1, count do if i ~= state.index or count == 1 then bag[#bag + 1] = i end end
        elseif #bag == 0 then
            for i = 1, count do bag[#bag + 1] = i end
        end
        local choices = {}
        for i, index in ipairs(bag) do
            if index ~= state.index or #bag == 1 then choices[#choices + 1] = i end
        end
        state.history = state.history or {}
        state.history[#state.history + 1] = state.index
        if #state.history > 256 then table.remove(state.history, 1) end
        state.index = table.remove(bag, choices[ZombRand(#choices) + 1])
        state.shuffleBag = bag
        return true
    end
    if state.mode == "shuffle" and direction < 0 and state.history and #state.history > 0 then
        state.index = table.remove(state.history)
        state.shuffleBag = nil
        return true
    end
    local nextIndex = state.index + direction
    if natural and state.mode == "order" and (nextIndex > count or nextIndex < 1) then return false end
    state.index = ((nextIndex - 1) % count) + 1
    return true
end

function M.owned(player, item)
    local container = item and item:getContainer()
    return container ~= nil and container:isInCharacterInventory(player)
        and container:contains(item)
end

function M.canMerge(player, items)
    if not player or type(items) ~= "table" or #items < 2 then return false, "SQM_NeedTwo" end
    local artist, kind, uniqueItems, uniqueTracks = nil, nil, {}, {}
    for _, item in ipairs(items) do
        local info = C.byItem[item:getFullType()]
        if not info or not info.artist or not M.owned(player, item) then return false, "SQM_OnlyOwnedSingles" end
        if not M.available(info.id, info.kind) then return false, "SQM_MissingSource" end
        if uniqueItems[item] or uniqueTracks[info.id] then return false, "SQM_NoDuplicates" end
        if item:isFavorite() or item:isEquipped() then return false, "SQM_Protected" end
        uniqueItems[item], uniqueTracks[info.id] = true, true
        if artist and artist ~= info.artist then artist = "Mixed" else artist = artist or info.artist end
        kind = kind or info.kind
        if kind ~= info.kind then return false, "SQM_SameKind" end
    end
    return true, artist, kind
end

local function snapshot(item)
    return { fullType = item:getFullType(), condition = item:getCondition(),
        name = item:getName(), customName = item:isCustomName(),
        modData = M.copy(item:getModData()) }
end

local function restore(record)
    if type(record) ~= "table" or type(record.fullType) ~= "string"
        or not getScriptManager():FindItem(record.fullType) then return nil end
    local item = instanceItem(record.fullType)
    if not item then return nil end
    if record.condition then item:setCondition(record.condition) end
    if record.customName and record.name then item:setName(record.name); item:setCustomName(true) end
    local data = item:getModData()
    for key, value in pairs(record.modData or {}) do data[key] = M.copy(value) end
    return item
end

-- Called only at the completion of a cancellable timed action. Every source is
-- rechecked before material removal; the result is prepared before committing.
function M.merge(player, items)
    local ok, artist, kind = M.canMerge(player, items)
    if not ok then return nil, artist end
    local ids, sources = {}, {}
    for _, item in ipairs(items) do
        ids[#ids + 1] = C.byItem[item:getFullType()].id
        sources[#sources + 1] = snapshot(item)
    end
    local fullType = kind == "cassette" and "SQMusic.CassetteCustom" or "SQMusic.VinylCustom"
    local result = instanceItem(fullType)
    if not result then return nil, "SQM_MissingCarrier" end
    local state = M.newState(artist, kind, "collected", ids)
    state.sources = sources
    if not M.setState(result, state) then return nil, "SQM_InvalidState" end
    ok = M.canMerge(player, items)
    if not ok then return nil, "SQM_ItemsMoved" end
    -- AddItem may refuse an invalid result. Do not consume sources until the
    -- carrier is confirmed present in the inventory.
    local added, addError = pcall(function() player:getInventory():AddItem(result) end)
    if not added or not M.owned(player, result) then
        if M.owned(player, result) then result:getContainer():DoRemoveItem(result) end
        if not added then print("[SQMusic] Collection insertion refused: " .. tostring(addError)) end
        return nil, "SQM_MissingCarrier"
    end
    local containers = {}
    for i, item in ipairs(items) do containers[i] = item:getContainer() end
    local committed, failure = pcall(function()
        for _, item in ipairs(items) do
            item:getContainer():DoRemoveItem(item)
            if M.owned(player, item) then error("source removal refused") end
        end
    end)
    if not committed then
        for i, item in ipairs(items) do
            if not M.owned(player, item) then containers[i]:AddItem(item) end
        end
        if M.owned(player, result) then result:getContainer():DoRemoveItem(result) end
        print("[SQMusic] Merge rolled back: " .. tostring(failure))
        return nil, "SQM_ExchangeFailed"
    end
    return result
end

function M.canSplit(player, item)
    if not M.owned(player, item) or item:isFavorite() or item:isEquipped() then return false, "SQM_Protected" end
    local state = M.state(item)
    if not state or state.origin ~= "collected" or type(state.sources) ~= "table"
        or #state.sources ~= #state.tracks then return false, "SQM_OnlyCustomSplit" end
    for i, source in ipairs(state.sources) do
        local info = type(source) == "table" and C.byItem[source.fullType]
        local track = C.tracks[state.tracks[i]]
        if not info or not track or info.id ~= state.tracks[i] or info.artist ~= track.artist
            or info.kind ~= state.kind or not getScriptManager():FindItem(source.fullType) then return false, "SQM_MissingSource" end
    end
    return true
end

function M.split(player, item)
    local ok, reason = M.canSplit(player, item)
    if not ok then return false, reason end
    local prepared = {}
    for _, record in ipairs(M.state(item).sources) do
        local restored = restore(record)
        if not restored then return false, "SQM_MissingSource" end
        prepared[#prepared + 1] = restored
    end
    if not M.canSplit(player, item) then return false, "SQM_ItemsMoved" end
    local source = item:getContainer()
    local committed, failure = pcall(function()
        for _, restored in ipairs(prepared) do
            player:getInventory():AddItem(restored)
            if not M.owned(player, restored) then error("source return refused") end
        end
        source:DoRemoveItem(item)
        if M.owned(player, item) then error("collection removal refused") end
    end)
    if not committed then
        for _, restored in ipairs(prepared) do
            if M.owned(player, restored) then restored:getContainer():DoRemoveItem(restored) end
        end
        if not M.owned(player, item) then source:AddItem(item) end
        print("[SQMusic] Split rolled back: " .. tostring(failure))
        return false, "SQM_ExchangeFailed"
    end
    return true
end
