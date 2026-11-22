-- ============================================================================
-- Adventure Journal - Core/UI/BookNavigator.lua
-- Navigation for an instance module (Dungeons, Raids): the list
-- (`Home`), an instance's book page or, for an instance with wings, its wing
-- page (`Home > <Instance>`), a wing's book page (`Home > <Instance> > <Wing>`),
-- and a boss or the quests tab inside a book (`... > <Boss>`). Keeps the
-- breadcrumbs in step and routes the search box to whichever view is open.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local PlaySound = PlaySound

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local BookNavigator = {}
BookNavigator.__index = BookNavigator

--- A navigator over `def.list` and `def.book` (the module's list and book views) for instances of
--- `def.instanceType`. `def.text`: `{ home, quests }` breadcrumb labels.
function BookNavigator:New(def)
    return setmetatable({ list = def.list, book = def.book, instanceType = def.instanceType, text = def.text },
        BookNavigator)
end

local function access()
    return ns.Data.InstanceAccess
end

local function pageTurn()
    PlaySound(ns.UI.Styles.SOUNDS.PAGE_TURN)
end

--- Builds the list and book inside `canvas`.
function BookNavigator:Init(canvas, headerBar)
    if self.rootFrame then
        return
    end
    self.headerBar = headerBar
    local root = CreateFrame("Frame", nil, canvas)
    root:SetAllPoints(canvas)
    self.rootFrame = root

    -- A favorite wing on the list opens its page directly, with its instance in the breadcrumbs
    self.list:Init(root, function(instance)
        if instance.wingKey then
            self:SelectWing(instance)
        else
            self:SelectInstance(instance)
        end
    end)
    self.book:Init(root, {
        onSelectBoss = function(boss)
            self:SelectBoss(boss)
        end,
        onSelectDungeonOverview = function()
            self:ReturnToOverview()
        end,
        onTabChanged = function()
            self.selectedBoss = self.book.selectedBoss
            self:UpdateBreadcrumbs()
        end,
    })
end

--- Breadcrumb steps for the open instance: Home, the instance (or its parent, then the wing).
function BookNavigator:PushInstanceSteps()
    local bar = self.headerBar
    bar:ResetBreadcrumbs(self.text.home, function()
        self:ShowRoot()
    end)
    local wingParent = self.wingParent
    if wingParent then
        bar:PushStep(wingParent.name, function()
            self:ShowWingPage(wingParent)
        end, nil, function()
            return self:InstanceMenu(wingParent.key)
        end)
    end
    local current = self.current
    if current then
        bar:PushStep(current.name, function()
            self:ReturnToOverview()
        end, nil, function()
            if wingParent then
                return self:WingMenu(wingParent)
            end
            return self:InstanceMenu(current.key)
        end)
    end
end

--- Brings the breadcrumbs in step with what's open.
function BookNavigator:UpdateBreadcrumbs()
    local bar = self.headerBar
    if not bar then
        return
    end
    if not self.current and not self.wingParent then
        bar:ResetBreadcrumbs(self.text.home, function()
            self:ShowRoot()
        end)
        return
    end
    self:PushInstanceSteps()
    if not self.current then
        return
    end
    if self.selectedBoss then
        local boss = self.selectedBoss
        bar:PushStep(boss.name, function()
            self:SelectBoss(boss)
        end, nil, function()
            return self:BossMenu()
        end)
    elseif self.book.activeRightTab == "quests" then
        bar:PushStep(self.text.quests, function() end, nil, function()
            return self:QuestMenu()
        end)
    end
end

--- Shows the list, closing any open book or wing page.
function BookNavigator:ShowRoot(headerBar)
    self.headerBar = headerBar or self.headerBar
    if not self.rootFrame then
        return
    end
    self.wingParent, self.current, self.selectedBoss = nil, nil, nil
    self:UpdateBreadcrumbs()
    self.list:SetSearchQuery(self.searchQuery or "")
    self.rootFrame:Show()
    self.book:Hide()
    self.list:Show()
end

--- Restores the book or wing page left open when the tab is shown again, else the list.
function BookNavigator:Show(headerBar)
    self.headerBar = headerBar or self.headerBar
    if not self.rootFrame then
        return
    end
    if self.current or self.wingParent then
        self.rootFrame:Show()
        self.list:Hide()
        self.book:Show()
        self:UpdateBreadcrumbs()
        return
    end
    self:ShowRoot()
end

--- Opens the instance or wing the player is inside, keeping the open boss or tab when its page is already
--- open. When the wing is unknown, opens the wing page unless a page of that instance is already open.
function BookNavigator:OpenCurrentInstance()
    local target = access():GetCurrentInstance(self.instanceType)
    if not target then
        return
    end
    if target.wingKey then
        if not (self.current and self.current.key == target.key) then
            self:SelectWing(target)
        end
        return
    end
    local open = self.current or self.wingParent
    if open and open.instanceID == target.instanceID then
        return
    end
    self:SelectInstance(target)
end

--- Opens a list entry: its wing page when it has wings, otherwise its book page.
function BookNavigator:SelectInstance(instance)
    if not instance then
        return
    end
    if instance.wingCount and instance.wingCount > 0 then
        self:ShowWingPage(instance)
        return
    end
    self.wingParent = nil
    self:OpenBook(instance)
end

--- Shows an instance's wing selection page.
function BookNavigator:ShowWingPage(instance)
    self.wingParent, self.current, self.selectedBoss = instance, nil, nil
    pageTurn()
    self:UpdateBreadcrumbs()
    self.list:Hide()
    self.book:SetWingContext(instance, function(wing)
        self:OpenBook(wing)
    end, self.searchQuery or "")
    self.book:Show()
end

--- Opens a wing's book page directly, with its instance in the breadcrumbs.
function BookNavigator:SelectWing(wing)
    self.wingParent = access():GetInstance(wing.instanceID)
    self:OpenBook(wing)
end

--- Opens an instance's (or wing's) book page.
function BookNavigator:OpenBook(instance)
    self.current, self.selectedBoss = instance, nil
    pageTurn()
    local query = self.searchQuery or (self.headerBar and self.headerBar.SearchBox and self.headerBar.SearchBox:GetText())
        or ""
    self.list:Hide()
    self.book:SetContext(instance, nil, query)
    self.book:Show()
    self.selectedBoss = self.book.selectedBoss or self.selectedBoss
    self:UpdateBreadcrumbs()
end

--- Returns from a boss or the quests tab to the instance's page. On the Loot tab it stays on Loot (now the
--- whole instance's loot), with Overview enabled again.
function BookNavigator:ReturnToOverview()
    if not self.current then
        if self.wingParent then
            self:ShowWingPage(self.wingParent)
        else
            self:ShowRoot()
        end
        return
    end
    self.selectedBoss = nil
    self.book:SetContext(self.current, nil, self.searchQuery or "", self.book.activeRightTab == "loot")
    self.book:Show()
    self:UpdateBreadcrumbs()
end

--- Selects a boss and adds it to the breadcrumbs.
function BookNavigator:SelectBoss(boss)
    if not self.current or not boss then
        return
    end
    self.selectedBoss = boss
    self:UpdateBreadcrumbs()
    self.book:SetSelectedBoss(boss)
end

--- Sends the search box's text to the open view (book, wing page or list).
function BookNavigator:OnSearch(queryText)
    self.searchQuery = queryText or ""
    if self.current then
        self.book:SetSearchQuery(self.searchQuery)
        local selected = self.book.selectedBoss
        if selected ~= self.selectedBoss then
            self.selectedBoss = selected
            self:UpdateBreadcrumbs()
        end
    elseif self.wingParent then
        self.book:SetSearchQuery(self.searchQuery)
    else
        self.list:SetSearchQuery(self.searchQuery)
    end
end

--- Hides the module's views when switching away.
function BookNavigator:Hide()
    if self.rootFrame then
        self.rootFrame:Hide()
    end
    self.book:Hide()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.BookNavigator = BookNavigator
