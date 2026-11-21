-- ============================================================================
-- Journal_Raids - Core.lua
-- Registers the Raids module with the Journal. Starts disabled while it is
-- under construction.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Raids or {} ; parent.Raids = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local RaidsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ICON,
    defaultDisabled = true,
}

--- Called once by the Journal when the Raids tab is first opened.
--- @param canvas Frame
function RaidsModule:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Raids tab is selected.
function RaidsModule:OnActivate()
    ns.UI.MainView:Show()
end

--- Called when the user switches away to another module tab.
function RaidsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(RaidsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = RaidsModule
