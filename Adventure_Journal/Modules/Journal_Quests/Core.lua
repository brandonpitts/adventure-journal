-- ============================================================================
-- Journal_Quests - Core.lua
-- Registers the standalone Quests plugin with Journal_Base.
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
local QuestsPlugin = {
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

--- Called once by `Journal_Base` when the Quests tab is first opened.
--- @param canvas Frame
function QuestsPlugin:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Quests bottom tab is selected or when `Quests` is
--- clicked in the breadcrumb navigation track (`Home > Quests`).
function QuestsPlugin:OnActivate()
    ns.UI.MainView:ShowRoot()
end

--- Called when the user switches away to Home or another plugin tab.
function QuestsPlugin:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Quests is active.
--- @param queryText string
function QuestsPlugin:OnSearch(queryText)
    -- Phase 2: Filter quest entries by `queryText`.
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(QuestsPlugin)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Plugin = QuestsPlugin

