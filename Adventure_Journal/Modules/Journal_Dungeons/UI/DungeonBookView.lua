-- ============================================================================
-- Journal_Dungeons - UI/DungeonBookView.lua
-- Open-Book Split View with Left-Page Boss Portrait Buttons and Right-Page
-- Instance Overview (Dungeon Art + Lore) and Boss Lore & Item Drops.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local math = math
local string = string
local tostring = tostring
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local UnitLevel = UnitLevel
local Constants = ns.Constants

local function safeGetItemInfo(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    if C_Item and C_Item.GetItemInfo then
        local name, link, quality, iLevel, reqLevel, class, subClass, maxStack, equipLoc, texture, price, classID, subclassID = C_Item.GetItemInfo(itemID)
        if name then
            return name, link, quality, iLevel, reqLevel, class, subClass, maxStack, equipLoc, texture, price, classID, subclassID
        end
    end
    if _G.GetItemInfo then
        local name, link, quality, iLevel, reqLevel, class, subClass, maxStack, equipLoc, texture, price, classID, subclassID = _G.GetItemInfo(itemID)
        if name then
            return name, link, quality, iLevel, reqLevel, class, subClass, maxStack, equipLoc, texture, price, classID, subclassID
        end
    end
    local getInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if getInstant then
        local _, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID = getInstant(itemID)
        if itemType or classID then
            return nil, nil, 1, nil, nil, itemType, itemSubType, nil, itemEquipLoc, icon, nil, classID, subclassID
        end
    end
    return nil
end

local function safeGetItemQualityColor(quality)
    local q = quality or 1
    if C_Item and C_Item.GetItemQualityColor then
        local r, g, b = C_Item.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    if _G.GetItemQualityColor then
        local r, g, b = _G.GetItemQualityColor(q)
        if r then return r, g, b end
    end
    local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
    if c then
        return c.r, c.g, c.b
    end
    return 1.0, 1.0, 1.0
end

--- Shows the item tooltip for an item row (`row.itemID`, optional `row.itemLink`).
--- Also assigned as the row's `UpdateTooltip`, which `GameTooltip_OnUpdate` calls every
--- `TOOLTIP_UPDATE_TIME` while hovered, so Shift-compare responds to Shift pressed mid-hover.
--- @param row Button
local function ShowItemRowTooltip(row)
    if not GameTooltip or not row.itemID then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if row.itemLink and row.itemLink:find("|Hitem:") then
        GameTooltip:SetHyperlink(row.itemLink)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(row.itemID)
    else
        GameTooltip:SetHyperlink("item:" .. tostring(row.itemID))
    end
    GameTooltip:Show()
end

--- Returns dynamic RGB difficulty color based on monster level vs player level.
--- @param bossLevel string|number
--- @return number r, number g, number b
local function GetDifficultyColor(bossLevel)
    return ns.UI.SharedWidgets:GetCreatureDifficultyColor(bossLevel)
end

local Access = ns.Data.DungeonAccess
local QuestAccess = ns.Data.QuestAccess
local Search = parent.Search
-- Core's window background (ink body text on parchment); named here because methods take a `parent` frame
local WindowBackground = parent.UI.WindowBackground

-- ItemStore, or nil when the DataStore is off
local function itemStore()
    local DataStore = parent.DataStore
    return DataStore and DataStore:IsEnabled() and DataStore.ItemStore or nil
end

--- The dungeon's entrance on the world map: { uiMapID, x, y, name }, or nil.
--- @param dungeon table a dungeon view (DungeonAccess)
--- @return table|nil
local function GetDungeonMapLocation(dungeon)
    return dungeon and Access:GetEntrance(dungeon) or nil
end

--- Checks whether the Show on Map button should be visible based on user map icon settings and player level.
--- @param dungeon table|nil
--- @return boolean
local function ShouldShowDungeonMapButton(dungeon)
    if not dungeon then return false end
    local loc = GetDungeonMapLocation(dungeon)
    if not loc or not loc.uiMapID then return false end

    -- Verify Map Icons utility module is enabled
    local isModuleEnabled = (_G.JournalBase and _G.JournalBase.IsModuleEnabled)
        or (parent and parent.IsModuleEnabled)
        or (ns and ns.IsModuleEnabled)
    if isModuleEnabled and not isModuleEnabled("map_icons") then
        return false
    end

    local setting = "min_level"
    if ns and ns.Settings and ns.Settings.GetMapIconsSetting then
        setting = ns.Settings:GetMapIconsSetting("worldMapDungeonIcons", "min_level")
    elseif _G.JournalBase and _G.JournalBase.GetMapIconsSetting then
        setting = _G.JournalBase:GetMapIconsSetting("worldMapDungeonIcons", "min_level")
    elseif _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        setting = _G.JournalBase:GetDungeonSetting("worldMapDungeonIcons", "min_level")
    end

    if setting == "disabled" then
        return false
    end
    if setting == "always" then
        return true
    end

    local playerLevel = (UnitLevel and UnitLevel("player")) or (_G.UnitLevel and _G.UnitLevel("player")) or 1
    local minLevel = (dungeon and dungeon.minLevel) or (loc and loc.minLevel) or 1
    local maxLevel = (dungeon and dungeon.maxLevel) or (loc and loc.maxLevel) or 60

    if setting == "min_level" then
        return playerLevel >= minLevel
    elseif setting == "bracket" then
        return playerLevel >= minLevel and playerLevel <= maxLevel
    end

    return true
end

-- ----------------------------------------------------------------------------
-- 2. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local DungeonBookView = {
    frame = nil,
    currentDungeon = nil,
    selectedBoss = nil,
    activeRightTab = "overview", -- "overview" | "loot"
    sideTabHolder = nil,
    overviewTabBtn = nil,
    lootTabBtn = nil,
    questsTabBtn = nil,
    bossButtonPool = {},
    categoryHeaderPool = {},
    itemRowPool = {},
    questButtonPool = {},
    wingButtonPool = {},
    wingPage = false,
    onSelectWing = nil,
    selectedQuest = nil,
    zoneBossEntry = nil,
    onSelectBoss = nil,
    onSelectDungeonOverview = nil,
    onTabChanged = nil,
}

--- Initializes the Open-Book Split View inside `parent`.
--- @param parent Frame
--- @param callbacks table `{ onSelectBoss, onSelectDungeonOverview, onTabChanged }`
function DungeonBookView:Init(parent, callbacks)
    if self.frame then
        return
    end
    self.onSelectBoss = callbacks and callbacks.onSelectBoss
    self.onSelectDungeonOverview = callbacks and callbacks.onSelectDungeonOverview
    self.onTabChanged = callbacks and callbacks.onTabChanged

    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    self.frame = frame

    -- ========================================================================
    -- LEFT PAGE: Dungeon Header Medallion + Scrollable Boss Portrait Buttons
    -- ========================================================================
    local leftPage = CreateFrame("Frame", nil, frame)
    leftPage:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    leftPage:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    leftPage:SetWidth(bookCfg.LEFT_WIDTH)
    self.leftPage = leftPage

    -- Dedicated Clickable Dungeon Portrait & Title Header Region
    local dungeonMedallion = SharedWidgets:CreateCircularMedallion(leftPage, 38, 52)
    dungeonMedallion:SetPoint("TOPLEFT", leftPage, "TOPLEFT", 2, -7)
    self.dungeonMedallion = dungeonMedallion

    local portraitBtn = CreateFrame("Button", nil, leftPage)
    portraitBtn:SetPoint("TOPLEFT", dungeonMedallion, "TOPLEFT", -6, 6)
    portraitBtn:SetPoint("BOTTOMLEFT", dungeonMedallion, "BOTTOMLEFT", -6, -6)
    portraitBtn:SetPoint("RIGHT", leftPage, "RIGHT", -50, 0)
    portraitBtn:SetFrameLevel(dungeonMedallion:GetFrameLevel() + 10)
    portraitBtn:RegisterForClicks("LeftButtonUp")

    portraitBtn:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if self.onSelectDungeonOverview then
            self.onSelectDungeonOverview()
        end
    end)

    portraitBtn:SetScript("OnEnter", function(btn)
        if self.dungeonMedallion and self.dungeonMedallion.SetHighlighted then
            self.dungeonMedallion:SetHighlighted(true)
        end
        if self.dungeonTitle then
            self.dungeonTitle:SetTextColor(1.0, 0.96, 0.72)
        end
        if not GameTooltip or not self.currentDungeon then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.currentDungeon.name, 1.0, 0.82, 0.0)
        if self.selectedBoss then
            if self.activeRightTab == "loot" then
                GameTooltip:AddLine("Click to view All Dungeon Loot & enable Overview tab", 0.30, 0.92, 0.38)
            else
                GameTooltip:AddLine("Click to return to Dungeon Overview", 0.30, 0.92, 0.38)
            end
        else
            GameTooltip:AddLine("Main Dungeon Page selected", 0.75, 0.75, 0.75)
        end
        GameTooltip:Show()
    end)

    portraitBtn:SetScript("OnLeave", function()
        if self.dungeonMedallion and self.dungeonMedallion.SetHighlighted then
            self.dungeonMedallion:SetHighlighted(false)
        end
        if self.dungeonTitle then
            self.dungeonTitle:SetTextColor(1.0, 1.0, 1.0)
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    self.portraitBtn = portraitBtn

    -- Capital City Faction Crest (prominent 38x38 crest occupying the far-right side of the header)
    local factionCrest = leftPage:CreateTexture(nil, "OVERLAY", nil, 6)
    factionCrest:SetSize(38, 38)
    factionCrest:SetPoint("RIGHT", leftPage, "RIGHT", -12, 0)
    factionCrest:SetPoint("CENTER", dungeonMedallion, "CENTER", 0, 0)
    factionCrest:Hide()
    self.factionCrest = factionCrest

    local dungeonTitle = leftPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    dungeonTitle:SetPoint("TOPLEFT", dungeonMedallion, "TOPRIGHT", 10, -2)
    dungeonTitle:SetPoint("RIGHT", leftPage, "RIGHT", -12, 0)
    dungeonTitle:SetJustifyH("LEFT")
    dungeonTitle:SetWordWrap(false)
    self.dungeonTitle = dungeonTitle

    local dungeonMeta = leftPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dungeonMeta:SetPoint("TOPLEFT", dungeonTitle, "BOTTOMLEFT", 0, -3)
    dungeonMeta:SetPoint("RIGHT", leftPage, "RIGHT", -12, 0)
    dungeonMeta:SetJustifyH("LEFT")
    dungeonMeta:SetTextColor(0.82, 0.72, 0.52)
    self.dungeonMeta = dungeonMeta

    local leftDivider = SharedWidgets:CreateHorizontalDividerBar(leftPage, 4)
    leftDivider:SetPoint("TOPLEFT", leftPage, "TOPLEFT", 6, -52)
    leftDivider:SetPoint("TOPRIGHT", leftPage, "TOPRIGHT", -12, -52)
    self.leftDivider = leftDivider

    local bossScroll = CreateFrame("ScrollFrame", "JournalDungeonsBossScrollFrame", leftPage, "UIPanelScrollFrameTemplate")
    bossScroll.scrollBarHideable = true
    bossScroll:SetPoint("TOPLEFT", leftPage, "TOPLEFT", 2, -62)
    bossScroll:SetPoint("BOTTOMRIGHT", leftPage, "BOTTOMRIGHT", -22, 6)
    self.bossScroll = bossScroll

    local bossScrollChild = CreateFrame("Frame", nil, bossScroll)
    bossScrollChild:SetSize(bookCfg.BOSS_BTN_WIDTH + 36, 320)
    bossScroll:SetScrollChild(bossScrollChild)
    self.bossScrollChild = bossScrollChild

    local eventDivider = SharedWidgets:CreateHorizontalDividerBar(bossScrollChild, 4)
    eventDivider:Hide()
    self.eventDivider = eventDivider

    -- Dedicated Section Header for Rare Encounters
    local rareHeader = CreateFrame("Frame", nil, bossScrollChild)
    rareHeader:SetHeight(26)
    rareHeader:Hide()

    local rareTitle = rareHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rareTitle:SetPoint("TOPLEFT", rareHeader, "TOPLEFT", 6, 0)
    rareTitle:SetPoint("TOPRIGHT", rareHeader, "TOPRIGHT", -6, 0)
    rareTitle:SetJustifyH("LEFT")
    rareTitle:SetTextColor(0.85, 0.90, 1.0)
    rareTitle:SetText("Rare Encounters")
    rareHeader.title = rareTitle

    local rareDivider = SharedWidgets:CreateHorizontalDividerBar(rareHeader, 4)
    rareDivider:SetPoint("BOTTOMLEFT", rareHeader, "BOTTOMLEFT", 4, 0)
    rareDivider:SetPoint("BOTTOMRIGHT", rareHeader, "BOTTOMRIGHT", -8, 0)
    rareHeader.divider = rareDivider
    self.rareHeader = rareHeader

    -- Dedicated Section Header for Minor & Quest Encounters
    local minorHeader = CreateFrame("Frame", nil, bossScrollChild)
    minorHeader:SetHeight(26)
    minorHeader:Hide()

    local minorTitle = minorHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minorTitle:SetPoint("TOPLEFT", minorHeader, "TOPLEFT", 6, 0)
    minorTitle:SetPoint("TOPRIGHT", minorHeader, "TOPRIGHT", -6, 0)
    minorTitle:SetJustifyH("LEFT")
    minorTitle:SetTextColor(0.75, 0.70, 0.60)
    minorTitle:SetText("Minor & Quest Encounters")
    minorHeader.title = minorTitle

    local minorDivider = SharedWidgets:CreateHorizontalDividerBar(minorHeader, 4)
    minorDivider:SetPoint("BOTTOMLEFT", minorHeader, "BOTTOMLEFT", 4, 0)
    minorDivider:SetPoint("BOTTOMRIGHT", minorHeader, "BOTTOMRIGHT", -8, 0)
    minorHeader.divider = minorDivider
    self.minorHeader = minorHeader

    -- Dedicated Section Header for Dungeon Set Challenges (Tier 0.5)
    local challengeHeader = CreateFrame("Frame", nil, bossScrollChild)
    challengeHeader:SetHeight(26)
    challengeHeader:Hide()

    local chTitle = challengeHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chTitle:SetPoint("TOPLEFT", challengeHeader, "TOPLEFT", 6, 0)
    chTitle:SetPoint("TOPRIGHT", challengeHeader, "TOPRIGHT", -6, 0)
    chTitle:SetJustifyH("LEFT")
    chTitle:SetTextColor(1.0, 0.82, 0.20)
    chTitle:SetText("Dungeon Set Challenges (Tier 0.5)")
    challengeHeader.title = chTitle

    local chDivider = SharedWidgets:CreateHorizontalDividerBar(challengeHeader, 4)
    chDivider:SetPoint("BOTTOMLEFT", challengeHeader, "BOTTOMLEFT", 4, 0)
    chDivider:SetPoint("BOTTOMRIGHT", challengeHeader, "BOTTOMRIGHT", -8, 0)
    challengeHeader.divider = chDivider
    self.challengeHeader = challengeHeader

    local trashDivider = SharedWidgets:CreateHorizontalDividerBar(bossScrollChild, 4)
    trashDivider:Hide()
    self.trashDivider = trashDivider

    -- Divider bar between player faction quests and opposing faction quests
    local questFactionDivider = SharedWidgets:CreateHorizontalDividerBar(bossScrollChild, 4)
    questFactionDivider:Hide()
    self.questFactionDivider = questFactionDivider

    local noEncountersText = bossScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noEncountersText:SetPoint("TOPLEFT", bossScrollChild, "TOPLEFT", 16, -40)
    noEncountersText:SetPoint("TOPRIGHT", bossScrollChild, "TOPRIGHT", -16, -40)
    noEncountersText:SetJustifyH("CENTER")
    noEncountersText:SetTextColor(0.80, 0.72, 0.55)
    noEncountersText:Hide()
    self.noEncountersText = noEncountersText

    -- ========================================================================
    -- CENTER VERTICAL DIVIDER (Between left boss scroll and right panel)
    -- ========================================================================
    local verticalDivider = SharedWidgets:CreateVerticalDividerBar(frame, 4)
    verticalDivider:SetPoint("TOP", leftPage, "TOPRIGHT", 8, -14)
    verticalDivider:SetPoint("BOTTOM", leftPage, "BOTTOMRIGHT", 8, 14)
    self.verticalDivider = verticalDivider

    -- ========================================================================
    -- RIGHT PAGE: Instance Overview or Boss Lore & Drops
    -- ========================================================================
    local rightPage = CreateFrame("Frame", nil, frame)
    rightPage:SetPoint("TOPLEFT", leftPage, "TOPRIGHT", 16, -10)
    rightPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 10)
    self.rightPage = rightPage

    -- Right-Page Boss Medallion (Circular portrait or icon)
    local bossMedallion = SharedWidgets:CreateCircularMedallion(rightPage, 40, 55)
    bossMedallion:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 8, -6)
    self.bossMedallion = bossMedallion

    -- Right-Page Title (Shown when viewing a Boss)
    local rightTitle = rightPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    rightTitle:SetPoint("TOPLEFT", bossMedallion, "TOPRIGHT", 10, -2)
    rightTitle:SetPoint("RIGHT", rightPage, "RIGHT", -12, 0)
    rightTitle:SetJustifyH("LEFT")
    rightTitle:SetWordWrap(true)
    rightTitle:SetSpacing(2)
    self.rightTitle = rightTitle

    -- Right-Page Boss Level / Rarity Tag (Placed directly under the title, pulled left inline with title and up against icon)
    local rightBossLevel = rightPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rightBossLevel:SetPoint("TOPLEFT", rightTitle, "BOTTOMLEFT", 0, -3)
    rightBossLevel:SetJustifyH("LEFT")
    rightBossLevel:SetWordWrap(false)
    self.rightBossLevel = rightBossLevel

    -- Boss Lore Description Snippet
    local detailDesc = rightPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    detailDesc:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 10, -66)
    detailDesc:SetWidth(bookCfg.RIGHT_CONTENT_WIDTH or bookCfg.ART_FRAME_WIDTH)
    detailDesc:SetJustifyH("LEFT")
    detailDesc:SetJustifyV("TOP")
    detailDesc:SetSpacing(3)
    detailDesc:SetTextColor(0.92, 0.86, 0.72)
    self.detailDesc = detailDesc

    -- Dividing line directly under the lore snippet
    local rightDivider = SharedWidgets:CreateHorizontalDividerBar(rightPage, 4)
    self.rightDivider = rightDivider

    -- Sub-Container 1: Instance Overview (Framed Dungeon Art + Lore)
    self:BuildInstanceOverviewPane(rightPage)

    -- Sub-Container 2: Scrollable item drop list under the divider
    local detailScroll = CreateFrame("ScrollFrame", "JournalDungeonsDetailScrollFrame", rightPage, "UIPanelScrollFrameTemplate")
    detailScroll.scrollBarHideable = true
    self.detailScroll = detailScroll

    local detailScrollChild = CreateFrame("Frame", nil, detailScroll)
    detailScrollChild:SetSize(bookCfg.RIGHT_CONTENT_WIDTH or bookCfg.ART_FRAME_WIDTH, 340)
    detailScroll:SetScrollChild(detailScrollChild)
    self.detailScrollChild = detailScrollChild

    local noDropsText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noDropsText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, -20)
    noDropsText:SetText("No item drops recorded for this encounter.")
    noDropsText:Hide()
    self.noDropsText = noDropsText

    -- Sub-Container 3: Selected Quest Detail View on the Right Page
    local questDetailContainer = CreateFrame("Frame", nil, rightPage)
    questDetailContainer:SetAllPoints(rightPage)
    questDetailContainer:Hide()
    self.questDetailContainer = questDetailContainer

    -- Horizontal divider line aligning directly with self.leftDivider on the Left Page
    local questDivider = SharedWidgets:CreateHorizontalDividerBar(questDetailContainer, 4)
    questDivider:SetPoint("TOP", leftDivider, "TOP", 0, 0)
    questDivider:SetPoint("LEFT", questDetailContainer, "LEFT", 6, 0)
    questDivider:SetPoint("RIGHT", questDetailContainer, "RIGHT", -12, 0)
    questDivider:SetHeight(4)
    self.questDivider = questDivider

    -- Circular Medallion for Quest Giver (kept hidden)
    local questGiverMedallion = SharedWidgets:CreateCircularMedallion(questDetailContainer, 38, 52)
    questGiverMedallion:SetPoint("TOP", dungeonMedallion, "TOP", 0, 0)
    questGiverMedallion:SetPoint("LEFT", questDetailContainer, "LEFT", 2, 0)
    questGiverMedallion:Hide()
    self.questGiverMedallion = questGiverMedallion

    -- Faction Crest for Quest Header (prominent 38x38 crest on the right side of the quest header)
    local questFactionCrest = questDetailContainer:CreateTexture(nil, "OVERLAY", nil, 6)
    questFactionCrest:SetSize(38, 38)
    questFactionCrest:SetPoint("RIGHT", questDetailContainer, "RIGHT", -12, 0)
    questFactionCrest:SetPoint("CENTER", dungeonMedallion, "CENTER", 0, 0)
    questFactionCrest:Hide()
    self.questFactionCrest = questFactionCrest

    -- Quest name matching dungeonTitle baseline and shifted flush left into portrait spot
    local questHeaderTitle = questDetailContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    questHeaderTitle:SetPoint("TOP", dungeonTitle, "TOP", 0, 0)
    questHeaderTitle:SetPoint("LEFT", questDetailContainer, "LEFT", 6, 0)
    questHeaderTitle:SetPoint("RIGHT", questDetailContainer, "RIGHT", -12, 0)
    questHeaderTitle:SetJustifyH("LEFT")
    questHeaderTitle:SetWordWrap(true)
    questHeaderTitle:SetSpacing(2)
    questHeaderTitle:SetTextColor(1.0, 0.82, 0.0)
    questHeaderTitle:SetShadowColor(0, 0, 0, 1.0)
    questHeaderTitle:SetShadowOffset(1, -1)
    self.questHeaderTitle = questHeaderTitle

    -- Subheader Meta matching dungeonMeta font and exact vertical spacing
    local questHeaderMeta = questDetailContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    questHeaderMeta:SetPoint("TOPLEFT", questHeaderTitle, "BOTTOMLEFT", 0, -3)
    questHeaderMeta:SetPoint("RIGHT", questDetailContainer, "RIGHT", -12, 0)
    questHeaderMeta:SetJustifyH("LEFT")
    questHeaderMeta:SetWordWrap(false)
    questHeaderMeta:SetTextColor(0.82, 0.72, 0.52)
    questHeaderMeta:SetShadowColor(0, 0, 0, 1.0)
    questHeaderMeta:SetShadowOffset(1, -1)
    self.questHeaderMeta = questHeaderMeta
    self.questHeaderLevel = questHeaderMeta

    -- Scrollable Quest Body Frame spanning from below questDivider to bottom margin
    local questBodyScroll = CreateFrame("ScrollFrame", "JournalDungeonsQuestBodyScrollFrame", questDetailContainer, "UIPanelScrollFrameTemplate")
    questBodyScroll:SetPoint("TOPLEFT", questDivider, "BOTTOMLEFT", 0, -8)
    questBodyScroll:SetPoint("BOTTOMRIGHT", questDetailContainer, "BOTTOMRIGHT", -22, 10)
    questBodyScroll.scrollBarHideable = true
    self.questBodyScroll = questBodyScroll

    local questBodyChild = CreateFrame("Frame", nil, questBodyScroll)
    questBodyChild:SetWidth(bookCfg.RIGHT_CONTENT_WIDTH or 340)
    questBodyChild:SetHeight(100)
    questBodyScroll:SetScrollChild(questBodyChild)
    self.questBodyChild = questBodyChild

    self.questBodyWidgets = {}

    -- Overview, Loot and Quests side tabs on the window's right edge
    self:BuildRightSideTabs(frame)

    -- A new window background recolors the open page's body text (ink on parchment)
    WindowBackground:OnChange(function()
        if self.frame and self.frame:IsShown() and self.currentDungeon then
            self:RefreshRightPage()
        end
    end)

    local dropUpdateTimer = nil
    local liveData = parent.DataStore and parent.DataStore.Live
    if liveData then
        liveData:AddListener(function()
            if self.frame and self.frame:IsShown() and self.currentDungeon and (self.selectedBoss or self.activeRightTab == "loot" or self.activeRightTab == "quests") then
                if dropUpdateTimer and dropUpdateTimer.Cancel then
                    dropUpdateTimer:Cancel()
                end
                if C_Timer and C_Timer.NewTimer then
                    dropUpdateTimer = C_Timer.NewTimer(0.08, function()
                        if self.frame and self.frame:IsShown() and self.currentDungeon then
                            if self.selectedBoss then
                                self:RenderItemDrops(self.currentDungeon, self.selectedBoss)
                            elseif self.activeRightTab == "loot" then
                                self:RenderDungeonItemDrops(self.currentDungeon)
                            elseif self.activeRightTab == "quests" then
                                self:RefreshRightPage()
                            end
                        end
                    end)
                else
                    if self.selectedBoss then
                        self:RenderItemDrops(self.currentDungeon, self.selectedBoss)
                    elseif self.activeRightTab == "loot" then
                        self:RenderDungeonItemDrops(self.currentDungeon)
                    elseif self.activeRightTab == "quests" then
                        self:RefreshRightPage()
                    end
                end
            end
        end)
    end

    frame:SetScript("OnShow", function()
        SharedWidgets:SyncWindowPortraitBorder(self.dungeonMedallion)
        if self.bossMedallion then
            SharedWidgets:SyncWindowPortraitBorder(self.bossMedallion)
        end
        if self.questGiverMedallion then
            SharedWidgets:SyncWindowPortraitBorder(self.questGiverMedallion)
        end
        self:UpdateSideTabs()
    end)

    -- Real-time reactive listener for dungeon module setting changes
    if _G.JournalBase then
        local prevHook = _G.JournalBase.OnDungeonSettingChanged
        _G.JournalBase.OnDungeonSettingChanged = function(jBase, key, val)
            if prevHook then
                pcall(prevHook, jBase, key, val)
            end
            if (key == "showBossLevel" or key == "showBossDifficultyColor" or key == "showMinorMonsters" or key == "hideMinorMonsters" or key == "showEventBosses" or key == "showDungeonSetChallenges" or key == "worldMapDungeonIcons" or key == "showBothFactionData") and self.frame and self.frame:IsShown() then
                self:UpdateSideTabs()
                self:RefreshLeftPage()
                self:RefreshRightPage()
            end
        end
    end

    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("QUEST_REMOVED")
    frame:SetScript("OnEvent", function(f, event, ...)
        if not self.frame or not self.frame:IsShown() then return end
        if event == "PLAYER_LEVEL_UP" then
            self:RefreshLeftPage()
            self:RefreshRightPage()
        elseif self.activeRightTab == "quests" then
            self:RefreshLeftPage()
            self:RefreshRightPage()
        end
    end)
end

--- Builds the Overview, Loot and Quests side tabs down the outer right edge of the journal window: Forever's
--- large side tabs (LargeSideTabButtonTemplate, the Legacy window's tabs) with our icons: the dungeon's own icon
--- (Overview), a treasure chest (Loot) and the quest exclamation mark (Quests).
--- @param bookFrame Frame
function DungeonBookView:BuildRightSideTabs(bookFrame)
    local mainWin = _G.JournalBaseMainFrame or bookFrame
    local holder = CreateFrame("Frame", nil, bookFrame)
    holder:SetSize(48, 170)
    holder:SetPoint("TOPLEFT", mainWin, "TOPRIGHT", 0, -70)
    holder:SetFrameStrata("HIGH")
    if mainWin.GetFrameLevel then
        holder:SetFrameLevel(mainWin:GetFrameLevel() + 15)
    end
    self.sideTabHolder = holder

    local function selectTab(tab)
        if not tab.isEnabled or self.activeRightTab == tab.tabKey then
            return
        end
        if PlaySound then
            PlaySound((SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB) or Constants.SOUNDS.PAGE_TURN)
        end
        self.activeRightTab = tab.tabKey
        if self.detailScroll and self.detailScroll.SetVerticalScroll then
            self.detailScroll:SetVerticalScroll(0)
        end
        if self.bossScroll and self.bossScroll.SetVerticalScroll then
            self.bossScroll:SetVerticalScroll(0)
        end
        self:UpdateSideTabs()
        self:RefreshLeftPage()
        self:RefreshRightPage()
        if self.onTabChanged then
            self.onTabChanged(tab.tabKey)
        end
    end

    -- Runs after the template's own OnEnter and replaces its tooltip with ours
    local function showTooltip(tab)
        if not GameTooltip then return end
        GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
        if tab.tabKey == "overview" then
            GameTooltip:SetText("Dungeon Overview", 1.0, 0.82, 0.0)
            if tab.isEnabled then
                GameTooltip:AddLine("View dungeon lore, artwork, and world map entrance.", 0.90, 0.90, 0.90, true)
            else
                GameTooltip:AddLine("Overview is only available on the main dungeon page.", 0.75, 0.75, 0.75, true)
                GameTooltip:AddLine("Click the dungeon portrait in the upper-left to enable.", 0.35, 0.95, 0.45, true)
            end
        elseif tab.tabKey == "quests" then
            GameTooltip:SetText("Dungeon Quests", 1.0, 0.82, 0.0)
            if tab.isEnabled then
                GameTooltip:AddLine("View all quests, chains, and rewards for this dungeon.", 0.90, 0.90, 0.90, true)
            elseif tab.disabledReason == "no_quests" then
                GameTooltip:AddLine("No quests available for your faction or class in this dungeon.", 0.75, 0.75, 0.75, true)
            else
                GameTooltip:AddLine("Quests are only available on the main dungeon page.", 0.75, 0.75, 0.75, true)
                GameTooltip:AddLine("Click the dungeon portrait in the upper-left to enable.", 0.35, 0.95, 0.45, true)
            end
        elseif self.selectedBoss then
            GameTooltip:SetText((self.selectedBoss.name or "Boss") .. " — Loot", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("Viewing categorized item drops for this encounter.", 0.90, 0.90, 0.90, true)
        else
            GameTooltip:SetText("All Dungeon Loot", 1.0, 0.82, 0.0)
            GameTooltip:AddLine("View every item drop across the entire dungeon.", 0.90, 0.90, 0.90, true)
        end
        GameTooltip:Show()
    end

    local function createTab(tabKey, titleText, setIcon)
        local tab = CreateFrame("Frame", nil, holder, "LargeSideTabButtonTemplate")
        tab:EnableMouse(true)
        tab.tabKey = tabKey
        tab.tooltipText = titleText
        tab.icon = tab.Icon
        setIcon(tab.Icon)
        tab:SetFillToInterior(true)
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside then
                selectTab(tab)
            end
        end)
        tab:HookScript("OnEnter", showTooltip)
        tab:HookScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        tab:SetChecked(false)
        return tab
    end

    self.overviewTabBtn = createTab("overview", "Dungeon Overview", function(icon)
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bone_HumanSkull_01")
    end)
    self.lootTabBtn = createTab("loot", "Loot", function(icon)
        icon:SetTexture("Interface\\Icons\\INV_Box_02")
    end)
    self.questsTabBtn = createTab("quests", "Quests", function(icon)
        if not (icon.SetAtlas and pcall(icon.SetAtlas, icon, "QuestNormal")) then
            icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        end
    end)
    self:UpdateSideTabs()
end

--- Updates the side tabs: which show, which is selected (checked), which are disabled (greyed out),
--- and the Overview tab's icon (the open dungeon's own).
function DungeonBookView:UpdateSideTabs()
    if not self.overviewTabBtn or not self.lootTabBtn or not self.questsTabBtn or not self.sideTabHolder then
        return
    end

    local overviewIcon = (self.currentDungeon and self.currentDungeon.icon) or "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
    self.overviewTabBtn.icon:SetTexture(overviewIcon)

    local hasBoss = (self.selectedBoss ~= nil)

    -- The wing selection page shows only the dungeon's overview
    self.lootTabBtn:SetShown(not self.wingPage)

    -- Quests come from the DataStore; the tab shows whenever it's on
    local questDb = QuestAccess
    local hasQuestsModule = QuestAccess:IsAvailable() and not self.wingPage
    self.questsTabBtn:SetShown(hasQuestsModule)

    local hasQuests = false
    if hasQuestsModule and self.currentDungeon then
        local showBoth = parent.Settings:IsBothFactionQuestsShown()
        local factionFilter = showBoth and "All" or (UnitFactionGroup("player") or "Both")
        local _, playerClass = UnitClass("player")
        local qList = questDb:GetDungeonQuests(self.currentDungeon, factionFilter, playerClass)
        hasQuests = (qList and #qList > 0)
    end

    local overviewEnabled = not hasBoss
    local lootEnabled = not self.wingPage
    if self.wingPage then
        self.activeRightTab = "overview"
    end
    local questsEnabled = hasQuestsModule and not hasBoss and hasQuests
    self.questsTabBtn.disabledReason = (hasBoss and "boss_selected") or (not hasQuests and "no_quests") or nil

    -- Auto-fallback if active tab is disabled:
    if hasBoss and (self.activeRightTab == "overview" or self.activeRightTab == "quests") then
        self.activeRightTab = "loot"
    elseif not questsEnabled and self.activeRightTab == "quests" then
        self.activeRightTab = "overview"
    end

    local overviewActive = overviewEnabled and (self.activeRightTab == "overview")
    local lootActive = (self.activeRightTab == "loot")
    local questsActive = questsEnabled and (self.activeRightTab == "quests")

    -- Checked lights the selected tab; a disabled tab's icon is greyed out and its clicks are ignored
    local function applyTabState(tab, isActive, isEnabled)
        tab.isActive = isActive
        tab.isEnabled = isEnabled
        tab:SetChecked(isActive)
        tab.icon:SetDesaturated(not isEnabled)
        tab.icon:SetAlpha(isEnabled and 1 or 0.45)
    end

    applyTabState(self.overviewTabBtn, overviewActive, overviewEnabled)
    applyTabState(self.lootTabBtn, lootActive, lootEnabled)
    applyTabState(self.questsTabBtn, questsActive, questsEnabled)

    -- Stacked down the window's right edge 2 px apart; a hidden tab leaves no gap
    local previous
    for _, tab in ipairs({ self.overviewTabBtn, self.lootTabBtn, self.questsTabBtn }) do
        tab:ClearAllPoints()
        if tab:IsShown() then
            if previous then
                tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
            else
                tab:SetPoint("TOPLEFT", self.sideTabHolder, "TOPLEFT", 0, 0)
            end
            previous = tab
        end
    end
end

DungeonBookView.UpdateRightSideTabStates = DungeonBookView.UpdateSideTabs

--- Builds the Instance Overview pane (Artwork banner + lore text).
function DungeonBookView:BuildInstanceOverviewPane(rightPage)
    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK

    local pane = CreateFrame("Frame", nil, rightPage)
    pane:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 6, -8)
    pane:SetPoint("BOTTOMRIGHT", rightPage, "BOTTOMRIGHT", -12, 6)
    self.overviewPane = pane

    -- Framed Dungeon Artwork Box (`376 x 186`)
    local artBox = CreateFrame("Frame", nil, pane)
    artBox:SetSize(bookCfg.ART_FRAME_WIDTH, bookCfg.ART_FRAME_HEIGHT)
    artBox:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -22)
    self.artBox = artBox

    -- Dark background backing for the art
    local artBg = artBox:CreateTexture(nil, "BACKGROUND")
    artBg:SetAllPoints(artBox)
    artBg:SetTexture(Constants.ASSETS.WHITE_8X8)
    artBg:SetVertexColor(0.06, 0.05, 0.04, 0.98)
    artBox.bg = artBg

    local overviewArt = artBox:CreateTexture(nil, "ARTWORK", nil, 0)
    overviewArt:SetPoint("TOPLEFT", artBox, "TOPLEFT", 2, -2)
    overviewArt:SetPoint("BOTTOMRIGHT", artBox, "BOTTOMRIGHT", -2, 2)
    self.overviewArt = overviewArt

    local artTopVignette = artBox:CreateTexture(nil, "ARTWORK", nil, 2)
    artTopVignette:SetPoint("TOPLEFT", artBox, "TOPLEFT", 2, -2)
    artTopVignette:SetPoint("TOPRIGHT", artBox, "TOPRIGHT", -2, -2)
    artTopVignette:SetHeight(48)
    artTopVignette:SetTexture(Constants.ASSETS.WHITE_8X8)
    if artTopVignette.SetGradient and CreateColor then
        artTopVignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.05), CreateColor(0, 0, 0, 0.80))
    else
        artTopVignette:SetVertexColor(0, 0, 0, 0.55)
    end

    local artBannerTitle = artBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    artBannerTitle:SetPoint("TOP", artBox, "TOP", 0, -14)
    artBannerTitle:SetTextColor(1.0, 0.84, 0.18)
    self.artBannerTitle = artBannerTitle

    -- DialogBox Border overlay around artBox (Interface\DialogFrame\UI-DialogBox-Border)
    local ok, borderFrame = pcall(CreateFrame, "Frame", nil, artBox, "BackdropTemplate")
    if ok and borderFrame and borderFrame.SetBackdrop then
        borderFrame:SetPoint("TOPLEFT", artBox, "TOPLEFT", -8, 8)
        borderFrame:SetPoint("BOTTOMRIGHT", artBox, "BOTTOMRIGHT", 8, -8)
        borderFrame:SetFrameLevel(artBox:GetFrameLevel() + 5)
        borderFrame:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
        })
        borderFrame:SetBackdropBorderColor(1, 1, 1, 1)
        self.artBorderFrame = borderFrame
    end

    -- Horizontal Divider Bar below the artwork box
    local overviewDivider = SharedWidgets:CreateHorizontalDividerBar(pane, 4)
    overviewDivider:SetPoint("TOPLEFT", artBox, "BOTTOMLEFT", 0, -14)
    overviewDivider:SetPoint("TOPRIGHT", artBox, "BOTTOMRIGHT", 0, -14)
    self.overviewDivider = overviewDivider

    -- Dungeon Lore Description below the divider
    local loreText = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loreText:SetPoint("TOPLEFT", overviewDivider, "BOTTOMLEFT", 4, -12)
    loreText:SetWidth(bookCfg.ART_FRAME_WIDTH - 8)
    loreText:SetJustifyH("LEFT")
    loreText:SetJustifyV("TOP")
    loreText:SetSpacing(4)
    loreText:SetTextColor(0.92, 0.85, 0.72)
    self.overviewLoreText = loreText

    -- "Show on Map" Button below the Dungeon Lore Description (gold text)
    local showOnMapBtn = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    showOnMapBtn:SetSize(200, 32)
    showOnMapBtn:SetPoint("TOP", loreText, "BOTTOM", 0, -18)
    showOnMapBtn:RegisterForClicks("LeftButtonUp")

    local mapSwirlIcon = showOnMapBtn:CreateTexture(nil, "ARTWORK")
    mapSwirlIcon:SetSize(20, 20)
    mapSwirlIcon:SetAtlas("Dungeon")
    showOnMapBtn.icon = mapSwirlIcon

    local mapBtnText = showOnMapBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapBtnText:SetText("Show on Map")
    mapBtnText:SetTextColor(1.0, 0.82, 0.15)
    showOnMapBtn.label = mapBtnText

    mapSwirlIcon:SetPoint("LEFT", showOnMapBtn, "LEFT", 36, 0)
    mapBtnText:SetPoint("LEFT", mapSwirlIcon, "RIGHT", 8, 0)

    showOnMapBtn:SetScript("OnEnter", function(btn)
        if not GameTooltip or not self.currentDungeon then return end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show on World Map", 1.0, 0.82, 0.0)
        local loc = GetDungeonMapLocation(self.currentDungeon)
        if loc and loc.name then
            GameTooltip:AddLine(string.format("Click to view %s entrance on the World Map.", loc.name), 1.0, 1.0, 1.0, true)
        else
            GameTooltip:AddLine("Click to view dungeon entrance on the World Map.", 1.0, 1.0, 1.0, true)
        end
        GameTooltip:Show()
    end)

    showOnMapBtn:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    showOnMapBtn:SetScript("OnClick", function()
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if not self.currentDungeon then return end
        local loc = GetDungeonMapLocation(self.currentDungeon)
        local uiMapID = loc and loc.uiMapID

        -- Open World Map and navigate to the dungeon's map zone (journal remains open)
        if _G.OpenWorldMap then
            _G.OpenWorldMap(uiMapID)
        elseif _G.ToggleWorldMap then
            if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then
                _G.ToggleWorldMap()
            end
        elseif _G.ShowUIPanel and _G.WorldMapFrame then
            _G.ShowUIPanel(_G.WorldMapFrame)
        elseif _G.WorldMapFrame then
            _G.WorldMapFrame:Show()
        end

        if uiMapID and _G.WorldMapFrame and _G.WorldMapFrame.SetMapID then
            _G.WorldMapFrame:SetMapID(uiMapID)
        end
    end)
    self.showOnMapBtn = showOnMapBtn

    local liveData = parent.DataStore and parent.DataStore.Live
    if liveData then
        liveData:AddListener(function()
            if self.frame and self.frame:IsShown() then
                if self.searchQuery and self.searchQuery ~= "" then
                    local prevBoss = self.selectedBoss
                    self:RefreshLeftPage()
                    self:RefreshRightPage()
                    if self.selectedBoss ~= prevBoss and self.selectedBoss and self.onSelectBoss then
                        self.onSelectBoss(self.selectedBoss)
                    end
                elseif self.selectedBoss or self.activeRightTab == "loot" or self.activeRightTab == "quests" then
                    self:RefreshRightPage()
                end
            end
        end)
    end
end

--- Acquires or creates a clickable Boss Portrait Button on the Left Page (`index`).
function DungeonBookView:AcquireBossButton(index)
    local btn = self.bossButtonPool[index]
    if btn then
        btn:Show()
        return btn
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK

    btn = CreateFrame("Button", nil, self.bossScrollChild)
    btn:SetSize(bookCfg.BOSS_BTN_WIDTH, bookCfg.BOSS_BTN_HEIGHT)
    SharedWidgets:StyleBossSlabButton(btn)

    -- "Horizontal Thermometer" circular medallion bulb overlapping and extending outside the button slab
    local medallion = SharedWidgets:CreateCircularMedallion(btn, bookCfg.BOSS_ICON_SIZE, bookCfg.BOSS_RING_SIZE)
    medallion:SetPoint("LEFT", btn, "LEFT", -10, 0)
    medallion:SetFrameLevel(btn:GetFrameLevel() + 5)
    btn.medallion = medallion

    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local fontFile, fontSize, fontFlags = nameText:GetFont()
    if fontFile then
        nameText:SetFont(fontFile, (fontSize or 12) + 2, fontFlags or "")
    end
    nameText:SetShadowColor(0, 0, 0, 1.0)
    nameText:SetShadowOffset(1, -1)
    nameText:SetPoint("LEFT", btn, "LEFT", 56, 0)
    nameText:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(true)
    nameText:SetSpacing(2)
    btn.nameText = nameText

    local levelText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetShadowColor(0, 0, 0, 1.0)
    levelText:SetShadowOffset(1, -1)
    levelText:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    levelText:SetJustifyH("RIGHT")
    levelText:Hide()
    btn.levelText = levelText

    if btn.HookScript then
        btn:HookScript("OnEnter", function(b)
            if (self.selectedBoss ~= b.boss) and b.nameText then
                b.nameText:SetTextColor(1.0, 0.94, 0.68)
            end
        end)
        btn:HookScript("OnLeave", function(b)
            if (self.selectedBoss ~= b.boss) and b.nameText then
                b.nameText:SetTextColor(1.0, 0.88, 0.55)
            end
        end)
    end

    btn:SetScript("OnClick", function(clicked)
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if clicked.boss and self.onSelectBoss then
            self.onSelectBoss(clicked.boss)
        end
    end)

    self.bossButtonPool[index] = btn
    return btn
end

--- Acquires or creates a wing button for the wing selection page (`index`): a stone card
--- (UI/StoneCard.lua) with the wing's name over its levels.
function DungeonBookView:AcquireWingButton(index)
    local btn = self.wingButtonPool[index]
    if btn then
        btn:Show()
        return btn
    end

    local bookCfg = Constants.BOOK
    btn = ns.UI.StoneCard:Create(self.bossScrollChild, bookCfg.BOSS_BTN_WIDTH, bookCfg.WING_BTN_HEIGHT,
        { picture = true })
    btn.levelText = btn.subText
    btn:SetScript("OnClick", function(clicked)
        if PlaySound then
            PlaySound(Constants.SOUNDS.CLICK)
        end
        if clicked.wing and self.onSelectWing then
            self.onSelectWing(clicked.wing)
        end
    end)

    self.wingButtonPool[index] = btn
    return btn
end

--- Shows a dungeon's wing selection page: its wings on the left, its overview on the right.
--- @param dungeon table a dungeon view with wings (DungeonAccess)
--- @param onSelectWing function `function(wing)`
function DungeonBookView:SetWingContext(dungeon, onSelectWing)
    self.wingPage = true
    self.onSelectWing = onSelectWing
    self.currentDungeon = dungeon
    self.selectedBoss = nil
    self.selectedQuest = nil
    self.activeRightTab = "overview"
    if self.detailScroll and self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    if self.bossScroll and self.bossScroll.SetVerticalScroll then
        self.bossScroll:SetVerticalScroll(0)
    end
    self:RefreshLeftPage()
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

--- Renders the wing list on the left page of the wing selection page.
--- @param d table the parent dungeon view
function DungeonBookView:RenderWingList(d)
    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK
    for _, pool in ipairs({ self.questButtonPool, self.wingButtonPool }) do
        for _, btn in ipairs(pool) do btn:Hide() end
    end
    for _, name in ipairs({ "eventDivider", "rareHeader", "minorHeader", "challengeHeader", "trashDivider",
        "questFactionDivider", "noEncountersText" }) do
        if self[name] then
            self[name]:Hide()
        end
    end
    self.leftDivider:Show()
    self.bossScroll:Show()

    local showLevel, showColor = true, true
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showLevel = _G.JournalBase:GetDungeonSetting("showBossLevel", true) == true
        showColor = _G.JournalBase:GetDungeonSetting("showBossDifficultyColor", true) == true
    end

    local currentY = -16
    for i, wing in ipairs(Access:GetWings(d)) do
        local btn = self:AcquireWingButton(i)
        btn.wing = wing
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 26, currentY)
        btn.nameText:SetText(wing.name)
        ns.UI.StoneCard:SetDungeonPicture(btn, wing)
        btn.levelText:SetText(wing.level and ("Lvl " .. wing.level) or "")
        btn.levelText:SetShown(showLevel)
        if showColor then
            btn.levelText:SetTextColor(SharedWidgets:GetDungeonDifficultyColor(wing))
        else
            btn.levelText:SetTextColor(1, 1, 1)
        end
        currentY = currentY - (bookCfg.WING_BTN_HEIGHT + bookCfg.WING_BTN_GAP)
    end
    local totalH = -currentY + 10
    self.bossScrollChild:SetHeight(math.max(1, totalH))
    SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, totalH)
end

--- Acquires or creates a category header frame for item drop sections.
--- @param index number
--- @return Frame
function DungeonBookView:AcquireCategoryHeader(index)
    local hdr = self.categoryHeaderPool[index]
    if hdr then
        hdr:Show()
        return hdr
    end

    hdr = CreateFrame("Frame", nil, self.detailScrollChild)
    hdr:SetHeight(24)

    local title = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", hdr, "TOPLEFT", 4, -2)
    title:SetTextColor(1.0, 0.82, 0.20)
    hdr.title = title

    local div = hdr:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 2, 2)
    div:SetPoint("BOTTOMRIGHT", hdr, "BOTTOMRIGHT", -4, 2)
    div:SetTexture(Constants.ASSETS.WHITE_8X8)
    div:SetVertexColor(0.68, 0.52, 0.20, 0.40)
    hdr.div = div

    self.categoryHeaderPool[index] = hdr
    return hdr
end

--- Acquires or creates a pooled item drop row button.
--- @param index number
--- @return Button
function DungeonBookView:AcquireItemRow(index)
    local row = self.itemRowPool[index]
    if row then
        row:Show()
        return row
    end

    local white = Constants.ASSETS.WHITE_8X8
    row = CreateFrame("Button", nil, self.detailScrollChild)
    row:SetHeight(36)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(white)
    bg:SetVertexColor(0.08, 0.07, 0.06, 0.35)
    row.bg = bg

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(white)
    hl:SetVertexColor(1.0, 0.90, 0.65, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local bTop = row:CreateTexture(nil, "OVERLAY")
    bTop:SetHeight(1)
    bTop:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    bTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 1)
    bTop:SetTexture(white)

    local bBottom = row:CreateTexture(nil, "OVERLAY")
    bBottom:SetHeight(1)
    bBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, -1)
    bBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    bBottom:SetTexture(white)

    local bLeft = row:CreateTexture(nil, "OVERLAY")
    bLeft:SetWidth(1)
    bLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 0)
    bLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, 0)
    bLeft:SetTexture(white)

    local bRight = row:CreateTexture(nil, "OVERLAY")
    bRight:SetWidth(1)
    bRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 0)
    bRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    bRight:SetTexture(white)

    function row:SetBorderColor(r, g, b, a)
        local alpha = a or 1.0
        bTop:SetVertexColor(r, g, b, alpha)
        bBottom:SetVertexColor(r, g, b, alpha)
        bLeft:SetVertexColor(r, g, b, alpha)
        bRight:SetVertexColor(r, g, b, alpha)
    end

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local subLeftText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subLeftText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 3)
    subLeftText:SetHeight(12)
    subLeftText:SetJustifyH("LEFT")
    subLeftText:SetWordWrap(false)
    if subLeftText.SetMaxLines then pcall(subLeftText.SetMaxLines, subLeftText, 1) end
    subLeftText:SetTextColor(0.75, 0.70, 0.60)
    row.subLeftText = subLeftText

    local subRightText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subRightText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 3)
    subRightText:SetHeight(12)
    subRightText:SetJustifyH("RIGHT")
    subRightText:SetWordWrap(false)
    if subRightText.SetMaxLines then pcall(subRightText.SetMaxLines, subRightText, 1) end
    row.subRightText = subRightText

    local bossSourceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossSourceText:SetJustifyH("LEFT")
    bossSourceText:SetWordWrap(false)
    bossSourceText:SetTextColor(0.92, 0.78, 0.42)
    bossSourceText:Hide()
    row.bossSourceText = bossSourceText

    row.UpdateTooltip = ShowItemRowTooltip
    row:SetScript("OnEnter", ShowItemRowTooltip)

    row:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row:SetScript("OnClick", function(r)
        if not r.itemLink then return end
        local isShift = (_G.IsShiftKeyDown and _G.IsShiftKeyDown())
        local isCtrl = (_G.IsControlKeyDown and _G.IsControlKeyDown())
        if isShift then
            local insertLink = _G.ChatEdit_InsertLink
            if insertLink then
                insertLink(r.itemLink)
            end
        elseif isCtrl then
            local dressUp = _G.DressUpItemLink or _G.DressUpLink
            if dressUp then
                dressUp(r.itemLink)
            end
        end
    end)

    self.itemRowPool[index] = row
    return row
end

--- Acquires or creates a pooled Quest list button on the Left Page.
--- Styled identically to the Boss Buttons (metallic beveled borders, subtle highlights/shadows)
--- using Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal-Desaturated as the background,
--- a QuestNormal atlas icon on the left, gold quest title, and player-level relative difficulty colored level text.
--- @param index number
--- @return Button
function DungeonBookView:AcquireQuestButton(index)
    local btn = self.questButtonPool[index]
    if btn then
        btn:Show()
        return btn
    end

    local white = Constants.ASSETS.WHITE_8X8
    local bookCfg = Constants.BOOK

    btn = CreateFrame("Button", nil, self.bossScrollChild)
    btn:SetSize((bookCfg.BOSS_BTN_WIDTH or 268) + 8, bookCfg.BOSS_BTN_HEIGHT or 44)

    -- 1. Outer subtle drop shadow (matching boss buttons)
    local shadow = btn:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    shadow:SetTexture(white)
    shadow:SetVertexColor(0.02, 0.02, 0.01, 0.60)
    btn._dropShadow = shadow

    -- 2. Base dark rim (1px border)
    local baseRim = btn:CreateTexture(nil, "BACKGROUND", nil, -4)
    baseRim:SetAllPoints(btn)
    baseRim:SetTexture(white)
    baseRim:SetVertexColor(0.12, 0.09, 0.06, 0.95)
    btn._baseRim = baseRim

    -- 3. Textured Desaturated Achievement Parchment fill
    local fill = btn:CreateTexture(nil, "BACKGROUND", nil, -3)
    fill:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    fill:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated")
    fill:SetVertexColor(1.0, 1.0, 1.0, 1.0)
    btn._fill = fill

    -- 4. Subtle top/left highlights and bottom/right shadows for embossed 3D feel
    local topHi = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    topHi:SetHeight(1)
    topHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    topHi:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    topHi:SetTexture(white)
    topHi:SetVertexColor(0.56, 0.44, 0.26, 0.70)

    local leftHi = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    leftHi:SetWidth(1)
    leftHi:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    leftHi:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    leftHi:SetTexture(white)
    leftHi:SetVertexColor(0.48, 0.38, 0.22, 0.60)

    local botSh = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    botSh:SetHeight(1)
    botSh:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    botSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    botSh:SetTexture(white)
    botSh:SetVertexColor(0.04, 0.03, 0.02, 0.95)

    local rightSh = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
    rightSh:SetWidth(1)
    rightSh:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    rightSh:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    rightSh:SetTexture(white)
    rightSh:SetVertexColor(0.04, 0.03, 0.02, 0.95)

    -- Subtle 1px inset hover highlight matching boss button treatment
    local hover = btn:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    hover:SetTexture(white)
    hover:SetBlendMode("ADD")
    hover:SetVertexColor(0.95, 0.80, 0.35, 0.18)

    -- 5a. Chain badge placed directly UNDER the quest marker so they overlap
    -- Placeholder art from another addon: replace fdj_quest_chain.tga with our own chain icon once we have one
    local chainBadge = btn:CreateTexture(nil, "ARTWORK")
    chainBadge:SetSize(26, 26)
    chainBadge:SetPoint("CENTER", btn, "LEFT", 22, 0)
    chainBadge:SetTexture("Interface\\AddOns\\Adventure_Journal\\Art\\Icons\\fdj_quest_chain.tga")
    chainBadge:Hide()
    btn.chainBadge = chainBadge

    -- 5b. Quest icon on the left (in OVERLAY layer above the chain badge)
    local qIcon = btn:CreateTexture(nil, "OVERLAY")
    qIcon:SetSize(24, 24)
    qIcon:SetPoint("CENTER", btn, "LEFT", 22, 0)
    if qIcon.SetAtlas then
        local ok = pcall(qIcon.SetAtlas, qIcon, "QuestNormal")
        if not ok then
            qIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        end
    else
        qIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end
    btn.qIcon = qIcon

    -- 6. Level text on the right (difficulty colored based on player level)
    local levelText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    levelText:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
    levelText:SetJustifyH("RIGHT")
    levelText:SetShadowColor(0, 0, 0, 1.0)
    levelText:SetShadowOffset(1, -1)
    btn.levelText = levelText

    -- 7. Quest title in gold text (word-wrapped across up to two lines)
    local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local fontFile, fontSize, fontFlags = nameText:GetFont()
    if fontFile then
        nameText:SetFont(fontFile, (fontSize or 12), fontFlags or "")
    end
    nameText:SetTextColor(1.0, 0.82, 0.0)
    nameText:SetShadowColor(0, 0, 0, 1.0)
    nameText:SetShadowOffset(1, -1)
    nameText:SetPoint("LEFT", btn, "LEFT", 40, 0)
    nameText:SetPoint("RIGHT", levelText, "LEFT", -6, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetJustifyV("MIDDLE")
    nameText:SetWordWrap(true)
    nameText:SetHeight(btn:GetHeight() - 6)
    btn.nameText = nameText

    -- 8. Selection Glow (matching boss button treatment)
    local selectedGlow = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    selectedGlow:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    selectedGlow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    selectedGlow:SetTexture(white)
    selectedGlow:SetVertexColor(0.85, 0.62, 0.18, 0.28)
    selectedGlow:Hide()
    btn.selectedGlow = selectedGlow

    -- 9. Click handler: selects this quest and updates both pages
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function(b)
        if PlaySound then
            PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or Constants.SOUNDS.CLICK)
        end
        self.selectedQuest = b.quest
        self:RefreshLeftPage()
        self:RefreshRightPage()
    end)

    self.questButtonPool[index] = btn
    return btn
end

--- Sets the active dungeon and optional selected boss, then refreshes both pages.
--- @param dungeon table
--- @param boss table|nil
--- @param searchQuery string|nil
--- @param preserveRightTab boolean|nil
function DungeonBookView:SetContext(dungeon, boss, searchQuery, preserveRightTab)
    self.wingPage = false
    self.currentDungeon = dungeon
    self.selectedBoss = boss
    self.selectedQuest = nil
    self.suppressSearchAutoBoss = (preserveRightTab == true and boss == nil)
    if not preserveRightTab then
        self.activeRightTab = boss and "loot" or "overview"
    elseif boss then
        self.activeRightTab = "loot"
    end
    if searchQuery ~= nil then
        self.searchQuery = searchQuery
    end
    if self.detailScroll and self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    if self.bossScroll and self.bossScroll.SetVerticalScroll then
        self.bossScroll:SetVerticalScroll(0)
    end
    self:RefreshLeftPage()
    if self.selectedBoss then
        self.activeRightTab = "loot"
    end
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

--- Updates the search query filter for the left page.
--- @param queryText string
function DungeonBookView:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    self.suppressSearchAutoBoss = false
    if self.frame and self.frame:IsShown() then
        if self.bossScroll and self.bossScroll.SetVerticalScroll then
            self.bossScroll:SetVerticalScroll(0)
        end
        self:RefreshLeftPage()
        if self.selectedBoss then
            self.activeRightTab = "loot"
        end
        self:UpdateSideTabs()
        self:RefreshRightPage()
    end
end

--- Updates only the selected boss (or `nil` for Instance Overview / Full Dungeon Loot) and refreshes.
--- @param boss table|nil
function DungeonBookView:SetSelectedBoss(boss)
    self.selectedBoss = boss
    if boss then
        self.activeRightTab = "loot"
        self.suppressSearchAutoBoss = false
    else
        self.suppressSearchAutoBoss = true
    end
    if self.detailScroll and self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    self:RefreshLeftPage()
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

--- Renders the Left Page (Dungeon Medallion Header, Boss Portrait Buttons, and Trash Drops).
function DungeonBookView:RefreshLeftPage()
    local d = self.currentDungeon
    if not d or not self.frame then
        return
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK

    local showBossLevel = true
    local showDifficultyColor = true
    local showMinor = true
    local showEventBosses = "holiday"
    local showDungeonSetChallenges = false
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showBossLevel = _G.JournalBase:GetDungeonSetting("showBossLevel", true) == true
        showDifficultyColor = _G.JournalBase:GetDungeonSetting("showBossDifficultyColor", true) == true
        showMinor = _G.JournalBase:GetDungeonSetting("showMinorMonsters", true) == true
        showEventBosses = _G.JournalBase:GetDungeonSetting("showEventBosses", "holiday")
        showDungeonSetChallenges = _G.JournalBase:GetDungeonSetting("showDungeonSetChallenges", false) == true
    end

    SharedWidgets:SetDungeonMedallionArt(self.dungeonMedallion, d)
    SharedWidgets:SyncWindowPortraitBorder(self.dungeonMedallion)
    self.dungeonTitle:SetText(d.fullName or "Dungeon")

    -- Capital-city faction crest (DungeonAccess decides which dungeons get one)
    local faction = d.crest
    if faction and self.factionCrest then
        local crestTex = (faction == "Horde") and "Interface\\Timer\\Horde-Logo" or "Interface\\Timer\\Alliance-Logo"
        self.factionCrest:SetTexture(crestTex)
        self.factionCrest:SetTexCoord(0, 1, 0, 1)
        self.factionCrest:SetSize(38, 38)
        self.factionCrest:ClearAllPoints()
        self.factionCrest:SetPoint("RIGHT", self.leftPage, "RIGHT", -12, 0)
        self.factionCrest:SetPoint("CENTER", self.dungeonMedallion, "CENTER", 0, 0)
        self.factionCrest:Show()

        self.dungeonTitle:ClearAllPoints()
        self.dungeonTitle:SetPoint("TOPLEFT", self.dungeonMedallion, "TOPRIGHT", 10, -2)
        self.dungeonTitle:SetPoint("RIGHT", self.factionCrest, "LEFT", -8, 0)

        self.dungeonMeta:ClearAllPoints()
        self.dungeonMeta:SetPoint("TOPLEFT", self.dungeonTitle, "BOTTOMLEFT", 0, -3)
        self.dungeonMeta:SetPoint("RIGHT", self.factionCrest, "LEFT", -8, 0)
    elseif self.factionCrest then
        self.factionCrest:Hide()

        self.dungeonTitle:ClearAllPoints()
        self.dungeonTitle:SetPoint("TOPLEFT", self.dungeonMedallion, "TOPRIGHT", 10, -2)
        self.dungeonTitle:SetPoint("RIGHT", self.leftPage, "RIGHT", -12, 0)

        self.dungeonMeta:ClearAllPoints()
        self.dungeonMeta:SetPoint("TOPLEFT", self.dungeonTitle, "BOTTOMLEFT", 0, -3)
        self.dungeonMeta:SetPoint("RIGHT", self.leftPage, "RIGHT", -12, 0)
    end
    if showDifficultyColor then
        local r, g, b = SharedWidgets:GetDungeonDifficultyColor(d)
        local hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
        self.dungeonMeta:SetText(string.format("|cff%sLv %s|r • %s", hex, d.level or "?", d.location or ""))
    else
        self.dungeonMeta:SetText(string.format("Lv %s • %s", d.level or "?", d.location or ""))
    end

    for _, btn in ipairs(self.bossButtonPool) do
        btn:Hide()
    end

    self.dungeonTitle:SetText(d.fullName or "Dungeon")

    if self.wingPage then
        self:RenderWingList(d)
        return
    end
    for _, btn in ipairs(self.wingButtonPool) do
        btn:Hide()
    end

    if self.activeRightTab == "quests" then
        self.leftDivider:Show()
        self.bossScroll:Show()
        if self.eventDivider then self.eventDivider:Hide() end
        if self.rareHeader then self.rareHeader:Hide() end
        if self.minorHeader then self.minorHeader:Hide() end
        if self.challengeHeader then self.challengeHeader:Hide() end
        if self.trashDivider then self.trashDivider:Hide() end
        if self.questFactionDivider then self.questFactionDivider:Hide() end
        if self.noEncountersText then self.noEncountersText:Hide() end

        self:RenderDungeonQuests(d)
        return
    else
        self.leftDivider:Show()
        self.bossScroll:Show()
        if self.questFactionDivider then self.questFactionDivider:Hide() end
        for _, btn in ipairs(self.questButtonPool) do
            btn:Hide()
        end
    end

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""

    local function bossMatches(boss)
        if q == "" then return true end
        return Access:BossMatches(boss, q)
    end

    local eventBosses = {}
    local mainBosses = {}
    local rareBosses = {}
    local minorBosses = {}
    local challengeBosses = {}
    local firstMatchingBoss = nil
    local selectedBossMatches = false
    local isSearching = (q ~= "")

    for _, boss in ipairs(Access:GetBosses(d)) do
        if bossMatches(boss) then
            local addedToSection = false

            if boss.isEvent then
                local shouldShow = true
                local holidayMgr = ns.HolidayManager or (_G.JournalBase and _G.JournalBase.HolidayManager)
                if holidayMgr and holidayMgr.ShouldShowEventBoss then
                    shouldShow = holidayMgr:ShouldShowEventBoss(boss, showEventBosses)
                else
                    shouldShow = (showEventBosses == "always") or (showEventBosses == true)
                end
                if shouldShow or isSearching then
                    eventBosses[#eventBosses + 1] = boss
                    addedToSection = true
                end
            elseif boss.isChallenge then
                if showDungeonSetChallenges or isSearching then
                    challengeBosses[#challengeBosses + 1] = boss
                    addedToSection = true
                end
            else
                local isRare = (boss.rare == true) or (boss.isRare == true) or (boss.classification == "rare") or (boss.classification == "rareelite")
                local isMinor = (boss.isMinor == true) or (boss.classification == "minor") or (boss.classification == "quest")
                if isRare then
                    rareBosses[#rareBosses + 1] = boss
                    addedToSection = true
                elseif isMinor then
                    if showMinor or isSearching then
                        minorBosses[#minorBosses + 1] = boss
                        addedToSection = true
                    end
                else
                    mainBosses[#mainBosses + 1] = boss
                    addedToSection = true
                end
            end

            if addedToSection then
                if not firstMatchingBoss then
                    firstMatchingBoss = boss
                end
                if self.selectedBoss == boss then
                    selectedBossMatches = true
                end
            end
        end
    end

    -- Evaluate Zone Drops and search match counts BEFORE rendering boss buttons
    local zoneDrops = d.zoneItemIDs or {}
    local hasZoneDrops = (#zoneDrops > 0)
    if hasZoneDrops and q ~= "" then
        hasZoneDrops = strfind("zone drops", q, 1, true) ~= nil
            or Access:BossMatches({ name = "Zone Drops", itemIDs = zoneDrops }, q)
    end

    if not self.zoneBossEntry or self.zoneBossEntry.dungeonId ~= d.id then
        self.zoneBossEntry = {
            dungeonId = d.id,
            itemIDs = zoneDrops,
            name = "Zone Drops",
            isZone = true,
            isTrash = true,
            classification = "trash",
            icon = "Interface\\Icons\\INV_Box_01",
            level = "Zone",
            description = string.format("Notable zone-wide drops from creatures throughout %s.", d.name or "the dungeon"),
        }
    end

    if hasZoneDrops and self.selectedBoss and (self.selectedBoss.isZone or self.selectedBoss.isTrash) then
        self.selectedBoss = self.zoneBossEntry
        selectedBossMatches = true
    end

    -- Auto-select behavior when search query is active:
    --   * Multiple item/encounter matches in the dungeon -> bring up Full Dungeon Loot (`selectedBoss = nil`, `activeRightTab = "loot"`)
    --   * Single match -> auto-select that single encounter
    if q ~= "" and not self.suppressSearchAutoBoss then
        local matchingEncounterCount = #eventBosses + #mainBosses + #rareBosses + #minorBosses + #challengeBosses + (hasZoneDrops and 1 or 0)
        local matchingItemCount = 0
        local parsedQuery = Search:Parse(q)
        local seenItems = {}
        local function countBossItems(itemIDs)
            for _, itemID in ipairs(itemIDs or {}) do
                if not seenItems[itemID] then
                    seenItems[itemID] = true
                    if Search:ItemMatches(itemID, parsedQuery) then
                        matchingItemCount = matchingItemCount + 1
                    end
                end
            end
        end
        for _, b in ipairs(eventBosses) do countBossItems(b.itemIDs) end
        for _, b in ipairs(mainBosses) do countBossItems(b.itemIDs) end
        for _, b in ipairs(rareBosses) do countBossItems(b.itemIDs) end
        for _, b in ipairs(minorBosses) do countBossItems(b.itemIDs) end
        for _, b in ipairs(challengeBosses) do countBossItems(b.itemIDs) end
        if hasZoneDrops then countBossItems(zoneDrops) end

        if not selectedBossMatches then
            if matchingItemCount > 1 or matchingEncounterCount > 1 then
                self.selectedBoss = nil
                self.activeRightTab = "loot"
            elseif firstMatchingBoss then
                self.selectedBoss = firstMatchingBoss
                self.activeRightTab = "loot"
            elseif hasZoneDrops then
                self.selectedBoss = self.zoneBossEntry
                self.activeRightTab = "loot"
            else
                self.selectedBoss = nil
                self.activeRightTab = "loot"
            end
        end
    end

    local function renderBossButton(btn, boss, yPos)
        btn.boss = boss
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 26, yPos)

        SharedWidgets:SetBossMedallionPortrait(btn.medallion, boss, d)
        SharedWidgets:SyncWindowPortraitBorder(btn.medallion)
        SharedWidgets:SetMedallionClassification(btn.medallion, boss)

        local isSelected = (self.selectedBoss == boss)
        if btn.selectedGlow then
            btn.selectedGlow:SetShown(isSelected)
        end
        if btn._slabFill then
            if isSelected then
                btn._slabFill:SetVertexColor(1.0, 0.92, 0.72, 1.0)
            else
                btn._slabFill:SetVertexColor(0.85, 0.75, 0.60, 0.90)
            end
        end

        btn.nameText:ClearAllPoints()
        btn.nameText:SetPoint("LEFT", btn, "LEFT", 56, 0)
        if showBossLevel then
            btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -58, 0)
        else
            btn.nameText:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
        end

        btn.nameText:SetText(boss.name or "")
        if isSelected then
            btn.nameText:SetTextColor(1.0, 0.98, 0.82)
        else
            btn.nameText:SetTextColor(1.0, 0.88, 0.55)
        end

        if btn.levelText then
            if showBossLevel then
                if boss.isEvent then
                    btn.levelText:SetText("Event ??")
                    if showDifficultyColor then
                        local r, g, b = GetDifficultyColor(boss.level or "??")
                        btn.levelText:SetTextColor(r, g, b)
                    else
                        btn.levelText:SetTextColor(1.0, 0.75, 0.30)
                    end
                else
                    local isRare = (not boss.isChallenge) and (boss.rare or boss.isRare or (boss.classification == "rare") or (boss.classification == "rareelite"))
                    if isRare then
                        btn.levelText:SetText("Rare " .. (boss.level or "??"))
                        if showDifficultyColor then
                            local r, g, b = GetDifficultyColor(boss.level or "??")
                            btn.levelText:SetTextColor(r, g, b)
                        else
                            btn.levelText:SetTextColor(0.75, 0.85, 0.95)
                        end
                    else
                        btn.levelText:SetText("Lv " .. (boss.level or "??"))
                        if showDifficultyColor then
                            local r, g, b = GetDifficultyColor(boss.level or "??")
                            btn.levelText:SetTextColor(r, g, b)
                        else
                            btn.levelText:SetTextColor(0.80, 0.72, 0.55)
                        end
                    end
                end
                btn.levelText:Show()
            else
                btn.levelText:Hide()
            end
        end
        btn:Show()
    end

    local btnIndex = 0
    local currentY = -16

    -- 1. EVENT BOSSES AT THE TOP
    if #eventBosses > 0 then
        for _, boss in ipairs(eventBosses) do
            btnIndex = btnIndex + 1
            local btn = self:AcquireBossButton(btnIndex)
            renderBossButton(btn, boss, currentY)
            currentY = currentY - (bookCfg.BOSS_BTN_HEIGHT + bookCfg.BOSS_BTN_GAP)
        end

        local eventDividerY = currentY
        if self.eventDivider then
            self.eventDivider:ClearAllPoints()
            self.eventDivider:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, eventDividerY)
            self.eventDivider:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, eventDividerY)
            self.eventDivider:Show()
        end
        currentY = eventDividerY - 30
    else
        if self.eventDivider then
            self.eventDivider:Hide()
        end
        if self.selectedBoss and self.selectedBoss.isEvent then
            local shouldShow = true
            local holidayMgr = ns.HolidayManager or (_G.JournalBase and _G.JournalBase.HolidayManager)
            if holidayMgr and holidayMgr.ShouldShowEventBoss then
                shouldShow = holidayMgr:ShouldShowEventBoss(self.selectedBoss, showEventBosses)
            else
                shouldShow = (showEventBosses == "always") or (showEventBosses == true)
            end
            if not shouldShow then
                self.selectedBoss = nil
            end
        end
    end

    -- 2. MAIN DUNGEON BOSSES
    for _, boss in ipairs(mainBosses) do
        btnIndex = btnIndex + 1
        local btn = self:AcquireBossButton(btnIndex)
        renderBossButton(btn, boss, currentY)
        currentY = currentY - (bookCfg.BOSS_BTN_HEIGHT + bookCfg.BOSS_BTN_GAP)
    end

    -- 3. RARE ENCOUNTERS
    if #rareBosses > 0 then
        local rareY = currentY - 14
        if self.rareHeader then
            self.rareHeader:ClearAllPoints()
            self.rareHeader:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, rareY)
            self.rareHeader:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, rareY)
            if self.rareHeader.title then
                self.rareHeader.title:SetText("Rare Encounters")
            end
            self.rareHeader:Show()
        end
        currentY = rareY - 44

        for _, boss in ipairs(rareBosses) do
            btnIndex = btnIndex + 1
            local btn = self:AcquireBossButton(btnIndex)
            renderBossButton(btn, boss, currentY)
            currentY = currentY - (bookCfg.BOSS_BTN_HEIGHT + bookCfg.BOSS_BTN_GAP)
        end
    else
        if self.rareHeader then
            self.rareHeader:Hide()
        end
    end

    -- 4. MINOR & QUEST ENCOUNTERS
    if #minorBosses > 0 then
        local minorY = currentY - 14
        if self.minorHeader then
            self.minorHeader:ClearAllPoints()
            self.minorHeader:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, minorY)
            self.minorHeader:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, minorY)
            if self.minorHeader.title then
                self.minorHeader.title:SetText("Minor & Quest Encounters")
            end
            self.minorHeader:Show()
        end
        currentY = minorY - 44

        for _, boss in ipairs(minorBosses) do
            btnIndex = btnIndex + 1
            local btn = self:AcquireBossButton(btnIndex)
            renderBossButton(btn, boss, currentY)
            currentY = currentY - (bookCfg.BOSS_BTN_HEIGHT + bookCfg.BOSS_BTN_GAP)
        end
    else
        if self.minorHeader then
            self.minorHeader:Hide()
        end
        if self.selectedBoss and (self.selectedBoss.isMinor or self.selectedBoss.classification == "minor" or self.selectedBoss.classification == "quest") and not showMinor then
            self.selectedBoss = nil
        end
    end

    -- 5. DUNGEON SET CHALLENGES (Tier 0.5)
    if #challengeBosses > 0 then
        local chY = currentY - 14
        if self.challengeHeader then
            self.challengeHeader:ClearAllPoints()
            self.challengeHeader:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, chY)
            self.challengeHeader:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, chY)
            if self.challengeHeader.title then
                self.challengeHeader.title:SetText("Dungeon Set Challenges (Tier 0.5)")
            end
            self.challengeHeader:Show()
        end
        currentY = chY - 44

        for _, boss in ipairs(challengeBosses) do
            btnIndex = btnIndex + 1
            local btn = self:AcquireBossButton(btnIndex)
            renderBossButton(btn, boss, currentY)
            currentY = currentY - (bookCfg.BOSS_BTN_HEIGHT + bookCfg.BOSS_BTN_GAP)
        end
    else
        if self.challengeHeader then
            self.challengeHeader:Hide()
        end
        if self.selectedBoss and self.selectedBoss.isChallenge and not showDungeonSetChallenges then
            self.selectedBoss = nil
        end
    end

    -- 6. ZONE DROPS AT THE BOTTOM
    if hasZoneDrops then
        local dividerY = currentY
        if self.trashDivider then
            self.trashDivider:ClearAllPoints()
            self.trashDivider:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, dividerY)
            self.trashDivider:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, dividerY)
            self.trashDivider:Show()
        end

        btnIndex = btnIndex + 1
        local zoneBtn = self:AcquireBossButton(btnIndex)

        local zoneY = dividerY - 30
        renderBossButton(zoneBtn, self.zoneBossEntry, zoneY)
        if zoneBtn.levelText then
            if showBossLevel then
                zoneBtn.levelText:SetText("Zone")
                zoneBtn.levelText:SetTextColor(0.80, 0.72, 0.55)
                zoneBtn.levelText:Show()
            else
                zoneBtn.levelText:Hide()
            end
        end

        local totalH = -(zoneY - bookCfg.BOSS_BTN_HEIGHT - 6) + 16
        self.bossScrollChild:SetHeight(math.max(1, totalH))
        SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, totalH)
    else
        if self.trashDivider then
            self.trashDivider:Hide()
        end
        if self.selectedBoss and (self.selectedBoss.isZone or self.selectedBoss.isTrash) then
            self.selectedBoss = nil
        end
        local totalH = (btnIndex > 0) and (-currentY + 10) or 1
        self.bossScrollChild:SetHeight(math.max(1, totalH))
        SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, totalH)
    end

    if self.noEncountersText then
        if btnIndex == 0 and not hasZoneDrops and q ~= "" then
            self.noEncountersText:SetText(string.format("No encounters or items matching\n|cffffd200\"%s\"|r", self.searchQuery or ""))
            self.noEncountersText:Show()
            self.bossScrollChild:SetHeight(120)
            SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, 120)
        else
            self.noEncountersText:Hide()
        end
    end
end

local ITEM_CATEGORIES = {
    { id = "EQUIPMENT", title = "Equipment" },
    { id = "RECIPE", title = "Recipes" },
    { id = "QUEST", title = "Quest Items & Keys" },
    { id = "COLLECTIBLE", title = "Collectibles" },
    { id = "MISC", title = "Other" },
}

--- Shared categorized item drop renderer supporting both Single-Boss Loot and Full-Dungeon Loot.
--- @param entries table Array of `{ itemID = number, sourceBossName = string|nil }`
--- @param filterByItem boolean
--- @param parsedQuery table|nil
--- @param q string
--- @param emptyText string
function DungeonBookView:RenderCategorizedDropEntries(entries, filterByItem, parsedQuery, q, emptyText)
    for _, hdr in ipairs(self.categoryHeaderPool) do hdr:Hide() end
    for _, row in ipairs(self.itemRowPool) do row:Hide() end
    for _, btn in ipairs(self.questButtonPool) do btn:Hide() end

    if not entries or #entries == 0 then
        self.noDropsText:SetText(emptyText or "No item drops recorded for this encounter.")
        self.noDropsText:Show()
        self.detailScrollChild:SetHeight(60)
        ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.detailScroll, 60)
        return
    end

    self.noDropsText:Hide()

    local grouped = {
        EQUIPMENT = {},
        RECIPE = {},
        QUEST = {},
        COLLECTIBLE = {},
        MISC = {},
    }

    for _, entry in ipairs(entries) do
        local itemID = entry.itemID
        local itemName, itemLink, itemQuality, _, _, itemType, itemSubType, _, itemEquipLoc, itemTexture, _, classID, subclassID = safeGetItemInfo(itemID)
        local items = itemStore()

        -- Fallback and async cache loading for items not yet in local client cache
        if not itemName or itemName == "" then
            if C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
            local getInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
            if getInstant then
                local _, instType, instSubType, instEquipLoc, instIcon, instClassID, instSubclassID = getInstant(itemID)
                itemType = itemType or instType
                itemSubType = itemSubType or instSubType
                itemEquipLoc = itemEquipLoc or instEquipLoc
                itemTexture = itemTexture or instIcon
                classID = classID or instClassID
                subclassID = subclassID or instSubclassID
            end
            local cachedName = items and items:GetLabel(itemID)
            if cachedName and cachedName ~= "" then
                itemName = cachedName
            end
        end

        local displayName = (itemName and itemName ~= "") and itemName or ("Item #" .. tostring(itemID))
        local matchesQuery = true
        if filterByItem then
            matchesQuery = Search:ItemMatches(itemID, parsedQuery or q)
            if not matchesQuery and entry.sourceBossName and q ~= "" then
                matchesQuery = strfind(strlower(entry.sourceBossName), q, 1, true) ~= nil
            end
        end

        if matchesQuery then
            local cat = (items and items:GetCategory(itemID)) or "MISC"
            local isGreyEquipment = (cat == "EQUIPMENT" and (itemQuality == 0 or itemQuality == "0"))
            if not isGreyEquipment then
                local itemData = {
                    id = itemID,
                    name = displayName,
                    link = itemLink or ("item:" .. tostring(itemID)),
                    quality = itemQuality or 1,
                    itemType = itemType,
                    itemSubType = itemSubType,
                    subType = items and items:GetTypeLabel(itemID),
                    equipLoc = itemEquipLoc,
                    texture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
                    classID = classID,
                    subclassID = subclassID,
                    sourceBossName = entry.sourceBossName,
                }
                grouped[cat][#grouped[cat] + 1] = itemData
            end
        end
    end

    local currentY = 0
    local hdrIdx = 0
    local rowIdx = 0
    local rowGap = 4

    for _, catDef in ipairs(ITEM_CATEGORIES) do
        local items = grouped[catDef.id]
        if items and #items > 0 then
            hdrIdx = hdrIdx + 1
            local hdr = self:AcquireCategoryHeader(hdrIdx)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", self.detailScrollChild, "TOPLEFT", 4, currentY)
            hdr:SetPoint("TOPRIGHT", self.detailScrollChild, "TOPRIGHT", -4, currentY)
            hdr.title:SetText(string.format("%s (%d)", catDef.title, #items))
            hdr:Show()

            currentY = currentY - 26

            for _, item in ipairs(items) do
                rowIdx = rowIdx + 1
                local row = self:AcquireItemRow(rowIdx)
                local hasBossSubtitle = (item.sourceBossName ~= nil and item.sourceBossName ~= "")
                local rowH = hasBossSubtitle and 48 or 36
                row:SetHeight(rowH)

                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.detailScrollChild, "TOPLEFT", 4, currentY)
                row:SetPoint("TOPRIGHT", self.detailScrollChild, "TOPRIGHT", -4, currentY)

                row.itemID = item.id
                row.itemLink = item.link

                row.icon:ClearAllPoints()
                if hasBossSubtitle then
                    row.icon:SetSize(34, 34)
                    row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
                else
                    row.icon:SetSize(32, 32)
                    row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
                end
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

                local r, g, b = safeGetItemQualityColor(item.quality)
                row:SetBorderColor(r, g, b, 1.0)

                row.nameText:ClearAllPoints()
                row.subLeftText:ClearAllPoints()
                row.subRightText:ClearAllPoints()

                if hasBossSubtitle then
                    row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -3)
                    row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    row.subLeftText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -18)
                    row.subRightText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -18)
                    if row.bossSourceText then
                        row.bossSourceText:ClearAllPoints()
                        row.bossSourceText:SetPoint("TOPLEFT", row, "TOPLEFT", 44, -32)
                        row.bossSourceText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                        row.bossSourceText:SetText(item.sourceBossName)
                        row.bossSourceText:Show()
                    end
                else
                    row.nameText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
                    row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    row.subLeftText:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
                    row.subRightText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 3)
                    if row.bossSourceText then
                        row.bossSourceText:Hide()
                    end
                end

                row.nameText:SetText(item.name or ("Item #" .. tostring(item.id)))
                row.nameText:SetTextColor(r, g, b)

                if catDef.id == "EQUIPMENT" then
                    local slotName = item.equipLoc and _G[item.equipLoc] or item.itemType or ""
                    if item.equipLoc == "INVTYPE_HOLDABLE" then
                        slotName = "Off-hand"
                    end
                    row.subLeftText:SetText(slotName)

                    local subType = item.subType or ""
                    local isUniversalSlot = (item.equipLoc == "INVTYPE_NECK"
                        or item.equipLoc == "INVTYPE_FINGER"
                        or item.equipLoc == "INVTYPE_TRINKET"
                        or item.equipLoc == "INVTYPE_CLOAK"
                        or item.equipLoc == "INVTYPE_HOLDABLE"
                        or item.equipLoc == "INVTYPE_BODY"
                        or item.equipLoc == "INVTYPE_TABARD")

                    if isUniversalSlot or subType == "Miscellaneous" or subType == "Junk" then
                        row.subRightText:SetText("")
                    else
                        row.subRightText:SetText(subType)
                        local itemData = itemStore()
                        local isUsable = not itemData or itemData:IsUsableByPlayer(item.id)
                        if not isUsable then
                            row.subRightText:SetTextColor(0.90, 0.20, 0.20)
                        else
                            row.subRightText:SetTextColor(0.75, 0.70, 0.60)
                        end
                    end
                elseif catDef.id == "RECIPE" then
                    row.subLeftText:SetText(item.itemSubType or "Recipe")
                    row.subRightText:SetText("")
                elseif catDef.id == "QUEST" then
                    local sub = item.itemSubType or "Quest"
                    if sub == "Miscellaneous" or sub == "Junk" or sub == "Armor" or sub == "" then
                        sub = "Quest"
                    end
                    row.subLeftText:SetText(sub)
                    row.subRightText:SetText("")
                elseif catDef.id == "COLLECTIBLE" then
                    local label = (item.equipLoc == "INVTYPE_TABARD" and (_G.INVTYPE_TABARD or "Tabard")) or item.itemSubType or "Collectible"
                    if label == "Miscellaneous" or label == "Junk" then
                        label = "Collectible"
                    end
                    row.subLeftText:SetText(label)
                    row.subRightText:SetText("")
                else
                    local subLabel = item.itemSubType or item.itemType or "Other"
                    if subLabel == "Miscellaneous" or subLabel == "Junk" then
                        subLabel = "Other"
                    end
                    row.subLeftText:SetText(subLabel)
                    row.subRightText:SetText("")
                end

                row:Show()
                currentY = currentY - (rowH + rowGap)
            end

            currentY = currentY - 6
        end
    end

    if hdrIdx == 0 then
        if filterByItem then
            self.noDropsText:SetText(string.format("No drops matching \"%s\".", self.searchQuery or ""))
        else
            self.noDropsText:SetText(emptyText or "No item drops recorded for this encounter.")
        end
        self.noDropsText:Show()
        self.detailScrollChild:SetHeight(60)
        ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.detailScroll, 60)
        return
    end

    local totalContentH = -currentY + 12
    self.detailScrollChild:SetHeight(math.max(1, totalContentH))
    ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.detailScroll, totalContentH)
end

--- Groups, formats, and renders categorized item drop rows for a single selected boss.
--- @param d table
--- @param boss table
function DungeonBookView:RenderItemDrops(d, boss)
    local dropIDs = boss.itemIDs or {}

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""
    local parsedQuery = (q ~= "") and Search:Parse(q) or nil
    local isMultiConstraint = Search:IsMultiConstraint(parsedQuery)
    local bossNameMatches = (not isMultiConstraint) and (boss.name and strfind(strlower(boss.name), q, 1, true))
    local filterByItem = (q ~= "" and not bossNameMatches)

    local entries = {}
    for _, itemID in ipairs(dropIDs) do
        entries[#entries + 1] = {
            itemID = itemID,
            sourceBossName = nil,
        }
    end

    self:RenderCategorizedDropEntries(entries, filterByItem, parsedQuery, q, "No item drops recorded for this encounter.")
end

--- Collects and renders every item drop across the entire dungeon (`d`), categorized in
--- standard encounter order (`Equipment` -> `Recipes` -> `Quest Items` -> `Collectibles` -> `Other`),
--- with the source Boss Name (or `"Zone Drops"`) displayed directly under each item.
--- @param d table
function DungeonBookView:RenderDungeonItemDrops(d)
    local showMinor = true
    local showEventBosses = "holiday"
    local showDungeonSetChallenges = false
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showMinor = _G.JournalBase:GetDungeonSetting("showMinorMonsters", true) == true
        showEventBosses = _G.JournalBase:GetDungeonSetting("showEventBosses", "holiday")
        showDungeonSetChallenges = _G.JournalBase:GetDungeonSetting("showDungeonSetChallenges", false) == true
    end

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""
    local parsedQuery = (q ~= "") and Search:Parse(q) or nil
    local isSearching = (q ~= "")

    local eventBosses = {}
    local mainBosses = {}
    local rareBosses = {}
    local minorBosses = {}
    local challengeBosses = {}

    for _, boss in ipairs(Access:GetBosses(d)) do
        if boss.isEvent then
            local shouldShow = true
            local holidayMgr = ns.HolidayManager or (_G.JournalBase and _G.JournalBase.HolidayManager)
            if holidayMgr and holidayMgr.ShouldShowEventBoss then
                shouldShow = holidayMgr:ShouldShowEventBoss(boss, showEventBosses)
            else
                shouldShow = (showEventBosses == "always") or (showEventBosses == true)
            end
            if shouldShow or isSearching then
                eventBosses[#eventBosses + 1] = boss
            end
        elseif boss.isChallenge then
            if showDungeonSetChallenges or isSearching then
                challengeBosses[#challengeBosses + 1] = boss
            end
        else
            local isRare = (boss.rare == true) or (boss.isRare == true) or (boss.classification == "rare") or (boss.classification == "rareelite")
            local isMinor = (boss.isMinor == true) or (boss.classification == "minor") or (boss.classification == "quest")
            if isRare then
                rareBosses[#rareBosses + 1] = boss
            elseif isMinor then
                if showMinor or isSearching then
                    minorBosses[#minorBosses + 1] = boss
                end
            else
                mainBosses[#mainBosses + 1] = boss
            end
        end
    end

    local orderedSources = {}
    for _, list in ipairs({ eventBosses, mainBosses, rareBosses, minorBosses, challengeBosses }) do
        for _, b in ipairs(list) do
            orderedSources[#orderedSources + 1] = { label = b.name, itemIDs = b.itemIDs }
        end
    end
    orderedSources[#orderedSources + 1] = { label = "Zone Drops", itemIDs = d.zoneItemIDs }

    local entries = {}
    local entryByItemID = {}

    for _, src in ipairs(orderedSources) do
        local dropIDs = src.itemIDs or {}
        for _, itemID in ipairs(dropIDs) do
            local existing = entryByItemID[itemID]
            if not existing then
                local newEntry = {
                    itemID = itemID,
                    sourceBossName = src.label,
                    _seenBosses = { [src.label] = true },
                }
                entryByItemID[itemID] = newEntry
                entries[#entries + 1] = newEntry
            elseif not existing._seenBosses[src.label] then
                existing._seenBosses[src.label] = true
                existing.sourceBossName = existing.sourceBossName .. ", " .. src.label
            end
        end
    end

    self:RenderCategorizedDropEntries(entries, isSearching, parsedQuery, q, "No item drops recorded for this dungeon.")
end

--- Renders all available quests for the dungeon inside `bossScrollChild` on the Left Page.
--- Buttons are styled identically to boss buttons (metallic beveled border + drop shadow),
--- with `Interface\AchievementFrame\UI-Achievement-Parchment-Horizontal-Desaturated` fill,
--- QuestNormal icon on left, gold quest title, and player-level relative difficulty colored level badge.
--- Spaced generously matching the boss buttons.
--- @param d table
function DungeonBookView:RenderDungeonQuests(d)
    for _, btn in ipairs(self.questButtonPool) do btn:Hide() end
    if self.questFactionDivider then self.questFactionDivider:Hide() end

    if not d then return end

    local questDb = QuestAccess
    local playerFaction = UnitFactionGroup("player") or "Both"
    local _, playerClass = UnitClass("player")

    local showBoth = parent.Settings:IsBothFactionQuestsShown()

    local topQuests = {}
    local bottomQuests = {}

    if showBoth then
        local allQuests = (questDb and questDb:GetDungeonQuests(d, "All", playerClass)) or {}
        for _, q in ipairs(allQuests) do
            local qFaction = q.faction or "Both"
            if qFaction == "Both" or qFaction == playerFaction then
                topQuests[#topQuests + 1] = q
            else
                bottomQuests[#bottomQuests + 1] = q
            end
        end
    else
        topQuests = (questDb and questDb:GetDungeonQuests(d, playerFaction, playerClass)) or {}
    end

    if #topQuests == 0 and #bottomQuests == 0 then
        self.selectedQuest = nil
        if self.noEncountersText then
            self.noEncountersText:SetText("No quests available for this dungeon.")
            self.noEncountersText:Show()
        end
        self.bossScrollChild:SetHeight(120)
        ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, 120)
        return
    end

    if self.noEncountersText then
        self.noEncountersText:Hide()
    end

    local currentY = -16
    local bookCfg = Constants.BOOK
    local btnWidth = bookCfg.BOSS_BTN_WIDTH or 268
    local btnHeight = bookCfg.BOSS_BTN_HEIGHT or 44
    local gap = 26 -- generous spacing matching boss buttons

    local hasSelected = false
    if self.selectedQuest then
        for _, q in ipairs(topQuests) do
            if q.id == self.selectedQuest.id then
                hasSelected = true
                self.selectedQuest = q
                break
            end
        end
        if not hasSelected then
            for _, q in ipairs(bottomQuests) do
                if q.id == self.selectedQuest.id then
                    hasSelected = true
                    self.selectedQuest = q
                    break
                end
            end
        end
    end
    if not hasSelected then
        self.selectedQuest = topQuests[1] or bottomQuests[1]
    end

    local buttonIndex = 1
    local function renderQuestButton(q)
        local btn = self:AcquireQuestButton(buttonIndex)
        buttonIndex = buttonIndex + 1
        btn.quest = q
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 18, currentY)
        btn:SetSize(btnWidth + 8, btnHeight)

        btn.nameText:SetText(q.name or "Unknown Quest")

        local qLevel = (q.reqLevel and q.reqLevel > 0 and q.reqLevel) or q.questLevel or q.level or 0
        btn.levelText:SetText("Lv " .. tostring(qLevel))
        local r, g, b = GetDifficultyColor(qLevel)
        btn.levelText:SetTextColor(r, g, b)

        -- 1. Check if quest is part of a multi-step chain -> show chain badge underneath '!'
        local fullChain = questDb and questDb.GetFullChain and questDb:GetFullChain(q.id)
        local isChain = (fullChain and #fullChain > 1) or q.isChain
        if btn.chainBadge then
            btn.chainBadge:SetShown(isChain == true)
        end

        -- 2. Check completion & log status:
        --    Completed -> green checkmark
        --    Active in quest log -> grey incomplete question mark (?)
        --    Available -> yellow exclamation mark (!)
        local isCompleted = questDb and questDb:IsQuestCompleted(q.id)
        local isActive = questDb and questDb:IsQuestActive(q.id)
        if not isActive and fullChain then
            for _, step in ipairs(fullChain) do
                if questDb:IsQuestActive(step.id) then
                    isActive = true
                    break
                end
            end
        end

        if isCompleted then
            btn.qIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            btn.qIcon:SetSize(20, 20)
            btn.qIcon:SetTexCoord(0, 1, 0, 1)
            if btn.qIcon.SetDesaturated then
                btn.qIcon:SetDesaturated(false)
            end
            btn.qIcon:SetVertexColor(1.0, 1.0, 1.0)
        elseif isActive then
            btn.qIcon:SetSize(24, 24)
            local setOk = false
            if btn.qIcon.SetAtlas then
                local ok = pcall(function()
                    btn.qIcon:SetAtlas("QuestTurnin")
                    if btn.qIcon.SetDesaturated then
                        btn.qIcon:SetDesaturated(true)
                    end
                    btn.qIcon:SetVertexColor(0.85, 0.85, 0.85)
                end)
                setOk = ok
            end
            if not setOk then
                btn.qIcon:SetTexture("Interface\\GossipFrame\\IncompleteQuestIcon")
                btn.qIcon:SetTexCoord(0, 1, 0, 1)
                if btn.qIcon.SetDesaturated then
                    btn.qIcon:SetDesaturated(false)
                end
                btn.qIcon:SetVertexColor(1.0, 1.0, 1.0)
            end
        else
            btn.qIcon:SetSize(24, 24)
            if btn.qIcon.SetDesaturated then
                btn.qIcon:SetDesaturated(false)
            end
            btn.qIcon:SetVertexColor(1.0, 1.0, 1.0)
            if btn.qIcon.SetAtlas then
                local ok = pcall(btn.qIcon.SetAtlas, btn.qIcon, "QuestNormal")
                if not ok then
                    btn.qIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    btn.qIcon:SetTexCoord(0, 1, 0, 1)
                end
            else
                btn.qIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                btn.qIcon:SetTexCoord(0, 1, 0, 1)
            end
        end

        local isSelected = (self.selectedQuest and self.selectedQuest.id == q.id)
        if btn.selectedGlow then
            btn.selectedGlow:SetShown(isSelected)
        end
        if btn._baseRim then
            if isSelected then
                btn._baseRim:SetVertexColor(0.85, 0.65, 0.20, 1.0)
            else
                btn._baseRim:SetVertexColor(0.12, 0.09, 0.06, 0.95)
            end
        end
        if btn._fill then
            if isSelected then
                btn._fill:SetVertexColor(1.0, 0.96, 0.85, 1.0)
            else
                btn._fill:SetVertexColor(0.88, 0.86, 0.82, 0.95)
            end
        end
        if btn.nameText then
            if isSelected then
                btn.nameText:SetTextColor(1.0, 0.94, 0.50)
            else
                btn.nameText:SetTextColor(1.0, 0.82, 0.0)
            end
        end

        btn:Show()
        currentY = currentY - (btnHeight + gap)
    end

    for _, q in ipairs(topQuests) do
        renderQuestButton(q)
    end

    if #bottomQuests > 0 then
        if #topQuests > 0 then
            local divY = currentY + 13
            if self.questFactionDivider then
                self.questFactionDivider:ClearAllPoints()
                self.questFactionDivider:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, divY)
                self.questFactionDivider:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, divY)
                self.questFactionDivider:Show()
            end
            currentY = divY - 20
        else
            if self.questFactionDivider then
                self.questFactionDivider:Hide()
            end
        end

        for _, q in ipairs(bottomQuests) do
            renderQuestButton(q)
        end
    else
        if self.questFactionDivider then
            self.questFactionDivider:Hide()
        end
    end

    local totalH = -currentY + 16
    self.bossScrollChild:SetHeight(math.max(1, totalH))
    ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.bossScroll, totalH)
end

function DungeonBookView:CreateAccordionBanner(parent)
    local white = Constants.ASSETS.WHITE_8X8
    local banner = CreateFrame("Button", nil, parent)
    banner:SetHeight(30)

    -- 1. Outer subtle drop shadow (matching quest buttons)
    local shadow = banner:CreateTexture(nil, "BACKGROUND", nil, -5)
    shadow:SetPoint("TOPLEFT", banner, "TOPLEFT", -1, 1)
    shadow:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 1, -1)
    shadow:SetTexture(white)
    shadow:SetVertexColor(0.02, 0.02, 0.01, 0.60)
    banner._dropShadow = shadow

    -- 2. Base dark rim (1px border)
    local baseRim = banner:CreateTexture(nil, "BACKGROUND", nil, -4)
    baseRim:SetAllPoints(banner)
    baseRim:SetTexture(white)
    baseRim:SetVertexColor(0.12, 0.09, 0.06, 0.95)
    banner._baseRim = baseRim

    -- 3. Textured Desaturated Achievement Parchment fill
    local fill = banner:CreateTexture(nil, "BACKGROUND", nil, -3)
    fill:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -1, 1)
    fill:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal-Desaturated")
    fill:SetVertexColor(0.88, 0.86, 0.82, 0.95)
    banner._fill = fill

    -- 4. Subtle top/left highlights and bottom/right shadows for embossed 3D feel
    local topHi = banner:CreateTexture(nil, "BACKGROUND", nil, -2)
    topHi:SetHeight(1)
    topHi:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
    topHi:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -1, -1)
    topHi:SetTexture(white)
    topHi:SetVertexColor(0.56, 0.44, 0.26, 0.70)

    local leftHi = banner:CreateTexture(nil, "BACKGROUND", nil, -2)
    leftHi:SetWidth(1)
    leftHi:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
    leftHi:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 1, 1)
    leftHi:SetTexture(white)
    leftHi:SetVertexColor(0.48, 0.38, 0.22, 0.60)

    local botSh = banner:CreateTexture(nil, "BACKGROUND", nil, -2)
    botSh:SetHeight(1)
    botSh:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 1, 1)
    botSh:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -1, 1)
    botSh:SetTexture(white)
    botSh:SetVertexColor(0.04, 0.03, 0.02, 0.95)

    local rightSh = banner:CreateTexture(nil, "BACKGROUND", nil, -2)
    rightSh:SetWidth(1)
    rightSh:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -1, -1)
    rightSh:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -1, 1)
    rightSh:SetTexture(white)
    rightSh:SetVertexColor(0.04, 0.03, 0.02, 0.95)

    -- Subtle 1px inset hover highlight matching quest button treatment
    local hl = banner:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", banner, "TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -1, 1)
    hl:SetTexture(white)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.95, 0.80, 0.35, 0.18)

    local statusIcon = banner:CreateTexture(nil, "ARTWORK")
    statusIcon:SetSize(18, 18)
    statusIcon:SetPoint("LEFT", banner, "LEFT", 8, 0)
    banner.statusIcon = statusIcon

    local arrowText = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrowText:SetPoint("RIGHT", banner, "RIGHT", -10, 0)
    arrowText:SetTextColor(0.85, 0.75, 0.50)
    arrowText:SetShadowColor(0, 0, 0, 1.0)
    arrowText:SetShadowOffset(1, -1)
    banner.arrowText = arrowText

    local levelText = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelText:SetPoint("RIGHT", arrowText, "LEFT", -10, 0)
    levelText:SetShadowColor(0, 0, 0, 1.0)
    levelText:SetShadowOffset(1, -1)
    banner.levelText = levelText

    local titleText = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("LEFT", statusIcon, "RIGHT", 8, 0)
    titleText:SetPoint("RIGHT", levelText, "LEFT", -8, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(false)
    titleText:SetShadowColor(0, 0, 0, 1.0)
    titleText:SetShadowOffset(1, -1)
    banner.titleText = titleText

    return banner
end

function DungeonBookView:CreateQuestItemRewardButton(parent)
    local white = Constants.ASSETS.WHITE_8X8
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(36)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetTexture(white)
    bg:SetVertexColor(0.08, 0.07, 0.06, 0.55)
    row.bg = bg

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetTexture(white)
    hl:SetVertexColor(1.0, 0.90, 0.65, 0.10)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local bTop = row:CreateTexture(nil, "OVERLAY")
    bTop:SetHeight(1)
    bTop:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    bTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 1)
    bTop:SetTexture(white)

    local bBottom = row:CreateTexture(nil, "OVERLAY")
    bBottom:SetHeight(1)
    bBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, -1)
    bBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    bBottom:SetTexture(white)

    local bLeft = row:CreateTexture(nil, "OVERLAY")
    bLeft:SetWidth(1)
    bLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 0)
    bLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -1, 0)
    bLeft:SetTexture(white)

    local bRight = row:CreateTexture(nil, "OVERLAY")
    bRight:SetWidth(1)
    bRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, 0)
    bRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, 0)
    bRight:SetTexture(white)

    function row:SetBorderColor(r, g, b, a)
        local alpha = a or 1.0
        bTop:SetVertexColor(r, g, b, alpha)
        bBottom:SetVertexColor(r, g, b, alpha)
        bLeft:SetVertexColor(r, g, b, alpha)
        bRight:SetVertexColor(r, g, b, alpha)
    end

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
    nameText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    nameText:SetHeight(14)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    if nameText.SetMaxLines then pcall(nameText.SetMaxLines, nameText, 1) end
    row.nameText = nameText

    local subText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
    subText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    subText:SetHeight(12)
    subText:SetJustifyH("LEFT")
    subText:SetWordWrap(false)
    if subText.SetMaxLines then pcall(subText.SetMaxLines, subText, 1) end
    row.subText = subText

    row.UpdateTooltip = ShowItemRowTooltip
    row:SetScript("OnEnter", ShowItemRowTooltip)
    row:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    row:SetScript("OnClick", function(self)
        if not self.itemLink then return end
        local isShift = (_G.IsShiftKeyDown and _G.IsShiftKeyDown())
        local isCtrl = (_G.IsControlKeyDown and _G.IsControlKeyDown())
        if isShift then
            local insertLink = _G.ChatEdit_InsertLink
            if insertLink then insertLink(self.itemLink) end
        elseif isCtrl then
            local dressUp = _G.DressUpItemLink or _G.DressUpLink
            if dressUp then dressUp(self.itemLink) end
        end
    end)

    return row
end

function DungeonBookView:SetupQuestRewardButton(row, itemID)
    row.itemID = itemID
    row.itemLink = nil

    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = safeGetItemInfo(itemID)
    local items = itemStore()

    if not itemName or itemName == "" then
        if C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
        local getInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
        if getInstant then
            local _, _, _, _, instIcon = getInstant(itemID)
            itemTexture = itemTexture or instIcon
        end
        local cachedName = items and items:GetLabel(itemID)
        if cachedName and cachedName ~= "" then
            itemName = cachedName
        end
    end

    if itemName and itemName ~= "" then
        row.itemLink = itemLink
        row.nameText:SetText(itemName)
        local r, g, b = safeGetItemQualityColor(itemQuality or 1)
        row.nameText:SetTextColor(r, g, b)
        row:SetBorderColor(r, g, b, 0.85)
        row.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

        row.subText:SetText(items and items:GetTypeLabel(itemID) or "")
    else
        row.nameText:SetText("Item #" .. tostring(itemID))
        row.nameText:SetTextColor(0.8, 0.8, 0.8)
        row:SetBorderColor(0.4, 0.4, 0.4, 0.7)
        row.icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.subText:SetText("Loading...")
    end
end

--- Sets a Blizzard map pin/waypoint at the specified coordinates and opens the World Map.
--- @param mapID number UiMapID
--- @param x number X coordinate (0.0 to 1.0 or 0 to 100)
--- @param y number Y coordinate (0.0 to 1.0 or 0 to 100)
--- @param label string Optional target label
function DungeonBookView:PinCoordinatesToMap(mapID, x, y, label)
    if not mapID or not x or not y then return end

    local normX = (x > 1.0) and (x / 100.0) or x
    local normY = (y > 1.0) and (y / 100.0) or y

    -- 1. Blizzard Map Pin System
    if _G.UiMapPoint and _G.UiMapPoint.CreateFromCoordinates and _G.C_Map and _G.C_Map.SetUserWaypoint then
        pcall(function()
            if _G.C_Map.ClearUserWaypoint then
                _G.C_Map.ClearUserWaypoint()
            end
            if not _G.C_Map.CanSetUserWaypointOnMap or _G.C_Map.CanSetUserWaypointOnMap(mapID) then
                local point = _G.UiMapPoint.CreateFromCoordinates(mapID, normX, normY)
                _G.C_Map.SetUserWaypoint(point)
                if _G.C_SuperTrack and _G.C_SuperTrack.SetSuperTrackedUserWaypoint then
                    _G.C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                end
            end
        end)
    end

    -- 2. Open World Map and navigate to mapID
    if _G.OpenWorldMap then
        pcall(_G.OpenWorldMap, mapID)
    elseif _G.ToggleWorldMap then
        if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then
            _G.ToggleWorldMap()
        end
    elseif _G.ShowUIPanel and _G.WorldMapFrame then
        _G.ShowUIPanel(_G.WorldMapFrame)
    elseif _G.WorldMapFrame then
        _G.WorldMapFrame:Show()
    end

    if mapID and _G.WorldMapFrame and _G.WorldMapFrame.SetMapID then
        pcall(_G.WorldMapFrame.SetMapID, _G.WorldMapFrame, mapID)
    end
end

function DungeonBookView:CreateQuestMapPinButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(36, 36)
    btn.isMapPinBtn = true
    btn:EnableMouse(true)

    if parent and parent.GetFrameLevel then
        btn:SetFrameLevel(parent:GetFrameLevel() + 25)
    end
    btn:SetHitRectInsets(-4, -4, -4, -4)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.icon = icon

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(36, 36)
    hl:SetPoint("CENTER", btn, "CENTER", 0, 0)
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(0.95, 0.80, 0.35, 0.35)
    btn.hl = hl

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnMouseDown", function(b)
        if b.isAvailable then
            if b.icon then b.icon:SetPoint("CENTER", b, "CENTER", 1, -1) end
            if b.hl then b.hl:SetPoint("CENTER", b, "CENTER", 1, -1) end
        end
    end)

    btn:SetScript("OnMouseUp", function(b)
        if b.icon then b.icon:SetPoint("CENTER", b, "CENTER", 0, 0) end
        if b.hl then b.hl:SetPoint("CENTER", b, "CENTER", 0, 0) end
    end)

    btn:SetScript("OnEnter", function(b)
        if b.isAvailable and SetCursor then
            pcall(SetCursor, "Interface\\CURSOR\\Point")
        end
        if b.isAvailable and b.icon then
            b.icon:SetVertexColor(1.0, 0.95, 0.60, 1.0)
        end
        if not GameTooltip then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        if b.isAvailable then
            GameTooltip:AddLine("Pin to map", 1.0, 0.82, 0.0)
            if b.targetLabel and b.targetLabel ~= "" then
                GameTooltip:AddLine(b.targetLabel, 1.0, 1.0, 1.0, true)
            end
            if b.coordText and b.coordText ~= "" then
                GameTooltip:AddLine(b.coordText, 0.7, 0.7, 0.7)
            end
            GameTooltip:AddLine("Click to set waypoint and open the World Map.", 0.2, 0.8, 1.0, true)
        else
            GameTooltip:AddLine("Pin unavailable", 0.75, 0.75, 0.75)
            if b.unavailableReason and b.unavailableReason ~= "" then
                GameTooltip:AddLine(b.unavailableReason, 0.6, 0.6, 0.6, true)
            end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(b)
        if ResetCursor then
            pcall(ResetCursor)
        end
        if b.isAvailable and b.icon then
            b.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    btn:SetScript("OnClick", function(b)
        if not b.isAvailable then return end
        if PlaySound then
            PlaySound((SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or Constants.SOUNDS.CLICK)
        end
        if b.mapID and b.mapX and b.mapY then
            self:PinCoordinatesToMap(b.mapID, b.mapX, b.mapY, b.targetLabel)
        end
    end)

    return btn
end

function DungeonBookView:ConfigureMapPin(btn, isAvailable, mapData, fallbackLabel, unavailableReason)
    local hasCoords = (mapData ~= nil and mapData.mapID ~= nil and mapData.x ~= nil and mapData.y ~= nil)
    local canPin = (isAvailable and isAvailable ~= false) and hasCoords
    btn.isAvailable = (canPin == true)
    btn.unavailableReason = unavailableReason

    if btn.isAvailable then
        -- Active Pin: Use the non-selected pin type (Waypoint-MapPin-Untracked)
        local setOk = false
        local activeAtlas = "Waypoint-MapPin-Untracked"
        if btn.icon.SetAtlas then
            local ok = pcall(btn.icon.SetAtlas, btn.icon, activeAtlas)
            if ok and btn.icon:GetTexture() then
                setOk = true
                if btn.hl and btn.hl.SetAtlas then
                    pcall(btn.hl.SetAtlas, btn.hl, activeAtlas)
                end
            end
            if not setOk then
                activeAtlas = "Waypoint-MapPin-ChatIcon"
                ok = pcall(btn.icon.SetAtlas, btn.icon, activeAtlas)
                if ok and btn.icon:GetTexture() then
                    setOk = true
                    if btn.hl and btn.hl.SetAtlas then
                        pcall(btn.hl.SetAtlas, btn.hl, activeAtlas)
                    end
                end
            end
            if not setOk then
                activeAtlas = "Waypoint-MapPin-Tracked"
                ok = pcall(btn.icon.SetAtlas, btn.icon, activeAtlas)
                if ok and btn.icon:GetTexture() then
                    setOk = true
                    if btn.hl and btn.hl.SetAtlas then
                        pcall(btn.hl.SetAtlas, btn.hl, activeAtlas)
                    end
                end
            end
        end
        if not setOk then
            local fallbackTex = "Interface\\Minimap\\Tracking\\Quest"
            btn.icon:SetTexture(fallbackTex)
            if btn.hl then btn.hl:SetTexture(fallbackTex) end
        end

        if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
        btn.icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        if btn.hl then
            btn.hl:SetBlendMode("ADD")
            btn.hl:SetVertexColor(0.95, 0.80, 0.35, 0.35) -- Matching boss & quest button warm golden glow
            btn.hl:SetAlpha(1.0)
        end
        btn:EnableMouse(true)

        btn.mapID = mapData.mapID
        btn.mapX = mapData.x
        btn.mapY = mapData.y
        btn.targetLabel = mapData.label or mapData.targetName or fallbackLabel or "Quest Location"
        local nx = (mapData.x > 1.0) and (mapData.x / 100.0) or mapData.x
        local ny = (mapData.y > 1.0) and (mapData.y / 100.0) or mapData.y
        btn.coordText = string.format("Coordinates: %.1f, %.1f", nx * 100, ny * 100)
    else
        -- Location Unavailable Pin: Keep existing appearance (Waypoint-MapPin-Tracked desaturated grey)
        local setOk = false
        if btn.icon.SetAtlas then
            local ok = pcall(btn.icon.SetAtlas, btn.icon, "Waypoint-MapPin-Tracked")
            if ok and btn.icon:GetTexture() then
                setOk = true
            end
            if not setOk then
                ok = pcall(btn.icon.SetAtlas, btn.icon, "Waypoint-MapPin-Untracked")
                if ok and btn.icon:GetTexture() then
                    setOk = true
                end
            end
        end
        if not setOk then
            btn.icon:SetTexture("Interface\\Minimap\\Tracking\\Quest")
        end

        if btn.icon.SetDesaturated then btn.icon:SetDesaturated(true) end
        btn.icon:SetVertexColor(0.40, 0.40, 0.40, 0.50) -- Dim muted grey
        if btn.hl then btn.hl:SetAlpha(0.0) end
        btn:EnableMouse(true)

        btn.mapID = nil
        btn.mapX = nil
        btn.mapY = nil
        btn.targetLabel = nil
        btn.coordText = nil
    end
end

function DungeonBookView:RenderQuestBodyDetails(q, giverInfo, dungeon)
    if not self.questBodyChild or not q then return end
    local child = self.questBodyChild
    local contentW = (self.questBodyScroll and self.questBodyScroll:GetWidth()) or 340
    if contentW <= 20 then contentW = 340 end
    local textW = contentW - 8
    child:SetWidth(contentW)

    if self.questBodyWidgets then
        for _, w in ipairs(self.questBodyWidgets) do
            w:Hide()
        end
    end
    self.questBodyWidgets = self.questBodyWidgets or {}
    local widgetIdx = 0

    if self.questDividers then
        for _, bar in ipairs(self.questDividers) do
            bar:Hide()
        end
    end
    self.questDividers = self.questDividers or {}
    local dividerIdx = 0

    local function AcquireText(font, r, g, b, wrap, customW)
        widgetIdx = widgetIdx + 1
        local fs = self.questBodyWidgets[widgetIdx]
        if not fs or fs:GetObjectType() ~= "FontString" then
            fs = child:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
            self.questBodyWidgets[widgetIdx] = fs
        else
            fs:SetFontObject(font or "GameFontNormal")
        end
        fs:ClearAllPoints()
        fs:SetWidth(customW or textW)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(wrap ~= false)
        if font == "GameFontHighlightSmall" then
            -- Body text: ink on a light background
            WindowBackground:ColorBodyText(fs, r or 1.0, g or 1.0, b or 1.0)
        else
            fs:SetTextColor(r or 1.0, g or 1.0, b or 1.0)
            fs:SetShadowOffset(1, -1)
        end
        fs:Show()
        return fs
    end

    local function AcquireItemButton()
        widgetIdx = widgetIdx + 1
        local btn = self.questBodyWidgets[widgetIdx]
        if not btn or btn:GetObjectType() ~= "Button" or btn.isAccordionBanner or btn.isMapPinBtn then
            btn = self:CreateQuestItemRewardButton(child)
            self.questBodyWidgets[widgetIdx] = btn
        end
        btn:ClearAllPoints()
        btn:Show()
        return btn
    end

    local function AcquireAccordionBanner()
        widgetIdx = widgetIdx + 1
        local btn = self.questBodyWidgets[widgetIdx]
        if not btn or btn:GetObjectType() ~= "Button" or not btn.isAccordionBanner then
            btn = self:CreateAccordionBanner(child)
            btn.isAccordionBanner = true
            self.questBodyWidgets[widgetIdx] = btn
        end
        btn:ClearAllPoints()
        btn:Show()
        return btn
    end

    local function AcquireMapPinButton()
        widgetIdx = widgetIdx + 1
        local btn = self.questBodyWidgets[widgetIdx]
        if not btn or btn:GetObjectType() ~= "Button" or not btn.isMapPinBtn then
            btn = self:CreateQuestMapPinButton(child)
            btn.isMapPinBtn = true
            self.questBodyWidgets[widgetIdx] = btn
        end
        btn:ClearAllPoints()
        btn:SetSize(36, 36)
        if btn.icon then
            btn.icon:SetSize(36, 36)
        end
        if child and child.GetFrameLevel then
            btn:SetFrameLevel(child:GetFrameLevel() + 25)
        end
        btn:EnableMouse(true)
        btn:Show()
        return btn
    end

    local function AcquireDividerBar()
        dividerIdx = dividerIdx + 1
        local bar = self.questDividers[dividerIdx]
        if not bar then
            local SharedWidgets = ns.UI.SharedWidgets
            bar = SharedWidgets:CreateHorizontalDividerBar(child, 4)
            bar.isDividerBar = true
            self.questDividers[dividerIdx] = bar
        end
        bar:ClearAllPoints()
        bar:SetHeight(4)
        bar:Show()
        return bar
    end

    local function RenderItemGrid(items, startX, startY, gridW, isChoice)
        if not items or #items == 0 then return startY end

        local subHdr = AcquireText("GameFontDisableSmall", 0.75, 0.70, 0.60, false, gridW)
        subHdr:SetPoint("TOPLEFT", child, "TOPLEFT", startX, startY)
        subHdr:SetText(isChoice and "Choose one of the following rewards:" or "You will also receive:")
        local curY = startY - 16

        local colGap = 8
        local itemW = math.floor((gridW - colGap) / 2)
        local itemH = 36

        for i, itemID in ipairs(items) do
            local col = (i - 1) % 2
            local rowIdx = math.floor((i - 1) / 2)
            local x = startX + (col * (itemW + colGap))
            local y = curY - (rowIdx * (itemH + 4))

            local row = AcquireItemButton()
            row:SetSize(itemW, itemH)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
            self:SetupQuestRewardButton(row, itemID)
        end

        local numRows = math.ceil(#items / 2)
        return curY - (numRows * (itemH + 4)) - 8
    end

    local curY = -4
    local questDb = QuestAccess
    local fullChain = (questDb and questDb.GetFullChain and questDb:GetFullChain(q.id))

    -- ========================================================================
    -- BRANCH A: MULTI-STEP QUEST CHAIN ACCORDION
    -- ========================================================================
    if fullChain and #fullChain > 1 then
        -- Initialize open state: earliest incomplete step is opened by default
        if self.accordionOpenQuestId ~= q.id then
            self.accordionOpenQuestId = q.id
            self.accordionOpenState = {}
            local defaultOpened = false
            for _, step in ipairs(fullChain) do
                if not step.isCompleted then
                    self.accordionOpenState[step.id] = true
                    defaultOpened = true
                    break
                end
            end
            if not defaultOpened then
                self.accordionOpenState[fullChain[#fullChain].id] = true
            end
        end

        for _, step in ipairs(fullChain) do
            local banner = AcquireAccordionBanner()
            banner:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
            banner:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, curY)

            local isOpen = (self.accordionOpenState[step.id] == true)
            banner.arrowText:SetText(isOpen and "[-]" or "[+]")

            local sLevel = (step.reqLevel and step.reqLevel > 0 and step.reqLevel) or step.level or 0
            local r, g, b = GetDifficultyColor(sLevel)
            local hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
            banner.levelText:SetText(string.format("|cff%sLv %d|r", hex, sLevel))

            banner.titleText:SetText(string.format("Step %d: %s", step.stepIndex, step.name))

            if banner._baseRim then
                if isOpen then
                    banner._baseRim:SetVertexColor(0.85, 0.65, 0.20, 1.0)
                else
                    banner._baseRim:SetVertexColor(0.12, 0.09, 0.06, 0.95)
                end
            end
            if banner._fill then
                if isOpen then
                    banner._fill:SetVertexColor(1.0, 0.96, 0.85, 1.0)
                else
                    banner._fill:SetVertexColor(0.88, 0.86, 0.82, 0.95)
                end
            end

            local stepActive = step.isActive or (questDb and questDb:IsQuestActive(step.id))
            if step.isCompleted then
                banner.statusIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                banner.statusIcon:SetSize(18, 18)
                if banner.statusIcon.SetDesaturated then banner.statusIcon:SetDesaturated(false) end
                banner.statusIcon:SetVertexColor(1.0, 1.0, 1.0)
                banner.titleText:SetTextColor(0.40, 0.90, 0.45)
            elseif stepActive then
                banner.statusIcon:SetSize(18, 18)
                local setOk = false
                if banner.statusIcon.SetAtlas then
                    local ok = pcall(function()
                        banner.statusIcon:SetAtlas("QuestTurnin")
                        if banner.statusIcon.SetDesaturated then banner.statusIcon:SetDesaturated(true) end
                        banner.statusIcon:SetVertexColor(0.85, 0.85, 0.85)
                    end)
                    setOk = ok
                end
                if not setOk then
                    banner.statusIcon:SetTexture("Interface\\GossipFrame\\IncompleteQuestIcon")
                    if banner.statusIcon.SetDesaturated then banner.statusIcon:SetDesaturated(false) end
                    banner.statusIcon:SetVertexColor(1.0, 1.0, 1.0)
                end
                banner.titleText:SetTextColor(0.88, 0.88, 0.88)
            else
                banner.statusIcon:SetSize(18, 18)
                if banner.statusIcon.SetDesaturated then banner.statusIcon:SetDesaturated(false) end
                banner.statusIcon:SetVertexColor(1.0, 1.0, 1.0)
                if banner.statusIcon.SetAtlas then
                    local ok = pcall(banner.statusIcon.SetAtlas, banner.statusIcon, "QuestNormal")
                    if not ok then
                        banner.statusIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                    end
                else
                    banner.statusIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
                end
                banner.titleText:SetTextColor(1.0, 0.82, 0.0)
            end

            banner:SetScript("OnClick", function()
                self.accordionOpenState[step.id] = not self.accordionOpenState[step.id]
                self:RenderQuestBodyDetails(q, giverInfo, dungeon)
            end)

            curY = curY - 32

            -- Expanded Body
            if isOpen then
                local bodyW = contentW - 24
                local bodyX = 14
                curY = curY - 4

                -- Objectives
                local objHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, bodyW)
                objHdr:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                objHdr:SetText("Objectives")
                curY = curY - 16

                local objBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, bodyW)
                objBody:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                objBody:SetText(step.objective or "No objective description available.")
                curY = curY - (objBody:GetStringHeight() or 14) - 24

                -- Quest Source & Turn-In
                local hasStepPickup = (step.pickup and step.pickup ~= "" and step.pickup ~= "Unknown")
                local hasStepTurnin = (step.turnin and step.turnin ~= "" and step.turnin ~= "Unknown")

                if hasStepPickup or hasStepTurnin then
                    local pStr = step.pickup or "Unknown"
                    local lowerP = pStr:lower()
                    local isItemOrInside = lowerP:find("inside") or lowerP:find("drops from") or lowerP:find("corpse") or lowerP:find("looted in") or lowerP:find("taken from") or lowerP:find("^[Ii]tem")

                    local stepGiverMap = nil
                    if hasStepPickup and not isItemOrInside then
                        if step.map and step.map.mapID and step.map.x and step.map.y then
                            stepGiverMap = step.map
                        elseif questDb and questDb.GetQuestMap then
                            stepGiverMap = questDb:GetQuestMap(step.id)
                        end
                        if (not stepGiverMap or not stepGiverMap.mapID) and questDb and questDb.FindMapForNpc then
                            local giverNpc = pStr:match("^(.-),") or pStr
                            stepGiverMap = questDb:FindMapForNpc(giverNpc)
                        end
                    end
                    local hasStepGiverBtn = (stepGiverMap ~= nil and stepGiverMap.mapID ~= nil and stepGiverMap.x ~= nil and stepGiverMap.y ~= nil)

                    local tStr = step.turnin or step.pickup or "Unknown"
                    local lowerT = tStr:lower()
                    local isTurninInside = lowerT:find("inside")

                    local stepTurninMap = nil
                    if hasStepTurnin and not isTurninInside then
                        if stepGiverMap and step.pickup and (tStr:lower():find(step.pickup:lower(), 1, true) or step.pickup:lower():find(tStr:lower(), 1, true)) then
                            stepTurninMap = stepGiverMap
                        end
                        if (not stepTurninMap or not stepTurninMap.mapID) and questDb and questDb.FindMapForNpc then
                            local turninNpc = tStr:match("^(.-),") or tStr
                            stepTurninMap = questDb:FindMapForNpc(turninNpc)
                        end
                    end
                    local hasStepTurninBtn = (stepTurninMap ~= nil and stepTurninMap.mapID ~= nil and stepTurninMap.x ~= nil and stepTurninMap.y ~= nil)

                    local pinSize = 36
                    local indentX = bodyX + 6
                    local textX = indentX + pinSize + 8
                    local fieldW = bodyW - (textX - bodyX)

                    if hasStepPickup then
                        local gBtn = AcquireMapPinButton()
                        gBtn:SetPoint("TOPLEFT", child, "TOPLEFT", indentX, curY)
                        local giverReason = isItemOrInside and "Source item is located inside the dungeon." or "Location coordinates unavailable."
                        self:ConfigureMapPin(gBtn, hasStepGiverBtn, stepGiverMap, pStr, giverReason)

                        local giverHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, fieldW)
                        giverHdr:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2)
                        giverHdr:SetText("Quest Source")

                        local giverBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, fieldW)
                        giverBody:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2 - 16)
                        giverBody:SetText(pStr)

                        local gBodyH = (giverBody and giverBody:GetStringHeight()) or 14
                        if gBodyH < 14 then gBodyH = 14 end
                        local gBlockH = math.max(pinSize, 2 + 16 + gBodyH)
                        curY = curY - gBlockH - 12
                    end

                    if hasStepTurnin then
                        local tBtn = AcquireMapPinButton()
                        tBtn:SetPoint("TOPLEFT", child, "TOPLEFT", indentX, curY)
                        local turninReason = isTurninInside and "Turn-in is located inside the dungeon." or "Location coordinates unavailable."
                        self:ConfigureMapPin(tBtn, hasStepTurninBtn, stepTurninMap, tStr, turninReason)

                        local turninHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, fieldW)
                        turninHdr:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2)
                        turninHdr:SetText("Turn-In")

                        local turninBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, fieldW)
                        turninBody:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2 - 16)
                        turninBody:SetText(tStr)

                        local tBodyH = (turninBody and turninBody:GetStringHeight()) or 14
                        if tBodyH < 14 then tBodyH = 14 end
                        local tBlockH = math.max(pinSize, 2 + 16 + tBodyH)
                        curY = curY - tBlockH - 14
                    end
                end

                -- Requirements
                if step.reqLevel and step.reqLevel > 0 then
                    local reqHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, bodyW)
                    reqHdr:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                    reqHdr:SetText("Requirements")
                    curY = curY - 16

                    local reqBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, bodyW)
                    reqBody:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                    reqBody:SetText("Requires Level " .. tostring(step.reqLevel))
                    curY = curY - (reqBody:GetStringHeight() or 14) - 4
                end

                -- Rewards
                local hasXP = (step.baseXP and step.baseXP > 0)
                local hasItems = (step.rewardItems and #step.rewardItems > 0)
                if hasXP or hasItems then
                    curY = curY - 8
                    local div = AcquireDividerBar()
                    div:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                    div:SetPoint("TOPRIGHT", child, "TOPRIGHT", -bodyX, curY)
                    curY = curY - 4 - 12

                    local rewHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, bodyW)
                    rewHdr:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                    rewHdr:SetText("Rewards")
                    curY = curY - 16

                    if hasXP then
                        local xpHdr = AcquireText("GameFontHighlightSmall", 0.80, 0.95, 0.80, false, bodyW)
                        xpHdr:SetPoint("TOPLEFT", child, "TOPLEFT", bodyX, curY)
                        xpHdr:SetText(string.format("• Experience: %s XP", tostring(step.baseXP)))
                        curY = curY - 16
                    end

                    if hasItems then
                        curY = RenderItemGrid(step.rewardItems, bodyX, curY, bodyW, step.rewardChoice == true)
                    end
                end

                curY = curY - 6
            end

            curY = curY - 4
        end

    -- ========================================================================
    -- BRANCH B: STANDALONE QUEST FLOW
    -- ========================================================================
    else
        -- 1. Objectives Section
        local objHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false)
        objHdr:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
        objHdr:SetText("Objectives")
        curY = curY - 16

        local objBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true)
        objBody:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
        local objText = q.objective or "No objective description available."
        objBody:SetText(objText)
        curY = curY - (objBody:GetStringHeight() or 14) - 24

        -- 2. Quest Source & Turn-In Sections (Side by Side)
        local qMap = questDb and questDb.GetQuestMap and questDb:GetQuestMap(q.id)
        local pickupStr = q.pickup
        if not pickupStr or pickupStr == "" then
            pickupStr = giverInfo.giverName or "Unknown"
        end
        if giverInfo.location and giverInfo.location ~= "" and not pickupStr:find(giverInfo.location, 1, true) and not pickupStr:find(",") then
            pickupStr = pickupStr .. ", " .. giverInfo.location
        end

        local lowerPickup = pickupStr:lower()
        local isPickupDropOrInside = giverInfo.isItem or lowerPickup:find("inside") or lowerPickup:find("corpse") or lowerPickup:find("dropped by") or lowerPickup:find("taken from")

        local giverMap = nil
        if not isPickupDropOrInside then
            if qMap and qMap.mapID and qMap.x and qMap.y then
                giverMap = qMap
            elseif questDb and questDb.FindMapForNpc then
                giverMap = questDb:FindMapForNpc(giverInfo.giverName)
            end
        end

        local hasGiverBtn = (giverMap ~= nil and giverMap.mapID ~= nil and giverMap.x ~= nil and giverMap.y ~= nil)

        local turninStr = q.turnin or q.pickup or giverInfo.giverName or "Unknown"
        local lowerTurnin = turninStr:lower()
        local isTurninInside = lowerTurnin:find("inside")

        local turninMap = nil
        if not isTurninInside then
            if isPickupDropOrInside and qMap and qMap.mapID and qMap.x and qMap.y then
                turninMap = qMap
            elseif giverMap and (turninStr:lower():find(giverInfo.giverName:lower(), 1, true) or giverInfo.giverName:lower():find(turninStr:lower(), 1, true)) then
                turninMap = giverMap
            elseif questDb and questDb.FindMapForNpc then
                local turninNpc = turninStr:match("^(.-),") or turninStr
                turninMap = questDb:FindMapForNpc(turninNpc)
            end
        end

        local hasTurninBtn = (turninMap ~= nil and turninMap.mapID ~= nil and turninMap.x ~= nil and turninMap.y ~= nil)

        local pinSize = 36
        local indentX = 14
        local textX = indentX + pinSize + 8
        local fieldW = textW - textX

        -- Row 1: Quest Source Bullet Block
        local gBtn = AcquireMapPinButton()
        gBtn:SetPoint("TOPLEFT", child, "TOPLEFT", indentX, curY)
        local giverReason = isPickupDropOrInside and "Source item is located inside the dungeon." or "Location coordinates unavailable."
        self:ConfigureMapPin(gBtn, hasGiverBtn, giverMap, giverInfo.giverName or "Quest Source", giverReason)

        local giverHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, fieldW)
        giverHdr:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2)
        giverHdr:SetText("Quest Source")

        local giverBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, fieldW)
        giverBody:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2 - 16)
        giverBody:SetText(pickupStr)

        local gBodyH = (giverBody and giverBody:GetStringHeight()) or 14
        if gBodyH < 14 then gBodyH = 14 end
        local gBlockH = math.max(pinSize, 2 + 16 + gBodyH)
        curY = curY - gBlockH - 12

        -- Row 2: Turn-In Bullet Block
        local tBtn = AcquireMapPinButton()
        tBtn:SetPoint("TOPLEFT", child, "TOPLEFT", indentX, curY)
        local turninReason = isTurninInside and "Turn-in is located inside the dungeon." or "Location coordinates unavailable."
        self:ConfigureMapPin(tBtn, hasTurninBtn, turninMap, turninStr or "Turn-In", turninReason)

        local turninHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false, fieldW)
        turninHdr:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2)
        turninHdr:SetText("Turn-In")

        local turninBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true, fieldW)
        turninBody:SetPoint("TOPLEFT", child, "TOPLEFT", textX, curY - 2 - 16)
        turninBody:SetText(turninStr)

        local tBodyH = (turninBody and turninBody:GetStringHeight()) or 14
        if tBodyH < 14 then tBodyH = 14 end
        local tBlockH = math.max(pinSize, 2 + 16 + tBodyH)
        curY = curY - tBlockH - 16

        -- 4. Requirements Section (Level, Faction, Class)
        local reqParts = {}
        if q.reqLevel and q.reqLevel > 0 then
            table.insert(reqParts, "Requires Level " .. q.reqLevel)
        end
        if q.faction and q.faction ~= "" and q.faction ~= "Both" then
            table.insert(reqParts, q.faction)
        end
        local questClass = q.classOnly
        if not questClass and q.tags then
            for _, t in ipairs(q.tags) do
                local c = t:match("^CLASS:(.+)$")
                if c then
                    questClass = c
                    break
                end
            end
        end
        if questClass and questClass ~= "" and questClass ~= "All" then
            local cUpper = questClass:upper()
            local cName = (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[cUpper])
                or (_G[cUpper])
                or (cUpper:sub(1, 1) .. cUpper:sub(2):lower())
            table.insert(reqParts, cName)
        end
        if #reqParts > 0 then
            local reqHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false)
            reqHdr:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
            reqHdr:SetText("Requirements")
            curY = curY - 16

            local reqBody = AcquireText("GameFontHighlightSmall", 0.92, 0.88, 0.80, true)
            reqBody:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
            reqBody:SetText(table.concat(reqParts, " • "))
            curY = curY - (reqBody:GetStringHeight() or 14) - 4
        end

        -- 5. Rewards Section
        local hasXP = (q.baseXP and q.baseXP > 0)
        local hasItems = (q.rewardItems and #q.rewardItems > 0)
        if hasXP or hasItems then
            curY = curY - 8
            local divider = AcquireDividerBar()
            divider:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
            divider:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, curY)
            curY = curY - 4 - 12

            local rewHdr = AcquireText("GameFontNormal", 1.0, 0.82, 0.20, false)
            rewHdr:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
            rewHdr:SetText("Rewards")
            curY = curY - 16

            if hasXP then
                local xpHdr = AcquireText("GameFontHighlightSmall", 0.80, 0.95, 0.80, false)
                xpHdr:SetPoint("TOPLEFT", child, "TOPLEFT", 4, curY)
                xpHdr:SetText(string.format("• Experience: %s XP", tostring(q.baseXP)))
                curY = curY - 16
            end

            if hasItems then
                curY = RenderItemGrid(q.rewardItems, 4, curY, contentW - 8, q.rewardChoice == true)
            end
        end
    end

    -- Hide all pooled widgets beyond widgetIdx
    for i = widgetIdx + 1, #self.questBodyWidgets do
        self.questBodyWidgets[i]:Hide()
    end

    if self.questDividers then
        for i = dividerIdx + 1, #self.questDividers do
            self.questDividers[i]:Hide()
        end
    end

    local totalH = math.max(1, -curY + 20)
    child:SetHeight(totalH)
    if ns.UI.SharedWidgets and ns.UI.SharedWidgets.UpdateScrollFrameVisibility then
        ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.questBodyScroll, totalH)
    end
end

--- Resolves and renders the circular medallion portrait for a quest giver (Item or NPC).
--- Uses native engine creature display 2D render or item texture with bronze ring border.
--- Strictly hides classification dragons (no elite horns/wings).
--- @param medallion Frame
--- @param quest table
--- @param giverInfo table
function DungeonBookView:RenderQuestGiverPortrait(medallion, quest, giverInfo)
    if not medallion or not medallion.icon then return end
    local tex = medallion.icon
    local SharedWidgets = ns.UI.SharedWidgets

    if medallion.CreateMaskTexture and not medallion.mask then
        local mask = medallion:CreateMaskTexture()
        mask:SetAllPoints(tex)
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        tex:AddMaskTexture(mask)
        medallion.mask = mask
    end

    SharedWidgets:SyncWindowPortraitBorder(medallion)
    SharedWidgets:SetMedallionClassification(medallion, nil)

    -- 1. Quest Starts from an Item
    if giverInfo.isItem then
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- The item's or object's icon (QuestAccess); missing shows the question mark
        local itemIcon = giverInfo.itemIcon or Constants.ASSETS.MISSING_ICON

        if SetPortraitToTexture then
            local ok = pcall(SetPortraitToTexture, tex, itemIcon)
            if not ok then tex:SetTexture(itemIcon) end
        else
            tex:SetTexture(itemIcon)
        end
        return
    end

    -- 2. Quest Starts from an NPC: Use authoritative 3D Creature Display ID
    tex:SetTexCoord(0, 1, 0, 1)
    local displayID = giverInfo.displayID

    if displayID and type(displayID) == "number" and displayID > 0 then
        if type(SetPortraitTextureFromCreatureDisplayID) == "function" then
            local ok = pcall(SetPortraitTextureFromCreatureDisplayID, tex, displayID)
            if ok then
                tex:SetTexCoord(0, 1, 0, 1)
                return
            end
        end
    end

    -- 3. Fallback: Clean quest exclamation icon (never a stale model from previous selection)
    local fallback = "Interface\\GossipFrame\\AvailableQuestIcon"
    if SetPortraitToTexture then
        local ok = pcall(SetPortraitToTexture, tex, fallback)
        if not ok then tex:SetTexture(fallback) end
    else
        tex:SetTexture(fallback)
    end
end

--- Renders the Right Page based on whether a boss is selected and which right-side tab is active.
function DungeonBookView:RefreshRightPage()
    local d = self.currentDungeon
    if not d or not self.frame then
        return
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local boss = self.selectedBoss
    self:UpdateSideTabs()

    -- ========================================================================
    -- MODE 1: NO BOSS SELECTED (Main Dungeon Overview OR Full Dungeon Loot)
    -- ========================================================================
    if not boss then
        if self.bossMedallion then
            self.bossMedallion:Hide()
        end
        self.rightTitle:SetText("")
        self.rightTitle:Hide()
        if self.rightBossLevel then
            self.rightBossLevel:Hide()
        end
        self.detailDesc:Hide()
        self.rightDivider:Hide()

        if self.activeRightTab == "loot" then
            -- Full Dungeon Loot View (every item in the dungeon with boss names underneath)
            if self.questDetailContainer then
                self.questDetailContainer:Hide()
            end
            if self.questFactionCrest then
                self.questFactionCrest:Hide()
            end
            if self.questGiverMedallion then
                self.questGiverMedallion:Hide()
            end
            self.overviewPane:Hide()
            self.detailScroll:ClearAllPoints()
            self.detailScroll:SetPoint("TOPLEFT", self.rightPage, "TOPLEFT", 6, -8)
            self.detailScroll:SetPoint("BOTTOMRIGHT", self.rightPage, "BOTTOMRIGHT", -24, 8)
            if self.detailScroll.SetVerticalScroll then
                self.detailScroll:SetVerticalScroll(0)
            end
            self.detailScroll:Show()
            self:RenderDungeonItemDrops(d)
            return
        elseif self.activeRightTab == "quests" then
            -- Dungeon Quests View: Quests are rendered on the Left Page, selected quest header on Right Page
            self.overviewPane:Hide()
            self.detailScroll:Hide()
            if self.questDetailContainer then
                self.questDetailContainer:Show()
                if self.questGiverMedallion then
                    self.questGiverMedallion:Hide()
                end

                if self.selectedQuest then
                    local q = self.selectedQuest
                    self.questHeaderTitle:SetText(q.name or "Unknown Quest")

                    -- Capital City / Faction Crest for Quest Header
                    local qFaction = q.faction
                    local crestTex = (qFaction == "Horde") and "Interface\\Timer\\Horde-Logo"
                        or (qFaction == "Alliance") and "Interface\\Timer\\Alliance-Logo"
                        or nil

                    if crestTex and self.questFactionCrest then
                        self.questFactionCrest:SetTexture(crestTex)
                        self.questFactionCrest:SetTexCoord(0, 1, 0, 1)
                        self.questFactionCrest:SetSize(38, 38)
                        self.questFactionCrest:Show()
                    elseif self.questFactionCrest then
                        self.questFactionCrest:Hide()
                    end

                    local dungeonLoc = (d and d.location and d.location ~= "") and (d.name .. ", " .. d.location) or (d and d.name)
                    local questDb = QuestAccess
                    local giverInfo = (questDb and questDb.GetQuestGiverInfo and questDb:GetQuestGiverInfo(q, d and d.name, dungeonLoc)) or {
                        isItem = false,
                        giverName = "",
                        location = "",
                        npcID = nil,
                        displayID = nil,
                        itemIcon = nil,
                        isChain = false,
                    }

                    local qLevel = (q.reqLevel and q.reqLevel > 0 and q.reqLevel) or q.questLevel or q.level or 0
                    local r, g, b = GetDifficultyColor(qLevel)
                    local hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))

                    local obtainingLoc = giverInfo.location
                    if not obtainingLoc or obtainingLoc == "" then
                        obtainingLoc = (d and d.name) or "Dungeon"
                    end

                    -- Construct strict subheader: Level • Sublocation, Location [ • Quest Chain | • Item Drop ]
                    local metaParts = {}
                    table.insert(metaParts, string.format("|cff%sLv %s|r", hex, tostring(qLevel)))
                    table.insert(metaParts, obtainingLoc)
                    if giverInfo.isItem then
                        table.insert(metaParts, "Item Drop")
                    elseif giverInfo.isChain then
                        table.insert(metaParts, "Quest Chain")
                    end

                    self.questHeaderMeta:SetText(table.concat(metaParts, " • "))

                    self.questHeaderTitle:ClearAllPoints()
                    self.questHeaderTitle:SetPoint("TOP", self.dungeonTitle, "TOP", 0, 0)
                    self.questHeaderTitle:SetPoint("LEFT", self.questDetailContainer, "LEFT", 6, 0)
                    if self.questFactionCrest and self.questFactionCrest:IsShown() then
                        self.questHeaderTitle:SetPoint("RIGHT", self.questFactionCrest, "LEFT", -6, 0)
                        self.questHeaderMeta:SetPoint("RIGHT", self.questFactionCrest, "LEFT", -6, 0)
                    else
                        self.questHeaderTitle:SetPoint("RIGHT", self.questDetailContainer, "RIGHT", -12, 0)
                        self.questHeaderMeta:SetPoint("RIGHT", self.questDetailContainer, "RIGHT", -12, 0)
                    end

                    if self.questGiverMedallion then
                        self.questGiverMedallion:Hide()
                    end

                    -- Print all quest info and details into the main body pane
                    self:RenderQuestBodyDetails(q, giverInfo, d)
                else
                    self.questHeaderTitle:SetText("")
                    self.questHeaderMeta:SetText("")
                    if self.questFactionCrest then
                        self.questFactionCrest:Hide()
                    end
                    if self.questGiverMedallion then
                        self.questGiverMedallion:Hide()
                    end
                    if self.questBodyWidgets then
                        for _, w in ipairs(self.questBodyWidgets) do w:Hide() end
                    end
                end
            end
            return
        end

        -- Dungeon Overview View (Artwork + Lore + Show on Map button)
        if self.questDetailContainer then
            self.questDetailContainer:Hide()
        end
        if self.questFactionCrest then
            self.questFactionCrest:Hide()
        end
        if self.questGiverMedallion then
            self.questGiverMedallion:Hide()
        end
        self.detailScroll:Hide()
        self.overviewPane:Show()

        self.artBannerTitle:SetText(string.upper(d.fullName or ""))
        SharedWidgets:ApplyDungeonArtwork(self.overviewArt, d)
        self.overviewLoreText:SetText(d.description or "")
        WindowBackground:ColorBodyText(self.overviewLoreText, 0.92, 0.85, 0.72)
        if self.showOnMapBtn then
            local shouldShow = ShouldShowDungeonMapButton(d)
            self.showOnMapBtn:SetShown(shouldShow)
        end
        return
    end

    -- ========================================================================
    -- MODE 2: BOSS ENCOUNTER OVERVIEW & DROPS (Boss selected, Loot tab active)
    -- ========================================================================
    self.overviewPane:Hide()
    if self.questDetailContainer then
        self.questDetailContainer:Hide()
    end
    if self.questFactionCrest then
        self.questFactionCrest:Hide()
    end
    if self.questGiverMedallion then
        self.questGiverMedallion:Hide()
    end

    -- 1. Boss Medallion Portrait + Name
    SharedWidgets:SetBossMedallionPortrait(self.bossMedallion, boss, d)
    SharedWidgets:SyncWindowPortraitBorder(self.bossMedallion)
    SharedWidgets:SetMedallionClassification(self.bossMedallion, boss)
    self.bossMedallion:Show()

    self.rightTitle:SetText(boss.name or "Boss")
    self.rightTitle:Show()

    local isRare = (not boss.isChallenge) and (boss.rare or boss.isRare or (boss.classification == "rare") or (boss.classification == "rareelite"))
    local showDifficultyColor = true
    if _G.JournalBase and _G.JournalBase.GetDungeonSetting then
        showDifficultyColor = _G.JournalBase:GetDungeonSetting("showBossDifficultyColor", true) == true
    end

    if boss.isEvent then
        self.rightBossLevel:SetText("Event ??")
        if showDifficultyColor then
            local r, g, b = GetDifficultyColor(boss.level or "??")
            self.rightBossLevel:SetTextColor(r, g, b)
        else
            self.rightBossLevel:SetTextColor(1.0, 0.75, 0.30)
        end
    elseif isRare then
        self.rightBossLevel:SetText("Rare " .. (boss.level or "??"))
        if showDifficultyColor then
            local r, g, b = GetDifficultyColor(boss.level or "??")
            self.rightBossLevel:SetTextColor(r, g, b)
        else
            self.rightBossLevel:SetTextColor(0.75, 0.85, 0.95)
        end
    elseif boss.isZone or boss.isTrash then
        self.rightBossLevel:SetText("Zone")
        self.rightBossLevel:SetTextColor(0.80, 0.72, 0.55)
    else
        self.rightBossLevel:SetText("Lv " .. (boss.level or "??"))
        if showDifficultyColor then
            local r, g, b = GetDifficultyColor(boss.level or "??")
            self.rightBossLevel:SetTextColor(r, g, b)
        else
            self.rightBossLevel:SetTextColor(0.80, 0.72, 0.55)
        end
    end
    self.rightBossLevel:Show()

    -- 2. Boss Lore Snippet dynamically positioned below whichever extends further (Medallion or Title+Level block)
    local medallionBottom = 6 + 44
    local titleH = self.rightTitle:GetStringHeight()
    local levelH = self.rightBossLevel:GetStringHeight()
    local headerTextBottom = 2 + titleH + 3 + levelH
    local headerH = math.max(medallionBottom, headerTextBottom)

    self.detailDesc:ClearAllPoints()
    self.detailDesc:SetPoint("TOPLEFT", self.rightPage, "TOPLEFT", 10, -(headerH + 12))
    self.detailDesc:SetText(boss.description or "Encounter overview and lore for this encounter.")
    WindowBackground:ColorBodyText(self.detailDesc, 0.92, 0.86, 0.72)
    self.detailDesc:Show()

    -- 3. Dynamic Dividing Line directly below the Lore Snippet
    local descH = math.max(28, self.detailDesc:GetStringHeight())
    local dividerY = -(headerH + 12 + descH + 12)
    self.rightDivider:ClearAllPoints()
    self.rightDivider:SetPoint("TOPLEFT", self.rightPage, "TOPLEFT", 6, dividerY)
    self.rightDivider:SetPoint("TOPRIGHT", self.rightPage, "TOPRIGHT", -24, dividerY)
    self.rightDivider:SetHeight(4)
    self.rightDivider:Show()

    -- 4. Clean Scrollable Container under Divider
    self.detailScroll:ClearAllPoints()
    self.detailScroll:SetPoint("TOPLEFT", self.rightDivider, "BOTTOMLEFT", 0, -8)
    self.detailScroll:SetPoint("BOTTOMRIGHT", self.rightPage, "BOTTOMRIGHT", -24, 8)
    if self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    self.detailScroll:Show()

    -- 5. Render Categorized Item Drops or Quests
    if self.activeRightTab == "quests" then
        self:RenderCategorizedDropEntries({}, false, nil, "", "Dungeon Quest tracking coming soon.")
    else
        self:RenderItemDrops(d, boss)
    end
end

function DungeonBookView:Show()
    if self.frame then
        self.frame:Show()
    end
end

function DungeonBookView:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.DungeonBookView = DungeonBookView
