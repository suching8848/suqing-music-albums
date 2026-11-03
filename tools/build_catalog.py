"""Build reviewed True Music metadata and references; never copy upstream audio.

First import: python tools/build_catalog.py --import-local
Rebuild: python tools/build_catalog.py
Verify generated files: python tools/build_catalog.py --check
Unknown upstream artists fail import instead of being assigned by item numbers.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/catalog-source.json"
READABLE = ROOT / "data/readable-titles.json"
MEDIA = ROOT / "mods/SuQingMusicCollections/42/media"
WORKSHOP = Path(r"D:\steam\steamapps\workshop\content\108600")
DISPLAY_FONT = WORKSHOP / "3556544454/mods/B42Trans_CN_As1/42.0/media/fonts/zomboidSmallCN.fnt"
PACKS = [(3554671997, "GIRLS BAND CRY Music"), (3585009083, "Poppin'Party music b42"),
         (3585014312, "Anime music b42"), (3654879576, "Roselia Music")]
# Explicitly reviewed from the installed packs' artist fields, not number ranges.
ARTISTS = {
    "TOGENASHI TOGEARI": ("TogenashiTogeari", "トゲナシトゲアリ"),
    "Diamond dust": ("DiamondDust", "ダイヤモンドダスト"),
    "Yusuke Tanaka,agehasprings": ("TanakaAgehasprings", "田中ユウスケ × agehasprings"),
    "Poppin'Party": ("PoppinParty", "Poppin'Party"),
    "Poppin'Party,GlitterGreen": ("PoppinPartyGlitterGreen", "Poppin'Party × Glitter*Green"),
    "Poppin'Party,Maejima Yumi, Ito Mika": ("PoppinPartyMaeshimaIto", "Poppin'Party × 前島亜美 × 伊藤美来"),
    "Poppin'Party,AIHA AI": ("PoppinPartyAiba", "Poppin'Party × 相羽あいな"),
    "MyGO!!!!!": ("MyGO", "MyGO!!!!!"), "Ave Mujica": ("AveMujica", "Ave Mujica"),
    "sumimi": ("sumimi", "sumimi"), "Roselia": ("Roselia", "Roselia"),
    "Roselia, Afterglow": ("RoseliaAfterglow", "Roselia × Afterglow"),
    "Roselia, LAYER": ("RoseliaLAYER", "Roselia × LAYER"),
    "Roselia, Sakura Ayane": ("RoseliaSakuraAyane", "Roselia × 佐倉綾音"),
}


def blocks(text: str, tag: str):
    for match in re.finditer(r"\b" + tag + r"\s+(\w+)\s*\{", text):
        start = match.end(); depth = 1; end = start
        while depth and end < len(text):
            depth += (text[end] == "{") - (text[end] == "}"); end += 1
        if depth: raise ValueError(f"Unclosed {tag}: {match[1]}")
        yield match[1], text[start:end - 1]


def media_for(wid: int) -> Path:
    roots = list((WORKSHOP / str(wid) / "mods").iterdir())
    if len(roots) != 1: raise ValueError(f"Ambiguous installed pack {wid}")
    return roots[0] / "42/media"


def sound_info(media: Path) -> dict:
    result = {}
    for path in sorted((media / "scripts").glob("*.txt")):
        for name, body in blocks(path.read_text(encoding="utf-8-sig"), "sound"):
            found = re.search(r"\bfile\s*=\s*([^,\r\n]+)", body)
            if not found: continue
            clip = found[1].strip()
            volume = re.search(r"\bvolume\s*=\s*([^,\r\n]+)", body)
            master = re.search(r"\bmaster\s*=\s*([^,\r\n]+)", body)
            result[name] = {"file": clip, "volume": float(volume[1]) if volume else 1.0,
                            "master": master[1].strip() if master else "Primary"}
    return result


def import_local() -> dict:
    tracks = []; hashes = {}; support = []; weights = {"cassette": set(), "vinyl": set()}
    for wid, mod_id in PACKS:
        media = media_for(wid)
        trans = media / "lua/shared/Translate"
        enfile = trans / "EN/ItemName.json"; cnfile = trans / "CN/ItemName.json"
        en = json.loads(enfile.read_text(encoding="utf-8-sig"))
        cn = json.loads(cnfile.read_text(encoding="utf-8-sig"))
        for p in [enfile, cnfile, *sorted((media / "scripts").glob("*.txt"))]:
            hashes[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
        sounds = sound_info(media)
        items = {}
        for p in (media / "scripts").glob("*.txt"):
            for name, body in blocks(p.read_text(encoding="utf-8-sig"), "item"):
                weight = re.search(r"\bWeight\s*=\s*([0-9.]+)", body)
                items[name] = float(weight[1]) if weight else None
        for full, value in en.items():
            if not full.startswith("Tsarcraft.Cassette"): continue
            name = full.split(".", 1)[1]; track_id = name[len("Cassette"):]
            raw = re.sub(r"^Anime\s+Cassette\s*", "", value)
            raw_artist, sep, title_en = raw.partition(" - ")
            if not sep or raw_artist not in ARTISTS: raise ValueError(f"Unreviewed artist {full}: {raw}")
            artist, artist_name = ARTISTS[raw_artist]
            cassette = "Cassette" + track_id; vinyl = "Vinyl" + track_id
            for carrier in (cassette, vinyl):
                if carrier not in items or carrier not in sounds: raise ValueError(f"Unpaired {carrier}")
                sounds[carrier]["available"] = (media.parent / sounds[carrier]["file"]).is_file()
                kind = "cassette" if carrier.startswith("Cassette") else "vinyl"
                if items[carrier] is None: raise ValueError(f"No source weight for {carrier}")
                weights[kind].add(items[carrier])
            title = cn.get(full, value).partition(" - ")[2].strip() or title_en.strip()
            talk = bool(re.search(r"after\s*talk|アフタートーク", title + " " + title_en, re.I))
            tracks.append({"id": track_id, "title": title, "titleEN": title_en.strip(),
                           "artist": artist, "artistName": artist_name, "sourceArtist": raw_artist,
                           "sourceWorkshop": str(wid), "sourceMod": mod_id, "talk": talk,
                           "available": all(sounds[c]["available"] for c in (cassette, vinyl)),
                           "cassette": "Tsarcraft." + cassette, "vinyl": "Tsarcraft." + vinyl,
                           "sounds": {"cassette": sounds[cassette], "vinyl": sounds[vinyl]}})
    tm = media_for(3397198968); sounds = sound_info(tm)
    for p in [tm / "scripts/TCTrueItems.txt", tm / "scripts/TCTrueSounds.txt"]:
        hashes[str(p)] = hashlib.sha256(p.read_bytes()).hexdigest()
    for kind in ("cassette", "vinyl"):
        sound = kind.title() + "MainTheme"
        if not (tm.parent / sounds[sound]["file"]).is_file(): raise ValueError(f"Missing {sound} audio")
        support.append({"id": "MainTheme", "kind": kind, "item": "Tsarcraft." + sound,
                        "title": "Project Zomboid Main Theme", "artist": "ProjectZomboid",
                        "sound": sound, **sounds[sound]})
    for name, body in blocks((tm / "scripts/TCTrueItems.txt").read_text(encoding="utf-8-sig"), "item"):
        for kind in ("cassette", "vinyl"):
            if name == kind.title() + "MainTheme":
                weight = re.search(r"\bWeight\s*=\s*([0-9.]+)", body)
                if not weight: raise ValueError(f"No source weight for {name}")
                weights[kind].add(float(weight[1]))
    if any(len(values) != 1 for values in weights.values()):
        raise ValueError(f"Source carrier weights differ; review before choosing album weights: {weights}")
    tracks.sort(key=lambda t: (next(i for i, p in enumerate(PACKS) if str(p[0]) == t["sourceWorkshop"]),
                               re.sub(r"\d+$", "", t["id"]), int(re.search(r"\d+$", t["id"])[0])))
    if len({t["id"] for t in tracks}) != len(tracks): raise ValueError("Track ID collision")
    if not DISPLAY_FONT.is_file(): raise ValueError("Review the active CN font before rebuilding display labels")
    hashes[str(DISPLAY_FONT)] = hashlib.sha256(DISPLAY_FONT.read_bytes()).hexdigest()
    return {"schema": 1, "review": "Artist groups derive from explicit upstream artist metadata. Collaboration groups remain separate. After-talk is excluded from default albums. No grouping is inferred from item number ranges.",
            "sourceHashes": hashes, "tracks": tracks, "support": support,
            "displayFont": str(DISPLAY_FONT),
            "carrierWeights": {kind: next(iter(values)) for kind, values in weights.items()}}


def lua(value):
    if value is None: return "nil"
    if value is True: return "true"
    if value is False: return "false"
    if isinstance(value, str):
        # The installed Kahlua lexer narrows raw Unicode source characters to a
        # byte before decoding a string as UTF-8. Emit the UTF-8 bytes explicitly.
        return '"' + ''.join(chr(b) if 32 <= b <= 126 and b not in (34, 92)
                             else '\\%03d' % b for b in value.encode("utf-8")) + '"'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, list): return "{" + ",".join(map(lua, value)) + "}"
    return "{" + ",".join("[" + lua(k) + "]=" + lua(v) for k, v in value.items()) + "}"


def generate(data: dict) -> dict[Path, str]:
    readable = json.loads(READABLE.read_text(encoding="utf-8"))
    title_cn = readable["trackTitlesCN"]
    names_cn_map = readable["artistNamesCN"]
    font_text = Path(data["displayFont"]).read_text(encoding="utf-8-sig")
    glyphs = {int(value) for value in re.findall(r"\bchar\s+id=\s*(\d+)", font_text)}
    def display_cn(original, fallback, english):
        if all(ord(char) in glyphs for char in original): return original
        return fallback if all(ord(char) in glyphs for char in fallback) else english
    tracks = {}; artists = {}; by_item = {}; albums = {}; aliases = {}
    for row in data["tracks"]:
        tid = row["id"]; aid = row["artist"]
        if tid in tracks: raise ValueError(f"Duplicate track {tid}")
        tracks[tid] = {key: row[key] for key in ("id", "title", "titleEN", "artist", "cassette", "vinyl", "talk", "available")}
        tracks[tid]["titleCN"] = title_cn.get(tid, row["title"])
        tracks[tid]["titleDisplayCN"] = display_cn(row["title"], tracks[tid]["titleCN"], row["titleEN"])
        artist = artists.setdefault(aid, {"id": aid, "name": row["artistName"],
                                         "nameEN": row["sourceArtist"],
                                         "nameCN": names_cn_map.get(aid, row["sourceArtist"]),
                                         "nameDisplayCN": display_cn(row["artistName"], names_cn_map.get(aid,row["sourceArtist"]), row["sourceArtist"]),
                                         "tracks": [], "allTracks": []})
        artist["allTracks"].append(tid)
        if not row["talk"] and row["available"]: artist["tracks"].append(tid)
        for kind in ("cassette", "vinyl"):
            full = row[kind]; sound = full.split(".", 1)[1]; private = "SQM_Private_" + sound
            by_item[full] = {"id": tid, "artist": aid, "kind": kind, "sound": sound,
                             "title": row["title"], "available": row["sounds"][kind]["available"]}
            if row["sounds"][kind]["available"]:
                by_item[full]["privateSound"] = private
                aliases[private] = row["sounds"][kind]
            else:
                by_item[full]["issue"] = "Upstream sound references a missing file: " + row["sounds"][kind]["file"]
    for row in data["support"]:
        private = "SQM_Private_" + row["sound"]
        by_item[row["item"]] = {"id": row["id"], "artist": "ProjectZomboid", "kind": row["kind"], "sound": row["sound"],
                                "privateSound": private, "title": row["title"], "available": True}
        aliases[private] = {k: row[k] for k in ("file", "volume", "master")}
        theme = tracks.setdefault("MainTheme", {"id": "MainTheme", "title": row["title"],
            "titleEN": row["title"], "titleCN": title_cn["MainTheme"], "artist": "ProjectZomboid",
            "titleDisplayCN": row["title"],
            "talk": False, "available": True})
        theme[row["kind"]] = row["item"]
    artists["ProjectZomboid"] = {"id": "ProjectZomboid", "name": "Project Zomboid",
        "nameEN": "Project Zomboid", "nameCN": names_cn_map["ProjectZomboid"],
        "nameDisplayCN": "Project Zomboid",
        "tracks": ["MainTheme"], "allTracks": ["MainTheme"]}
    names_cn = {}; names_en = {}; item_defs = []
    def item(full, cn, en, kind):
        name = full.split(".", 1)[1]; is_tape = kind == "cassette"
        icon = "SQM_CassetteAlbum" if is_tape else "SQM_VinylAlbum"
        world_model = "TCTape2" if is_tape else "TCVinylrecord2"
        names_cn[full] = cn; names_en[full] = en
        item_defs.append(f"    item {name}\n    {{\n        ItemType = base:normal,\n        DisplayCategory = Entertainment,\n        Weight = {data['carrierWeights'][kind]},\n        Icon = {icon},\n        WorldStaticModel = Tsarcraft.{world_model},\n        OnCreate = SQMusic.onCreateAlbum,\n    }}")
    for aid, artist in artists.items():
        if len(artist["tracks"]) < 2: continue
        for kind in ("cassette", "vinyl"):
            full = "SQMusic." + kind.title() + aid
            albums[full] = {"artist": aid, "kind": kind}
            cn = ("磁带精选专辑：" if kind == "cassette" else "黑胶精选专辑：") + artist["nameDisplayCN"]
            item(full, cn, artist["nameEN"] + (" Cassette Selection" if kind == "cassette" else " Vinyl Selection"), kind)
    for kind in ("cassette", "vinyl"):
        full = "SQMusic." + kind.title() + "Custom"; albums[full] = {"kind": kind, "custom": True}
        item(full, "自制" + ("磁带专辑" if kind == "cassette" else "黑胶专辑"), "Custom " + kind.title() + " Album", kind)
    if len(item_defs) != 18 or len(albums) != 18:
        raise ValueError("Reviewed release requires 16 artist selections and 2 custom album carriers; review item count changes")
    lines = ["-- Generated by tools/build_catalog.py; edit reviewed data/catalog-source.json.",
             "require \"TCMusicDefenitions\"", "SQMusic = SQMusic or {}", "SQMusic.Catalog = {"]
    for name, table in [("tracks", tracks), ("artists", artists), ("byItem", by_item), ("albumsByType", albums)]:
        lines.append("    " + name + " = {")
        lines.extend("        [" + lua(k) + "]=" + lua(v) + "," for k, v in table.items())
        lines.append("    },")
    lines += ["}", "-- This registry is carrier recognition only; it does not declare an audio source.",
              "for fullType, album in pairs(SQMusic.Catalog.albumsByType) do",
              "    local itemType = string.match(fullType, \"^[^.]+%.(.+)$\")",
              "    GlobalMusic[itemType] = album.kind == \"cassette\" and \"tsarcraft_music_01_62\" or \"tsarcraft_music_01_63\"",
              "end", "return SQMusic.Catalog", ""]
    sound_lines = ["/* Original audio references only. Private aliases are 2D, with source clip gain. */", "module SQMusic", "{"]
    for name, clip in aliases.items():
        sound_lines += [f"    sound {name}", "    {", "        category = True Music,", f"        master = {clip['master']},",
                        "        is3D = false,", "        loop = false,", "        clip", "        {",
                        f"            file = {clip['file']},", f"            volume = {clip['volume']},", "        }", "    }"]
    sound_lines += ["}", ""]
    result = {MEDIA / "lua/shared/SQMusic/Catalog.lua": "\n".join(lines),
              MEDIA / "scripts/SQM_Items.txt": "module SQMusic\n{\n" + "\n\n".join(item_defs) + "\n}\n",
              MEDIA / "scripts/SQM_Sounds.txt": "\n".join(sound_lines), MEDIA / "lua/server/SQMusic/Loot.lua": LOOT,
              MEDIA / "lua/shared/SQMusic/Text.lua": TEXT.replace("__MIXED_CN__", lua("自制专辑"))}
    for lang, names in [("CN", names_cn), ("EN", names_en)]:
        result[MEDIA / f"lua/shared/Translate/{lang}/ItemName.json"] = json.dumps(names, ensure_ascii=False, indent=2) + "\n"
    original_artists = {row["artist"]: row["artistName"] for row in data["tracks"]}
    missing_titles = {row["id"]: "".join(dict.fromkeys(char for char in row["title"] if ord(char) not in glyphs))
                      for row in data["tracks"] if any(ord(char) not in glyphs for char in row["title"])}
    missing_artists = {aid: "".join(dict.fromkeys(char for char in name if ord(char) not in glyphs))
                       for aid, name in original_artists.items() if any(ord(char) not in glyphs for char in name)}
    font_evidence = {"font": data["displayFont"], "sha256": data["sourceHashes"][data["displayFont"]],
        "owningMod": "B42Trans_CN", "fontEnum": "UIFont.Small", "glyphCount": len(glyphs),
        "sourceTrackTitles": len(data["tracks"]), "coveredOriginalTrackTitles": len(data["tracks"])-len(missing_titles),
        "sourceArtistNames": len(original_artists), "coveredOriginalArtistNames": len(original_artists)-len(missing_artists),
        "missingTitleGlyphs": missing_titles, "missingArtistGlyphs": missing_artists,
        "defaultCNPolicy": "Preserve the upstream original title/reviewed artist name when its glyphs are present; otherwise use the readable CN label, then the source English label.",
        "runtimeUTF8Policy": "Lua text is generated as ASCII-safe UTF-8 byte escapes for the installed Kahlua lexer.",
        "scope": "Static glyph-map coverage of the currently enabled CN font. This does not claim visual in-game acceptance."}
    result[ROOT / "data/font-coverage.json"] = json.dumps(font_evidence,ensure_ascii=False,indent=2)+"\n"
    return result


TEXT = '''-- Generated ASCII-safe Lua; upstream original strings remain in Catalog.
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
        return (code == "CN" or code == "CH" or code == "CN_READABLE") and __MIXED_CN__ or "Custom Album"
    end
    local artist = M.Catalog.artists[id]
    if not artist then return tostring(id or "?") end
    if code == "CN" or code == "CH" then return artist.nameDisplayCN or artist.nameCN or artist.name end
    if code == "CN_READABLE" then return artist.nameCN or artist.name end
    if code == "JP" or code == "ORIGINAL" then return artist.name or artist.nameEN end
    return artist.nameEN or artist.name or tostring(id)
end
return M
'''


LOOT = '''-- Add selections where ordinary source media can already spawn. No world refill.
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
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--import-local", action="store_true", help="Refresh the reviewed local source; rejects unknown artists")
    parser.add_argument("--check", action="store_true", help="Verify outputs without writing")
    args = parser.parse_args()
    if args.check and args.import_local: parser.error("--check and --import-local are mutually exclusive")
    if args.import_local:
        data = import_local(); SOURCE.parent.mkdir(parents=True, exist_ok=True)
        SOURCE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    changed = [path for path, expected in data["sourceHashes"].items()
               if not Path(path).is_file() or hashlib.sha256(Path(path).read_bytes()).hexdigest() != expected]
    if changed:
        raise SystemExit("Upstream metadata changed; review before --import-local: " + ", ".join(changed))
    outputs = generate(data); different = []
    for path, content in outputs.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content: different.append(str(path))
        else:
            path.parent.mkdir(parents=True, exist_ok=True); path.write_text(content, encoding="utf-8")
    if different: raise SystemExit("Generated output differs: " + ", ".join(different))
    counts = Counter(t["artist"] for t in data["tracks"] if not t["talk"] and t["available"])
    print(json.dumps({"tracks":len(data["tracks"]), "talkExcluded":sum(t["talk"] for t in data["tracks"]),
                      "artists":len(counts), "premadeArtists":sum(n>=2 for n in counts.values()),
                      "unavailable":sum(not t["available"] for t in data["tracks"]),
                      "privateSounds":sum(sum(c["available"] for c in t["sounds"].values()) for t in data["tracks"])+len(data["support"]), "outputs":len(outputs), "check":args.check}, ensure_ascii=False))


if __name__ == "__main__": main()
