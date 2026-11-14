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
    if ns.UI and ns.UI.MainView then
        ns.UI.MainView:OnSearch(queryText)
    end
end

--- Unloads all Dungeons module data tables, encounter drops, and UI frames from memory
--- when the module is disabled, requiring a UI `/reload` to restore.
function DungeonsPlugin:OnUnload()
    if ns.UI then
        if ns.UI.DungeonGridView and ns.UI.DungeonGridView.frame then
            ns.UI.DungeonGridView.frame:UnregisterAllEvents()
            ns.UI.DungeonGridView.frame:SetScript("OnEvent", nil)
            ns.UI.DungeonGridView.frame:SetScript("OnShow", nil)
            ns.UI.DungeonGridView.frame:Hide()
        end
        if ns.UI.DungeonBookView and ns.UI.DungeonBookView.frame then
            ns.UI.DungeonBookView.frame:Hide()
        end
        if ns.UI.MainView and ns.UI.MainView.rootFrame then
            ns.UI.MainView.rootFrame:Hide()
        end
    end

    if _G.JournalBase then
        _G.JournalBase.OnDungeonSettingChanged = nil
    end

    if ns.Data then
        if ns.Data.DungeonsData and type(ns.Data.DungeonsData.dungeons) == "table" then
            table.wipe(ns.Data.DungeonsData.dungeons)
        end
        if ns.Data.ItemsClassic and type(ns.Data.ItemsClassic) == "table" then
            table.wipe(ns.Data.ItemsClassic)
        end
        table.wipe(ns.Data)
    end

    if parent.DropsDungeons and type(parent.DropsDungeons) == "table" then
        table.wipe(parent.DropsDungeons)
        parent.DropsDungeons = nil
    end
    if parent.SourcesOverrides and type(parent.SourcesOverrides) == "table" then
        table.wipe(parent.SourcesOverrides)
        parent.SourcesOverrides = nil
    end
    if parent.ItemDatabase and parent.ItemDatabase.Unload then
        parent.ItemDatabase:Unload()
    end

    table.wipe(ns)
    parent.Dungeons = nil
    _G.JournalDungeons = nil
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
