-- ============================================================================
-- Journal_Quests - Core.lua
-- Registers the Quests module with the Journal. Starts disabled while it is
-- under construction.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Quests or {} ; parent.Quests = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local QuestsModule = {
    id = Constants.MODULE_ID,
    title = Constants.TITLE,
    addonName = Constants.ADDON_NAME,
    description = Constants.DESCRIPTION,
    order = Constants.TAB_ORDER,
    icon = Constants.ICON,
    defaultDisabled = true,
}

--- Called once by the Journal when the Quests tab is first opened.
--- @param canvas Frame
function QuestsModule:OnInitialize(canvas)
    ns.UI.MainView:Init(canvas)
end

--- Called whenever the Quests tab is selected.
function QuestsModule:OnActivate()
    ns.UI.MainView:Show()
end

--- Called when the user switches away to another module tab.
function QuestsModule:OnDeactivate()
    ns.UI.MainView:Hide()
end

if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(QuestsModule)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Module = QuestsModule
