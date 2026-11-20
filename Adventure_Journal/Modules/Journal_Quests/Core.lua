-- ============================================================================
-- Journal_Quests - Core.lua
-- Registers the Quests module with the Journal.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Quests or {} ; parent.Quests = ns

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
local QuestsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ASSETS.ICON,
}

--- Called once by the Journal when the Quests tab is first opened.
--- @param canvas Frame
function QuestsModule:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Quests bottom tab is selected or when `Quests` is
--- clicked in the breadcrumb navigation track (`Home > Quests`).
function QuestsModule:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another module tab.
function QuestsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Quests is active.
--- @param queryText string
function QuestsModule:OnSearch(queryText)
    -- Phase 2: Filter quest entries by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(QuestsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = QuestsModule

