# Developing Forever Dungeons

How to set up, change things, check them, and release. [AGENTS.md](../AGENTS.md) has the rules;
[HANDOFF.md](../HANDOFF.md) has what's known about the Forever client.

## Set up

```bash
sudo apt install -y lua5.1 python3-pil gh
```

- **Game**: WoW Forever, `## Interface: 16001`. Copy or symlink `ForeverDungeons/` into
  `Interface\AddOns`, turn on Lua errors with `/console scriptErrors 1`, and restart the client after
  changing textures.
- Run Python with `-P` (`python3 -P tools/...`) so the script's folder stays off the import path.
- `tools/gen_data.py` fetches tables and textures from wago.tools. It sends its own User-Agent (the
  site rejects Python's default). A missing file answers HTTP 200 with an empty body: check the size.

## The loop

1. Change the Lua, or a tool and regenerate its output.
2. Check (CI runs the same):
   ```bash
   for f in ForeverDungeons/*.lua ForeverDungeons/Data/*.lua; do luac5.1 -p "$f"; done
   python3 -P tools/test/lint.py
   lua5.1 tools/test/harness.lua
   ```
   `lint.py` (adapted from OpenMap's) catches single backslashes in texture paths, local functions or
   values used before they're defined, calls to functions that don't exist, and `x and f()` dropping
   return values. When the addon starts using a new Blizzard API, add it to `WOW_API` in the lint.
3. Test in game. The harness uses a stub, so it can't tell whether pins line up or a frame looks right.

## Releasing

1. Bump `## Version:` in `ForeverDungeons/ForeverDungeons.toc` and commit.
2. With the maintainer's go-ahead, tag it: `git tag v0.1.0-beta && git push origin v0.1.0-beta`.
3. The `release` workflow checks the tag matches the TOC version, runs the checks, zips
   `ForeverDungeons/` (folder at the zip root) and makes a GitHub release. Tags with `-alpha` or
   `-beta` are marked pre-release. CurseForge is not automated.

To build the zip by hand: `python3 -P tools/package.py v0.1.0-beta` (writes `dist/`).
