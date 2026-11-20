# Handoff: Noobs Forever Dungeon Mapper

Notes for the next working session (Claude Code on the Linux server). Read this first.

## What this is

A World of Warcraft: Forever addon (`NoobsForeverDungeonMapper/`) that opens the dungeon map when you enter
a dungeon. It has a minimap button to toggle the map, a floor picker, boss pins, and a boss list
with kill tracking. Users install it by copying `NoobsForeverDungeonMapper/` into the game's `Interface\AddOns`.

- Repo: https://github.com/rickbme/noobs-forever-dungeon-mapper (only branch: `main`, which is the default)
- Version: `0.1.0-beta` (in `NoobsForeverDungeonMapper/NoobsForeverDungeonMapper.toc`)
- License: MIT. Blizzard art and data are not covered; the addon loads them from the client at runtime.
- Status: **never run in the live game yet.** It only passes the offline harness (194 checks).

## Layout

| Path | What |
|---|---|
| `NoobsForeverDungeonMapper/NoobsForeverDungeonMapper.toc` | `## Interface: 16001`, game type `forever`, load order |
| `NoobsForeverDungeonMapper/Data/Dungeons.lua` | **generated**: dungeons, floors (12 texture FileDataIDs each), bosses and pins, sub-zones |
| `NoobsForeverDungeonMapper/Core.lua` | saved variables (`NoobsForeverDungeonMapperDB`), events, kill tracking, floor guessing, `/fd` commands, addon compartment |
| `NoobsForeverDungeonMapper/MapFrame.lua` | the map window: tiles, pins, boss list, location line, dungeon menu (`MenuUtil`) |
| `NoobsForeverDungeonMapper/MinimapButton.lua` | draggable minimap button; left-click toggles, right-click opens the dungeon menu |
| `NoobsForeverDungeonMapper/LiveView.lua` | optional enlarged minimap inside dungeons (`/fd live`) |
| `tools/gen_data.py` | regenerates `Data/Dungeons.lua` from wago.tools; `--verify` checks the textures exist in the Forever build |
| `tools/test/harness.lua` | offline test against a stubbed WoW API: `lua5.1 tools/test/harness.lua` |

## Commands to run

```bash
sudo apt install -y lua5.1 python3-pil gh
```

```bash
for f in NoobsForeverDungeonMapper/*.lua NoobsForeverDungeonMapper/Data/*.lua; do luac5.1 -p "$f"; done
```

```bash
lua5.1 tools/test/harness.lua
```

```bash
python3 tools/gen_data.py --verify
```

## Key facts learned (don't re-research these)

- **Forever client**: product `wowf` on wago.tools, build 1.60.1.70959 as of 2026-11-19. TOC
  interface `16001`. It uses the modern (Midnight 12.x-era) API, including "secret values".
  `issecretvalue()` exists, and the addon wraps reads in `ns.Safe`.
- **Forever has no dungeon UiMaps**: its `UiMap` table has only 60 world, zone and city maps.
  `C_Map.GetBestMapForUnit("player")` returns nil inside dungeons.
- **The legacy dungeon map textures still ship in the Forever client.** The addon draws them by
  FileDataID: 4x3 tiles of 256 px, with a visible area of 1002x668. Map definitions and boss pins
  come from **MoP Classic** (`wow_classic`, build 5.5.4.x) tables `UiMap`, `UiMapAssignment`,
  `UiMapXMapArt`, `UiMapArtTile`, `UiMapGroupMember` and `JournalEncounter`. Wrath Classic tables
  lack the vanilla dungeon art; don't use them.
- JournalEncounter `Map_0`/`Map_1` are 0-1 fractions of the 1002x668 area. Pins are kept only when
  the boss name matches a Forever boss. That drops the Cataclysm/MoP remake bosses, so Deadmines,
  RFC, Stockade, SM and Scholomance have no pins.
- **Player position is blocked in instances**: `C_Map.GetPlayerMapPosition`, `UnitPosition` and
  `GetPlayerFacing` all return nil there. That's why the addon uses sub-zone text, encounter events
  and the minimap instead.
- **Boss kills**: Forever fires `ENCOUNTER_END` (with `success == 1`) for dungeon bosses.
  `BOSS_KILL` is not reliable. Payload values may be secret, so the addon matches by encounter ID
  and then by name.
- `GetInstanceInfo()`'s 8th return is the instanceID (equal to the Map table ID). The Forever
  `LFGDungeons` table has MapID 0 everywhere, so it can't distinguish wings.
- **Don't hook `WorldMapFrame`**: another Forever addon found that hooks break the map's OnShow
  on this client. This addon uses its own standalone window.
- **Minimap**: Forever has its own "Camelot" minimap code inside an Edit Mode–managed
  `MinimapContainer`. Live view only calls `Minimap:SetScale` (never the container) and never in
  combat. `MenuUtil` and the addon compartment exist.
- **wago.tools rejects Python's default User-Agent**: `gen_data.py` sends its own. Useful
  endpoints are `/api/builds`, `/db2/<Table>/csv?build=<ver>` and
  `/api/casc/<FileDataID>?download&version=<ver>`.
- **Blizzard UI source for Forever**: https://github.com/Gethe/wow-ui-source, branch `forever`.
  `Interface/AddOns/Blizzard_APIDocumentationGenerated/` lists each function's restrictions.
- **Reference addons** (studied, no code copied; both are GPL, so keep it that way):
  perweum/dungeon-crawler-forever, which also stitched WMO minimap tiles for the new dungeons'
  maps, and Arcaneology/WowHandbookAddon.

## To do next

1. **Publish the v0.1.0-beta release.** It couldn't be done from the cloud session. From the
   server, after `gh auth login`, build the zip with the `NoobsForeverDungeonMapper` folder at the zip's
   root, then run:
   ```bash
   gh release create v0.1.0-beta NoobsForeverDungeonMapper-v0.1.0-beta.zip --target main --prerelease --title "Noobs Forever Dungeon Mapper v0.1.0 Beta" --generate-notes
   ```
2. **Add a GitHub Actions release workflow.** Bumping `## Version:` in the TOC on `main` would
   then build the zip and publish a release automatically.
3. **Add `.claude/settings.json` allow rules** for `lua5.1`, `luac5.1`, `python3 tools/gen_data.py`,
   and WebFetch on warcraft.wiki.gg, wago.tools and curseforge.com.
4. **In-game testing** (on the gaming PC):
   - the window looks right
   - pins line up
   - the minimap button sits on the minimap's edge
   - `ENCOUNTER_END` really fires on kills
   - live view looks OK on the Forever minimap
   - nothing errors with `/console scriptErrors 1`
5. **Later features:**
   - maps for the 9 new Forever dungeons (stitch WMO minimap tiles from the client, or use
     community art with permission)
   - hand-placed pins for the remade dungeons
   - quest and loot notes
   - an option to auto-hide the map in combat

## Things that were blocked in the cloud session (not an issue on the server)

- GitHub releases, tag pushes, branch deletion and repo-settings changes are all refused by the
  cloud session's GitHub proxy.
- The auto-mode safety check blocked fetching CurseForge pages and the branch delete.
- Lua wasn't preinstalled, so it was installed with `apt-get install lua5.1` each session.
