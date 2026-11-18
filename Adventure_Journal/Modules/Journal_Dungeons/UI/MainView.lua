-- ============================================================================
-- Journal_Dungeons - UI/MainView.lua
-- State controller for `Journal_Dungeons`, coordinating:
--   * Level 1 (`Dungeons`): 4-Column Dungeon Browser Grid
--   * Level 2 (`Dungeons > <Dungeon>`): Open-Book Instance Overview
--   * Level 3 (`Dungeons > <Dungeon> > <Boss>`): Boss Encounter Lore & Drops
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local MainView = {
    rootFrame = nil,
    headerBar = nil,
    currentDungeon = nil,
    selectedBoss = nil,
}

--- Initializes the Dungeons views inside `parentCanvas`.
--- @param parentCanvas Frame
--- @param headerBar table|nil
function MainView:Init(parentCanvas, headerBar)
    if self.rootFrame then
        return
    end
    self.headerBar = headerBar

    local root = CreateFrame("Frame", nil, parentCanvas)
    root:SetAllPoints(parentCanvas)
    self.rootFrame = root

    ns.UI.DungeonGridView:Init(root, function(dungeon)
        self:SelectDungeon(dungeon)
    end)

    ns.UI.DungeonBookView:Init(root, {
        onSelectBoss = function(boss)
            self:SelectBoss(boss)
        end,
        onSelectDungeonOverview = function()
            self:ReturnToDungeonOverview()
        end,
        onTabChanged = function(tabKey)
            self:UpdateBreadcrumbs()
        end,
    })
end

--- Synchronizes the breadcrumb track to the current view state:
--- Home > <Dungeon Name> (> <Boss Name> | > Dungeon Quests)
function MainView:UpdateBreadcrumbs()
    if not self.headerBar or not self.headerBar.PopToIndex or not self.headerBar.PushStep then
        return
    end
    if not self.currentDungeon then
        self.headerBar:ResetBreadcrumbs("Home", function()
            self:ShowRoot()
        end)
        return
    end

    self.headerBar:PopToIndex(2)

    if self.selectedBoss then
        local boss = self.selectedBoss
        self.headerBar:PushStep(boss.name, function()
            self:SelectBoss(boss)
        end)
    elseif ns.UI.DungeonBookView and ns.UI.DungeonBookView.activeRightTab == "quests" then
        self.headerBar:PushStep("Dungeon Quests", function()
            -- Already on Dungeon Quests tab
        end)
    end
end

--- Displays the root 4-column Dungeon Browser Grid,
--- resetting any open dungeon/boss book view.
--- @param headerBar table|nil
function MainView:ShowRoot(headerBar)
    if headerBar then
        self.headerBar = headerBar
    end
    if not self.rootFrame then
        return
    end

    self.currentDungeon = nil
    self.selectedBoss = nil

    if self.headerBar and self.headerBar.ResetBreadcrumbs then
        self.headerBar:ResetBreadcrumbs("Home", function()
            self:ShowRoot()
        end)
    end

    if ns.UI.DungeonGridView and ns.UI.DungeonGridView.SetSearchQuery then
        ns.UI.DungeonGridView:SetSearchQuery(self.searchQuery or "")
    end

    self.rootFrame:Show()
    ns.UI.DungeonBookView:Hide()
    ns.UI.DungeonGridView:Show()
end

--- Transitions to the Open-Book Instance View (`Home > <Dungeon Name>`).
--- @param dungeon table
function MainView:SelectDungeon(dungeon)
    if not dungeon then
        return
    end
    self.currentDungeon = dungeon
    self.selectedBoss = nil

    if PlaySound then
        PlaySound(Constants.SOUNDS.PAGE_TURN)
    end

    if self.headerBar and self.headerBar.ResetBreadcrumbs and self.headerBar.PushStep then
        self.headerBar:ResetBreadcrumbs("Home", function()
            self:ShowRoot()
        end)
        self.headerBar:PushStep(dungeon.name, function()
            self:ReturnToDungeonOverview()
        end)
    end

    local query = self.searchQuery or (self.headerBar and self.headerBar.SearchBox and self.headerBar.SearchBox:GetText()) or ""
    ns.UI.DungeonGridView:Hide()
    ns.UI.DungeonBookView:SetContext(dungeon, nil, query)
    ns.UI.DungeonBookView:Show()

    if ns.UI.DungeonBookView.selectedBoss then
        self.selectedBoss = ns.UI.DungeonBookView.selectedBoss
    end
    self:UpdateBreadcrumbs()
end

--- Returns from a selected boss or quest tab back to the main Dungeon page (`Home > <Dungeon Name>`).
--- If currently viewing the Loot tab, preserves the Loot tab to show Full Dungeon Loot
--- while re-enabling the Overview tab so the user can switch back.
function MainView:ReturnToDungeonOverview()
    if not self.currentDungeon then
        self:ShowRoot()
        return
    end
    self.selectedBoss = nil

    local query = self.searchQuery or ""
    local bookView = ns.UI.DungeonBookView
    local preserveRightTab = (bookView and bookView.activeRightTab == "loot")
    bookView:SetContext(self.currentDungeon, nil, query, preserveRightTab)
    bookView:Show()
    self:UpdateBreadcrumbs()
end

--- Selects a boss on the Left Page and pushes `<Boss Name>` to the breadcrumb bar
--- (`Home > <Dungeon Name> > <Boss Name>`).
--- @param boss table
function MainView:SelectBoss(boss)
    if not self.currentDungeon or not boss then
        return
    end
    self.selectedBoss = boss
    self:UpdateBreadcrumbs()
    ns.UI.DungeonBookView:SetSelectedBoss(boss)
end

--- Forwards live search box queries to the active Dungeon view (Grid or Book).
--- @param queryText string
function MainView:OnSearch(queryText)
    self.searchQuery = queryText or ""
    if self.currentDungeon and ns.UI.DungeonBookView and ns.UI.DungeonBookView.SetSearchQuery then
        ns.UI.DungeonBookView:SetSearchQuery(queryText or "")
        local selected = ns.UI.DungeonBookView.selectedBoss
        if selected and self.selectedBoss ~= selected then
            self.selectedBoss = selected
            self:UpdateBreadcrumbs()
        elseif not selected and self.selectedBoss then
            self.selectedBoss = nil
            self:UpdateBreadcrumbs()
        end
    else
        ns.UI.DungeonGridView:SetSearchQuery(queryText or "")
    end
end

--- Hides the Dungeons view when switching away.
function MainView:Hide()
    if self.rootFrame then
        self.rootFrame:Hide()
    end
    if ns.UI.DungeonBookView and ns.UI.DungeonBookView.Hide then
        ns.UI.DungeonBookView:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.MainView = MainView
