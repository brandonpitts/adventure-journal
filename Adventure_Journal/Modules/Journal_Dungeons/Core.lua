-- ============================================================================
-- Journal_Dungeons - Core.lua
-- Registers the standalone Dungeons plugin with Journal_Base.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

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
local DungeonsPlugin = {
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

--- Called once by `Journal_Base` when the Dungeons tab is first opened.
--- @param canvas Frame
--- @param headerBar table|nil
function DungeonsPlugin:OnInitialize(canvas, headerBar)
    ns.UI.MainView:Init(canvas, headerBar)
end

--- Called whenever the Dungeons bottom tab is selected or when `Dungeons` is
--- clicked in the breadcrumb navigation track.
--- @param _canvas Frame
--- @param headerBar table|nil
function DungeonsPlugin:OnActivate(_canvas, headerBar)
    ns.UI.MainView:ShowRoot(headerBar)
end

--- Called when the user switches away to another plugin tab.
function DungeonsPlugin:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Dungeons is active.
--- @param queryText string
function DungeonsPlugin:OnSearch(queryText)
    ns.UI.MainView:OnSearch(queryText)
end

if _G.JournalBase and _G.JournalBase.RegisterPlugin then
    _G.JournalBase:RegisterPlugin(DungeonsPlugin)
end

_G.JournalDungeons = {
    ns = ns,
    ItemsManager = ns.ItemsManager,
}

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Plugin = DungeonsPlugin
