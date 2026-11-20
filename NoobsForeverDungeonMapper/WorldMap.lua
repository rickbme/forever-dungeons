-- Noobs Forever Dungeon Mapper: the world map. Zoom out from a dungeon to see where every dungeon and
-- raid entrance is, on Azeroth or on either continent. Click an entrance to open that dungeon's map.
-- Uses the Forever client's own continent maps (drawn by FileDataID) and Data/WorldMaps.lua.
-- It is a window of its own: Blizzard's WorldMapFrame is never touched.
local ADDON, ns = ...

local MAP_W, MAP_H, TILE, PAD = 1002, 668, 256, 12
local WORLD = 947

local f -- the window
local current -- the WorldMaps entry being shown
local pins, regions = {}, {}

local function MapData(uiMapID)
    for _, m in ipairs(ns.WorldMaps or {}) do
        if m.uiMapID == uiMapID then return m end
    end
end

local function CircleTexture(parent, layer, size)
    local t = parent:CreateTexture(nil, layer)
    t:SetSize(size, size)
    t:SetColorTexture(1, 1, 1)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(t)
    t:AddMaskTexture(mask)
    return t
end

local function SmallButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

-- Which instance the player is in, or last looked at: its entrance gets a glow.
local function HighlightedID()
    return ns.CurrentInstance() or ns.ViewedInstance()
end

local function LevelText(inst)
    if inst[4] == inst[5] then return tostring(inst[4]) end
    return inst[4] .. "-" .. inst[5]
end

local function PinTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(#self.instances > 1 and "Dungeons here" or self.instances[1][2])
    for _, inst in ipairs(self.instances) do
        local id = inst[1]
        local d = ns.Dungeons[id]
        local line = (#self.instances > 1 and (inst[2] .. "  ") or "") .. (inst[3] and "Raid, level " or "Level ") .. LevelText(inst)
        if d then
            local killed, total = ns.KillCount(id)
            if total > 0 then line = line .. ("   %d/%d bosses"):format(killed, total) end
            if d.new then line = line .. "   |cff20ff20new|r" end
            GameTooltip:AddLine(line, 1, 1, 1)
        else
            GameTooltip:AddLine(line .. "   |cff808080(no map yet)|r", 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:AddLine("Click to open the dungeon map.", 1, 0.82, 0)
    GameTooltip:Show()
end

local function OpenInstance(id)
    if not (id and ns.Dungeons[id]) then return end
    f:Hide()
    ns.ShowDungeon(id)
end

local function PinClick(self)
    local opens = {}
    for _, inst in ipairs(self.instances) do
        if ns.Dungeons[inst[1]] then opens[#opens + 1] = inst end
    end
    if #opens == 0 then return end
    if #opens == 1 or not (MenuUtil and MenuUtil.CreateContextMenu) then
        return OpenInstance(opens[1][1])
    end
    MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle("Open a dungeon map")
        for _, inst in ipairs(opens) do
            root:CreateButton(("%s |cff808080(%s)|r"):format(inst[2], LevelText(inst)), function() OpenInstance(inst[1]) end)
        end
    end)
end

local function CreatePin(i)
    local p = CreateFrame("Button", nil, f.canvas)
    p:SetFrameLevel(f.canvas:GetFrameLevel() + 6)
    p.glow = CircleTexture(p, "BACKGROUND", 34)
    p.glow:SetPoint("CENTER")
    p.glow:SetVertexColor(0.3, 0.8, 1, 0.55)
    p.ring = CircleTexture(p, "ARTWORK", 20)
    p.ring:SetPoint("CENTER")
    p.ring:SetVertexColor(1, 1, 1, 1)
    p.dot = CircleTexture(p, "OVERLAY", 16)
    p.dot:SetPoint("CENTER")
    p.num = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.num:SetPoint("CENTER", 0, 0)
    p.num:SetTextColor(1, 1, 1)
    p:SetScript("OnEnter", PinTooltip)
    p:SetScript("OnLeave", GameTooltip_Hide)
    p:SetScript("OnClick", PinClick)
    pins[i] = p
    return p
end

local function Create()
    f = CreateFrame("Frame", "NoobsForeverDungeonMapperWorld", UIParent, "BackdropTemplate")
    f:SetSize(PAD * 2 + MAP_W, PAD * 2 + 34 + MAP_H + 40)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    tinsert(UISpecialFrames, "NoobsForeverDungeonMapperWorld")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", PAD + 4, -PAD - 2)
    f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 10, -1)

    f.canvas = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.canvas:SetSize(MAP_W, MAP_H)
    f.canvas:SetPoint("TOPLEFT", PAD, -PAD - 30)
    f.canvas:SetClipsChildren(true)
    f.tiles = {}
    for row = 0, 2 do
        for col = 0, 3 do
            local t = f.canvas:CreateTexture(nil, "BACKGROUND")
            t:SetSize(TILE, TILE)
            t:SetPoint("TOPLEFT", col * TILE, -row * TILE)
            f.tiles[#f.tiles + 1] = t
        end
    end

    -- Buttons along the bottom: pick the map, go back to a dungeon
    f.tabs = {}
    local prev
    for _, uiMapID in ipairs({ WORLD, 1415, 1414 }) do
        local data = MapData(uiMapID)
        if data then
            local b = SmallButton(f, data.name, uiMapID == WORLD and 80 or 130)
            b:SetPoint("TOPLEFT", prev or f.canvas, prev and "TOPRIGHT" or "BOTTOMLEFT", prev and 4 or 0, prev and 0 or -8)
            b:SetScript("OnClick", function() ns.ShowWorldMap(uiMapID) end)
            f.tabs[uiMapID] = b
            prev = b
        end
    end
    f.back = SmallButton(f, "Dungeon map", 100)
    f.back:SetPoint("TOPRIGHT", f.canvas, "BOTTOMRIGHT", 0, -8)
    f.back:SetScript("OnClick", function()
        f:Hide()
        ns.ToggleMap()
    end)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("LEFT", prev, "RIGHT", 14, 0)
    f.hint:SetText("Click an entrance to open that dungeon's map.")

    f.pins = pins -- (the offline tests click them)
    f:Hide()
end

local function Draw()
    local data = current
    for i, t in ipairs(f.tiles) do
        t:SetTexture(data.tiles[i])
        t:Show()
    end
    f.title:SetText(data.name)
    f.subtitle:SetText("World map")

    for _, p in ipairs(pins) do p:Hide() end
    local here = HighlightedID()
    local size = data.uiMapID == WORLD and 18 or 22
    for i, pin in ipairs(data.pins) do
        local p = pins[i] or CreatePin(i)
        p.instances = pin[3]
        p:SetSize(size, size)
        p:ClearAllPoints()
        p:SetPoint("CENTER", f.canvas, "TOPLEFT", pin[1] * MAP_W, -pin[2] * MAP_H)
        local raidOnly, isHere = true, false
        for _, inst in ipairs(pin[3]) do
            if not inst[3] then raidOnly = false end
            if inst[1] == here then isHere = true end
        end
        if raidOnly then p.dot:SetVertexColor(0.6, 0.25, 0.85) else p.dot:SetVertexColor(0.8, 0.15, 0.1) end
        p.num:SetText(#pin[3] > 1 and #pin[3] or "")
        p.glow:SetShown(isHere)
        p:Show()
    end

    -- On the world map, the continents are clickable too
    for _, r in ipairs(regions) do r:Hide() end
    for i, sub in ipairs(data.sub or {}) do
        local r = regions[i]
        if not r then
            r = CreateFrame("Button", nil, f.canvas)
            r:SetFrameLevel(f.canvas:GetFrameLevel() + 2)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetText(self.name or "")
                GameTooltip:AddLine("Click to zoom in.", 1, 0.82, 0)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", GameTooltip_Hide)
            r:SetScript("OnClick", function(self) ns.ShowWorldMap(self.target) end)
            regions[i] = r
        end
        local target = MapData(sub[1])
        r.target, r.name = sub[1], target and target.name
        r:SetSize(sub[4] * MAP_W, sub[5] * MAP_H)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f.canvas, "TOPLEFT", sub[2] * MAP_W, -sub[3] * MAP_H)
        r:Show()
    end
    for uiMapID, b in pairs(f.tabs) do b:SetEnabled(uiMapID ~= data.uiMapID) end
end

-- Pick the map that has the entrance of the dungeon the player is in or looked at, else the last one.
local function DefaultMap()
    local here = HighlightedID()
    if here then
        for _, m in ipairs(ns.WorldMaps or {}) do
            if m.uiMapID ~= WORLD then
                for _, pin in ipairs(m.pins) do
                    for _, inst in ipairs(pin[3]) do
                        if inst[1] == here then return m.uiMapID end
                    end
                end
            end
        end
    end
    return ns.db.worldMap or WORLD
end

function ns.ShowWorldMap(uiMapID)
    local data = MapData(uiMapID or DefaultMap())
    if not data then
        ns.Print("The world map isn't available.")
        return
    end
    if not f then Create() end
    current = data
    ns.db.worldMap = data.uiMapID
    f:SetScale(ns.db.scale or 1)
    f:Show()
    Draw()
end

function ns.ToggleWorldMap()
    if f and f:IsShown() then return f:Hide() end
    ns.ShowWorldMap()
end

function ns.HideWorldMap() if f then f:Hide() end end
