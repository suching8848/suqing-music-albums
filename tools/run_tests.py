"""Fresh-compile helpers and test the exact candidate in installed game Kahlua.

Audio/Java/UI fixtures are explicit boundaries. No game launcher or world starts.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import shutil
import subprocess
from datetime import datetime
from zoneinfo import ZoneInfo
from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def literal(value):
    data = value.encode("utf-8")
    return '"' + ''.join(chr(b) if 32 <= b <= 126 and b not in (34, 92)
                         else '\\%03d' % b for b in data) + '"'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--game", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--javac", type=Path)
    parser.add_argument("--syntax-only", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    game = args.game.resolve()
    mod = root / "mods" / "SuQingMusicCollections"
    out, classes = root / "validation", root / "validation/classes"
    classes.mkdir(parents=True, exist_ok=True)
    java = game / "jre64/bin/java.exe"
    candidates = [args.javac, Path(shutil.which("javac")) if shutil.which("javac") else None,
        Path(r"E:\code\kp_1016\lab2_evidence\ide-extensions\redhat.java-1.58.0-win32-x64\jre\25.0.4.1-win32-x86_64\bin\javac.exe")]
    javac = next((p for p in candidates if p and p.is_file()), None)
    files = sorted(p for p in mod.rglob("*") if p.is_file())
    report = {"passed": False, "checked_at": datetime.now(ZoneInfo("Asia/Shanghai")).isoformat(),
        "gameplay_verified": False, "game_started": False,
        "source_hashes": {p.relative_to(mod).as_posix(): digest(p) for p in files},
        "game_jar_sha256": digest(game / "projectzomboid.jar"), "counts": {}, "suites": [],
        "limitations": [
            "No game launcher, world, real save, UI acceptance or actual FMOD playback was run.",
            "Kahlua runs production Lua and selected real upstream Lua; Java inventory, device, event and audio boundaries use controlled fixtures.",
            "Native KahluaTable serialization uses the installed game implementation, fixture save version 241 and isolated in-memory buffers.",
            "Audio call traces can prove which mocked APIs production invokes, not audible spatialization or actual zombie perception.",
            "Native GameSoundScript loads each private alias as 2D metadata; no FMOD audio stream starts. Item scripts receive native structural parsing, not full registration/world loading.",
            "Native Item.Load weight checks use the exact Weight property in isolation; texture, world-dictionary and full inventory registration are outside this headless check.",
            "Native UI suite loads actual installed ISUI/RWM/window Lua; native Java rendering/input and pre-existing power/volume/media panel contents are controlled fixtures, not visual acceptance.",
        ]}
    logs = []

    def run(label, command):
        result = subprocess.run([str(x) for x in command], cwd=out, capture_output=True,
                                text=True, encoding="utf-8", errors="replace")
        text = result.stdout + result.stderr
        logs.append(label + "\n" + text)
        assert result.returncode == 0, label + " failed; see test-output.txt"
        return text

    try:
        assert files, "No candidate mod files exist."
        assert javac, "A JDK25 compiler is required; game JRE does not include javac."
        report["compiler"], report["runtime"] = str(javac), str(java)
        shutil.copyfile(game / "stdlib.lua", out / "stdlib.lua")
        report["stdlib_sha256"] = digest(game / "stdlib.lua")
        lua = sorted(p for p in (mod / "42/media/lua").rglob("*.lua"))
        assert lua, "No production Lua modules found."
        report["counts"]["lua_files"] = len(lua)
        translations = sorted((mod / "42/media/lua/shared/Translate").rglob("*.json"))
        keys = {}
        for path in translations:
            data = json.loads(path.read_text(encoding="utf-8-sig"))
            assert isinstance(data, dict) and data, f"Invalid translation: {path}"
            assert all(isinstance(v, str) and v for v in data.values()), f"Invalid translation values: {path}"
            keys[(path.parent.name, path.stem)] = set(data)
        for language, stem in keys:
            other = "EN" if language == "CN" else "CN"
            assert keys.get((other, stem)) == keys[(language, stem)], f"CN/EN translation mismatch: {stem}"
        report["counts"]["translation_files"] = len(translations)
        item_text = (mod / "42/media/scripts/SQM_Items.txt").read_text(encoding="utf-8-sig")
        album_items = re.findall(r"\bitem\s+(\w+)\s*\{([^}]+)\}", item_text)
        assert len(album_items) == 18, "Expected sixteen artist selections and two custom album items."
        icons = set()
        for item_name, body in album_items:
            cassette = item_name.startswith("Cassette")
            assert cassette or item_name.startswith("Vinyl"), "Unexpected album carrier: " + item_name
            icon = "SQM_CassetteAlbum" if cassette else "SQM_VinylAlbum"
            model = "Tsarcraft.TCTape2" if cassette else "Tsarcraft.TCVinylrecord2"
            assert re.search(r"\bIcon\s*=\s*" + re.escape(icon) + r"\s*,", body), "Album must use its own inventory icon: " + item_name
            assert re.search(r"\bWorldStaticModel\s*=\s*" + re.escape(model) + r"\s*,", body), "Original world model changed: " + item_name
            icons.add(icon)
        for icon in icons:
            path = mod / "42/media/textures" / ("Item_" + icon + ".png")
            with Image.open(path) as image:
                image.load()
                width, height = image.size
                assert image.format == "PNG" and image.mode == "RGBA", "Expected true RGBA PNG: " + str(path)
                assert width == height and width >= 32 and width & (width - 1) == 0, "Icon must be a power-of-two square: " + str(path)
                assert image.getchannel("A").getextrema()[1] > 0, "Icon is completely transparent: " + str(path)
        report["counts"]["album_items"] = len(album_items)
        report["counts"]["own_inventory_icons"] = len(icons)
        evidence = json.loads((root / "data/catalog-source.json").read_text(encoding="utf-8"))
        source_hashes = evidence["sourceHashes"]
        registry = set()
        for name, expected in source_hashes.items():
            source_path = Path(name)
            assert source_path.is_file() and digest(source_path) == expected, "Catalog upstream source drift: " + name
            if source_path.suffix.lower() == ".txt":
                source = source_path.read_text(encoding="utf-8-sig")
                module_match = re.search(r"\bmodule\s+(\S+)\s*\{", source)
                if module_match:
                    registry.update(module_match.group(1) + "." + item
                                    for item in re.findall(r"\bitem\s+(\S+)\s*\{", source))
        for source_path in (mod / "42/media/scripts").rglob("*.txt"):
            source = source_path.read_text(encoding="utf-8-sig")
            module_match = re.search(r"\bmodule\s+(\S+)\s*\{", source)
            if module_match:
                registry.update(module_match.group(1) + "." + item
                                for item in re.findall(r"\bitem\s+(\S+)\s*\{", source))
        report["upstream_source_hashes"] = source_hashes
        oracle = {"custom.source": "离线测试磁带", "mixed.title": "自制专辑 - 3首",
                  "artist.original.RoseliaSakuraAyane": "Roselia × 佐倉綾音",
                  "artist.original.TogenashiTogeari": "トゲナシトゲアリ",
                  "artist.original.ProjectZomboid": "Project Zomboid"}
        upstream_cn_path = next(Path(name) for name in source_hashes if "3585014312" in name and name.endswith("CN\\ItemName.json"))
        upstream_en_path = next(Path(name) for name in source_hashes if "3585014312" in name and name.endswith("EN\\ItemName.json"))
        upstream_cn = json.loads(upstream_cn_path.read_text(encoding="utf-8-sig"))
        upstream_en = json.loads(upstream_en_path.read_text(encoding="utf-8-sig"))
        readable_path = root / "data/readable-titles.json"
        readable = json.loads(readable_path.read_text(encoding="utf-8"))
        translation_cache = {}
        for track in evidence["tracks"]:
            wid = track["sourceWorkshop"]
            for language, prefix in (("CN", "original."), ("EN", "english.")):
                key = (wid, language)
                if key not in translation_cache:
                    path = next(Path(name) for name in source_hashes if wid in name and name.endswith(language + "\\ItemName.json"))
                    translation_cache[key] = json.loads(path.read_text(encoding="utf-8-sig"))
                oracle[prefix + track["id"]] = translation_cache[key][track["cassette"]].split(" - ", 1)[1].strip()
            oracle.setdefault("artist.source." + track["artist"], track["artistName"])
        oracle["original.MainTheme"] = oracle["english.MainTheme"] = "Project Zomboid Main Theme"
        oracle["artist.source.ProjectZomboid"] = "Project Zomboid"
        for track_id in ("AM53", "AM65", "AM25"):
            item_key = "Tsarcraft.Cassette" + track_id
            oracle["original." + track_id] = upstream_cn[item_key].split(" - ", 1)[1]
            oracle["english." + track_id] = upstream_en[item_key].split(" - ", 1)[1]
            oracle["readable." + track_id] = readable["trackTitlesCN"][track_id]
        oracle["artist.MyGO"] = upstream_cn["Tsarcraft.CassetteAM53"].split(" - ", 1)[0].removeprefix("动漫磁带 ")
        oracle["artist.RoseliaSakuraAyane"] = readable["artistNamesCN"]["RoseliaSakuraAyane"]
        oracle["artist.ProjectZomboid"] = "僵尸毁灭工程"
        for path in translations:
            if path.parent.name == "CN" and path.stem == "UI":
                for key, value in json.loads(path.read_text(encoding="utf-8-sig")).items(): oracle["translation." + key] = value
        oracle_path = out / "utf8-oracle.tsv"
        oracle_path.write_text("".join(key + "\t" + value.encode("utf-8").hex() + "\n" for key, value in sorted(oracle.items())), encoding="ascii")
        report["utf8_oracle"] = {"sha256": digest(oracle_path), "entries": len(oracle),
            "sources": {str(path): digest(path) for path in (upstream_cn_path, upstream_en_path, readable_path)}}
        report["counts"]["source_item_types"] = len(registry)
        sound_text = (mod / "42/media/scripts/SQM_Sounds.txt").read_text(encoding="utf-8-sig")
        aliases = {}
        for alias, block in re.findall(r"\bsound\s+(\S+)\s*\{(.*?)\n    \}", sound_text, re.S):
            def field(name):
                found = re.search(r"\b" + name + r"\s*=\s*([^,\r\n]+)", block)
                assert found, "Missing sound property " + name + ": " + alias
                return found.group(1).strip()
            aliases[alias] = {"file": field("file"), "volume": float(field("volume")),
                              "master": field("master"), "is3D": field("is3D")}
        source_media = {}
        for name in source_hashes:
            source_path = Path(name)
            if source_path.suffix.lower() == ".txt" and source_path.parent.name == "scripts":
                match = re.search(r"[\\/]108600[\\/](\d+)[\\/]", name)
                if match: source_media[match.group(1)] = source_path.parent.parent.parent
        expected_by_item = {}
        missing_sources = []
        for track in evidence["tracks"]:
            for kind, sound in track["sounds"].items():
                path = source_media[track["sourceWorkshop"]] / sound["file"]
                available = path.is_file()
                assert available == sound.get("available", True), "Music clip availability drift: " + str(path)
                if not available: missing_sources.append(str(path))
                expected_by_item[track[kind]] = (sound, available)
        for sound in evidence.get("support", []):
            assert (source_media["3397198968"] / sound["file"]).is_file(), "Base theme audio missing"
            expected_by_item[sound["item"]] = (sound, True)
        catalog_text = (mod / "42/media/lua/shared/SQMusic/Catalog.lua").read_text(encoding="utf-8-sig")
        used_aliases = set()
        checked_links = 0
        for full_type, block in re.findall(r'^\s*\["(Tsarcraft\.[^"]+)"\]=\{([^\n]+)\},?\s*$', catalog_text, re.M):
            sound, available = expected_by_item[full_type]
            match = re.search(r'\["privateSound"\]="([^"]+)"', block)
            if not available:
                assert not match and '["available"]=false' in block, "Missing audio must have no private alias: " + full_type
                continue
            assert match, "Playable source lacks private alias: " + full_type
            alias = match.group(1)
            assert alias in aliases and alias not in used_aliases, "Unknown/duplicate private alias: " + alias
            used_aliases.add(alias)
            actual = aliases[alias]
            assert actual["file"] == sound["file"] and abs(actual["volume"] - sound["volume"]) < 0.00001, "Private alias changed source file/gain: " + full_type
            assert actual["master"] == sound["master"] and actual["is3D"] == "false", "Private alias changed master/spatial mode: " + full_type
            checked_links += 1
        assert used_aliases == set(aliases), "Unreferenced private sounds"
        report["counts"]["verified_private_audio_links"] = checked_links
        report["known_unavailable_upstream_clips"] = missing_sources
        registry_lines = ["FIXTURE_REGISTERED_ITEMS = {"]
        registry_lines.extend("[" + literal(name) + "]=true," for name in sorted(registry))
        registry_lines.append("}")
        for track in evidence["tracks"]:
            for kind, sprite in (("cassette", "tsarcraft_music_01_62"), ("vinyl", "tsarcraft_music_01_63")):
                full_type = track[kind]
                assert full_type in registry, "Catalog references missing source item: " + full_type
                registry_lines.append("GlobalMusic[" + literal(full_type.split(".", 1)[1]) + "]=" + literal(sprite))
        (out / "registry.lua").write_text("\n".join(registry_lines) + "\n", encoding="utf-8")
        generated = "\n".join("assert(loadstring(" + literal(p.read_text(encoding="utf-8-sig"))
                              + "," + literal(p.relative_to(mod).as_posix()) + "))" for p in lua)
        syntax = out / "syntax.lua"
        syntax.write_text(generated + "\nreturn true\n", encoding="utf-8")
        compile_cmd = [javac, "-encoding", "UTF-8", "-cp", game / "projectzomboid.jar",
                       "-d", classes, root / "tools/KahluaValidation.java", root / "tools/NativeAssetsValidation.java"]
        run("FRESH COMPILE", compile_cmd)
        base = [java, "--enable-native-access=ALL-UNNAMED", "-cp",
                str(game / "projectzomboid.jar") + ";" + str(classes)]
        run("KAHLUA SYNTAX", base + ["KahluaValidation", syntax])
        scripts = sorted((mod / "42/media/scripts").rglob("*.txt"))
        if scripts:
            source_item_files = [Path(name) for name in source_hashes if name.endswith(".txt") and "MusicScript" in name or name.endswith("TCTrueItems.txt")]
            source_args = [part for path in source_item_files for part in ("--source-items", path)]
            text = run("NATIVE SCRIPT STRUCTURE", base + ["NativeAssetsValidation", *scripts, *source_args])
            report["counts"]["native_script_blocks"] = int(re.search(r"NATIVE_SCRIPT_BLOCKS=(\d+)", text).group(1))
            report["counts"]["native_2d_sounds"] = int(re.search(r"NATIVE_2D_SOUNDS=(\d+)", text).group(1))
            report["counts"]["native_item_weights"] = int(re.search(r"NATIVE_ITEM_WEIGHTS=(\d+)", text).group(1))
        if not args.syntax_only:
            manifest = json.loads((root / "tests/suites.json").read_text(encoding="utf-8"))
            assert manifest, "No behavior suites registered."
            suite_hashes = {}
            for suite in manifest:
                script_paths = [root / p for p in suite["scripts"]]
                for path in script_paths:
                    assert path.is_file(), "Suite file missing: " + str(path)
                    suite_hashes[str(path)] = digest(path)
                text = run(suite["name"], base + ["KahluaValidation", "--oracle", oracle_path, *script_paths])
                result = {"name": suite["name"], "passed": True}
                counts = re.findall(r"ASSERTIONS=(\d+)", text)
                result["assertions"] = int(counts[-1]) if counts else 0
                trips = re.search(r"NATIVE_TABLE_ROUND_TRIPS=(\d+)", text)
                result["native_table_round_trips"] = int(trips.group(1)) if trips else 0
                report["suites"].append(result)
            assert all(Path(p).is_file() and digest(Path(p)) == value for p, value in suite_hashes.items()), "Loaded production/upstream/test source changed during tests."
            report["loaded_lua_hashes"] = suite_hashes
        report["syntax_only"] = args.syntax_only
        assert report["source_hashes"] == {p.relative_to(mod).as_posix(): digest(p) for p in files}, "Candidate changed during tests; rerun exact final sources."
        assert set(report["source_hashes"]) == {p.relative_to(mod).as_posix() for p in mod.rglob("*") if p.is_file()}, "Candidate file set changed during tests."
        assert all(Path(p).is_file() and digest(Path(p)) == value for p, value in source_hashes.items()), "Upstream source changed during tests."
        report["passed"] = True
    except Exception as exc:
        report["error"] = str(exc)
        logs.append("ERROR: " + str(exc))
    (out / "test-output.txt").write_text("\n".join(logs), encoding="utf-8")
    (out / "test-result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("\n".join(logs))
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
