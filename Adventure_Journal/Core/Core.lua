-- ============================================================================
-- Journal_Base - Core.lua
-- Addon bootstrap, centralized event dispatcher, slash commands, and public API.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local print = print
local tostring = tostring
local strtrim = strtrim
local CreateFrame = CreateFrame
local Constants = ns.Constants

-- Required global localization strings for `Bindings.xml`
_G.BINDING_HEADER_JOURNALBASE = Constants.TITLE
_G.BINDING_NAME_JOURNALBASE_TOGGLE = "Toggle Adventure Journal"

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Normalizes a slash command argument string.
--- @param msg string|nil
--- @return string
local function normalizeCommand(msg)
    if not msg then
        return ""
    end
    if strtrim then
        return strtrim(msg):lower()
    end
    return msg:match("^%s*(.-)%s*$"):lower()
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local JournalBase = {
    VERSION = Constants.VERSION,
    PLUGIN_API_VERSION = Constants.PLUGIN_API_VERSION,
    HolidayManager = ns.HolidayManager,
}

--- Standardized chat message helper prefixed with `[Journal]`.
--- @param message string
function JournalBase:Print(message)
    print(Constants.CHAT_PREFIX .. tostring(message or ""))
end

--- Toggles the main Journal window open or closed.
function JournalBase:Toggle()
    ns.UI.MainFrame:Toggle()
end

--- Opens the main Journal window.
function JournalBase:Show()
    ns.UI.MainFrame:Show()
end

--- Closes the main Journal window.
function JournalBase:Hide()
    ns.UI.MainFrame:Hide()
end

--- Opens the native WoW Options -> AddOns -> Journal settings category.
function JournalBase:OpenSettings()
    ns.UI.SettingsPanel:Open()
end

--- Public contract for standalone `Journal_*` plugins to register a tab.
--- @param pluginDef table
--- @return boolean success, string|nil errorMessage
function JournalBase:RegisterPlugin(pluginDef)
    local ok, err = ns.PluginRegistry:Register(pluginDef)
    if not ok and err then
        self:Print(err)
    end
    return ok, err
end

--- Retrieves a registered plugin by its `id`.
--- @param pluginId string
--- @return table|nil
function JournalBase:GetPlugin(pluginId)
    return ns.PluginRegistry:GetPlugin(pluginId)
end

--- Activates the Journal Base "Home" screen and resets breadcrumbs to `Home`.
function JournalBase:ActivateHome()
    ns.PluginRegistry:ActivateHome()
end

-- ----------------------------------------------------------------------------
-- Breadcrumb Navigation Subsystem (Public API)
-- ----------------------------------------------------------------------------

--- Sets the active breadcrumb trail across the recessed header track.
--- @param crumbList table Array of `{ id, label, onClick }`
function JournalBase:SetBreadcrumbs(crumbList)
    local headerBar = ns.UI.MainFrame and ns.UI.MainFrame:GetHeaderBar()
    if headerBar and headerBar.SetBreadcrumbs then
        headerBar:SetBreadcrumbs(crumbList)
    end
end

--- Appends a new breadcrumb step onto the header navigation track.
--- @param label string
--- @param onClick function|nil
--- @param id string|nil
function JournalBase:PushBreadcrumb(label, onClick, id)
    local headerBar = ns.UI.MainFrame and ns.UI.MainFrame:GetHeaderBar()
    if headerBar and headerBar.PushStep then
        headerBar:PushStep(label, onClick, id)
    end
end

--- Pops the breadcrumb trail back to `targetIndex`.
--- @param targetIndex number
function JournalBase:PopBreadcrumb(targetIndex)
    local headerBar = ns.UI.MainFrame and ns.UI.MainFrame:GetHeaderBar()
    if headerBar and headerBar.PopToIndex then
        headerBar:PopToIndex(targetIndex)
    end
end

--- Resets the breadcrumb trail back to the root level.
--- @param rootLabel string|nil
--- @param onRootClick function|nil
function JournalBase:ResetBreadcrumbs(rootLabel, onRootClick)
    local headerBar = ns.UI.MainFrame and ns.UI.MainFrame:GetHeaderBar()
    if headerBar and headerBar.ResetBreadcrumbs then
        headerBar:ResetBreadcrumbs(rootLabel, onRootClick)
    end
end

-- ----------------------------------------------------------------------------
-- Module Settings Subsystem (Public API)
-- ----------------------------------------------------------------------------

--- Retrieves a module-specific setting.
--- @param moduleKey string
--- @param settingKey string
--- @param defaultVal any
--- @return any
function JournalBase:GetModuleSetting(moduleKey, settingKey, defaultVal)
    return ns.Database:GetModuleSetting(moduleKey, settingKey, defaultVal)
end

--- Persists a module-specific setting.
--- @param moduleKey string
--- @param settingKey string
--- @param val any
function JournalBase:SetModuleSetting(moduleKey, settingKey, val)
    ns.Database:SetModuleSetting(moduleKey, settingKey, val)
    if self.OnModuleSettingChanged then
        self:OnModuleSettingChanged(moduleKey, settingKey, val)
    end
end

--- Convenience getter for Dungeons module settings.
--- @param key string
--- @param defaultVal any
--- @return any
function JournalBase:GetDungeonSetting(key, defaultVal)
    return ns.Database:GetDungeonSetting(key, defaultVal)
end

--- Convenience setter for Dungeons module settings.
--- @param key string
--- @param val any
function JournalBase:SetDungeonSetting(key, val)
    ns.Database:SetDungeonSetting(key, val)
    if self.OnDungeonSettingChanged then
        self:OnDungeonSettingChanged(key, val)
    end
    if self.OnModuleSettingChanged then
        self:OnModuleSettingChanged("dungeons", key, val)
    end
end

-- ----------------------------------------------------------------------------
-- Side Tab Subsystem (Public API)
-- ----------------------------------------------------------------------------

-- Centralized Table-Driven Event Dispatcher
local EventDispatcher = CreateFrame("Frame")

function EventDispatcher:ADDON_LOADED(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    ns.Database:Init()
    ns.PluginRegistry:RegisterBuiltInPlugins()
    ns.UI.MainFrame:Init()
    ns.UI.MinimapButton:Init()
    ns.UI.SettingsPanel:Init()
end

function EventDispatcher:PLAYER_ENTERING_WORLD()
    ns.UI.MinimapButton:RefreshVisibility()
    ns.UI.SettingsPanel:Refresh()
    ns.UI.MainFrame:OnPluginsChanged()
end

EventDispatcher:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

EventDispatcher:RegisterEvent("ADDON_LOADED")
EventDispatcher:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Slash Commands (/journal, /jb)
_G.SLASH_JOURNALBASE1 = "/journal"
_G.SLASH_JOURNALBASE2 = "/jb"

_G.SlashCmdList.JOURNALBASE = function(msg)
    local cmd = normalizeCommand(msg)
    if cmd == "settings" or cmd == "options" or cmd == "config" then
        JournalBase:OpenSettings()
        return
    end
    JournalBase:Toggle()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Core = JournalBase
_G.JournalBase = JournalBase

