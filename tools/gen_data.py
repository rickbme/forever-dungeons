#!/usr/bin/env python3
"""Generate NoobsForeverDungeonMapper/Data/Dungeons.lua from public game-data tables.

Sources (all fetched from https://wago.tools, which mirrors Blizzard's client data):
  * Forever client (product "wowf"): instance names (Map), boss lists (DungeonEncounter),
    named sub-areas (AreaTable).
  * Mists of Pandaria Classic client (product "wow_classic"): the dungeon map definitions
    (UiMap*, UiMapArtTile) and boss pin positions (JournalEncounter). The Forever client has
    no dungeon maps of its own, but it still ships the legacy map textures these tables point
    to, so the addon can draw them by FileDataID without redistributing any art.

Nothing downloaded is executed; CSVs are cached in --cache (default ~/.cache/noobs-forever-dungeon-mapper).

Usage:
  python3 tools/gen_data.py            # fetch (if not cached) and write the Lua data file
  python3 tools/gen_data.py --verify   # also check one tile per floor exists in the Forever build
"""
import argparse
import collections
import csv
import json
import os
import re
import sys
import urllib.request

FOREVER_PRODUCT = "wowf"
ART_PRODUCT = "wow_classic"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "NoobsForeverDungeonMapper", "Data", "Dungeons.lua")

# Forever's dungeon and raid list (Warcraft Wiki, "World of Warcraft: Forever", November 2026).
# instanceID = Map.ID = 8th return of GetInstanceInfo().
DUNGEONS = [
    # id, short, levels, new, raid
    (3065, "HoT", "13-20", True, False),     # The Hall of Thanes
    (389, "RFC", "13-19", False, False),     # Ragefire Chasm
    (2999, "RoL", "15-22", True, False),     # Ruins of Lordaeron
    (43, "WC", "15-24", False, False),       # Wailing Caverns
    (36, "DM", "17-26", False, False),       # The Deadmines
    (33, "SFK", "20-30", False, False),      # Shadowfang Keep
    (34, "Stocks", "24-32", False, False),   # The Stockade
    (48, "BFD", "24-32", False, False),      # Blackfathom Deeps
    (2998, "ESW", "26-33", True, False),     # Excavation Site: Wetlands
    (2959, "Dal", "28-35", True, False),     # City of Dalaran
    (47, "RFK", "29-38", False, False),      # Razorfen Kraul
    (90, "Gnomer", "29-38", False, False),   # Gnomeregan
    (189, "SM", "30-46", False, False),      # Scarlet Monastery (all four wings)
    (2970, "DC", "35-42", True, False),      # The Drowned City
    (129, "RFD", "37-46", False, False),     # Razorfen Downs
    (3039, "KS", "40-47", True, False),      # Krol'dok Stronghold
    (70, "Ulda", "41-51", False, False),     # Uldaman
    (209, "ZF", "44-54", False, False),      # Zul'Farrak
    (349, "Mara", "46-55", False, False),    # Maraudon
    (2994, "AP", "48-55", True, False),      # Alcaz Prison
    (109, "ST", "50-60", False, False),      # Sunken Temple
    (230, "BRD", "52-60", False, False),     # Blackrock Depths
    (429, "DM", "54-60", False, False),      # Dire Maul (East, West, North)
    (229, "BRS", "55-60", False, False),     # Blackrock Spire (Lower and Upper)
    (2974, "BMH", "55-60", True, False),     # Blackmaw Hold
    (3001, "ShT", "58-60", True, False),     # The Shaper's Terrace
    (329, "Strat", "58-60", False, False),   # Stratholme
    (289, "Scholo", "58-60", False, False),  # Scholomance
    (249, "Ony", "60", False, True),         # Onyxia's Lair
]

# Encounter difficulties that belong to Forever's normal mode. Other IDs in the table
# (198, 201, 215, ...) are leftovers from seasonal Classic modes.
NORMAL_DIFFICULTIES = {"0", "1"}

# Map tiles: legacy dungeon maps are 4 x 3 tiles of 256 px, showing a 1002 x 668 area.
TILE_COLS, TILE_ROWS = 4, 3


def get(url):
    # wago.tools rejects Python's default User-Agent.
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "noobs-forever-dungeon-mapper-gen/1.0"}))


def latest_build(product):
    with get("https://wago.tools/api/builds") as r:
        builds = json.load(r)
    return builds[product][0]["version"]


def fetch_table(cache, build, table):
    path = os.path.join(cache, build, table + ".csv")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        url = f"https://wago.tools/db2/{table}/csv?build={build}"
        print(f"  fetching {table} ({build})", file=sys.stderr)
        with get(url) as r, open(path, "wb") as f:
            f.write(r.read())
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def build_data(cache, forever_build, art_build):
    t = lambda b, n: fetch_table(cache, b, n)
    maps = {int(r["ID"]): r["MapName_lang"] for r in t(forever_build, "Map")}

    encounters = collections.defaultdict(list)
    for r in t(forever_build, "DungeonEncounter"):
        if r["DifficultyID"] in NORMAL_DIFFICULTIES:
            encounters[int(r["MapID"])].append(r)

    subzones = collections.defaultdict(list)
    for r in t(forever_build, "AreaTable"):
        subzones[int(r["ContinentID"])].append(r["AreaName_lang"])

    uimaps = {int(r["ID"]): r for r in t(art_build, "UiMap")}
    assign = collections.defaultdict(set)
    for r in t(art_build, "UiMapAssignment"):
        assign[int(r["UiMapID"])].add(int(r["MapID"]))
    xart = {}
    for r in t(art_build, "UiMapXMapArt"):
        xart.setdefault(int(r["UiMapID"]), int(r["UiMapArtID"]))
    tiles = collections.defaultdict(dict)
    for r in t(art_build, "UiMapArtTile"):
        if r["LayerIndex"] == "0":
            tiles[int(r["UiMapArtID"])][(int(r["RowIndex"]), int(r["ColIndex"]))] = int(r["FileDataID"])
    group = {int(r["UiMapID"]): r for r in t(art_build, "UiMapGroupMember")}
    journal = collections.defaultdict(list)
    for r in t(art_build, "JournalEncounter"):
        journal[int(r["UiMapID"])].append(r)

    out = []
    for inst, short, levels, new, raid in DUNGEONS:
        name = maps.get(inst)
        if not name:
            sys.exit(f"instance {inst} not in the Forever Map table")

        floors = []
        for uid, um in uimaps.items():
            if um["Type"] not in ("4", "6") or inst not in assign[uid] or uid not in xart:
                continue
            grid = tiles[xart[uid]]
            if len(grid) != TILE_COLS * TILE_ROWS:
                continue
            g = group.get(uid, {})
            floors.append({
                "uiMapID": uid,
                "name": g.get("Name_lang") or um["Name_lang"],
                "order": int(g.get("FloorIndex") or 0),
                "tiles": [grid[(row, col)] for row in range(TILE_ROWS) for col in range(TILE_COLS)],
            })
        floors.sort(key=lambda f: (f["order"], f["uiMapID"]))
        floor_index = {f["uiMapID"]: i + 1 for i, f in enumerate(floors)}

        # Boss positions from the journal, matched by name: the journal also covers the
        # Cataclysm remakes of some dungeons, whose bosses Forever does not have.
        pins = {}
        for uid in floor_index:
            for j in journal[uid]:
                pins.setdefault(norm(j["Name_lang"]), (floor_index[uid], float(j["Map_0"]), float(j["Map_1"])))

        bosses, seen = [], set()
        for e in sorted(encounters[inst], key=lambda e: int(e["OrderIndex"])):
            key = norm(e["Name_lang"])
            if key in seen or "nolongerinuse" in key:
                continue
            seen.add(key)
            b = {"id": int(e["ID"]), "name": e["Name_lang"]}
            if key in pins:
                b["floor"], b["x"], b["y"] = pins[key]
            bosses.append(b)

        subs = [s for s in dict.fromkeys(subzones[inst]) if s != name and "UNUSED" not in s.upper()
                and not s.startswith("*") and not s.lower().startswith("unused")]

        out.append({"id": inst, "name": name, "short": short, "levels": levels, "new": new,
                    "raid": raid, "floors": floors, "bosses": bosses, "subzones": subs})
    return out


def write_lua(data, forever_build, art_build):
    lines = [
        "-- GENERATED by tools/gen_data.py. Do not edit by hand; rerun the script instead.",
        f"-- Forever build {forever_build}; map definitions and boss pins from build {art_build}.",
        "-- [instanceID] = { name, short, levels, new, raid, floors = { {uiMapID, name, tiles = 12 FileDataIDs,",
        "--   row by row, 4 x 256 px across, 3 down} }, bosses = { {id = DungeonEncounterID, name, floor, x, y} },",
        "--   subzones = { names } }",
        "local _, ns = ...",
        "ns.Dungeons = {",
    ]
    for d in data:
        lines.append(f"  [{d['id']}] = {{")
        lines.append(f"    name = {lua_str(d['name'])}, short = {lua_str(d['short'])}, levels = {lua_str(d['levels'])},"
                     f" new = {str(d['new']).lower()}, raid = {str(d['raid']).lower()},")
        lines.append("    floors = {")
        for f in d["floors"]:
            lines.append(f"      {{ uiMapID = {f['uiMapID']}, name = {lua_str(f['name'])}, tiles = {{"
                         + ",".join(str(x) for x in f["tiles"]) + "} },")
        lines.append("    },")
        lines.append("    bosses = {")
        for b in d["bosses"]:
            pos = f", floor = {b['floor']}, x = {b['x']:.4f}, y = {b['y']:.4f}" if "floor" in b else ""
            lines.append(f"      {{ id = {b['id']}, name = {lua_str(b['name'])}{pos} }},")
        lines.append("    },")
        lines.append("    subzones = {" + ", ".join(lua_str(s) for s in d["subzones"]) + "},")
        lines.append("  },")
    lines.append("}")
    lines.append("ns.DungeonOrder = {" + ", ".join(str(d["id"]) for d in data) + "}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def verify(data, forever_build):
    missing = 0
    for d in data:
        for f in d["floors"]:
            fd = f["tiles"][0]
            try:
                with get(f"https://wago.tools/api/casc/{fd}?download&version={forever_build}") as r:
                    ok = r.read(4) == b"BLP2"
            except Exception:
                ok = False
            if not ok:
                missing += 1
                print(f"  MISSING in Forever: {d['name']} / {f['name']} tile {fd}", file=sys.stderr)
    return missing


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", default=os.path.expanduser("~/.cache/noobs-forever-dungeon-mapper"))
    ap.add_argument("--forever-build", help="Forever build (default: latest on wago.tools)")
    ap.add_argument("--art-build", help="MoP Classic build for map data (default: latest)")
    ap.add_argument("--verify", action="store_true", help="check the map tiles exist in the Forever build")
    a = ap.parse_args()

    fb = a.forever_build or latest_build(FOREVER_PRODUCT)
    ab = a.art_build or latest_build(ART_PRODUCT)
    print(f"Forever build {fb}, map data build {ab}", file=sys.stderr)
    data = build_data(a.cache, fb, ab)
    write_lua(data, fb, ab)

    nf = sum(len(d["floors"]) for d in data)
    nb = sum(len(d["bosses"]) for d in data)
    npins = sum(1 for d in data for b in d["bosses"] if "floor" in b)
    print(f"wrote {OUT}: {len(data)} instances, {nf} floors, {nb} bosses ({npins} with map pins)", file=sys.stderr)
    for d in data:
        if not d["floors"]:
            print(f"  no map art: {d['name']}", file=sys.stderr)
    if a.verify:
        missing = verify(data, fb)
        print(f"verify: {missing} floor(s) missing from the Forever build", file=sys.stderr)
        sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
