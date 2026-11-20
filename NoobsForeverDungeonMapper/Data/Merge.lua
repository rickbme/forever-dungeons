-- Gives a dungeon the game has no map for its floors. First choice is the maps drawn by Santiago Reyes
-- (Data/DungeonDrawn.lua, used with his permission and credited on the map); where there is none, the
-- floors built from the game's own minimap pictures (Data/DungeonMinimap.lua). Dungeons that already
-- have Blizzard's map tiles are left alone. Hand-written; the data files it reads are generated.
local _, ns = ...

local function Add(d, floors, fromMinimap)
    for _, f in ipairs(floors) do
        d.floors[#d.floors + 1] = {
            name = f.name or d.name, tiles = f.tiles, yards = f.yards,
            credit = f.credit, subzones = f.subzones, builtFromMinimap = fromMinimap,
        }
    end
end

for id, d in pairs(ns.Dungeons) do
    if #d.floors == 0 then
        local drawn = ns.MapDungeonDrawn and ns.MapDungeonDrawn[id]
        local built = ns.MapDungeonMinimap and ns.MapDungeonMinimap[id]
        if drawn then Add(d, drawn, false) elseif built then Add(d, built, true) end
    end
end

-- Boss pins. Order of preference: placed by hand (Data/BossPlaces.lua), then OpenMap's
-- (Data/DungeonBosses.lua; its tables only apply where the floor order matches ours), then none.
local function key(name) return (name:lower():gsub("[^%w]", "")) end
local DIFFERENT_FLOORS = { [229] = true, [429] = true } -- Blackrock Spire, Dire Maul

local function Pin(b, p)
    if p and not b.x and p[1] and p[2] and p[3] then b.floor, b.x, b.y = p[1], p[2], p[3] end
end

for id, d in pairs(ns.Dungeons) do
    local placed = ns.BossPlaces and ns.BossPlaces[id] or {}
    local theirs = (ns.MapDungeonBosses and not DIFFERENT_FLOORS[id]) and ns.MapDungeonBosses[id] or {}
    local byKey = {}
    for name, p in pairs(placed) do byKey[key(name)] = p end
    for _, b in ipairs(d.bosses) do Pin(b, byKey[key(b.name)]) end
    byKey = {}
    for name, p in pairs(theirs) do byKey[key(name)] = p end
    for _, b in ipairs(d.bosses) do Pin(b, byKey[key(b.name)]) end
end
