-- ============================================================================
-- Journal_Raids - Core.lua
-- Registers the standalone Raids plugin with Journal_Base.
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
local RaidsPlugin = {
    id = Constants.PLUGIN_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    version = Constants.VERSION,
    lastUpdated = Constants.LAST_UPDATED,
    description = Constants.DESCRIPTION,
    apiVersion = Constants.API_VERSION,
    order = Constants.TAB_ORDER,
    icon = Constants.ASSETS.ICON,
}

--- Called once by `Journal_Base` when the Raids tab is first opened.
--- @param canvas Frame
function RaidsPlugin:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Raids bottom tab is selected or when `Raids` is
--- clicked in the breadcrumb navigation track (`Home > Raids`).
function RaidsPlugin:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another plugin tab.
function RaidsPlugin:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Raids is active.
--- @param queryText string
function RaidsPlugin:OnSearch(queryText)
    -- Phase 2: Filter raid cards by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(RaidsPlugin)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Plugin = RaidsPlugin

