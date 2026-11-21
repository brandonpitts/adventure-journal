-- ============================================================================
-- Journal_Dungeons - UI/DungeonGridView.lua
-- Scrollable dungeon tile browser.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns
-- Init takes a `parent` frame that hides the addon namespace; this name reaches it there
local addonNs = parent

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pairs = pairs
local math = math
local string = string
local pcall = pcall
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- The zone part of a dungeon's location ("Moonbrook, Westfall" -> "Westfall").
local function zoneOf(location)
    if not location then
        return nil
    end
    return location:match(",%s*([^,]+)$") or location
end

-- Grid order: by the top of the level range, then the bottom, then name; or by name
local function compareByLevel(a, b)
    local maxA, maxB = a.maxLevel or 0, b.maxLevel or 0
    if maxA ~= maxB then
        return maxA < maxB
    end
    local minA, minB = a.minLevel or 0, b.minLevel or 0
    if minA ~= minB then
        return minA < minB
    end
    return (a.name or "") < (b.name or "")
end

-- Highest level range first; equal ranges stay A-Z
local function compareByLevelDesc(a, b)
    local maxA, maxB = a.maxLevel or 0, b.maxLevel or 0
    if maxA ~= maxB then
        return maxA > maxB
    end
    local minA, minB = a.minLevel or 0, b.minLevel or 0
    if minA ~= minB then
        return minA > minB
    end
    return (a.name or "") < (b.name or "")
end

local function compareByName(a, b)
    return (a.name or "") < (b.name or "")
end

--- The grid's dungeons, filtered by the search box and sorted ("level", "levelDesc" or "alphabetical").
local function filteredDungeons(searchQuery, sortOrder)
    local Access = ns.Data.DungeonAccess
    local results = {}
    for _, dungeon in ipairs(Access:GetDungeonList()) do
        if Access:DungeonMatches(dungeon, searchQuery) then
            results[#results + 1] = dungeon
        end
    end
    local compare = compareByLevel
    if sortOrder == "alphabetical" or sortOrder == "name" then
        compare = compareByName
    elseif sortOrder == "levelDesc" then
        compare = compareByLevelDesc
    end
    table.sort(results, compare)
    return results
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local DungeonGridView = {
    frame = nil,
    scrollFrame = nil,
    scrollChild = nil,
    tilePools = {}, -- layout key -> tiles of that layout's size
    searchQuery = "",
    onSelectDungeon = nil,
}

--- Initializes the Dungeon Browser Grid inside `parent`.
--- @param parent Frame
--- @param onSelectDungeon function `function(dungeon)`
function DungeonGridView:Init(parent, onSelectDungeon)
    if self.frame then
        return
    end
    self.onSelectDungeon = onSelectDungeon

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame

    -- Scrollable Grid Container filling the whole window
    local gridCfg = Constants.GRID
    local scrollFrame = addonNs.UI.ScrollFrame:Create(frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", gridCfg.SCROLL_LEFT_X, gridCfg.SCROLL_TOP_Y)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", gridCfg.SCROLL_RIGHT_X, gridCfg.SCROLL_BOTTOM_Y)
    self.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(742, 400)
    scrollFrame:SetScrollChild(scrollChild)
    self.scrollChild = scrollChild

    frame:SetScript("OnShow", function()
        self:Refresh()
    end)

    -- Real-time reactive listener for difficulty color setting changes
    if _G.JournalBase then
        local prevHook = _G.JournalBase.OnDungeonSettingChanged
        _G.JournalBase.OnDungeonSettingChanged = function(jBase, key, val)
            if prevHook then
                pcall(prevHook, jBase, key, val)
            end
            if (key == "showBossLevel" or key == "showBossDifficultyColor" or key == "dungeonGridSort"
                or key == "dungeonGridLayout") and self.frame and self.frame:IsShown() then
                self:Refresh()
            end
        end
    end

    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function(f, event)
        if event == "PLAYER_LEVEL_UP" and self.frame and self.frame:IsShown() then
            self:Refresh()
        end
    end)

    local liveData = addonNs.DataStore and addonNs.DataStore.Live
    -- Loaded item names can change which dungeons a search matches; loads close together refresh once
    local refreshTimer
    if liveData then
        liveData:AddListener(function()
            if refreshTimer or not (self.frame and self.frame:IsShown() and self.searchQuery and self.searchQuery ~= "") then
                return
            end
            refreshTimer = C_Timer.NewTimer(0.08, function()
                refreshTimer = nil
                if self.frame and self.frame:IsShown() then
                    self:Refresh()
                end
            end)
        end)
    end
end

--- Acquires or creates a dungeon tile at `index` for `layoutKey`: a card (UI/StoneCard.lua) of the layout's
--- size with the dungeon's loading screen cropped in its window.
--- @param index number
--- @param layoutKey string a key of Constants.GRID.LAYOUTS
--- @return Button
function DungeonGridView:AcquireTile(index, layoutKey)
    local pool = self.tilePools[layoutKey]
    if not pool then
        pool = {}
        self.tilePools[layoutKey] = pool
    end
    local tile = pool[index]
    if tile then
        tile:Show()
        return tile
    end

    local layout = Constants.GRID.LAYOUTS[layoutKey]
    -- Centered: the name and levels in the middle; otherwise the name in gold on the left, "Lvl - zone" under it
    tile = ns.UI.StoneCard:Create(self.scrollChild, layout.width, layout.height,
        { picture = true, noFade = layout.noFade, centered = layout.centered })
    if not layout.centered then
        tile.subText:SetPoint("RIGHT", tile, "RIGHT", -16, 0)
        tile.subText:SetWordWrap(false)
    end

    tile:SetScript("OnClick", function(btn)
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if btn.dungeon and self.onSelectDungeon then
            self.onSelectDungeon(btn.dungeon)
        end
    end)

    -- Hooked, not set: the card's own hover and press visuals are hooks too
    tile:HookScript("OnEnter", function(btn)
        local d = btn.dungeon
        if not d or not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.fullName, 1.0, 0.82, 0.0)
        GameTooltip:AddLine("Level " .. (d.level or "?") .. " • " .. (d.location or ""), 0.90, 0.82, 0.62)
        if d.description and d.description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(d.description, 0.85, 0.85, 0.85, true)
        end
        -- A dungeon with wings lists them in order, each with its levels
        if d.wingCount and d.wingCount > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Wings", 1.0, 0.82, 0.0)
            for _, wing in ipairs(ns.Data.DungeonAccess:GetWings(d)) do
                GameTooltip:AddDoubleLine(wing.name, wing.level and ("Level " .. wing.level) or "",
                    0.95, 0.95, 0.95, 0.90, 0.82, 0.62)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open", 0.25, 0.92, 0.32)
        GameTooltip:Show()
    end)

    tile:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    pool[index] = tile
    return tile
end

--- Updates the active search filter and re-renders the grid.
--- @param queryText string
function DungeonGridView:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

--- Rebuilds the dungeon tile grid sorted by level range or alphabetical name.
function DungeonGridView:Refresh()
    if not self.frame then
        return
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local showBossLevel = true
    local showDiffColor = true
    local sortOrder = "level"
    local gridCfg = Constants.GRID
    local layoutKey = gridCfg.DEFAULT_LAYOUT
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showBossLevel = _G.JournalBase:GetDungeonSetting("showBossLevel", true) == true
        showDiffColor = _G.JournalBase:GetDungeonSetting("showBossDifficultyColor", true) == true
        sortOrder = _G.JournalBase:GetDungeonSetting("dungeonGridSort", "level")
        layoutKey = _G.JournalBase:GetDungeonSetting("dungeonGridLayout", gridCfg.DEFAULT_LAYOUT)
    end
    if not gridCfg.LAYOUTS[layoutKey] then
        layoutKey = gridCfg.DEFAULT_LAYOUT
    end
    local layout = gridCfg.LAYOUTS[layoutKey]
    local dungeons = filteredDungeons(self.searchQuery, sortOrder)

    for _, pool in pairs(self.tilePools) do
        for _, tile in ipairs(pool) do
            tile:Hide()
        end
    end

    local cols = layout.columns
    for i, dungeon in ipairs(dungeons) do
        local tile = self:AcquireTile(i, layoutKey)
        tile.dungeon = dungeon

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = gridCfg.START_X + col * (layout.width + gridCfg.GAP_X)
        local y = gridCfg.START_Y - row * (layout.height + gridCfg.GAP_Y)

        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", x, y)

        local name = dungeon.name or ""
        tile.nameText:SetText(tile.upperName and name:upper() or name)
        local info = {}
        if showBossLevel then
            local level = "Lvl " .. (dungeon.level or "")
            if showDiffColor then
                local r, g, b = SharedWidgets:GetDungeonDifficultyColor(dungeon)
                level = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, level)
            end
            info[#info + 1] = level
        end
        -- The small centered cards show only the levels; the others add the zone
        if not layout.centered then
            info[#info + 1] = zoneOf(dungeon.location)
        end
        tile.subText:SetText(table.concat(info, " - "))

        ns.UI.StoneCard:SetDungeonPicture(tile, dungeon)
    end

    local totalRows = math.max(1, math.ceil(#dungeons / cols))
    local totalHeight = math.abs(gridCfg.START_Y) + totalRows * (layout.height + gridCfg.GAP_Y) + 12
    self.scrollChild:SetHeight(math.max(1, totalHeight))
    SharedWidgets:UpdateScrollFrameVisibility(self.scrollFrame, totalHeight)
end

function DungeonGridView:Show()
    if self.frame then
        self.frame:Show()
        self:Refresh()
    end
end

function DungeonGridView:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.DungeonGridView = DungeonGridView
