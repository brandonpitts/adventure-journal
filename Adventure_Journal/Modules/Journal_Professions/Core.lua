-- ============================================================================
-- Journal_Professions - Core.lua
-- Registers the Professions module with the Journal.
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
local ProfessionsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ASSETS.ICON,
}

--- Called once by the Journal when the Professions tab is first opened.
--- @param canvas Frame
function ProfessionsModule:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Professions bottom tab is selected or when `Professions` is
--- clicked in the breadcrumb navigation track (`Home > Professions`).
function ProfessionsModule:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another module tab.
function ProfessionsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Professions is active.
--- @param queryText string
function ProfessionsModule:OnSearch(queryText)
    -- Phase 2: Filter profession recipes/trainers by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(ProfessionsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = ProfessionsModule

