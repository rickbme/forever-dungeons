# Plan: from Forever Dungeons to a world map addon

Draft, 2026-11-19. Reference: https://github.com/openmap-world/openmap (MIT, code only; Blizzard art excluded).

## Open question (decides everything below)

OpenMap is already a seamless world map for WoW Forever, with dungeon maps included. What will ours do
that OpenMap doesn't? Until that is answered, this plan assumes **our own addon that reuses OpenMap's
MIT code and data where it helps, with credit**, and keeping our edge: auto-open dungeon map, boss kill tracking,
floor guessing from sub-zone text. If the answer is "nothing", forking OpenMap and contributing
upstream is cheaper than rebuilding it.

## Rules (adopted in spirit from OpenMap's AGENTS.md; written as our own AGENTS.md in phase 0)

1. True to the game: Blizzard's art and Blizzard's tables only; credit anything drawn by players.
2. Generated files are generated (`Data/*.lua` come from `tools/gen_data.py`).
3. OpenMap's code, data tables and tools are MIT and we reuse them, crediting it (CREDITS.md, file headers).
   Not covered: Blizzard art and the player-drawn art (permission needs the artist). Other addons
   (perweum, Arcaneology) are GPL: study, don't copy.
4. No secrets or personal data in the repo; releases only with the maintainer's go-ahead.
5. Don't weaken the checks to pass a change.
6. Never touch Blizzard's `WorldMapFrame` (hooks break its OnShow on this client). Own window only.
7. Secret values: never compare or do arithmetic on them; go through `ns.Safe`.

## Phase 0: groundwork (done 2026-11-19 except publishing the release)

- Add `AGENTS.md` and `docs/development.md` (rules above, verify commands, in-game-check list).
- Add `.claude/settings.json` allow rules (handoff item 3).
- Add `.github/workflows/test.yml` (luac syntax check + harness) and a tag-triggered `release.yml`
  that builds `ForeverDungeons-<tag>.zip` with the folder at the zip root (handoff items 1-2).
- Add a lint script (single-backslash texture paths, tabs, no global leaks).
- Publish v0.1.0-beta after `gh auth login`.
- Baseline today: all `.lua` pass `luac5.1 -p`; harness runs on Lua 5.1.

## Phase 1: make the dungeon addon real (in game, on the gaming PC)

This is the riskiest gap: the addon has never run in the live game.
- Checklist from the handoff: window layout, pin alignment, minimap button, `ENCOUNTER_END`
  firing, live view, no errors with `/console scriptErrors 1`.
- Fix what breaks; extend the harness for each bug found.

## Phase 2: dungeons parity with OpenMap

- Maps for the 9 new Forever dungeons. Options: stitch WMO minimap tiles from the client, or use
  OpenMap's player-drawn art **only with the artists' permission** (they credit the drawer in game).
- Hand-placed pins for remade dungeons (Deadmines, RFC, Stockade, SM, Scholomance).
- Multi-language sub-zone matching for floor guessing; locale file scaffolding.

## Phase 3: world map (only if the open question justifies it)

- Standalone window, never hooking `WorldMapFrame`. Zones come from the 60 Forever UiMaps.
- Stitch zone art into a seamless continent view; pan and zoom; player pin via
  `C_Map.GetPlayerMapPosition` (works outdoors, blocked in instances).
- Dungeon entrances as pins that open our dungeon window.
- Data pipeline in `tools/` like `gen_data.py`, with `--verify` against the client.
- Options panel (Ace3 or plain frames: decide; Ace3 adds bundled libs and licences).

## Phase 4: polish

- Quest and loot notes, auto-hide in combat, minimap integration, CurseForge listing (manual approval only).

## Not decided / needs the user

- The differentiator vs OpenMap (above).
- Name: keep "Forever Dungeons" or rename once it is more than dungeons.
- Whether to ask OpenMap's maintainers about sharing data or art.

## Status 2026-11-19 (maps from the game's own files)

- Ported OpenMap's minimap pipeline (`tools/map-dungeons/minimap.py`, `tools/casc/casc.py`). It reads
  the local install (`OPENMAP_WOW`, needs `pip install pillow numpy scipy` in a venv).
- Built maps for The Hall of Thanes, Ruins of Lordaeron (2 floors) and City of Dalaran. They are wired in
  by `Data/Merge.lua`; dungeons with Blizzard tiles are untouched.
- **Blocked:** the WDT files for The Drowned City, Blackmaw Hold, Shaper's Terrace, Krol'dok Stronghold
  and Alcaz Prison are encrypted in the installed build, so they can't be built until Blizzard releases
  them (re-run the tool then). Excavation Site: Wetlands has data but no good crop yet.
- Not done: boss pins on the new maps, Dalaran's blank patches (rooms with no minimap picture).

## Status 2026-11-19 (later): Reyes' maps included

- His announcement allows addon use (non-commercial, credit and watermark kept). Ported OpenMap's
  `drawn.py`; `art/drawn/dungeons/` holds his 15 maps and `Data/DungeonDrawn.lua` the tiles (35 MB of TGA).
- `Data/Merge.lua` now prefers his maps, falling back to minimap-built floors. The window shows
  "Map by Santiago Reyes - sreyesmaps.com"; Dalaran's Underbelly floor opens by sub-zone.
- Eight of the nine new dungeons now have maps. **Alcaz Prison** still has none (he lists it as planned).
- Next: boss pins on the new maps (hand-placed, maybe via an editor like OpenMap's), pins for the remade
  classic dungeons from OpenMap's `DungeonBosses.lua`, then in-game testing, then the world map (Phase 3).
- Not included yet: his sea chart and gap paintings (need his OK for the world map), OpenMap's world map code.

## Status 2026-11-19 (later still): location anchors

- Idea: since coordinates are hidden in instances, mark where you are by sub-zone ("you are here" marker
  from `Data/Anchors.lua`), plus manual placement and an in-game placer later.
- Built: `/fd probe` (`Probe.lua`) to test the game's position APIs in a live dungeon; sub-zone names
  you enter are always recorded in `ForeverDungeonsDB.seen`; the marker moves with the sub-zone and
  turns the map to that anchor's floor. Only The Hall of Thanes has anchors so far, and its three names
  are read from Reyes' map labels, not confirmed in game.
- Next: run the probe in game, fill `Data/Anchors.lua` from `seen`, then click-to-place "I'm here".
