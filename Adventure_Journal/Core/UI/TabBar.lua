-- ============================================================================
-- Journal_Base - UI/TabBar.lua
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

--- Applies native Blizzard tab sizing if `PanelTemplates_TabResize` is present.
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

    if index == 1 then
        tab:SetPoint("TOPLEFT", self.parentFrame, "BOTTOMLEFT", 11, 2)
    else
        tab:SetPoint("LEFT", self.tabs[index - 1], "RIGHT", -14, 0)
    end

    tab:SetScript("OnClick", function(btn)
        if PlaySound then
            PlaySound(Constants.SOUNDS.TAB)
        end
        if btn.pluginId then
            ns.PluginRegistry:ActivatePlugin(btn.pluginId)
        end
    end)

    self.tabs[index] = tab
    return tab
end

--- Rebuilds and positions bottom tabs to match the currently registered plugins.
--- @param orderedPlugins table[]
function TabBar:RefreshTabs(orderedPlugins)
    if not self.parentFrame then
        return
    end

    for _, tab in ipairs(self.tabs) do
        tab:Hide()
        tab.pluginId = nil
    end

    local count = #orderedPlugins
    if count == 0 then
        return
    end

    for index, plugin in ipairs(orderedPlugins) do
        local tab = self:AcquireTab(index)
        tab.pluginId = plugin.id
        tab:SetText(plugin.title)
        resizeTabButton(tab)
        tab:Show()
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(self.parentFrame, count)
    end
end

--- Visually selects the bottom tab corresponding to `pluginId`.
--- @param pluginId string
function TabBar:SelectPlugin(pluginId)
    if not self.parentFrame then
        return
    end

    for index, tab in ipairs(self.tabs) do
        if tab:IsShown() and tab.pluginId == pluginId then
            if PanelTemplates_SetTab then
                PanelTemplates_SetTab(self.parentFrame, index)
            end
            return
        end
    end
end

--- Deselects all bottom plugin tabs (used when viewing the base `Home` screen).
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
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.TabBar = TabBar

