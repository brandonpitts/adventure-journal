-- ============================================================================
-- Journal_Base - UI/TabBar.lua
-- Bottom PanelTabButtonTemplate manager and tab selection state.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local _G = _G
local ipairs = ipairs
local math = math
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

--- Applies native Blizzard tab sizing strictly fitted to the tab's text string width
--- so tabs never stretch across empty space.
local function resizeTabButton(tabButton)
    local tabName = tabButton:GetName()
    local fs = tabButton:GetFontString()
        or tabButton.Text
        or (tabName and _G[tabName .. "Text"])

    local textWidth = nil
    if fs then
        fs:SetWidth(0)
        if fs.GetStringWidth then
            local w = fs:GetStringWidth()
            if w and w > 0 then
                textWidth = math.ceil(w)
            end
        end
    end

    if PanelTemplates_TabResize then
        PanelTemplates_TabResize(tabButton, 0, nil, nil, nil, textWidth)
    end

    -- Enforce compact width based on actual string measurement
    if textWidth and textWidth > 0 then
        local leftTex = tabButton.Left or (tabName and _G[tabName .. "Left"])
        local sideWidths = (leftTex and leftTex.GetWidth and leftTex:GetWidth() and (2 * leftTex:GetWidth())) or 40
        local middleWidth = textWidth + 24
        local totalWidth = middleWidth + sideWidths

        local middleTex = tabButton.Middle or (tabName and _G[tabName .. "Middle"])
        local middleDisabledTex = tabButton.MiddleDisabled or (tabName and _G[tabName .. "MiddleDisabled"])
        local highlightTex = tabButton.HighlightTexture or (tabName and _G[tabName .. "HighlightTexture"])

        if middleTex and middleTex.SetWidth then
            middleTex:SetWidth(middleWidth)
        end
        if middleDisabledTex and middleDisabledTex.SetWidth then
            middleDisabledTex:SetWidth(middleWidth)
        end
        if highlightTex and highlightTex.SetWidth then
            highlightTex:SetWidth(totalWidth)
        end
        tabButton:SetWidth(totalWidth)
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
        if tab:IsShown() and tab.pluginId then
            tab:ClearAllPoints()
            resizeTabButton(tab)

            if not prevTab then
                tab:SetPoint("TOPLEFT", self.parentFrame, "BOTTOMLEFT", 11, 2)
            else
                tab:SetPoint("LEFT", prevTab, "RIGHT", -14, 0)
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
        if btn.pluginId then
            ns.PluginRegistry:ActivatePlugin(btn.pluginId)
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

--- Rebuilds and positions bottom tabs to match the currently registered plugins.
--- Tabs anchor left-to-right from `BOTTOMLEFT`.
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
        tab:Show()
    end

    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(self.parentFrame, count)
    end

    self:PositionTabs()
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
            self:PositionTabs()
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
    self:PositionTabs()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.TabBar = TabBar
