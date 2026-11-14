-- ============================================================================
-- Journal_Dungeons - UI/DungeonGridView.lua
-- 4-column scrollable dungeon tile browser.
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
local CreateColor = CreateColor
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Formats a dungeon name in uppercase with clean wrapping for the 4-column tile.
local function formatTileTitle(name)
    if not name then
        return ""
    end
    return string.upper(name)
end

--- Applies Morpheus or QuestTitleFont typography to fontString.
local function applyDungeonTileTypography(fontString)
    local fontApplied = false
    local candidateFonts = {
        "Fonts\\MORPHEUS.TTF",
        "Fonts\\MORPHEUS_CYR.TTF",
        "Fonts\\morpheus.ttf",
    }
    for _, fontFile in ipairs(candidateFonts) do
        local ok = pcall(fontString.SetFont, fontString, fontFile, 14, "")
        if ok and fontString:GetFont() then
            fontApplied = true
            break
        end
    end

    if not fontApplied then
        if _G.QuestTitleFont then
            fontString:SetFontObject("QuestTitleFont")
        elseif _G.QuestFont_Huge then
            fontString:SetFontObject("QuestFont_Huge")
        elseif _G.GameFontNormalLarge then
            fontString:SetFontObject("GameFontNormalLarge")
        else
            fontString:SetFontObject("GameFontNormal")
        end
    end

    fontString:SetTextColor(1.0, 0.82, 0.15)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 0.95)
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

--- Initializes the 4-column Dungeon Browser Grid inside `parent`.
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

    -- Scrollable 4-Column Grid Container shifted up to fill the whole window
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

    if ns.ItemsManager and ns.ItemsManager.RegisterUpdateListener then
        ns.ItemsManager:RegisterUpdateListener(function()
            if self.frame and self.frame:IsShown() and self.searchQuery and self.searchQuery ~= "" then
                self:Refresh()
            end
        end)
    end
end

--- Acquires or creates an outward-bulging 3D dungeon tile button at `index`.
--- @param index number
--- @return Button
function DungeonGridView:AcquireTile(index)
    local tile = self.tilePool[index]
    if tile then
        tile:Show()
        return tile
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local gridCfg = Constants.GRID

    tile = CreateFrame("Button", nil, self.scrollChild)
    tile:SetSize(gridCfg.TILE_WIDTH, gridCfg.TILE_HEIGHT)

    SharedWidgets:StyleOutwardBulgingButton(tile)

    local artTex = tile:CreateTexture(nil, "ARTWORK", nil, 0)
    artTex:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
    artTex:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
    tile.artTex = artTex

    local fallbackMedallion = SharedWidgets:CreateCircularMedallion(tile, 36, 48)
    fallbackMedallion:SetPoint("CENTER", tile, "CENTER", 0, -4)
    tile.fallbackMedallion = fallbackMedallion

    local topVignette = tile:CreateTexture(nil, "ARTWORK", nil, 2)
    topVignette:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
    topVignette:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -1, -1)
    topVignette:SetHeight(44)
    topVignette:SetTexture(Constants.ASSETS.WHITE_8X8)
    if topVignette.SetGradient and CreateColor then
        topVignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.05), CreateColor(0, 0, 0, 0.82))
    else
        topVignette:SetVertexColor(0, 0, 0, 0.58)
    end

    -- Bottom readability vignette behind the level range
    local botVignette = tile:CreateTexture(nil, "ARTWORK", nil, 2)
    botVignette:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 1, 1)
    botVignette:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
    botVignette:SetHeight(24)
    botVignette:SetTexture(Constants.ASSETS.WHITE_8X8)
    if botVignette.SetGradient and CreateColor then
        botVignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.82), CreateColor(0, 0, 0, 0.05))
    else
        botVignette:SetVertexColor(0, 0, 0, 0.58)
    end
    tile.botVignette = botVignette

    -- Golden Centered Dungeon Title (Morpheus / QuestTitleFont from game files)
    local nameText = tile:CreateFontString(nil, "OVERLAY")
    nameText:SetPoint("TOPLEFT", tile, "TOPLEFT", 8, -8)
    nameText:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -8)
    nameText:SetJustifyH("CENTER")
    nameText:SetJustifyV("TOP")
    nameText:SetWordWrap(true)
    applyDungeonTileTypography(nameText)
    tile.nameText = nameText

    -- Bottom-Left Level Bracket Badge
    local levelText = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelText:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 8, 6)
    levelText:SetTextColor(0.92, 0.86, 0.70)
    levelText:SetShadowOffset(1, -1)
    levelText:SetShadowColor(0, 0, 0, 0.95)
    tile.levelText = levelText

    -- Interactive Hover Glow
    local hoverGlow = tile:CreateTexture(nil, "HIGHLIGHT")
    hoverGlow:SetPoint("TOPLEFT", tile, "TOPLEFT", 3, -3)
    hoverGlow:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -3, 3)
    hoverGlow:SetTexture(Constants.ASSETS.WHITE_8X8)
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetVertexColor(0.95, 0.75, 0.30, 0.22)

    -- Push-down visual feedback on mouse click
    tile:SetScript("OnMouseDown", function(btn)
        nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 9, -9)
        nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -7, -9)
        levelText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 9, 5)
    end)
    tile:SetScript("OnMouseUp", function(btn)
        nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -8)
        nameText:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -8)
        levelText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
    end)

    tile:SetScript("OnClick", function(btn)
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if btn.dungeon and self.onSelectDungeon then
            self.onSelectDungeon(btn.dungeon)
        end
    end)

    tile:SetScript("OnEnter", function(btn)
        local d = btn.dungeon
        if not d or not GameTooltip then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine(d.name, 1.0, 0.82, 0.0)
        GameTooltip:AddLine("Level " .. (d.level or "?") .. " • " .. (d.location or ""), 0.90, 0.82, 0.62)
        if d.description and d.description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(d.description, 0.85, 0.85, 0.85, true)
        end
        local bossCount = (d.bosses and #d.bosses) or 0
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("%d Boss Encounters — Click to open", bossCount), 0.25, 0.92, 0.32)
        GameTooltip:Show()
    end)

    tile:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self.tilePool[index] = tile
    return tile
end

--- Updates the active search filter and re-renders the 4-column grid.
--- @param queryText string
function DungeonGridView:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

--- Rebuilds the 4-column dungeon tile grid sorted by level range or alphabetical name.
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
    local dungeons = ns.Data.DungeonsData:GetFiltered(self.searchQuery, sortOrder)

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

        tile.nameText:SetText(formatTileTitle(dungeon.name))
        if showBossLevel then
            tile.levelText:SetText("Lvl " .. (dungeon.level or ""))
            if showDiffColor then
                local r, g, b = SharedWidgets:GetDungeonDifficultyColor(dungeon)
                tile.levelText:SetTextColor(r, g, b)
            else
                tile.levelText:SetTextColor(0.92, 0.86, 0.70)
            end
            tile.levelText:Show()
            if tile.botVignette then
                tile.botVignette:Show()
            end
        else
            tile.levelText:Hide()
            if tile.botVignette then
                tile.botVignette:Hide()
            end
        end

        local hasArt = SharedWidgets:ApplyDungeonArtwork(tile.artTex, dungeon)
        if hasArt then
            tile.fallbackMedallion:Hide()
        else
            SharedWidgets:SetMedallionIcon(tile.fallbackMedallion, dungeon.icon)
            SharedWidgets:SyncWindowPortraitBorder(tile.fallbackMedallion)
            tile.fallbackMedallion:Show()
        end
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
