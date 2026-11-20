# Instructions for AI coding agents

These rules apply to any automated assistant working in this repository, and summarise it for people
too. Read [docs/development.md](docs/development.md) for the workflow, [HANDOFF.md](HANDOFF.md) for
what's known about the game, and [PLAN.md](PLAN.md) for where this is going. The structure and rules
follow [OpenMap](https://github.com/openmap-world/openmap)'s, which this addon is modelled on.

## What this is

Forever Dungeons: a map addon for WoW Forever (Lua 5.1 in the game's retail-engine client,
`## Interface: 16001`). It opens the dungeon map when you enter a dungeon, with floors, boss pins and
kill tracking. The addon is `ForeverDungeons/`; everything else is tooling and docs.

## Hard rules

1. **True to the game.** Art is Blizzard's, loaded from the client by FileDataID. Facts (names,
   positions, bosses) come from the game's tables or a cited source. Player-drawn art only with the
   artist's permission, credited in game and in CREDITS.md.
2. **Generated files are generated.** `ForeverDungeons/Data/*.lua` comes from `tools/gen_data.py`.
   Change the script and rerun it; commit both together.
3. **Code from other addons.** OpenMap's code, data tables and tools are MIT and may be reused: say so
   in the file's first lines and add it to the table in CREDITS.md. Its player-drawn art and Blizzard
   art are not covered by that licence. Don't copy from GPL or "all rights reserved" addons
   (perweum/dungeon-crawler-forever, Arcaneology/WowHandbookAddon): study them, write our own.
4. **No secrets, no personal data** in the repo: no keys, tokens, emails or local paths.
5. **Never push a tag, publish a release or upload to CurseForge** without the maintainer's go-ahead
   for that release.
6. **Don't weaken the checks** to make a change pass.
7. **Never hook Blizzard's `WorldMapFrame`.** Hooks break its OnShow on this client; use our own
   window.

## Verify every change

```bash
for f in ForeverDungeons/*.lua ForeverDungeons/Data/*.lua; do luac5.1 -p "$f"; done
python3 -P tools/test/lint.py
lua5.1 tools/test/harness.lua
```

All must pass. For data changes also run `python3 -P tools/gen_data.py --verify`. You can't run the
game: say plainly what still needs an in-game check (textures need a full client restart), and don't
claim it works in game.

## Things that break silently here

- Single backslashes in texture paths (`"Map\947"`): use `"Map\\947"`. Lint catches it.
- Secret values: never compare, do arithmetic on, or nil-test them; use `ns.Safe`.
- `a and f()` drops `f`'s extra return values (Lua 5.1). Lint catches the common form.
- Player position is blocked in instances (`C_Map.GetPlayerMapPosition`, `UnitPosition`,
  `GetPlayerFacing` return nil).
- Writing to Blizzard frames' layout tables or calling protected functions in combat: taint.
- The offline stub answers any unknown global with a placeholder, so a typo'd or missing API passes
  the harness and is a nil global in game.
- When scripting edits, write the script to a file rather than a shell heredoc: quoting mangles
  Lua and regex backslashes.

## Style

Match the surrounding code: tabs in Lua, short comments that say why, plain names, no new
dependencies without a reason. Don't write personal data or local paths into files.
