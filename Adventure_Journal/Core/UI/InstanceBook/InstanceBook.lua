-- ============================================================================
-- Adventure Journal - Core/UI/InstanceBook/InstanceBook.lua
-- An instance book (dungeons, raids) drawn from a template: the left page's
-- header and boss, wing or quest list, the right page's overview, encounter
-- and loot or quest, and the side tabs. Its text, sections, tabs, slots and
-- sizes all come from the template (Core/Templates), the Quests tab's from
-- the template's quest template (Core/UI/QuestGroup); the other files in
-- this folder add its pages, tabs and updates.
-- ============================================================================
local addonName, ns = ...
local addonNs = ns
local Blocks = ns.UI.Blocks

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

-- ----------------------------------------------------------------------------
-- 2. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local InstanceBook = {}
InstanceBook.__index = InstanceBook

--- A book for instances drawn from `template` (a registered template, e.g. "dungeon"). Call Init to build it.
function InstanceBook:New(template)
    return setmetatable({ template = template, activeRightTab = "overview", wingPage = false }, InstanceBook)
end

--- The template's text for `key` (Templates:Text).
function InstanceBook:T(key, ...)
    return ns.Templates:Text(self.template, key, ...)
end

--- One of the page's settings by the template's name for it (`template.settingKeys`).
function InstanceBook:Setting(name)
    return ns.Settings:GetModuleSetting(self.template.settings, self.template.settingKeys[name])
end

--- The icon an encounter shows when it has no portrait (the template's encounter.icon slot).
function InstanceBook:EncounterIcon(boss)
    return ns.Templates.Resolver:Slot(self.template, "encounter.icon", boss, "EncounterStore", boss.key)
end

--- Whether the boss list leaves out encounters known only by name; a template without the setting shows them.
function InstanceBook:HidesIncomplete()
    return self.template.settingKeys.showIncomplete ~= nil and self:Setting("showIncomplete") ~= true
end

--- Initializes the Open-Book Split View inside `parent`.
--- @param parent Frame
--- @param callbacks table `{ onSelectBoss, onSelectDungeonOverview, onTabChanged }`
function InstanceBook:Init(parent, callbacks)
    if self.frame then
        return
    end
    self.onSelectBoss = callbacks and callbacks.onSelectBoss
    self.onSelectDungeonOverview = callbacks and callbacks.onSelectDungeonOverview
    self.onTabChanged = callbacks and callbacks.onTabChanged

    local bookCfg = self.template.layout.book

    local book = Blocks.BookLayout:Create(parent, bookCfg.LEFT_WIDTH, bookCfg.BOSS_BTN_WIDTH + 36)
    self.book = book
    local frame = book.frame
    self.frame = frame
    self.leftPage, self.rightPage = book.leftPage, book.rightPage
    local rightPage = book.rightPage

    -- The left page's header: clicking the dungeon's medallion or name returns to its overview
    self.header = Blocks.PageHeader:Create(book.leftPage, function()
        if self.onSelectDungeonOverview then
            self.onSelectDungeonOverview()
        end
    end, function(owner)
        if not self.currentDungeon then
            return
        end
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.currentDungeon.name, 1.0, 0.82, 0.0)
        if self.selectedBoss then
            if self.activeRightTab == "loot" then
                GameTooltip:AddLine(self:T("headerToAllLoot"), 0.30, 0.92, 0.38)
            else
                GameTooltip:AddLine(self:T("headerToOverview"), 0.30, 0.92, 0.38)
            end
        else
            GameTooltip:AddLine(self:T("headerSelected"), 0.75, 0.75, 0.75)
        end
        GameTooltip:Show()
    end)
    self.dungeonMedallion = self.header.medallion
    self.leftDivider = self.header.divider

    local bossScroll, bossScrollChild = book.listScroll, book.listChild
    self.bossScroll, self.bossScrollChild = bossScroll, bossScrollChild
    self.noEncountersText = book.emptyText

    self.encounterList = Blocks.EncounterList:Create(bossScroll, bossScrollChild, {
        width = bookCfg.BOSS_BTN_WIDTH, height = bookCfg.BOSS_BTN_HEIGHT, gap = bookCfg.BOSS_BTN_GAP,
        iconSize = bookCfg.BOSS_ICON_SIZE, ringSize = bookCfg.BOSS_RING_SIZE,
    }, function(boss)
        if self.onSelectBoss then
            self.onSelectBoss(boss)
        end
    end)

    self.wingList = Blocks.WingList:Create(bossScroll, bossScrollChild, bookCfg.BOSS_BTN_WIDTH,
        bookCfg.WING_BTN_HEIGHT, bookCfg.WING_BTN_GAP, function(wing)
            if self.onSelectWing then
                self.onSelectWing(wing)
            end
        end)
    self.questList = Blocks.QuestList:Create(bossScroll, bossScrollChild, bookCfg.BOSS_BTN_WIDTH + 8,
        bookCfg.BOSS_BTN_HEIGHT, function(quest)
            self.selectedQuest = quest
            self:RefreshLeftPage()
            self:RefreshRightPage()
        end)

    self.encounterDetail = Blocks.EncounterDetail:Create(rightPage, bookCfg.RIGHT_CONTENT_WIDTH)

    -- Sub-Container 1: Instance Overview (Framed Dungeon Art + Lore)
    self.overview = Blocks.OverviewPane:Create(rightPage, bookCfg.ART_FRAME_WIDTH, bookCfg.ART_FRAME_HEIGHT)
    self.overviewPane = self.overview.frame

    -- Sub-Container 2: Scrollable item drop list under the divider
    self.lootList = Blocks.LootList:Create(rightPage, bookCfg.RIGHT_CONTENT_WIDTH)
    self.detailScroll = self.lootList.scroll

    -- Sub-Container 3: Selected Quest Detail View on the Right Page
    local questDetailContainer = CreateFrame("Frame", nil, rightPage)
    questDetailContainer:SetAllPoints(rightPage)
    questDetailContainer:Hide()
    self.questDetailContainer = questDetailContainer

    self.questDetail = Blocks.QuestDetail:Create(questDetailContainer, bookCfg.RIGHT_CONTENT_WIDTH)
    -- The Quests tab's composer, from the template's quest template
    self.quests = ns.UI.QuestGroup:New(ns.Templates:Get(self.template.quests), self)

    -- Overview, Loot and Quests side tabs on the window's right edge
    self:BuildRightSideTabs(frame)

    self:RegisterUpdates(frame)
end

--- Shows a dungeon's wing selection page: its wings on the left, its overview on the right.
--- @param dungeon table a dungeon view with wings (InstanceAccess)
--- @param onSelectWing function `function(wing)`
--- @param searchQuery string|nil the live search; filters the wing list
function InstanceBook:SetWingContext(dungeon, onSelectWing, searchQuery)
    self.wingPage = true
    self.searchQuery = searchQuery or ""
    self.onSelectWing = onSelectWing
    self.currentDungeon = dungeon
    self.selectedBoss = nil
    self.selectedQuest = nil
    self.activeRightTab = "overview"
    self.detailScroll:SetVerticalScroll(0)
    self.bossScroll:SetVerticalScroll(0)
    self:RefreshLeftPage()
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

--- Sets the active dungeon and optional selected boss, then refreshes both pages.
--- @param dungeon table
--- @param boss table|nil
--- @param searchQuery string|nil
--- @param preserveRightTab boolean|nil
function InstanceBook:SetContext(dungeon, boss, searchQuery, preserveRightTab)
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
    self.detailScroll:SetVerticalScroll(0)
    self.bossScroll:SetVerticalScroll(0)
    self:RefreshLeftPage()
    if self.selectedBoss then
        self.activeRightTab = "loot"
    end
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

--- Updates the search query filter for the left page.
--- @param queryText string
function InstanceBook:SetSearchQuery(queryText)
    self.searchQuery = queryText or ""
    self.suppressSearchAutoBoss = false
    if self.frame and self.frame:IsShown() then
        self.bossScroll:SetVerticalScroll(0)
        self:RefreshLeftPage()
        if self.selectedBoss then
            self.activeRightTab = "loot"
        end
        self:UpdateSideTabs()
        self:RefreshRightPage()
    end
end

--- Updates only the selected boss (or `nil` for the overview or the whole instance's loot) and refreshes.
--- @param boss table|nil
function InstanceBook:SetSelectedBoss(boss)
    self.selectedBoss = boss
    if boss then
        self.activeRightTab = "loot"
        self.suppressSearchAutoBoss = false
    else
        self.suppressSearchAutoBoss = true
    end
    self.detailScroll:SetVerticalScroll(0)
    self:RefreshLeftPage()
    self:UpdateSideTabs()
    self:RefreshRightPage()
end

function InstanceBook:Show()
    if self.frame then
        self.frame:Show()
    end
end

function InstanceBook:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.InstanceBook = InstanceBook
