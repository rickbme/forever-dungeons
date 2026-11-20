-- Boss pin positions placed by hand (with the in-game placer: Options > mapmaker tools), for bosses
-- neither the game's journal nor OpenMap has a place for. These win over every other source.
--   [instanceID] = { ["Boss name"] = { floor index, x 0..1 across, y 0..1 down }, ... }
-- x and y are fractions of the 1002 x 668 map picture, as for the other pins.
-- Hand-written: fill it from the lines players export with "Share my boss pins" in the options.
local _, ns = ...

ns.BossPlaces = {
}
