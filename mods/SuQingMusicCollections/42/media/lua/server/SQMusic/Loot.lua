-- Add selections where ordinary source media can already spawn. No world refill.
require "Items/ProceduralDistributions"
require "SQMusic/Catalog"
SQMusic = SQMusic or {}
local M = SQMusic
local C = M.Catalog
local distributionsMerged = false

local function eligibleAlbums()
    local types = {cassette={}, vinyl={}}
    local manager = getScriptManager and getScriptManager()
    if not manager then return types end
    for fullType, album in pairs(C.albumsByType) do
        local artist = album.artist and C.artists[album.artist]
        if not album.custom and artist and manager:FindItem(fullType) then
            local available = 0
            for _, id in ipairs(artist.tracks) do
                local track = C.tracks[id]
                local source = track and track[album.kind]
                local info = source and C.byItem[source]
                if track and track.available ~= false and info and info.available ~= false and manager:FindItem(source) then
                    available = available + 1
                end
            end
            if available >= 2 then types[album.kind][#types[album.kind]+1] = fullType end
        end
    end
    table.sort(types.cassette); table.sort(types.vinyl)
    return types
end

local function sourceProfile(items)
    local profile = {}
    for i=1,#items-1,2 do
        local fullType, weight = items[i], items[i+1]
        local info = type(fullType) == "string" and C.byItem[fullType]
        if not info and type(fullType) == "string" and not string.find(fullType,"%.") then info=C.byItem["Tsarcraft."..fullType] end
        if info and (info.kind == "cassette" or info.kind == "vinyl") and type(weight) == "number" and weight > 0 then
            local byType=profile[info.kind] or {}; profile[info.kind]=byType
            local canonical=C.byItem[fullType] and fullType or "Tsarcraft."..fullType
            local record=byType[canonical] or {weight=0,artist=info.artist}
            record.weight=record.weight+weight; byType[canonical]=record
        end
    end
    return profile
end

local function mergeProfile(target, source)
    for kind, byType in pairs(source) do
        local combined=target[kind] or {}; target[kind]=combined
        for fullType, record in pairs(byType) do
            local entry=combined[fullType] or {weight=0,artist=record.artist}
            entry.weight=entry.weight+record.weight; combined[fullType]=entry
        end
    end
end

-- Also handles shared tables, nested junk tables and array wrappers. Item arrays
-- are never interpreted as container trees and cyclic addon tables terminate.
local function walk(node, path, visit, seen, depth)
    if type(node) ~= "table" or seen[node] or depth > 64 then return end
    seen[node] = true
    if type(node.items) == "table" then visit(node.items,path) end
    for key, child in pairs(node) do
        if key ~= "items" and type(child) == "table" then
            path[#path+1] = key
            walk(child,path,visit,seen,depth+1)
            path[#path] = nil
        end
    end
end

local function finalItems(base, path)
    local node = base
    for _, key in ipairs(path) do
        if node[key] == nil then node[key] = {} end
        if type(node[key]) ~= "table" then return nil end
        node = node[key]
    end
    if node.items == nil then node.items = {} end
    return type(node.items) == "table" and node.items or nil
end

function M.installLoot(roots, phase)
    if phase == "post" then distributionsMerged=true end
    if phase == "pre" then distributionsMerged=false end
    local afterMerge = phase == "post" or (phase == nil and distributionsMerged)
    local albums = eligibleAlbums()
    local report = {tablesScanned=0,sourceTables=0,added=0}
    local counted, seen = {}, {}
    local function augment(items, profile)
        if not counted[items] then
            counted[items] = true; report.tablesScanned=report.tablesScanned+1
        end
        if not profile.cassette and not profile.vinyl then return end
        report.sourceTables=report.sourceTables+1
        local present, add = {}, {}
        for i=1,#items,2 do if type(items[i]) == "string" then present[items[i]]=true end end
        for kind, byType in pairs(profile) do
            local sum, count, artists = 0,0,{}
            for _, record in pairs(byType) do
                sum=sum+record.weight; count=count+1
                if record.artist then
                    local entry=artists[record.artist] or {sum=0,count=0}
                    entry.sum=entry.sum+record.weight; entry.count=entry.count+1
                    artists[record.artist]=entry
                end
            end
            for _, fullType in ipairs(albums[kind]) do
                if not present[fullType] then
                    local artist=artists[C.albumsByType[fullType].artist]
                    local weight=artist and artist.sum/artist.count or sum/count
                    present[fullType]=true; add[#add+1]={fullType=fullType,weight=weight}
                end
            end
        end
        table.sort(add,function(a,b) return a.fullType<b.fullType end)
        if #add == 0 then return end
        -- Follow ordinary single-carrier weights. Duplicate registrations of one
        -- source type are summed first; each album uses its artist's per-type
        -- arithmetic mean, or the kind-wide mean when that artist is absent.
        -- No multiplier, cap, or multiplication by the number of album tracks.
        for _, entry in ipairs(add) do
            items[#items+1]=entry.fullType; items[#items+1]=entry.weight
            report.added=report.added+1
        end
    end
    local function visit(items)
        augment(items,sourceProfile(items))
    end
    if roots then
        for _, root in ipairs(roots) do walk(root,{},visit,seen,0) end
    else
        -- Native Suburbs merging concatenates each addon items list. Aggregate
        -- matching logical paths, injecting ONLY into the final base list so
        -- an album isn't injected once per addon then duplicated by the merge.
        local hasArray=type(Distributions) == "table" and type(Distributions[1]) == "table"
        if not afterMerge and hasArray then
            local pending = {}
            for _, distribution in ipairs(Distributions) do
                walk(distribution,{},function(items,path)
                    local profile = sourceProfile(items)
                    if profile.cassette or profile.vinyl then
                        local target = finalItems(Distributions[1],path)
                        if target then
                            local entry=pending[target] or {profile={},sources={}}
                            if not entry.sources[items] then
                                entry.sources[items]=true; mergeProfile(entry.profile,profile)
                            end
                            pending[target]=entry
                        end
                    end
                end,{},0)
            end
            for items, entry in pairs(pending) do augment(items,entry.profile) end
        end
        if type(ProceduralDistributions) == "table" then walk(ProceduralDistributions,{},visit,seen,0) end
        if (afterMerge or not hasArray) and type(SuburbsDistributions) == "table" then
            walk(SuburbsDistributions,{},visit,seen,0)
        end
        if type(VehicleDistributions) == "table" then walk(VehicleDistributions,{},visit,seen,0) end
    end
    M.lootLastReport=report
    return true,report
end

-- Authors append their ordinary music before these merge lifecycle events.
-- Re-running after table replacement or a late addon is safe and idempotent.
if Events then
    if Events.OnPreDistributionMerge then Events.OnPreDistributionMerge.Add(function() M.installLoot(nil,"pre") end) end
    if Events.OnPostDistributionMerge then Events.OnPostDistributionMerge.Add(function() M.installLoot(nil,"post") end) end
    if Events.OnGameStart then Events.OnGameStart.Add(function() M.installLoot(nil,"post") end) end
end
-- Wait until author distribution appends are complete; installing on module
-- load can lock an early partial weight into an otherwise idempotent table.
return M.installLoot
