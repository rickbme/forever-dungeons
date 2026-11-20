-- Noobs Forever Dungeon Mapper: core state, events, kill tracking and slash commands.
--
-- What the game allows inside a dungeon (Forever 1.60.x, Midnight-era API):
--   * GetInstanceInfo() tells us which dungeon we are in (8th return = instanceID).
--   * GetSubZoneText() gives the named area we stand in (only some dungeons have several).
--   * ENCOUNTER_START / ENCOUNTER_END (and sometimes BOSS_KILL) tell us about boss fights.
--   * Player coordinates (C_Map.GetPlayerMapPosition, UnitPosition, GetPlayerFacing) are
--     blocked inside instances, so the map never claims to know exactly where you stand.
local ADDON, ns = ...

ns.DEFAULTS = {
    autoOpen = true,      -- open the map when entering a dungeon
    autoClose = true,     -- hide it again when leaving
    followProgress = true, -- after a kill, turn to the floor of the next boss
    scale = 1,
    liveView = false,     -- enlarge the minimap while inside a dungeon
    liveScale = 1.8,
    minimapButton = true, -- show the minimap button
    minimapAngle = 200,   -- its position around the minimap, in degrees
    floors = {},          -- [instanceID] = last floor viewed
    runs = {},            -- [instanceID] = { killed = { [key] = true }, last = time() }
    welcomed = false,     -- the first-run popup has been shown
    seen = {},            -- [instanceID] = { [sub-zone name] = times entered }, for writing anchors
}

-- A run is forgotten after this long without entering or killing anything in it.
local RUN_TIMEOUT = 2 * 60 * 60

local function Print(...)
    print("|cff33ccffNoobs Forever Dungeon Mapper|r:", ...)
end
ns.Print = Print

-- Midnight-era clients can hand addons "secret" values that cannot be read. Treat them as nil.
local function Safe(v)
    if v ~= nil and issecretvalue and issecretvalue(v) then return nil end
    return v
end
ns.Safe = Safe

function ns.Norm(name)
    name = Safe(name)
    if type(name) ~= "string" then return nil end
    return (name:lower():gsub("[^%w]", ""))
end

-- Returns instanceID, dungeon data when the player is inside a dungeon we know about.
function ns.CurrentInstance()
    local inInstance = Safe(IsInInstance())
    if not inInstance then return nil end
    local instanceID = Safe(select(8, GetInstanceInfo()))
    if instanceID and ns.Dungeons[instanceID] then
        return instanceID, ns.Dungeons[instanceID]
    end
end

-------------------------------------------------------------------------------
-- Kill tracking
-------------------------------------------------------------------------------

local function Run(instanceID, create)
    local runs = ns.db.runs
    local run = runs[instanceID]
    if run and run.last and time() - run.last > RUN_TIMEOUT then
        run = nil
        runs[instanceID] = nil
    end
    if not run and create then
        run = { killed = {}, last = time() }
        runs[instanceID] = run
    end
    return run
end

local function BossKey(boss) return boss.id end

function ns.IsKilled(instanceID, boss)
    local run = Run(instanceID)
    return run and run.killed[BossKey(boss)] or false
end

function ns.SetKilled(instanceID, boss, killed)
    local run = Run(instanceID, true)
    run.killed[BossKey(boss)] = killed or nil
    run.last = time()
    ns.Refresh()
end

function ns.KillCount(instanceID)
    local d, n = ns.Dungeons[instanceID], 0
    for _, b in ipairs(d.bosses) do
        if ns.IsKilled(instanceID, b) then n = n + 1 end
    end
    return n, #d.bosses
end

-- The first boss (in the game's own encounter order) not yet killed.
function ns.NextBoss(instanceID)
    for i, b in ipairs(ns.Dungeons[instanceID].bosses) do
        if not ns.IsKilled(instanceID, b) then return b, i end
    end
end

function ns.ResetRun(instanceID)
    ns.db.runs[instanceID] = nil
    ns.Refresh()
end

-- Finds a boss of this dungeon by encounter ID, then by name.
local function FindBoss(instanceID, encounterID, name)
    local d = ns.Dungeons[instanceID]
    if not d then return nil end
    encounterID = Safe(encounterID)
    local key = ns.Norm(name)
    for _, b in ipairs(d.bosses) do
        if (encounterID and b.id == encounterID) or (key and ns.Norm(b.name) == key) then
            return b
        end
    end
end

-------------------------------------------------------------------------------
-- Floor choice
-------------------------------------------------------------------------------

-- The anchor (Data/Anchors.lua) for the sub-zone the player stands in, if there is one.
function ns.CurrentAnchor(instanceID)
    local list = ns.Anchors and ns.Anchors[instanceID]
    local sub = ns.Norm(GetSubZoneText())
    if not (list and sub and sub ~= "") then return nil end
    for _, a in ipairs(list) do
        if ns.Norm(a.sub) == sub then return a end
    end
end

-- The floor whose name matches the area the player stands in, if any.
function ns.FloorForSubzone(instanceID)
    local d = ns.Dungeons[instanceID]
    local sub = ns.Norm(GetSubZoneText())
    if not (d and sub and sub ~= "") then return nil end
    local a = ns.CurrentAnchor(instanceID)
    if a then return a.floor or 1 end
    for i, f in ipairs(d.floors) do
        if ns.Norm(f.name) == sub then return i end
        for _, name in ipairs(f.subzones or {}) do
            if ns.Norm(name) == sub then return i end
        end
    end
end

-- Best guess for the floor to show on entering, or after the player moved.
function ns.GuessFloor(instanceID)
    local d = ns.Dungeons[instanceID]
    if not d or #d.floors == 0 then return nil end
    local f = ns.FloorForSubzone(instanceID)
    if f then return f end
    if ns.db.followProgress then
        local nextBoss = ns.NextBoss(instanceID)
        if nextBoss and nextBoss.floor and (ns.KillCount(instanceID)) > 0 then return nextBoss.floor end
    end
    local saved = ns.db.floors[instanceID]
    if saved and d.floors[saved] then return saved end
    return 1
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local inDungeon -- instanceID while inside a known dungeon
local notedUnknown -- instanceID of an unknown dungeon we already mentioned

-- Entering a dungeon or raid the addon has no data for: say so once per visit.
local function NoteUnknownInstance()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    instanceType, instanceID = Safe(instanceType), Safe(instanceID)
    if not (Safe(IsInInstance()) and (instanceType == "party" or instanceType == "raid")) then
        notedUnknown = nil
        return
    end
    if instanceID and instanceID ~= notedUnknown then
        notedUnknown = instanceID
        Print(("No map data for %s yet."):format(tostring(Safe(name) or "this instance")))
    end
end

local function OnEnterWorld()
    ns.MaybeShowWelcome()
    local id = ns.CurrentInstance()
    if id ~= inDungeon then
        local left = inDungeon
        inDungeon = id
        if id then
            local run = Run(id, true)
            run.last = time()
            if ns.db.autoOpen then ns.ShowDungeon(id, ns.GuessFloor(id)) end
        elseif left and ns.db.autoClose then
            ns.HideMap()
        end
        ns.LiveView_Update()
    end
    if not id then NoteUnknownInstance() end
end

local function OnZoneChanged()
    if not inDungeon then return end
    ns.RecordSubzone(inDungeon)
    ns.UpdateLocationText()
    ns.UpdateYouAreHere()
    local f = ns.FloorForSubzone(inDungeon)
    if f then ns.ShowFloorIfViewing(inDungeon, f) end
end

local function OnEncounterStart(encounterID, name)
    if not inDungeon then return end
    local b = FindBoss(inDungeon, encounterID, name)
    if b and b.floor then ns.ShowFloorIfViewing(inDungeon, b.floor) end
    ns.SetFighting(b)
end

local function OnEncounterEnd(encounterID, name, success)
    ns.SetFighting(nil)
    if not inDungeon then return end
    success = Safe(success)
    if not (success == 1 or success == true) then return ns.Refresh() end
    local b = FindBoss(inDungeon, encounterID, name)
    if not b then return ns.Refresh() end
    if not ns.IsKilled(inDungeon, b) then
        ns.SetKilled(inDungeon, b, true)
        local killed, total = ns.KillCount(inDungeon)
        Print(("%s defeated (%d/%d)."):format(b.name, killed, total))
    end
    if ns.db.followProgress then
        local nextBoss = ns.NextBoss(inDungeon)
        if nextBoss and nextBoss.floor then ns.ShowFloorIfViewing(inDungeon, nextBoss.floor) end
    end
end

-- "<dungeon> has been reset." clears that dungeon's kills.
local resetPattern
local function OnSystemMessage(msg)
    msg = Safe(msg)
    if type(msg) ~= "string" or not INSTANCE_RESET_SUCCESS then return end
    if not resetPattern then
        -- INSTANCE_RESET_SUCCESS is "%s has been reset." (localized). Escape it, then capture the name.
        local p = INSTANCE_RESET_SUCCESS:gsub("([%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
        p = p:gsub("%%s", "(.+)")
        resetPattern = "^" .. p .. "$"
    end
    local name = msg:match(resetPattern)
    if not name then return end
    for id, d in pairs(ns.Dungeons) do
        if d.name == name then ns.ResetRun(id) end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        NoobsForeverDungeonMapperDB = NoobsForeverDungeonMapperDB or {}
        ns.db = NoobsForeverDungeonMapperDB
        for k, v in pairs(ns.DEFAULTS) do
            if ns.db[k] == nil then ns.db[k] = type(v) == "table" and {} or v end
        end
        self:UnregisterEvent("ADDON_LOADED")
        ns.MinimapButton_Update()
        ns.Options_Init()
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
            "ZONE_CHANGED_INDOORS", "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL",
            "CHAT_MSG_SYSTEM", "PLAYER_REGEN_ENABLED" }) do
            self:RegisterEvent(e)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        OnEnterWorld()
        OnZoneChanged()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        OnZoneChanged()
    elseif event == "ENCOUNTER_START" then
        OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        local id, name, _, _, success = ...
        OnEncounterEnd(id, name, success)
    elseif event == "BOSS_KILL" then
        local id, name = ...
        OnEncounterEnd(id, name, 1)
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemMessage(...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.LiveView_Update()
    end
end)

-------------------------------------------------------------------------------
-- Slash commands and the addon compartment
-------------------------------------------------------------------------------

local HELP = {
    "/fd - show or hide the map (current dungeon, or the last one viewed)",
    "/fd options - open the options window (no typing needed: right-click the minimap button, then Options)",
    "/fd welcome - show the welcome tips again",
    "/fd list - pick any dungeon to view",
    "/fd reset - clear boss kills for the current dungeon",
    "/fd auto - toggle opening the map automatically in dungeons",
    "/fd follow - toggle turning to the next boss's floor after a kill",
    "/fd live - toggle the enlarged minimap inside dungeons",
    "/fd button - show or hide the minimap button",
    "/fd scale <0.5-2> - map window size",
    "/fd probe [log|clear] - check what position data the game gives addons in a dungeon",
}

SLASH_NOOBSFOREVERDUNGEONMAPPER1 = "/fd"
SLASH_NOOBSFOREVERDUNGEONMAPPER2 = "/nfdm"
SlashCmdList.NOOBSFOREVERDUNGEONMAPPER = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then
        ns.ToggleMap()
    elseif cmd == "list" then
        ns.ShowDungeonMenu()
    elseif cmd == "reset" then
        local id = ns.CurrentInstance() or ns.ViewedInstance()
        if id then
            ns.ResetRun(id)
            Print("Kills cleared for " .. ns.Dungeons[id].name .. ".")
        end
    elseif cmd == "auto" then
        ns.db.autoOpen = not ns.db.autoOpen
        Print("Open automatically in dungeons: " .. (ns.db.autoOpen and "on" or "off"))
    elseif cmd == "follow" then
        ns.db.followProgress = not ns.db.followProgress
        Print("Follow boss progress between floors: " .. (ns.db.followProgress and "on" or "off"))
    elseif cmd == "live" then
        ns.LiveView_Toggle()
    elseif cmd == "button" then
        ns.MinimapButton_Toggle()
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        ns.ToggleOptions()
    elseif cmd == "welcome" or cmd == "help" then
        ns.ShowWelcome(true)
    elseif cmd == "probe" then
        ns.Probe(arg)
    elseif cmd == "scale" and tonumber(arg) then
        ns.db.scale = math.min(2, math.max(0.5, tonumber(arg)))
        ns.ApplyScale()
    else
        ns.ShowWelcome(true)
        for _, line in ipairs(HELP) do Print(line) end
    end
end

function NoobsForeverDungeonMapper_OnCompartmentClick(_, button)
    if button == "RightButton" then ns.ShowDungeonMenu() else ns.ToggleMap() end
end

function NoobsForeverDungeonMapper_OnCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("Noobs Forever Dungeon Mapper")
    GameTooltip:AddLine("Left-click: show or hide the map", 1, 1, 1)
    GameTooltip:AddLine("Right-click: pick a dungeon", 1, 1, 1)
    GameTooltip:Show()
end

function NoobsForeverDungeonMapper_OnCompartmentLeave()
    GameTooltip:Hide()
end
