-- ============================================================================
-- Adventure Journal - Core/UI/TabBar.lua
-- Bottom PanelTabButtonTemplate manager and tab selection state.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local CreateFrame = CreateFrame
local PlaySound = PlaySound
local PanelTemplates_SetNumTabs = PanelTemplates_SetNumTabs
local PanelTemplates_SetTab = PanelTemplates_SetTab
local PanelTemplates_DeselectTab = PanelTemplates_DeselectTab
local PanelTemplates_TabResize = PanelTemplates_TabResize
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

-- Gap between neighboring tabs, as on the game's Character window (CharacterFrame.xml)
local TAB_GAP = 1

--- Fits a tab to its label the way the game's own tabs are sized: the text plus the template's side padding.
--- The template stretches its middle art between the edge pieces, so only the button width is set.
local function resizeTabButton(tabButton)
    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tabButton, 0)
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local TabBar = {
    parentFrame = nil,
    tabs = {},
}

--- Initializes the TabBar manager for `parentFrame`.
--- @param parentFrame Frame Named main window (`JournalBaseMainFrame`)
function TabBar:Init(parentFrame)
    self.parentFrame = parentFrame
    self.tabs = {}

    if parentFrame and parentFrame.HookScript then
        parentFrame:HookScript("OnShow", function()
            self:PositionTabs()
        end)
    end
end

--- Positions all active tabs left-to-right, clearing any points injected by Blizzard's PanelTemplates.
function TabBar:PositionTabs()
    if not self.parentFrame then
        return
    end

    local prevTab = nil

    for _, tab in ipairs(self.tabs) do
        if tab:IsShown() and tab.moduleId then
            tab:ClearAllPoints()
            resizeTabButton(tab)

            if not prevTab then
                tab:SetPoint("TOPLEFT", self.parentFrame, "BOTTOMLEFT", 11, 2)
            else
                tab:SetPoint("TOPLEFT", prevTab, "TOPRIGHT", TAB_GAP, 0)
            end
            prevTab = tab
        end
    end
end

--- Acquires or creates the `index`-th bottom tab button on `JournalBaseMainFrame`.
--- Note: Blizzard's `PanelTemplates_SetNumTabs` requires global `$parentTabN` naming.
--- @param index number
--- @return Button
function TabBar:AcquireTab(index)
    local tab = self.tabs[index]
    if tab then
        return tab
    end

    local parentName = self.parentFrame:GetName() or "JournalBaseMainFrame"
    local tabName = parentName .. "Tab" .. index
    tab = CreateFrame("Button", tabName, self.parentFrame, "PanelTabButtonTemplate", index)

    tab:SetScript("OnClick", function(btn)
        if PlaySound then
            PlaySound(Constants.SOUNDS.TAB)
        end
        if btn.moduleId then
            ns.ModuleRegistry:ActivateModule(btn.moduleId)
        end
    end)

    if tab.HookScript then
        tab:HookScript("OnShow", function(btn)
            resizeTabButton(btn)
            self:PositionTabs()
        end)
    end

    self.tabs[index] = tab
    return tab
end

--- Rebuilds and positions bottom tabs to match the currently registered modules.
--- Tabs anchor left-to-right from `BOTTOMLEFT`.
--- @param orderedModules table[]
function TabBar:RefreshTabs(orderedModules)
    if not self.parentFrame then
        return
    end

    for _, tab in ipairs(self.tabs) do
        tab:Hide()
        tab.moduleId = nil
    end

    local count = #orderedModules
    if count == 0 then
        return
    end

    for index, module in ipairs(orderedModules) do
        local tab = self:AcquireTab(index)
        tab.moduleId = module.id
        tab:SetText(module.title)
        tab:Show()
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(self.parentFrame, count)
    end

    self:PositionTabs()
end

--- Visually selects the bottom tab corresponding to `moduleId`.
--- @param moduleId string
function TabBar:SelectModule(moduleId)
    if not self.parentFrame then
        return
    end

    for index, tab in ipairs(self.tabs) do
        if tab:IsShown() and tab.moduleId == moduleId then
            if PanelTemplates_SetTab then
                PanelTemplates_SetTab(self.parentFrame, index)
            end
            self:PositionTabs()
            return
        end
    end
end

--- Deselects all bottom module tabs (used when viewing the base `Home` screen).
function TabBar:ClearSelection()
    if not self.parentFrame then
        return
    end
    self.parentFrame.selectedTab = nil
    for _, tab in ipairs(self.tabs) do
        if tab:IsShown() and PanelTemplates_DeselectTab then
            PanelTemplates_DeselectTab(tab)
        end
    end
    self:PositionTabs()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.TabBar = TabBar
