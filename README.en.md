# SuQing's Music Albums

Published publicly on 2026-11-03: [Workshop 3832881848](https://steamcommunity.com/sharedfiles/filedetails/?id=3832881848) · [Git source](https://github.com/suching8848/suqing-music-albums). Native submit and public query checks passed; publication, local installation and gameplay acceptance are separate. Actual audio, zombie response and new artwork remain subject to user gameplay checks.

Single-player True Music extension, version 1.1.0, for Project Zomboid B42.21.
Stable Mod ID: `SuQingMusicCollections`. Requires True Music B42 (`truemusic`,
Workshop 3397198968). It references separately installed recordings and includes
no music audio. See [NOTICE.md](NOTICE.md) for sources and rights.

The reviewed catalog supports the GIRLS BAND CRY, Poppin'Party, MyGO!!!!! / Ave
Mujica and Roselia packs listed in NOTICE, plus the base main-theme media. Enable
the packs you want to use. Other True Music addons are not automatically imported.
The existing True Music headphone compatibility subpatch is optional; the offline
suite exercises playback with and without it against the current upstream code.

Find premade artist selections where ordinary supported tapes and vinyl spawn,
or select at least two different owned singles of the same medium and use the
inventory context menu to make your own album. Artists may be mixed. Custom
albums can be split back into the exact input items; premade selections cannot.
All carriers weigh 0.02, matching the current original single items regardless of
track count. Selections use existing single-item loot weights, with no extra
probability multiplier or track-count scaling.

Open the normal device options to see the integrated collapsible playlist. Pick
a song or use previous/next, stop, play once in order, list loop, single repeat or
shuffle without repeats within a round. The same artist appears as the album
heading; mixed tracks show “Custom Album” and each track's artist. Closing the
window keeps playback running. Each media slot retains its own playlist state.
Reloading starts paused while retaining the chosen track and mode.

Walkmans and carried devices with headphones use local nonspatial audio. Their
managed music creates no public playback record or zombie sound event; removing
headphones, power or battery stops it. Ordinary speakers and vehicle/world radios
retain public sound behavior. Offline traces and native parsing do not replace
actual FMOD, audible spatialization or zombie-response acceptance in game.

`PPP75` references a missing upstream audio file and is unavailable; it is not
silently replaced. Missing packs cannot supply their own songs. Before disabling
the mod, eject every collection and split any custom albums you want to preserve.
New collection items are not guaranteed to survive disabling their item scripts.

The original game, saves, enabled-mod lists and Workshop files are preserved.
`tools/build_catalog.py --check` checks reviewed generated data;
`tools/run_tests.py` runs native Kahlua and structural/behavior validation without
launching the game, opening a world or loading a personal save. The current
machine-specific regression fixtures and font evidence are documented in
`validation/test-result.json`; full visual and gameplay acceptance is separate.
