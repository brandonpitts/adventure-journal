-- ============================================================================
-- Journal_Professions - Core.lua
-- Registers the standalone Professions plugin with Journal_Base.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Professions or {} ; parent.Professions = ns

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
local ProfessionsPlugin = {
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

--- Called once by `Journal_Base` when the Professions tab is first opened.
--- @param canvas Frame
function ProfessionsPlugin:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Professions bottom tab is selected or when `Professions` is
--- clicked in the breadcrumb navigation track (`Home > Professions`).
function ProfessionsPlugin:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another plugin tab.
function ProfessionsPlugin:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Professions is active.
--- @param queryText string
function ProfessionsPlugin:OnSearch(queryText)
    -- Phase 2: Filter profession recipes/trainers by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(ProfessionsPlugin)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Plugin = ProfessionsPlugin

