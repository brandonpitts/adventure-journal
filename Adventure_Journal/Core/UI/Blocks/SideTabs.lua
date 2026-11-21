-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/SideTabs.lua
-- Large side tabs down the outside of the Journal window's right edge
-- (Forever's LargeSideTabButtonTemplate). The checked tab is the open one; a
-- disabled tab's icon is greyed out and its clicks are ignored; hidden tabs
-- leave no gap.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local setmetatable = setmetatable
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local TAB_GAP = 2
local DISABLED_ALPHA = 0.45

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local SideTabs = {}
SideTabs.__index = SideTabs

--- Side tabs on `parent`, hung off `window`'s right edge. `defs`: `{ key, title, setIcon(texture) }` in order.
--- `onClick(key)` runs when an enabled tab is clicked; `onTooltip(tab)` fills the tooltip (GameTooltip owned).
function SideTabs:Create(parent, window, defs, onClick, onTooltip)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(48, 170)
    holder:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -70)
    holder:SetFrameStrata("HIGH")
    holder:SetFrameLevel(window:GetFrameLevel() + 15)
    local tabs = setmetatable({ holder = holder, list = {}, byKey = {} }, SideTabs)

    for _, def in ipairs(defs) do
        local tab = CreateFrame("Frame", nil, holder, "LargeSideTabButtonTemplate")
        tab:EnableMouse(true)
        tab.tabKey = def.key
        tab.tooltipText = def.title
        tab.icon = tab.Icon
        def.setIcon(tab.Icon)
        tab:SetFillToInterior(true)
        tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
            if button == "LeftButton" and upInside and tab.isEnabled then
                onClick(tab.tabKey)
            end
        end)
        -- Runs after the template's own OnEnter and replaces its tooltip
        tab:HookScript("OnEnter", function(t)
            GameTooltip:SetOwner(t, "ANCHOR_RIGHT")
            onTooltip(t)
            GameTooltip:Show()
        end)
        tab:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        tab:SetChecked(false)
        tabs.list[#tabs.list + 1] = tab
        tabs.byKey[def.key] = tab
    end
    return tabs
end

--- The tab with `key`.
function SideTabs:Get(key)
    return self.byKey[key]
end

--- Applies `states[key] = { shown, active, enabled }` and stacks the shown tabs 2px apart.
function SideTabs:Update(states)
    for _, tab in ipairs(self.list) do
        local state = states[tab.tabKey]
        tab:SetShown(state.shown)
        tab.isActive = state.active
        tab.isEnabled = state.enabled
        tab:SetChecked(state.active)
        tab.icon:SetDesaturated(not state.enabled)
        tab.icon:SetAlpha(state.enabled and 1 or DISABLED_ALPHA)
    end
    local previous
    for _, tab in ipairs(self.list) do
        tab:ClearAllPoints()
        if tab:IsShown() then
            if previous then
                tab:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -TAB_GAP)
            else
                tab:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 0, 0)
            end
            previous = tab
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks.SideTabs = SideTabs
