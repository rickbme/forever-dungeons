# Developing Noobs Forever Dungeon Mapper

How to set up, change things, check them, and release. [AGENTS.md](../AGENTS.md) has the rules;
[HANDOFF.md](../HANDOFF.md) has what's known about the Forever client.

## Set up

```bash
sudo apt install -y lua5.1 python3-pil gh
```

- **Game**: WoW Forever, `## Interface: 16001`. Copy or symlink `NoobsForeverDungeonMapper/` into
  `Interface\AddOns`, turn on Lua errors with `/console scriptErrors 1`, and restart the client after
  changing textures.
- Run Python with `-P` (`python3 -P tools/...`) so the script's folder stays off the import path.
- `tools/gen_data.py` fetches tables and textures from wago.tools. It sends its own User-Agent (the
  site rejects Python's default). A missing file answers HTTP 200 with an empty body: check the size.

## The loop

1. Change the Lua, or a tool and regenerate its output.
2. Check (CI runs the same):
   ```bash
   for f in NoobsForeverDungeonMapper/*.lua NoobsForeverDungeonMapper/Data/*.lua; do luac5.1 -p "$f"; done
   python3 -P tools/test/lint.py
   lua5.1 tools/test/harness.lua
   ```
   `lint.py` (adapted from OpenMap's) catches single backslashes in texture paths, local functions or
   values used before they're defined, calls to functions that don't exist, and `x and f()` dropping
   return values. When the addon starts using a new Blizzard API, add it to `WOW_API` in the lint.
3. Test in game. The harness uses a stub, so it can't tell whether pins line up or a frame looks right.

## The world map data

`NoobsForeverDungeonMapper/Data/WorldMaps.lua` is generated: the continents' art comes from the Forever
client's own tables, and the entrances from OpenMap's `Places.lua` (`tools/map-world/places.lua`).

```bash
~/.venvs/fd/bin/python -P tools/map-world/build.py                                   # regenerate
~/.venvs/fd/bin/python -P tools/map-world/build.py --preview /tmp/fd-preview --wow "<World of Warcraft folder>"
```

The second form also renders each map with its pins as PNGs, to check that the pins land in the right
places before you ship them.

## Finding out what the game allows (the probe)

Inside a dungeon, run these once and then play normally:

- `/fd probe` prints what `C_Map.GetPlayerMapPosition`, `UnitPosition`, `GetPlayerFacing` and the
  zone-text functions return (nil, a number, or a secret value) and says whether any position API works.
- `/fd probe log` records every sub-zone change, with whether a position API answered.
- The results are saved in `NoobsForeverDungeonMapperDB.probe` and `NoobsForeverDungeonMapperDB.seen` (every sub-zone name you
  entered, per dungeon). After logging out, read them from
  `WTF/Account/<account>/SavedVariables/NoobsForeverDungeonMapper.lua`, and use them to fill in `Data/Anchors.lua`.

## Releasing

1. Bump `## Version:` in `NoobsForeverDungeonMapper/NoobsForeverDungeonMapper.toc` and commit.
2. With the maintainer's go-ahead, tag it: `git tag v0.1.0-beta && git push origin v0.1.0-beta`.
3. The `release` workflow checks the tag matches the TOC version, runs the checks, zips
   `NoobsForeverDungeonMapper/` (folder at the zip root) and makes a GitHub release. Tags with `-alpha` or
   `-beta` are marked pre-release. A second job, on Windows, builds the installer and adds it to the same
   release. CurseForge is not automated.

To build the zip by hand: `python3 -P tools/package.py v0.1.0-beta` (writes `dist/`).

## The Windows installer

`installer/NoobsForeverDungeonMapper.iss` is an [Inno Setup 6](https://jrsoftware.org/isinfo.php) script.
On Windows (`winget install JRSoftware.InnoSetup --source winget`), from the repo root:

```bat
iscc installer\NoobsForeverDungeonMapper.iss
```

This writes `dist\NoobsForeverDungeonMapper-Setup-<version>.exe`, with the version read from the TOC
(`/DAppVersion=<version>` is accepted but must match it). `iscc` is in Inno Setup's folder, which isn't on
`PATH` by default.

What it does:

- **Finds the game**: the folder that contains `_forever_`. It tries the Windows uninstall entry for
  World of Warcraft (`InstallLocation`), Blizzard's `InstallPath` keys, then the usual folders on every
  fixed drive. Blizzard's records can be stale (a game moved to another drive), so each candidate must
  really hold `_forever_`. Picking `_forever_`, `_retail_` or `_forever_\Interface\AddOns` by mistake is
  corrected to the game folder; any other folder without `_forever_` gets a friendly message.
- **Installs** into `_forever_\Interface\AddOns\NoobsForeverDungeonMapper\`, after deleting the old copy
  and the legacy `ForeverDungeons` folder. It never touches `WTF\`.
- **Warns if `Wow.exe` is running** (the game only loads addons at start-up), with *check again* or
  *install anyway*.
- **Uninstalls** only the addon folder. The uninstaller itself lives in ProgramData, not the game folder.
- Asks for admin, because the game is usually under Program Files. `/CURRENTUSER` skips that, for testing.
- Keep `AppId` as it is: Windows recognises upgrades and the uninstaller by it.

To test without touching a real install, make a fake game folder and install into it silently:

```bat
mkdir "%TEMP%\fake\World of Warcraft\_forever_\Interface\AddOns"
dist\NoobsForeverDungeonMapper-Setup-0.1.0-beta.exe /VERYSILENT /CURRENTUSER /DIR="%TEMP%\fake\World of Warcraft" /LOG="%TEMP%\fake\setup.log"
```

The installer isn't signed, so Windows SmartScreen shows "Windows protected your PC" (*More info* >
*Run anyway*). A code-signing certificate would remove that; not worth it for the beta.
