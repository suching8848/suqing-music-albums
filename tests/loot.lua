local M, C = SQMusic, SQMusic.Catalog
local authors = {}
for fullType, info in pairs(C.albumsByType) do
    if not info.custom and info.kind == "cassette" and #C.artists[info.artist].tracks >= 2 then
        authors[#authors + 1] = info.artist
    end
end
check(#authors >= 2, "two album authors exist")
local authorA, authorB = authors[1], authors[2]
local a1 = C.tracks[C.artists[authorA].tracks[1]].cassette
local a2 = C.tracks[C.artists[authorA].tracks[2]].cassette
local b1 = C.tracks[C.artists[authorB].tracks[1]].cassette
local vinylA = C.tracks[C.artists[authorA].tracks[1]].vinyl
local sets = {cassette = {}, vinyl = {}}
for fullType, info in pairs(C.albumsByType) do
    if not info.custom and #C.artists[info.artist].tracks >= 2 then sets[info.kind][fullType] = true end
end
local function verify(items, original, allowed, weightFor)
    for i, value in ipairs(original) do equal(items[i], value, "original item/weight prefix untouched") end
    local found = {}
    for i = #original + 1, #items, 2 do
        local fullType, weight = items[i], items[i + 1]
        local info = C.albumsByType[fullType]
        check(info and not info.custom and allowed[info.kind], "only matching-medium premade carrier appended")
        check(not found[fullType], "album appended once"); found[fullType] = true
        near(weight, weightFor(info.artist, info.kind), "album follows original per-single weight")
    end
    for kind in pairs(allowed) do
        for fullType in pairs(sets[kind]) do
            if not FIXTURE_MISSING_ITEMS[fullType] then
                local already = false
                for i = 1, #original, 2 do if original[i] == fullType then already = true end end
                check(found[fullType] or already, "every eligible same-medium album available at original spawn point")
            end
        end
    end
end
local function profileWeight(artist)
    if artist == authorA then return 3 end
    if artist == authorB then return 10 end
    return 16 / 3
end

local cassette = {items = {a1, 2, a2, 4, b1, 10, "Base.Unrelated", 81}}
local vinyl = {items = {vinylA, 7}}
local unqualified = {items = {"Base.NotMusic", 11}}
local root = {room = {cabinet = cassette, shelf = {junk = vinyl}}, arrays = {{outer = unqualified}}}
root.circular = root
local originalC, originalV, originalN = M.copy(cassette.items), M.copy(vinyl.items), M.copy(unqualified.items)
check(M.installLoot({root}), "nested/cyclic roots install")
verify(cassette.items, originalC, {cassette = true}, profileWeight)
verify(vinyl.items, originalV, {vinyl = true}, function() return 7 end)
check(deepEqual(unqualified.items, originalN), "nonmusic container unchanged")
local firstC, firstV = M.copy(cassette.items), M.copy(vinyl.items)
M.installLoot({root}); check(deepEqual(cassette.items, firstC) and deepEqual(vinyl.items, firstV), "reinstall leaves entries and weights identical")

local raw = {items = {a1:match("[^.]+$"), 5}}
local dup = {items = {a1, 2, a1, 4, a2, 10}}
local mixed = {items = {a1, 2, vinylA, 8}}
local originalRaw, originalDup, originalMixed = M.copy(raw.items), M.copy(dup.items), M.copy(mixed.items)
M.installLoot({{[1] = raw, junk = {dup, mixed}}})
verify(raw.items, originalRaw, {cassette = true}, function() return 5 end)
verify(dup.items, originalDup, {cassette = true}, function() return 8 end)
verify(mixed.items, originalMixed, {cassette = true, vinyl = true}, function(_, kind) return kind == "cassette" and 2 or 8 end)

local retainedType
for fullType in pairs(sets.cassette) do retainedType = fullType; break end
local retained = {items = {a1, 2, retainedType, 99}}
local originalRetained = M.copy(retained.items)
M.installLoot({retained})
verify(retained.items, originalRetained, {cassette = true}, function() return 2 end)
near(retained.items[4], 99, "existing album custom weight never overwritten")

local shared = {items = {b1, 3}}
local sharedRoot = {one = shared, two = shared}; sharedRoot.self = sharedRoot
local ok, report = M.installLoot({sharedRoot, shared})
check(ok); equal(report.sourceTables, 1, "shared items table counted once")
local unavailable = {items = {a1, 2}}
FIXTURE_MISSING_ITEMS[retainedType] = true
local originalUnavailable = M.copy(unavailable.items)
M.installLoot({unavailable})
verify(unavailable.items, originalUnavailable, {cassette = true}, function() return 2 end)
for i = #originalUnavailable + 1, #unavailable.items, 2 do check(unavailable.items[i] ~= retainedType, "uninstalled album is not spawned") end
FIXTURE_MISSING_ITEMS[retainedType] = nil

-- Default lifecycle roots include procedural, Suburbs, vehicle and addon array
-- definitions. Same logical addon paths inject only into the final base list.
ProceduralDistributions = {list = {AnyOriginalLocation = {items = {a1, 2}}}}
SuburbsDistributions = {}
VehicleDistributions = {Car = {GloveBox = {items = {b1, 9}}}}
Distributions = {{house = {shelf = {rolls = 2, fillRand = 0, items = {a1, 2}, junk = {rolls = 3, items = {vinylA, 7}}}}},
    {house = {shelf = {rolls = 9, fillRand = 8, items = {a2, 4, b1, 10}, junk = {rolls = 4, items = {vinylA, 5}}}}}}
local baseItems, addonItems = Distributions[1].house.shelf.items, Distributions[2].house.shelf.items
local baseBefore, addonBefore = M.copy(baseItems), M.copy(addonItems)
local procBefore = M.copy(ProceduralDistributions.list.AnyOriginalLocation.items)
local junkBefore = M.copy(Distributions[1].house.shelf.junk.items)
local vehicleBefore = M.copy(VehicleDistributions.Car.GloveBox.items)
fire("OnPreDistributionMerge")
verify(baseItems, baseBefore, {cassette = true}, profileWeight)
check(deepEqual(addonItems, addonBefore), "addon source arrays remain unchanged before native merge")
verify(ProceduralDistributions.list.AnyOriginalLocation.items, procBefore, {cassette = true}, function() return 2 end)
verify(Distributions[1].house.shelf.junk.items, junkBefore, {vinyl = true}, function() return 12 end)
verify(VehicleDistributions.Car.GloveBox.items, vehicleBefore, {cassette = true}, function() return 9 end)
fire("OnDistributionMerge") -- actual installed MergeDistributionRecursive/mergeDistributions
check(SuburbsDistributions == Distributions[1], "native merge selects final base distribution")
equal(SuburbsDistributions.house.shelf.rolls, 2, "native merge preserves original rolls")
equal(SuburbsDistributions.house.shelf.fillRand, 0, "native merge preserves original fill metadata")
equal(SuburbsDistributions.house.shelf.junk.rolls, 3, "native merge preserves original junk rolls")
local afterNativeMerge = M.copy(baseItems)
SuburbsDistributions.house.drawer = {junk = {items = {vinylA, 17}}}
local subBefore = M.copy(SuburbsDistributions.house.drawer.junk.items)
fire("OnPostDistributionMerge"); fire("OnGameStart")
verify(SuburbsDistributions.house.drawer.junk.items, subBefore, {vinyl = true}, function() return 17 end)
check(deepEqual(baseItems, afterNativeMerge), "post-merge/game-start hooks do not duplicate or reweight merged albums")
for fullType in pairs(sets.cassette) do
    local n = 0; for i = 1, #baseItems, 2 do if baseItems[i] == fullType then n = n + 1 end end
    equal(n, 1, "native concatenated distributions contain each album once")
end
ProceduralDistributions.list.LateLoaded = {items = {vinylA, 13}}
local lateBefore = M.copy(ProceduralDistributions.list.LateLoaded.items)
fire("OnPostDistributionMerge")
verify(ProceduralDistributions.list.LateLoaded.items, lateBefore, {vinyl = true}, function() return 13 end)

-- Album availability can change between Pre and Post. The final merged source
-- weights must be read once, not recombined with addon registrations again.
local lateType
for fullType in pairs(sets.cassette) do if C.albumsByType[fullType].artist == authorA then lateType = fullType; break end end
FIXTURE_MISSING_ITEMS[lateType] = true
ProceduralDistributions, VehicleDistributions, SuburbsDistributions = {list = {}}, {}, {}
Distributions = {{house = {shelf = {rolls = 2, items = {a1, 2}}}}, {house = {shelf = {items = {a2, 4, b1, 10}}}}}
fire("OnPreDistributionMerge")
fire("OnDistributionMerge")
FIXTURE_MISSING_ITEMS[lateType] = nil
fire("OnPostDistributionMerge")
local seenLate = 0
for i = 1, #SuburbsDistributions.house.shelf.items, 2 do
    if SuburbsDistributions.house.shelf.items[i] == lateType then
        seenLate = seenLate + 1
        near(SuburbsDistributions.house.shelf.items[i + 1], 3, "post-only eligibility inherits original final weight without addon double count")
    end
end
equal(seenLate, 1, "post-only eligible album added once")
equal(SuburbsDistributions.house.shelf.rolls, 2, "late post sweep retains roll metadata")
print("ASSERTIONS=" .. tostring(CHECKS))
return true
