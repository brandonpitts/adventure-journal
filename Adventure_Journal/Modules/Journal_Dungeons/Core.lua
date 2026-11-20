-- ============================================================================
-- Journal_Dungeons - Core.lua
-- Registers the Dungeons module with the Journal.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local pairs = pairs
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local DungeonsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ASSETS.ICON,
}

--- Called once by the Journal when the Dungeons tab is first opened.
--- @param canvas Frame
--- @param headerBar table|nil
function DungeonsModule:OnInitialize(canvas, headerBar)
    ns.UI.MainView:Init(canvas, headerBar)
end

--- Called whenever the Dungeons bottom tab is selected: shows the page left open, or the grid.
--- @param _canvas Frame
--- @param headerBar table|nil
function DungeonsModule:OnActivate(_canvas, headerBar)
    ns.UI.MainView:Show(headerBar)
end

--- Called when the Home breadcrumb is clicked: shows the dungeon grid.
--- @param _canvas Frame
--- @param headerBar table|nil
function DungeonsModule:OnHome(_canvas, headerBar)
    ns.UI.MainView:ShowRoot(headerBar)
end

--- Takes focus when the Journal opens while the player is inside a dungeon in the catalog.
--- @return boolean
function DungeonsModule:WantsWindowFocus()
    return ns.Data.DungeonAccess:GetCurrentInstanceDungeon() ~= nil
end

--- Opens the page of the dungeon the player is inside.
function DungeonsModule:OnWindowFocus()
    ns.UI.MainView:OpenCurrentInstance()
end

--- Called when the user switches away to another module tab.
function DungeonsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

--- Called when the user types in the Journal header search box while Dungeons is active.
--- @param queryText string
function DungeonsModule:OnSearch(queryText)
    if ns.UI and ns.UI.MainView then
        ns.UI.MainView:OnSearch(queryText)
    end
end

--- Unloads all Dungeons module data tables, encounter drops, and UI frames from memory
--- when the module is disabled, requiring a UI `/reload` to restore.
function DungeonsModule:OnUnload()
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
        for _, access in pairs(ns.Data) do
            if access.ClearCache then
                access:ClearCache()
            end
        end
        table.wipe(ns.Data)
    end

    table.wipe(ns)
    parent.Dungeons = nil
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(DungeonsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = DungeonsModule
