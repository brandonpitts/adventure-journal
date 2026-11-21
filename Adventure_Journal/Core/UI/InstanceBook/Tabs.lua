-- ============================================================================
-- Adventure Journal - Core/UI/InstanceBook/Tabs.lua
-- An instance book's side tabs (from the template; Overview, Loot, Quests):
-- which show, which are enabled, and what a click opens.
-- ============================================================================
local addonName, ns = ...
local addonNs = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local GameTooltip = GameTooltip
local PlaySound = PlaySound
local UnitClass = UnitClass
local UnitFactionGroup = UnitFactionGroup
local Blocks = ns.UI.Blocks
local QuestAccess = ns.Data.QuestAccess

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local InstanceBook = ns.UI.InstanceBook

--- Builds the template's side tabs down the outer right edge of the journal window. The Overview tab shows the
--- open instance's own icon.
--- @param bookFrame Frame
function InstanceBook:BuildRightSideTabs(bookFrame)
    local window = addonNs.UI.MainFrame.frame or bookFrame

    local function onClick(key)
        if self.activeRightTab == key then
            return
        end
        PlaySound(addonNs.UI.Styles.SOUNDS.TAB)
        self.activeRightTab = key
        -- Quests belong to the dungeon, so opening them leaves the boss page
        if key == "quests" and self.selectedBoss then
            self.selectedBoss = nil
            self.suppressSearchAutoBoss = true
        end
        self.detailScroll:SetVerticalScroll(0)
        self.bossScroll:SetVerticalScroll(0)
        self:UpdateSideTabs()
        self:RefreshLeftPage()
        self:RefreshRightPage()
        if self.onTabChanged then
            self.onTabChanged(key)
        end
    end

    local function onTooltip(tab)
        if tab.tabKey == "overview" then
            GameTooltip:SetText(self:T("overviewTab"), 1.0, 0.82, 0.0)
            if tab.isEnabled then
                GameTooltip:AddLine(self:T("overviewTabHint"), 0.90, 0.90, 0.90, true)
            else
                GameTooltip:AddLine(self:T("overviewTabOff"), 0.75, 0.75, 0.75, true)
                GameTooltip:AddLine(self:T("overviewTabHow"), 0.35, 0.95, 0.45, true)
            end
        elseif tab.tabKey == "quests" then
            GameTooltip:SetText(self:T("questsTab"), 1.0, 0.82, 0.0)
            if tab.isEnabled then
                GameTooltip:AddLine(self:T("questsTabHint"), 0.90, 0.90, 0.90, true)
            else
                GameTooltip:AddLine(self:T("questsTabOff"), 0.75, 0.75, 0.75, true)
            end
        elseif self.selectedBoss then
            GameTooltip:SetText(self:T("encounterLoot", self.selectedBoss.name or "?"), 1.0, 0.82, 0.0)
            GameTooltip:AddLine(self:T("encounterLootHint"), 0.90, 0.90, 0.90, true)
        else
            GameTooltip:SetText(self:T("allLoot"), 1.0, 0.82, 0.0)
            GameTooltip:AddLine(self:T("allLootHint"), 0.90, 0.90, 0.90, true)
        end
    end

    local defs = {}
    for i, tab in ipairs(self.template.tabs) do
        defs[i] = { key = tab.key, title = self:T(tab.title), setIcon = function(icon)
            if tab.atlas then
                icon:SetAtlas(tab.atlas)
            else
                icon:SetTexture(tab.icon)
            end
        end }
    end
    self.sideTabs = Blocks.SideTabs:Create(bookFrame, window, defs, onClick, onTooltip)
    self:UpdateSideTabs()
end

--- Updates the side tabs: which show, which is selected (checked), which are disabled (greyed out),
--- and the Overview tab's icon (the open dungeon's own).
function InstanceBook:UpdateSideTabs()
    if not self.sideTabs then
        return
    end
    local overviewIcon = self.template.tabs[1].icon
    self.sideTabs:Get("overview").icon:SetTexture((self.currentDungeon and self.currentDungeon.icon) or overviewIcon)

    local hasBoss = (self.selectedBoss ~= nil)
    -- Quests come from the DataStore; the tab shows whenever it's on (never on the wing selection page)
    local hasQuestsModule = QuestAccess:IsAvailable() and not self.wingPage
    local hasQuests = false
    if hasQuestsModule and self.currentDungeon then
        local showBoth = self:Setting("showBothFactions") == true
        local factionFilter = showBoth and "All" or (UnitFactionGroup("player") or "Both")
        local _, playerClass = UnitClass("player")
        hasQuests = QuestAccess:HasInstanceQuests(self.currentDungeon, factionFilter, playerClass)
    end

    local overviewEnabled = not hasBoss
    local lootEnabled = not self.wingPage
    if self.wingPage then
        self.activeRightTab = "overview"
    end
    local questsEnabled = hasQuestsModule and hasQuests

    -- A disabled tab can't stay open
    if hasBoss and (self.activeRightTab == "overview" or self.activeRightTab == "quests") then
        self.activeRightTab = "loot"
    elseif not questsEnabled and self.activeRightTab == "quests" then
        self.activeRightTab = "overview"
    end

    self.sideTabs:Update({
        overview = { shown = true, active = overviewEnabled and self.activeRightTab == "overview", enabled = overviewEnabled },
        loot = { shown = not self.wingPage, active = self.activeRightTab == "loot", enabled = lootEnabled },
        quests = { shown = hasQuestsModule, active = questsEnabled and self.activeRightTab == "quests",
            enabled = questsEnabled },
    })
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Adds methods to ns.UI.InstanceBook)
