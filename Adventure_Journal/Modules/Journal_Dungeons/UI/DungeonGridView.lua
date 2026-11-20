-- ============================================================================
-- Journal_Dungeons - UI/DungeonGridView.lua
-- Scrollable dungeon tile browser.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local math = math
local string = string
local pcall = pcall
local CreateFrame = CreateFrame
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

local function compareByName(a, b)
    return (a.name or "") < (b.name or "")
end

--- The grid's dungeons, filtered by the search box and sorted ("level" or "alphabetical").
local function filteredDungeons(searchQuery, sortOrder)
    local Access = ns.Data.DungeonAccess
    local results = {}
    for _, dungeon in ipairs(Access:GetDungeonList()) do
        if Access:DungeonMatches(dungeon, searchQuery) then
            results[#results + 1] = dungeon
        end
    end
    local byName = (sortOrder == "alphabetical" or sortOrder == "name")
    table.sort(results, byName and compareByName or compareByLevel)
    return results
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local DungeonGridView = {
    frame = nil,
    scrollFrame = nil,
    scrollChild = nil,
    tilePool = {},
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
    local scrollFrame = CreateFrame("ScrollFrame", "JournalDungeonsGridScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", gridCfg.SCROLL_LEFT_X, gridCfg.SCROLL_TOP_Y)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", gridCfg.SCROLL_RIGHT_X, gridCfg.SCROLL_BOTTOM_Y)
    scrollFrame.scrollBarHideable = true
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
            if (key == "showBossLevel" or key == "showBossDifficultyColor" or key == "dungeonGridSort") and self.frame and self.frame:IsShown() then
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

    local liveData = parent.DataStore and parent.DataStore.Live
    if liveData then
        liveData:AddListener(function()
            if self.frame and self.frame:IsShown() and self.searchQuery and self.searchQuery ~= "" then
                self:Refresh()
            end
        end)
    end
end

--- Acquires or creates a dungeon tile at `index`: a card (UI/StoneCard.lua) with the dungeon's loading
--- screen cropped in its window and the name and levels centered on it.
--- @param index number
--- @return Button
function DungeonGridView:AcquireTile(index)
    local tile = self.tilePool[index]
    if tile then
        tile:Show()
        return tile
    end

    local gridCfg = Constants.GRID
    -- The card's own text: the name in gold on the left, "Lvl 17-26 - Westfall" under it
    tile = ns.UI.StoneCard:Create(self.scrollChild, gridCfg.TILE_WIDTH, gridCfg.TILE_HEIGHT, { picture = true })
    tile.subText:SetPoint("RIGHT", tile, "RIGHT", -16, 0)
    tile.subText:SetWordWrap(false)

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
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open", 0.25, 0.92, 0.32)
        GameTooltip:Show()
    end)

    tile:HookScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.tilePool[index] = tile
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
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showBossLevel = _G.JournalBase:GetDungeonSetting("showBossLevel", true) == true
        showDiffColor = _G.JournalBase:GetDungeonSetting("showBossDifficultyColor", true) == true
        sortOrder = _G.JournalBase:GetDungeonSetting("dungeonGridSort", "level")
    end
    local dungeons = filteredDungeons(self.searchQuery, sortOrder)

    for _, tile in ipairs(self.tilePool) do
        tile:Hide()
    end

    local gridCfg = Constants.GRID
    local cols = gridCfg.COLUMNS
    for i, dungeon in ipairs(dungeons) do
        local tile = self:AcquireTile(i)
        tile.dungeon = dungeon

        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = gridCfg.START_X + col * (gridCfg.TILE_WIDTH + gridCfg.GAP_X)
        local y = gridCfg.START_Y - row * (gridCfg.TILE_HEIGHT + gridCfg.GAP_Y)

        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", x, y)

        tile.nameText:SetText(dungeon.name or "")
        local info = {}
        if showBossLevel then
            local level = "Lvl " .. (dungeon.level or "")
            if showDiffColor then
                local r, g, b = SharedWidgets:GetDungeonDifficultyColor(dungeon)
                level = string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, level)
            end
            info[#info + 1] = level
        end
        info[#info + 1] = zoneOf(dungeon.location)
        tile.subText:SetText(table.concat(info, " - "))

        ns.UI.StoneCard:SetDungeonPicture(tile, dungeon)
    end

    local totalRows = math.max(1, math.ceil(#dungeons / cols))
    local totalHeight = math.abs(gridCfg.START_Y) + totalRows * (gridCfg.TILE_HEIGHT + gridCfg.GAP_Y) + 12
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
