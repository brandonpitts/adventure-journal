-- ============================================================================
-- Journal_Raids - Core.lua
-- Registers the Raids module with the Journal.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Raids or {} ; parent.Raids = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local RaidsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ASSETS.ICON,
}

--- Called once by the Journal when the Raids tab is first opened.
--- @param canvas Frame
function RaidsModule:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Raids bottom tab is selected or when `Raids` is
--- clicked in the breadcrumb navigation track (`Home > Raids`).
function RaidsModule:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another module tab.
function RaidsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Raids is active.
--- @param queryText string
function RaidsModule:OnSearch(queryText)
    -- Phase 2: Filter raid cards by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(RaidsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = RaidsModule

