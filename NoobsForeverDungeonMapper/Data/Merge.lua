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
