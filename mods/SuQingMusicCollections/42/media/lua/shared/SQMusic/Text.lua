-- Generated ASCII-safe Lua; upstream original strings remain in Catalog.
require "SQMusic/Catalog"
SQMusic = SQMusic or {}
local M = SQMusic

local function languageCode(override)
    if override then return string.upper(tostring(override)) end
    local language = Translator and Translator.getLanguage and Translator.getLanguage()
    return language and language:name() or "EN"
end

function M.trackTitle(id, language)
    local track = M.Catalog.tracks[id]
    if not track then return tostring(id or "?") end
    local code = languageCode(language)
    if code == "CN" or code == "CH" then return track.titleDisplayCN or track.titleCN or track.titleEN or track.title end
    if code == "CN_READABLE" then return track.titleCN or track.titleEN or track.title end
    if code == "JP" or code == "ORIGINAL" then return track.title or track.titleEN end
    return track.titleEN or track.title
end

function M.artistName(id, language)
    local code = languageCode(language)
    if id == "Mixed" or id == "mixed" then
        return (code == "CN" or code == "CH" or code == "CN_READABLE") and "\232\135\170\229\136\182\228\184\147\232\190\145" or "Custom Album"
    end
    local artist = M.Catalog.artists[id]
    if not artist then return tostring(id or "?") end
    if code == "CN" or code == "CH" then return artist.nameDisplayCN or artist.nameCN or artist.name end
    if code == "CN_READABLE" then return artist.nameCN or artist.name end
    if code == "JP" or code == "ORIGINAL" then return artist.name or artist.nameEN end
    return artist.nameEN or artist.name or tostring(id)
end
return M
