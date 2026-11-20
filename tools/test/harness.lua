-- Offline test harness: loads the addon against a minimal stub of the WoW API and plays
-- through a dungeon run (enter, floor changes, boss kills, reset, leave).
-- Run from the repository root:  lua5.1 tools/test/harness.lua
-- This only checks the addon's own logic; it cannot show what the frames look like in game.

local ADDON = "NoobsForeverDungeonMapper"
local failures = 0
local out = print
local function check(cond, msg)
    if cond then out("  ok   " .. msg) else failures = failures + 1; out("  FAIL " .. msg) end
end

-------------------------------------------------------------------------------
-- WoW API stubs
-------------------------------------------------------------------------------
local game = { inInstance = false, instanceID = nil, instanceType = "none", subzone = "", combat = false, minimapScale = 1 }
local printed = {}

local realPrint = print
_G.print = function(...)
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(t, " ")
end

local function noop() end
local widgetMeta
local function NewWidget()
    local w = { shown = true, scripts = {}, points = {}, text = "", events = {} }
    return setmetatable(w, widgetMeta)
end
widgetMeta = {
    __index = function(self, k)
        local methods = {
            Show = function(s) s.shown = true end,
            Hide = function(s) s.shown = false end,
            IsShown = function(s) return s.shown end,
            SetShown = function(s, v) s.shown = not not v end,
            SetScript = function(s, n, fn) s.scripts[n] = fn end,
            GetScript = function(s, n) return s.scripts[n] end,
            SetText = function(s, t) s.text = t end,
            GetText = function(s) return s.text end,
            SetTexture = function(s, t) s.texture = t end,
            SetEnabled = function(s, v)
                assert(type(v) == "boolean", "SetEnabled needs a boolean")
                s.enabled = v
            end,
            SetScale = function(s, v) s.scale = v end,
            GetScale = function(s) return rawget(s, "scale") or 1 end,
            GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
            GetFrameLevel = function() return 1 end,
            GetWidth = function() return 140 end,
            GetCenter = function() return 100, 100 end,
            GetEffectiveScale = function() return 1 end,
            CreateTexture = function() return NewWidget() end,
            CreateFontString = function() return NewWidget() end,
            CreateMaskTexture = function() return NewWidget() end,
            CreateAnimationGroup = function() return NewWidget() end,
            CreateAnimation = function() return NewWidget() end,
            RegisterEvent = function(s, e) s.events[e] = true end,
            UnregisterEvent = function(s, e) s.events[e] = nil end,
        }
        return methods[k] or noop
    end,
}

local eventFrames = {}
function CreateFrame(kind, name)
    local w = NewWidget()
    if kind == "Frame" and not name then eventFrames[#eventFrames + 1] = w end
    if name then _G[name] = w end
    return w
end
UIParent = NewWidget()
GameTooltip = NewWidget()
GameTooltip_Hide = noop
Minimap = NewWidget()
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
INSTANCE_RESET_SUCCESS = "%s has been reset."
issecretvalue = function(v) return type(v) == "table" and v.secret end
function IsInInstance() return game.inInstance, game.instanceType end
function GetInstanceInfo()
    return game.instanceName or "Azeroth", game.instanceType, 1, "Normal", 5, 0, false, game.instanceID
end
function GetSubZoneText() return game.subzone end
function GetZoneText() return game.instanceName or "Azeroth" end
function GetRealZoneText() return game.instanceName or "Azeroth" end
function GetMinimapZoneText() return game.subzone end
function IsIndoors() return true end
function GetUnitSpeed() return 0, 7, 7, 4.7 end
function UnitPosition() return nil end
function GetPlayerFacing() return nil end
C_Map = { GetBestMapForUnit = function() return nil end }
function InCombatLockdown() return game.combat end
local cursor = { 0, 0 }
function GetCursorPosition() return cursor[1], cursor[2] end
time = os.time

local function Fire(event, ...)
    for _, fr in ipairs(eventFrames) do
        if fr.events and fr.events[event] and fr.scripts.OnEvent then fr.scripts.OnEvent(fr, event, ...) end
    end
end

-------------------------------------------------------------------------------
-- Load the addon like the client does: each file gets (addonName, namespace)
-------------------------------------------------------------------------------
local ns = {}
for _, file in ipairs({ "Data/Dungeons.lua", "Data/DungeonDrawn.lua", "Data/DungeonMinimap.lua", "Data/Merge.lua", "Data/Anchors.lua", "Core.lua", "Probe.lua", "MapFrame.lua", "LiveView.lua", "MinimapButton.lua" }) do
    local chunk = assert(loadfile("NoobsForeverDungeonMapper/" .. file))
    chunk(ADDON, ns)
end
Fire("ADDON_LOADED", ADDON)

realPrint("Data")
local n = 0
for id, d in pairs(ns.Dungeons) do
    n = n + 1
    for _, f in ipairs(d.floors) do
        check(#f.tiles == 12, d.name .. " / " .. f.name .. " has 12 tiles")
    end
    for _, b in ipairs(d.bosses) do
        if b.floor then
            check(d.floors[b.floor] and b.x >= 0 and b.x <= 1 and b.y >= 0 and b.y <= 1,
                d.name .. " / " .. b.name .. " pin is on a real floor and inside the map")
        end
    end
end
check(n == #ns.DungeonOrder, "every dungeon is in DungeonOrder")
-- every dungeon the game has no map for gets floors from Reyes' drawings or the minimap data,
-- except the ones that are still encrypted in the client
for _, id in ipairs({ 3065, 2999, 2959, 2998, 2970, 3039, 2974, 3001 }) do
    local d = ns.Dungeons[id]
    check(#d.floors > 0, d.name .. " has floors")
    check(d.floors[1] and d.floors[1].credit == "Santiago Reyes", d.name .. " uses the drawn map and credits the artist")
end
check(#ns.Dungeons[2994].floors == 0, "Alcaz Prison has no art yet")
for id, d in pairs(ns.Dungeons) do
    for _, f in ipairs(d.floors) do
        for _, t in ipairs(f.tiles) do
            if type(t) == "string" then
                local path = t:gsub("^Interface\\AddOns\\", ""):gsub("\\", "/") .. ".tga"
                local fh = io.open("./" .. path)
                check(fh ~= nil, "tile exists: " .. path)
                if fh then fh:close() end
            end
        end
    end
end

realPrint("Minimap button")
local mb = NoobsForeverDungeonMapperMinimapButton
check(mb and mb:IsShown(), "minimap button is created and shown")
cursor[1], cursor[2] = 100, 200 -- straight above the minimap centre
mb.scripts.OnDragStart(mb)
mb.scripts.OnUpdate(mb)
mb.scripts.OnDragStop(mb)
check(math.abs(ns.db.minimapAngle - 90) < 0.01, "dragging moves the button (angle 90)")
check(mb.scripts.OnUpdate == nil, "dragging stops on release")

realPrint("Entering Blackfathom Deeps")
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 48, "Blackfathom Deeps"
Fire("PLAYER_ENTERING_WORLD")
check(NoobsForeverDungeonMapperFrame and NoobsForeverDungeonMapperFrame:IsShown(), "map opens automatically")
check(ns.ViewedInstance() == 48, "map shows Blackfathom Deeps")
check(NoobsForeverDungeonMapperFrame.title.text == "Blackfathom Deeps", "title is the dungeon name")
check(NoobsForeverDungeonMapperFrame.tiles[1].texture == ns.Dungeons[48].floors[1].tiles[1], "first floor tiles are drawn")

realPrint("Walking into a named area that is also a floor")
game.subzone = "Moonshrine Sanctum"
Fire("ZONE_CHANGED_INDOORS")
check(NoobsForeverDungeonMapperFrame.tiles[1].texture == ns.Dungeons[48].floors[2].tiles[1], "floor follows the sub-zone")
check(NoobsForeverDungeonMapperFrame.location.text:find("Moonshrine Sanctum", 1, true), "location line shows the area")

realPrint("Killing the first boss")
local first = ns.Dungeons[48].bosses[1]
Fire("ENCOUNTER_START", first.id, first.name, 1, 5)
check(NoobsForeverDungeonMapperFrame.location.text:find("Fighting", 1, true), "location line shows the fight")
Fire("ENCOUNTER_END", first.id, first.name, 1, 5, 1)
check(ns.IsKilled(48, first), "boss is marked killed")
check(select(1, ns.KillCount(48)) == 1, "kill count is 1")
check(ns.NextBoss(48) == ns.Dungeons[48].bosses[2], "next boss advances")
check(NoobsForeverDungeonMapperFrame.subtitle.text:find("1/" .. #ns.Dungeons[48].bosses, 1, true), "subtitle shows progress")

realPrint("A wipe does not count as a kill")
local second = ns.Dungeons[48].bosses[2]
Fire("ENCOUNTER_END", second.id, second.name, 1, 5, 0)
check(not ns.IsKilled(48, second), "wipe leaves the boss alive")

realPrint("Secret values are ignored, the name still matches")
Fire("ENCOUNTER_END", { secret = true }, second.name, 1, 5, 1)
check(ns.IsKilled(48, second), "kill found by name when the ID is secret")
Fire("ENCOUNTER_END", { secret = true }, { secret = true }, 1, 5, { secret = true })
check(select(1, ns.KillCount(48)) == 2, "fully secret payload changes nothing")

realPrint("BOSS_KILL after ENCOUNTER_END does not double count")
Fire("BOSS_KILL", second.id, second.name)
check(select(1, ns.KillCount(48)) == 2, "still 2 kills")

realPrint("Instance reset message")
Fire("CHAT_MSG_SYSTEM", "Blackfathom Deeps has been reset.")
check(select(1, ns.KillCount(48)) == 0, "kills cleared by the reset message")

realPrint("Live view")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("live")
check(Minimap:GetScale() == ns.db.liveScale, "minimap enlarged inside the dungeon")
game.combat = true

realPrint("Leaving the dungeon in combat")
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.subzone = false, "none", nil, nil, ""
Fire("PLAYER_ENTERING_WORLD")
check(not NoobsForeverDungeonMapperFrame:IsShown(), "map closes on leaving")
check(Minimap:GetScale() == ns.db.liveScale, "minimap left alone during combat")
game.combat = false
Fire("PLAYER_REGEN_ENABLED")
check(Minimap:GetScale() == 1, "minimap restored after combat")

realPrint("Slash command opens the last dungeon outside")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("")
check(NoobsForeverDungeonMapperFrame:IsShown() and ns.ViewedInstance() == 48, "/fd reopens the last viewed dungeon")
check(NoobsForeverDungeonMapperFrame.location.text:find("Viewing only", 1, true), "outside, the map says it is only a preview")

realPrint("Minimap button toggles the map")
mb.scripts.OnClick(mb, "LeftButton")
check(not NoobsForeverDungeonMapperFrame:IsShown(), "click hides the map")
mb.scripts.OnClick(mb, "LeftButton")
check(NoobsForeverDungeonMapperFrame:IsShown(), "click shows it again")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("button")
check(not mb:IsShown(), "/fd button hides the button")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("button")
check(mb:IsShown(), "/fd button shows it again")

realPrint("A new Forever dungeon without art")
ns.ShowDungeon(2994)
check(NoobsForeverDungeonMapperFrame.noArt:IsShown(), "no-art message shows")
check(not NoobsForeverDungeonMapperFrame.tiles[1]:IsShown(), "no tiles drawn")

realPrint("A new Forever dungeon with a drawn map shows the credit")
ns.ShowDungeon(3065)
check(not NoobsForeverDungeonMapperFrame.noArt:IsShown(), "no no-art message")
check(NoobsForeverDungeonMapperFrame.tiles[1]:IsShown(), "tiles drawn")
check(NoobsForeverDungeonMapperFrame.credit:GetText():find("Santiago Reyes", 1, true), "artist is credited on the map")


realPrint("You-are-here marker follows the sub-zone")
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 3065, "The Hall of Thanes"
game.subzone = "Dark Iron Ingress"
Fire("PLAYER_ENTERING_WORLD")
local here = NoobsForeverDungeonMapperFrame.here
check(here:IsShown(), "marker shows in a known area")
check(here.anchor and here.anchor.sub == "Dark Iron Ingress", "marker uses that area's anchor")
game.subzone = "Somewhere Unlisted"
Fire("ZONE_CHANGED_INDOORS")
check(not here:IsShown(), "marker hides in an area with no anchor")
check(ns.db.seen[3065]["Somewhere Unlisted"] == 1, "the new sub-zone name is recorded")

realPrint("Probe")
printed = {}
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe")
local joined = table.concat(printed, "\n")
check(joined:find("UnitPosition = nil", 1, true), "probe reports a blocked API as nil")
check(joined:find("only sub-zone anchors", 1, true), "probe says no position API answered")
check(ns.db.probe.last and ns.db.probe.last.anyPosition == false, "probe result is saved")
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe log")
game.subzone = "Anvilmar's Rest"
Fire("ZONE_CHANGED_INDOORS")
check(#ns.db.probe.log == 1 and ns.db.probe.log[1].sub == "Anvilmar's Rest", "probe log records a sub-zone change")
UnitPosition = function() return 10, 20, 30, 40 end
game.subzone = "Reliquary of Kings"
Fire("ZONE_CHANGED_INDOORS")
check(ns.db.probe.log[2].anyPosition == true, "probe log notices when a position API answers")
UnitPosition = function() return nil end
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER("probe clear")
check(ns.db.probe == nil, "probe clear forgets results")
game.inInstance, game.instanceType, game.instanceID, game.instanceName, game.subzone = false, "none", nil, nil, ""
Fire("PLAYER_ENTERING_WORLD")

realPrint("Unknown instance prints a note")
printed = {}
game.inInstance, game.instanceType, game.instanceID, game.instanceName = true, "party", 99999, "Somewhere New"
Fire("PLAYER_ENTERING_WORLD")
check(printed[1] and printed[1]:find("No map data for Somewhere New", 1, true), "note printed")

realPrint(failures == 0 and "\nAll checks passed." or ("\n" .. failures .. " check(s) failed."))
os.exit(failures == 0 and 0 or 1)
