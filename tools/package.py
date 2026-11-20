"""Build dist/NoobsForeverDungeonMapper-<tag>.zip with the NoobsForeverDungeonMapper folder at the zip's root.

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
        for base, _dirs, files in os.walk(os.path.join(ROOT, ADDON)):
            for name in sorted(files):
                path = os.path.join(base, name)
                z.write(path, os.path.relpath(path, ROOT))
    print(out)


main()
