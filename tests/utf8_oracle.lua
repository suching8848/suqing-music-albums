local M, C = SQMusic, SQMusic.Catalog
-- Expected bytes are decoded by Java directly from source-JSON/independent
-- editable reading labels, never re-entered through the Lua compiler.
for id, track in pairs(C.tracks) do
    check(nativeAssertUTF8(track.title, "original." .. id), "every original title compiles to exact source UTF8: " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "CN"), "original." .. id), "every CN default respects current supported original glyphs: " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "EN"), "english." .. id), "every English title matches independent source: " .. id)
end
for id, artist in pairs(C.artists) do
    check(nativeAssertUTF8(artist.name, "artist.source." .. id), "every reviewed artist preserves exact Unicode bytes: " .. id)
    check(nativeAssertUTF8(M.artistName(id, "CN"), "artist.source." .. id), "every default CN artist respects original name: " .. id)
end
for _, id in ipairs({"AM53", "AM65", "AM25"}) do
    check(nativeAssertUTF8(C.tracks[id].title, "original." .. id), "original catalog Unicode " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "ORIGINAL"), "original." .. id), "original helper Unicode " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "CN"), "original." .. id), "CN default preserves original name " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "CN_READABLE"), "readable." .. id), "optional readable Chinese title " .. id)
    check(nativeAssertUTF8(M.trackTitle(id, "EN"), "english." .. id), "upstream English title " .. id)
end
check(nativeAssertUTF8(M.artistName("MyGO", "ORIGINAL"), "artist.MyGO"), "upstream artist name")
check(nativeAssertUTF8(M.artistName("RoseliaSakuraAyane", "CN"), "artist.original.RoseliaSakuraAyane"), "default original collaboration author")
check(nativeAssertUTF8(M.artistName("TogenashiTogeari", "CN"), "artist.original.TogenashiTogeari"), "default original Japanese author")
check(nativeAssertUTF8(M.artistName("RoseliaSakuraAyane", "CN_READABLE"), "artist.RoseliaSakuraAyane"), "optional Chinese collaboration author")
check(nativeAssertUTF8(M.artistName("ProjectZomboid", "CN"), "artist.original.ProjectZomboid"), "default base soundtrack author")
check(nativeAssertUTF8(M.artistName("ProjectZomboid", "CN_READABLE"), "artist.ProjectZomboid"), "optional base soundtrack Chinese author")

function getText(key, ...)
    local text = nativeLookupText("translation." .. key) or key
    local values = {...}
    for i, value in ipairs(values) do text = text:gsub("%%" .. tostring(i), function() return tostring(value) end) end
    return text
end
Translator = {getLanguage = function() return {name = function() return "CN" end} end}
local tracks, artists = {}, {}
for id, track in pairs(C.tracks) do
    if track.available ~= false and not artists[track.artist] then
        artists[track.artist] = true; tracks[#tracks + 1] = id
        if #tracks == 3 then break end
    end
end
local mixed = M.newState("Mixed", "cassette", "collected", tracks)
check(M.isMixed(mixed), "mixed title fixture has three authors")
check(nativeAssertUTF8(M.title(mixed), "mixed.title"), "actual Chinese mixed title and count")
check(nativeAssertUTF8(M.artistName("Mixed", "CN"), "translation.UI_SQM_CustomAlbum"), "Mixed sentinel displays localized title")
check(nativeAssertUTF8(nativeRoundTrip({title = M.title(mixed)}).title, "mixed.title"), "Chinese title survives native serialization")
print("ASSERTIONS=" .. tostring(CHECKS))
return true
