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

--- Returns dynamic RGB difficulty color based on monster level vs player level.
--- @param bossLevel string|number
--- @return number r, number g, number b
local function GetDifficultyColor(bossLevel)
    return ns.UI.SharedWidgets:GetCreatureDifficultyColor(bossLevel)
end

--- Resolves entrance coordinates and metadata across all module namespaces.
--- @param dungeonID string
--- @return table|nil
local function GetDungeonMapLocation(dungeonID)
    if not dungeonID then return nil end
    local fn = (ns and ns.GetDungeonMapLocation)
        or (parent and parent.GetDungeonMapLocation)
        or (parent and parent.Dungeons and parent.Dungeons.GetDungeonMapLocation)
        or (_G.JournalBase and _G.JournalBase.GetDungeonMapLocation)
        or _G.AdventureJournal_GetDungeonMapLocation
        or (parent and parent.EntranceCoordinates and parent.EntranceCoordinates.GetByDungeonID)
    if fn then
        return fn(dungeonID)
    end
    return nil
end

--- Checks whether the Show on Map button should be visible based on user map icon settings and player level.
--- @param dungeon table|nil
--- @return boolean
local function ShouldShowDungeonMapButton(dungeon)
    if not dungeon then return false end
    local loc = GetDungeonMapLocation(dungeon.id)
    if not loc or not loc.uiMapID then return false end

    -- Verify Map Icons utility module is enabled
    local isPluginEnabled = (_G.JournalBase and _G.JournalBase.IsPluginEnabled)
        or (parent and parent.IsPluginEnabled)
        or (ns and ns.IsPluginEnabled)
    if isPluginEnabled and not isPluginEnabled("map_icons") then
        return false
    end

    local setting = "min_level"
    if ns and ns.Database and ns.Database.GetMapIconsSetting then
        setting = ns.Database:GetMapIconsSetting("worldMapDungeonIcons", "min_level")
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
    bossButtonPool = {},
    categoryHeaderPool = {},
    itemRowPool = {},
    zoneBossEntry = nil,
    onSelectBoss = nil,
    onSelectDungeonOverview = nil,
}

--- Initializes the Open-Book Split View inside `parent`.
--- @param parent Frame
--- @param callbacks table `{ onSelectBoss, onSelectDungeonOverview }`
function DungeonBookView:Init(parent, callbacks)
    if self.frame then
        return
    end
    self.onSelectBoss = callbacks and callbacks.onSelectBoss
    self.onSelectDungeonOverview = callbacks and callbacks.onSelectDungeonOverview

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

    -- Dedicated Clickable Dungeon Portrait Medallion (focused specifically on portrait)
    local dungeonMedallion = SharedWidgets:CreateCircularMedallion(leftPage, 38, 52)
    dungeonMedallion:SetPoint("TOPLEFT", leftPage, "TOPLEFT", 2, -7)
    self.dungeonMedallion = dungeonMedallion

    local portraitBtn = CreateFrame("Button", nil, dungeonMedallion)
    portraitBtn:SetSize(48, 48)
    portraitBtn:SetPoint("CENTER", dungeonMedallion, "CENTER", 0, 0)
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
        if not GameTooltip or not self.currentDungeon then
            return
        end
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.currentDungeon.name, 1.0, 0.82, 0.0)
        GameTooltip:AddLine("Click to view Dungeon Overview", 0.30, 0.92, 0.38)
        GameTooltip:Show()
    end)

    portraitBtn:SetScript("OnLeave", function()
        if self.dungeonMedallion and self.dungeonMedallion.SetHighlighted then
            self.dungeonMedallion:SetHighlighted(false)
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

    -- Sub-Container 2: Scrollable Area under Divider (Reserved for future Item/Drop list)
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

    local dropUpdateTimer = nil
    if ns.ItemsManager and ns.ItemsManager.RegisterUpdateListener then
        ns.ItemsManager:RegisterUpdateListener(function()
            if self.frame and self.frame:IsShown() and self.selectedBoss and self.currentDungeon then
                if dropUpdateTimer and dropUpdateTimer.Cancel then
                    dropUpdateTimer:Cancel()
                end
                if C_Timer and C_Timer.NewTimer then
                    dropUpdateTimer = C_Timer.NewTimer(0.08, function()
                        if self.frame and self.frame:IsShown() and self.selectedBoss and self.currentDungeon then
                            self:RenderItemDrops(self.currentDungeon, self.selectedBoss)
                        end
                    end)
                else
                    self:RenderItemDrops(self.currentDungeon, self.selectedBoss)
                end
            end
        end)
    end

    frame:SetScript("OnShow", function()
        SharedWidgets:SyncQuestDividerBar(self.leftDivider)
        SharedWidgets:SyncQuestDividerBar(self.rightDivider)
        if self.eventDivider and self.eventDivider:IsShown() then
            SharedWidgets:SyncQuestDividerBar(self.eventDivider)
        end
        if self.rareHeader and self.rareHeader:IsShown() and self.rareHeader.divider then
            SharedWidgets:SyncQuestDividerBar(self.rareHeader.divider)
        end
        if self.minorHeader and self.minorHeader:IsShown() and self.minorHeader.divider then
            SharedWidgets:SyncQuestDividerBar(self.minorHeader.divider)
        end
        if self.challengeHeader and self.challengeHeader:IsShown() and self.challengeHeader.divider then
            SharedWidgets:SyncQuestDividerBar(self.challengeHeader.divider)
        end
        if self.trashDivider and self.trashDivider:IsShown() then
            SharedWidgets:SyncQuestDividerBar(self.trashDivider)
        end
        if self.overviewDivider then
            SharedWidgets:SyncQuestDividerBar(self.overviewDivider)
        end
        SharedWidgets:SyncWindowPortraitBorder(self.dungeonMedallion)
        if self.bossMedallion then
            SharedWidgets:SyncWindowPortraitBorder(self.bossMedallion)
        end
    end)

    -- Real-time reactive listener for dungeon module setting changes
    if _G.JournalBase then
        local prevHook = _G.JournalBase.OnDungeonSettingChanged
        _G.JournalBase.OnDungeonSettingChanged = function(jBase, key, val)
            if prevHook then
                pcall(prevHook, jBase, key, val)
            end
            if (key == "showBossLevel" or key == "showBossDifficultyColor" or key == "showMinorMonsters" or key == "hideMinorMonsters" or key == "showEventBosses" or key == "showDungeonSetChallenges" or key == "worldMapDungeonIcons") and self.frame and self.frame:IsShown() then
                self:RefreshLeftPage()
                self:RefreshRightPage()
            end
        end
    end

    frame:RegisterEvent("PLAYER_LEVEL_UP")
    frame:SetScript("OnEvent", function(f, event, ...)
        if event == "PLAYER_LEVEL_UP" and self.frame and self.frame:IsShown() then
            self:RefreshLeftPage()
            self:RefreshRightPage()
        end
    end)
end

--- Builds the Instance Overview pane (Artwork banner + lore text).
function DungeonBookView:BuildInstanceOverviewPane(rightPage)
    local SharedWidgets = ns.UI.SharedWidgets
    local bookCfg = Constants.BOOK

    local pane = CreateFrame("Frame", nil, rightPage)
    pane:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 6, -8)
    pane:SetPoint("BOTTOMRIGHT", rightPage, "BOTTOMRIGHT", -12, 6)
    self.overviewPane = pane

    -- Framed Dungeon Artwork Box (`376 x 186`), lowered slightly for balanced margin
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

    -- "Show on Map" Button below the Dungeon Lore Description (sized +25% with gold text)
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
        local loc = GetDungeonMapLocation(self.currentDungeon.id)
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
        local loc = GetDungeonMapLocation(self.currentDungeon.id)
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

    if ns.ItemsManager and ns.ItemsManager.RegisterUpdateListener then
        ns.ItemsManager:RegisterUpdateListener(function()
            if self.frame and self.frame:IsShown() then
                if self.searchQuery and self.searchQuery ~= "" then
                    local prevBoss = self.selectedBoss
                    self:RefreshLeftPage()
                    self:RefreshRightPage()
                    if self.selectedBoss ~= prevBoss and self.selectedBoss and self.onSelectBoss then
                        self.onSelectBoss(self.selectedBoss)
                    end
                elseif self.selectedBoss then
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
    subLeftText:SetJustifyH("LEFT")
    subLeftText:SetTextColor(0.75, 0.70, 0.60)
    row.subLeftText = subLeftText

    local subRightText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subRightText:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 3)
    subRightText:SetJustifyH("RIGHT")
    row.subRightText = subRightText

    row:SetScript("OnEnter", function(r)
        if not GameTooltip or not r.itemID then return end
        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
        if r.itemLink and r.itemLink:find("|Hitem:") then
            GameTooltip:SetHyperlink(r.itemLink)
        elseif GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(r.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. tostring(r.itemID))
        end
        GameTooltip:Show()
    end)

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

--- Sets the active dungeon and optional selected boss, then refreshes both pages.
--- @param dungeon table
--- @param boss table|nil
--- @param searchQuery string|nil
function DungeonBookView:SetContext(dungeon, boss, searchQuery)
    self.currentDungeon = dungeon
    self.selectedBoss = boss
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
    self:RefreshRightPage()
end

--- Updates the search query filter for the left page.
--- @param queryText string
function DungeonBookView:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    if self.frame and self.frame:IsShown() then
        if self.bossScroll and self.bossScroll.SetVerticalScroll then
            self.bossScroll:SetVerticalScroll(0)
        end
        self:RefreshLeftPage()
        self:RefreshRightPage()
    end
end

--- Updates only the selected boss (or `nil` for Instance Overview) and refreshes.
--- @param boss table|nil
function DungeonBookView:SetSelectedBoss(boss)
    self.selectedBoss = boss
    if self.detailScroll and self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    self:RefreshLeftPage()
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
    self.dungeonTitle:SetText(d.name or "Dungeon")

    -- Capital City Faction Crest (Horde: Ragefire Chasm, Ruins of Lordaeron; Alliance: Hall of Thanes, The Stockade)
    local CITY_DUNGEON_FACTIONS = {
        ["ragefire_chasm"] = "Horde",
        ["ragefire"] = "Horde",
        ["ruins_of_lordaeron"] = "Horde",
        ["hall_of_thanes"] = "Alliance",
        ["the_stockade"] = "Alliance",
    }
    local faction = CITY_DUNGEON_FACTIONS[d.id]
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
        self.dungeonMeta:SetText(string.format("|cff%sLvl %s|r • %s", hex, d.level or "?", d.location or ""))
    else
        self.dungeonMeta:SetText(string.format("Lvl %s • %s", d.level or "?", d.location or ""))
    end

    for _, btn in ipairs(self.bossButtonPool) do
        btn:Hide()
    end

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""

    local function bossMatches(boss)
        if q == "" then return true end
        if ns.ItemsManager and ns.ItemsManager.BossMatchesQuery then
            return ns.ItemsManager:BossMatchesQuery(d.id, boss, q)
        end
        return boss.name and strfind(strlower(boss.name), q, 1, true)
    end

    local eventBosses = {}
    local mainBosses = {}
    local rareBosses = {}
    local minorBosses = {}
    local challengeBosses = {}
    local firstMatchingBoss = nil
    local selectedBossMatches = false
    local isSearching = (q ~= "")

    for _, boss in ipairs(d.bosses or {}) do
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
            SharedWidgets:SyncQuestDividerBar(self.eventDivider)
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
            if self.rareHeader.divider then
                SharedWidgets:SyncQuestDividerBar(self.rareHeader.divider)
            end
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
            if self.minorHeader.divider then
                SharedWidgets:SyncQuestDividerBar(self.minorHeader.divider)
            end
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
            if self.challengeHeader.divider then
                SharedWidgets:SyncQuestDividerBar(self.challengeHeader.divider)
            end
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
    local zoneDrops = ns.ItemsManager and ns.ItemsManager:GetEncounterDrops(d.id, "Zone Drops") or {}
    local hasZoneDrops = (#zoneDrops > 0)
    if hasZoneDrops and q ~= "" then
        local zoneMatches = false
        if strfind("zone drops", q, 1, true) then
            zoneMatches = true
        elseif ns.ItemsManager and ns.ItemsManager.BossMatchesQuery then
            zoneMatches = ns.ItemsManager:BossMatchesQuery(d.id, { name = "Zone Drops", isZone = true }, q)
        end
        hasZoneDrops = zoneMatches
    end

    if not self.zoneBossEntry or self.zoneBossEntry.dungeonId ~= d.id then
        self.zoneBossEntry = {
            dungeonId = d.id,
            name = "Zone Drops",
            isZone = true,
            isTrash = true,
            classification = "trash",
            icon = "Interface\\Icons\\INV_Box_01",
            level = "Zone",
            description = string.format("Notable zone-wide drops from creatures throughout %s.", d.name or "the dungeon"),
        }
    end

    -- Preserve Zone Drops selection if currently selected and valid
    if hasZoneDrops and self.selectedBoss and (self.selectedBoss.isZone or self.selectedBoss.isTrash) then
        self.selectedBoss = self.zoneBossEntry
        selectedBossMatches = true
    end

    -- Auto-select matching boss or zone drops when search query is active
    if q ~= "" then
        if not selectedBossMatches then
            if firstMatchingBoss then
                self.selectedBoss = firstMatchingBoss
            elseif hasZoneDrops then
                self.selectedBoss = self.zoneBossEntry
            else
                self.selectedBoss = nil
            end
        end
    end

    if hasZoneDrops then
        local dividerY = currentY
        if self.trashDivider then
            self.trashDivider:ClearAllPoints()
            self.trashDivider:SetPoint("TOPLEFT", self.bossScrollChild, "TOPLEFT", 10, dividerY)
            self.trashDivider:SetPoint("TOPRIGHT", self.bossScrollChild, "TOPRIGHT", -14, dividerY)
            self.trashDivider:Show()
            SharedWidgets:SyncQuestDividerBar(self.trashDivider)
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
    { id = "COLLECTIBLE", title = "Collectibles" },
    { id = "QUEST", title = "Quest Items & Keys" },
    { id = "MISC", title = "Other" },
}

--- Groups, formats, and renders categorized item drop rows.
--- @param d table
--- @param boss table
function DungeonBookView:RenderItemDrops(d, boss)
    for _, hdr in ipairs(self.categoryHeaderPool) do hdr:Hide() end
    for _, row in ipairs(self.itemRowPool) do row:Hide() end

    local bossKey = (boss.isZone or boss.isTrash) and "Zone Drops" or boss.name
    local dropIDs = ns.ItemsManager and ns.ItemsManager:GetEncounterDrops(d.id, bossKey) or {}

    local q = (type(self.searchQuery) == "string" and strlower(self.searchQuery:match("^%s*(.-)%s*$") or "")) or ""
    local parsedQuery = (q ~= "" and ns.ItemsManager and ns.ItemsManager.ParseQuery) and ns.ItemsManager:ParseQuery(q) or nil
    local isMultiConstraint = parsedQuery and ((#parsedQuery.tags > 1) or parsedQuery.minLevel or parsedQuery.maxLevel or (#parsedQuery.tags == 1 and #parsedQuery.textTerms > 0))
    local bossNameMatches = (not isMultiConstraint) and (boss.name and strfind(strlower(boss.name), q, 1, true))
    local filterByItem = (q ~= "" and not bossNameMatches)

    if #dropIDs == 0 then
        self.noDropsText:SetText("No item drops recorded for this encounter.")
        self.noDropsText:Show()
        self.detailScrollChild:SetHeight(60)
        ns.UI.SharedWidgets:UpdateScrollFrameVisibility(self.detailScroll, 60)
        return
    end

    self.noDropsText:Hide()

    local grouped = {
        EQUIPMENT = {},
        RECIPE = {},
        COLLECTIBLE = {},
        QUEST = {},
        MISC = {},
    }

    for _, itemID in ipairs(dropIDs) do
        local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, _, classID, subclassID = safeGetItemInfo(itemID)
        local catalogRec = ns.ItemsManager and ns.ItemsManager.GetItem and ns.ItemsManager:GetItem(itemID) or nil

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
            local cachedName = (catalogRec and catalogRec.name) or (ns.ItemsManager and ns.ItemsManager:GetItemName(itemID))
            if cachedName and cachedName ~= "" then
                itemName = cachedName
            end
        end

        if catalogRec then
            if itemQuality == nil and catalogRec.q ~= nil then
                itemQuality = catalogRec.q
            end
            if (not itemSubType or itemSubType == "") and catalogRec.subType then
                itemSubType = catalogRec.subType
            end
        end

        local displayName = (itemName and itemName ~= "") and itemName or ("Item #" .. tostring(itemID))
        local matchesQuery = true
        if filterByItem then
            if ns.ItemsManager and ns.ItemsManager.ItemMatchesQuery then
                matchesQuery = ns.ItemsManager:ItemMatchesQuery(itemID, parsedQuery or q)
            else
                matchesQuery = strfind(strlower(displayName), q, 1, true) ~= nil
            end
        end

        if matchesQuery then
            local cat = (ns.ItemsManager and ns.ItemsManager:GetItemCategory(itemType, itemSubType, itemEquipLoc, itemID, itemName, classID, subclassID)) or "MISC"
            local isGreyEquipment = (cat == "EQUIPMENT" and (itemQuality == 0 or itemQuality == "0"))
            if not isGreyEquipment then
                local itemData = {
                    id = itemID,
                    name = displayName,
                    link = itemLink or ("item:" .. tostring(itemID)),
                    quality = itemQuality or 1,
                    itemType = itemType,
                    itemSubType = itemSubType,
                    equipLoc = itemEquipLoc,
                    texture = itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
                    classID = classID,
                    subclassID = subclassID,
                }
                grouped[cat][#grouped[cat] + 1] = itemData
            end
        end
    end

    local currentY = 0
    local hdrIdx = 0
    local rowIdx = 0
    local rowH = 36
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
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.detailScrollChild, "TOPLEFT", 4, currentY)
                row:SetPoint("TOPRIGHT", self.detailScrollChild, "TOPRIGHT", -4, currentY)

                row.itemID = item.id
                row.itemLink = item.link

                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.icon:SetTexture(item.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

                local r, g, b = safeGetItemQualityColor(item.quality)
                row:SetBorderColor(r, g, b, 1.0)

                row.nameText:SetText(item.name or ("Item #" .. tostring(item.id)))
                row.nameText:SetTextColor(r, g, b)

                if catDef.id == "EQUIPMENT" then
                    local slotName = item.equipLoc and _G[item.equipLoc] or item.itemType or ""
                    if item.equipLoc == "INVTYPE_HOLDABLE" then
                        slotName = "Off-hand"
                    end
                    row.subLeftText:SetText(slotName)

                    local subType = item.itemSubType or ""
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
                        local isUsable = ns.ItemsManager:IsItemUsableByPlayer(item.itemType, item.itemSubType, item.equipLoc)
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
            self.noDropsText:SetText("No item drops recorded for this encounter.")
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

--- Renders the Right Page based on whether a boss is selected.
function DungeonBookView:RefreshRightPage()
    local d = self.currentDungeon
    if not d or not self.frame then
        return
    end

    local SharedWidgets = ns.UI.SharedWidgets
    local boss = self.selectedBoss

    -- ========================================================================
    -- MODE 1: INSTANCE OVERVIEW (No boss selected)
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
        self.detailScroll:Hide()
        self.overviewPane:Show()

        self.artBannerTitle:SetText(string.upper(d.name or ""))
        SharedWidgets:ApplyDungeonArtwork(self.overviewArt, d)
        self.overviewLoreText:SetText(d.description or "")
        if self.overviewDivider then
            SharedWidgets:SyncQuestDividerBar(self.overviewDivider)
        end
        if self.showOnMapBtn then
            local shouldShow = ShouldShowDungeonMapButton(d)
            self.showOnMapBtn:SetShown(shouldShow)
        end
        return
    end

    -- ========================================================================
    -- MODE 2: BOSS ENCOUNTER OVERVIEW & DROPS (Boss selected)
    -- ========================================================================
    self.overviewPane:Hide()

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
    self.detailDesc:Show()

    -- 3. Dynamic Dividing Line directly below the Lore Snippet
    local descH = math.max(28, self.detailDesc:GetStringHeight())
    local dividerY = -(headerH + 12 + descH + 12)
    self.rightDivider:ClearAllPoints()
    self.rightDivider:SetPoint("TOPLEFT", self.rightPage, "TOPLEFT", 6, dividerY)
    self.rightDivider:SetPoint("TOPRIGHT", self.rightPage, "TOPRIGHT", -24, dividerY)
    self.rightDivider:SetHeight(4)
    self.rightDivider:Show()
    SharedWidgets:SyncQuestDividerBar(self.rightDivider)

    -- 4. Clean Scrollable Container under Divider
    self.detailScroll:ClearAllPoints()
    self.detailScroll:SetPoint("TOPLEFT", self.rightDivider, "BOTTOMLEFT", 0, -8)
    self.detailScroll:SetPoint("BOTTOMRIGHT", self.rightPage, "BOTTOMRIGHT", -24, 8)
    if self.detailScroll.SetVerticalScroll then
        self.detailScroll:SetVerticalScroll(0)
    end
    self.detailScroll:Show()

    -- 5. Render Categorized Item Drops
    self:RenderItemDrops(d, boss)
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
