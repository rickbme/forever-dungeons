"""Build dist/NoobsForeverDungeonMapper-<tag>.zip: the addon for players. The zip holds only the
NoobsForeverDungeonMapper folder (no code, tools or docs) and a HOW-TO-INSTALL.txt.

    python3 -P tools/package.py v0.1.0-beta

The tag must equal "v" + the toc's `## Version:`, so a release can't ship under the wrong number.
"""
import os
import re
import sys
import zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ADDON = "NoobsForeverDungeonMapper"


def toc_version():
    text = open(os.path.join(ROOT, ADDON, ADDON + ".toc"), encoding="utf-8").read()
    m = re.search(r"^## Version:\s*(\S+)", text, re.M)
    if not m:
        sys.exit("no ## Version: in the toc")
    return m.group(1)


INSTALL = """HOW TO INSTALL: Noobs Forever Dungeon Mapper %(tag)s
==========================================================

1. Close World of Warcraft.
2. Open the game's folder. It is the one that holds "_forever_", for example
   C:\\Program Files (x86)\\World of Warcraft
3. Go into:  _forever_\\Interface\\AddOns
   (If there is an older "NoobsForeverDungeonMapper" or "ForeverDungeons" folder in there, delete it first.)
4. Copy the folder "NoobsForeverDungeonMapper" from this zip into that AddOns folder.
   The inside of it must look like: ...\\AddOns\\NoobsForeverDungeonMapper\\NoobsForeverDungeonMapper.toc
   (not a folder inside a folder).
5. Start the game. At the character screen click "AddOns" and check that
   "Noobs Forever Dungeon Mapper" is ticked.
6. Walk into a dungeon. The map opens by itself. The map icon on your minimap shows and hides it,
   and right-click on it opens the options. No typing needed.

Problems? Tell us in the Noobs Forever Discord, or open an issue at
https://github.com/rickbme/noobs-forever-dungeon-mapper/issues
Map pictures of the new dungeons are by Santiago Reyes (sreyesmaps.com). Thank you!
"""

SKIP = {".DS_Store", "Thumbs.db"}


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    tag = sys.argv[1]
    if tag != "v" + toc_version():
        sys.exit("tag %s doesn't match the toc version v%s" % (tag, toc_version()))
    out_dir = os.path.join(ROOT, "dist")
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, "%s-%s.zip" % (ADDON, tag))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        # a plain-text note first, then ONLY the addon folder (players copy that folder into AddOns)
        z.writestr("HOW-TO-INSTALL.txt", INSTALL.replace("\n", "\r\n") % {"tag": tag})
        for base, dirs, files in os.walk(os.path.join(ROOT, ADDON)):
            dirs[:] = sorted(d for d in dirs if d != "__pycache__")
            for name in sorted(files):
                if name in SKIP or name.endswith(".pyc"):
                    continue
                path = os.path.join(base, name)
                z.write(path, os.path.relpath(path, ROOT))
    print(out)


main()
