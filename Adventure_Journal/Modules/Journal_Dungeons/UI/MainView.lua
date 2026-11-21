-- ============================================================================
-- Journal_Dungeons - UI/MainView.lua
-- State controller for `Journal_Dungeons`, coordinating:
--   * `Home`: the dungeon grid (one card per instance)
--   * `Home > <Dungeon>`: a dungeon's book page, or for a dungeon with wings, its wing page
--   * `Home > <Dungeon> > <Wing>`: a wing's book page (the breadcrumb shows only the wing's name)
--   * `... > <Boss>` or `... > Dungeon Quests`: a boss or the quests tab
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
    wingParent = nil,     -- the dungeon whose wing page (or one of whose wings) is open
    currentDungeon = nil, -- the dungeon or wing whose book page is open
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
        onTabChanged = function()
            self.selectedBoss = ns.UI.DungeonBookView.selectedBoss
            self:UpdateBreadcrumbs()
        end,
    })
end

--- Breadcrumb steps for the open dungeon: Home, the dungeon (or its parent then the wing).
function MainView:PushDungeonSteps()
    local bar = self.headerBar
    if not bar then
        return
    end
    bar:ResetBreadcrumbs("Home", function()
        self:ShowRoot()
    end)
    local wingParent = self.wingParent
    if wingParent then
        bar:PushStep(wingParent.name, function()
            self:ShowWingPage(wingParent)
        end)
    end
    if self.currentDungeon then
        bar:PushStep(self.currentDungeon.name, function()
            self:ReturnToDungeonOverview()
        end)
    end
end

--- Synchronizes the breadcrumb track to the current view state.
function MainView:UpdateBreadcrumbs()
    if not self.headerBar or not self.headerBar.PopToIndex or not self.headerBar.PushStep then
        return
    end
    if not self.currentDungeon and not self.wingParent then
        self.headerBar:ResetBreadcrumbs("Home", function()
            self:ShowRoot()
        end)
        return
    end
    self:PushDungeonSteps()
    if not self.currentDungeon then
        return
    end

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

--- Displays the dungeon grid, closing any open book or wing page.
--- @param headerBar table|nil
function MainView:ShowRoot(headerBar)
    if headerBar then
        self.headerBar = headerBar
    end
    if not self.rootFrame then
        return
    end

    self.wingParent = nil
    self.currentDungeon = nil
    self.selectedBoss = nil
    self:UpdateBreadcrumbs()

    if ns.UI.DungeonGridView and ns.UI.DungeonGridView.SetSearchQuery then
        ns.UI.DungeonGridView:SetSearchQuery(self.searchQuery or "")
    end

    self.rootFrame:Show()
    ns.UI.DungeonBookView:Hide()
    ns.UI.DungeonGridView:Show()
end

--- Restores the previously open book or wing view when returning to the Dungeons tab,
--- or opens the root grid when no dungeon is currently open.
--- @param headerBar table|nil
function MainView:Show(headerBar)
    if headerBar then
        self.headerBar = headerBar
    end
    if not self.rootFrame then
        return
    end
    if self.currentDungeon or self.wingParent then
        self.rootFrame:Show()
        ns.UI.DungeonGridView:Hide()
        ns.UI.DungeonBookView:Show()
        self:UpdateBreadcrumbs()
        return
    end
    self:ShowRoot(headerBar)
end

--- Opens the dungeon or wing the player is inside, keeping the open boss or tab when its page is already
--- open. When the wing is unknown, opens the wing page unless a page of that instance is already open.
function MainView:OpenCurrentInstance()
    local target = ns.Data.DungeonAccess:GetCurrentInstanceDungeon()
    if not target then
        return
    end
    if target.wingKey then
        if not (self.currentDungeon and self.currentDungeon.key == target.key) then
            self:SelectWing(target)
        end
        return
    end
    local open = self.currentDungeon or self.wingParent
    if open and open.instanceID == target.instanceID then
        return
    end
    self:SelectDungeon(target)
end

--- Opens a grid entry: its wing page when it has wings, otherwise its book page.
--- @param dungeon table a dungeon view (DungeonAccess)
function MainView:SelectDungeon(dungeon)
    if not dungeon then
        return
    end
    if dungeon.wingCount and dungeon.wingCount > 0 then
        self:ShowWingPage(dungeon)
        return
    end
    self.wingParent = nil
    self:OpenBook(dungeon)
end

--- Shows a dungeon's wing selection page (`Home > <Dungeon>`).
--- @param dungeon table a dungeon view with wings
function MainView:ShowWingPage(dungeon)
    self.wingParent = dungeon
    self.currentDungeon = nil
    self.selectedBoss = nil
    if PlaySound then
        PlaySound(Constants.SOUNDS.PAGE_TURN)
    end
    self:UpdateBreadcrumbs()
    ns.UI.DungeonGridView:Hide()
    ns.UI.DungeonBookView:SetWingContext(dungeon, function(wing)
        self:OpenBook(wing)
    end, self.searchQuery or "")
    ns.UI.DungeonBookView:Show()
end

--- Opens a wing's book page directly, with its dungeon in the breadcrumb (`Home > <Dungeon> > <Wing>`).
--- @param wing table a wing view (DungeonAccess)
function MainView:SelectWing(wing)
    self.wingParent = ns.Data.DungeonAccess:GetDungeon(wing.instanceID)
    self:OpenBook(wing)
end

--- Opens a dungeon's or wing's book page.
--- @param dungeon table a dungeon or wing view
function MainView:OpenBook(dungeon)
    self.currentDungeon = dungeon
    self.selectedBoss = nil

    if PlaySound then
        PlaySound(Constants.SOUNDS.PAGE_TURN)
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

--- Returns from a selected boss or quest tab back to the dungeon's book page.
--- If currently viewing the Loot tab, preserves the Loot tab to show Full Dungeon Loot
--- while re-enabling the Overview tab so the user can switch back.
function MainView:ReturnToDungeonOverview()
    if not self.currentDungeon then
        if self.wingParent then
            self:ShowWingPage(self.wingParent)
        else
            self:ShowRoot()
        end
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

--- Selects a boss on the left page and pushes `<Boss Name>` to the breadcrumb bar.
--- @param boss table
function MainView:SelectBoss(boss)
    if not self.currentDungeon or not boss then
        return
    end
    self.selectedBoss = boss
    self:UpdateBreadcrumbs()
    ns.UI.DungeonBookView:SetSelectedBoss(boss)
end

--- Forwards live search box queries to the active Dungeon view (grid or book).
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
    elseif self.wingParent then
        ns.UI.DungeonBookView:SetSearchQuery(queryText or "")
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
