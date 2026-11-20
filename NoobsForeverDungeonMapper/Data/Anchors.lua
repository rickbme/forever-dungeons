-- Known places inside dungeons, keyed by the game's sub-zone name (what GetSubZoneText returns while
-- you stand there). Inside an instance the game hides your coordinates, so the map can only say
-- "you are somewhere in this area": when the sub-zone changes, the "you are here" marker moves to
-- the anchor of that name.
--   [instanceID] = { { sub = sub-zone name, floor = floor index, x = 0..1 across, y = 0..1 down,
--                      verified = true once seen in game }, ... }
-- x and y are fractions of the 1002 x 668 map picture, as the boss pins use.
-- Hand-written. The names below are read off Santiago Reyes' Hall of Thanes map labels and are not
-- yet confirmed in game: /fd probe log records the real names (NoobsForeverDungeonMapperDB.seen) so this table
-- can be filled in and checked.
local _, ns = ...

ns.Anchors = {
    [3065] = { -- The Hall of Thanes
        { sub = "Reliquary of Kings", floor = 1, x = 0.50, y = 0.21 },
        { sub = "Dark Iron Ingress", floor = 1, x = 0.67, y = 0.45 },
        { sub = "Anvilmar's Rest", floor = 1, x = 0.44, y = 0.73 },
    },
}
