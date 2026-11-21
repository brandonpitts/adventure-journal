-- ============================================================================
-- Adventure Journal - Core/Core.lua
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

--- Returns whether the Adventure Journal window is locked against dragging.
--- @return boolean
function JournalBase:IsWindowLocked()
    return ns.Settings and ns.Settings.IsWindowLocked and ns.Settings:IsWindowLocked() or false
end

--- Sets whether the Adventure Journal window is locked against dragging.
--- @param isLocked boolean
function JournalBase:SetWindowLocked(isLocked)
    if ns.Settings and ns.Settings.SetWindowLocked then
        ns.Settings:SetWindowLocked(isLocked)
    end
end

--- Public contract for Journal modules to register a tab.
--- @param moduleDef table
--- @return boolean success, string|nil errorMessage
function JournalBase:RegisterModule(moduleDef)
    local ok, err = ns.ModuleRegistry:Register(moduleDef)
    if not ok and err then
        self:Print(err)
    end
    return ok, err
end

--- Retrieves a registered module by its `id`.
--- @param moduleId string
--- @return table|nil
function JournalBase:GetModule(moduleId)
    return ns.ModuleRegistry:GetModule(moduleId)
end

--- Activates the tab used last, or the first enabled tab (e.g. Dungeons).
function JournalBase:ActivateDefaultModule()
    ns.ModuleRegistry:ActivateDefaultModule()
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
    return ns.Settings:GetModuleSetting(moduleKey, settingKey, defaultVal)
end

--- Persists a module-specific setting.
--- @param moduleKey string
--- @param settingKey string
--- @param val any
function JournalBase:SetModuleSetting(moduleKey, settingKey, val)
    ns.Settings:SetModuleSetting(moduleKey, settingKey, val)
    if self.OnModuleSettingChanged then
        self:OnModuleSettingChanged(moduleKey, settingKey, val)
    end
end

--- Convenience getter for Dungeons module settings.
--- @param key string
--- @param defaultVal any
--- @return any
function JournalBase:GetDungeonSetting(key, defaultVal)
    return ns.Settings:GetDungeonSetting(key, defaultVal)
end

--- Convenience setter for Dungeons module settings.
--- @param key string
--- @param val any
function JournalBase:SetDungeonSetting(key, val)
    ns.Settings:SetDungeonSetting(key, val)
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

-- ----------------------------------------------------------------------------
-- Blizzard Addon Compartment Support
-- ----------------------------------------------------------------------------
function _G.AdventureJournal_OnAddonCompartmentClick(addonName, mouseButton)
    if mouseButton == "RightButton" then
        JournalBase:OpenSettings()
    else
        JournalBase:Toggle()
    end
end

function _G.AdventureJournal_OnAddonCompartmentEnter(addonName, button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine(Constants.TITLE, 1.0, 0.82, 0.0)
    GameTooltip:AddLine("Left-click to toggle Adventure Journal.", 1, 1, 1, true)
    GameTooltip:AddLine("Right-click to open Settings.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

function _G.AdventureJournal_OnAddonCompartmentLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function RegisterAddonCompartment()
    if _G.AddonCompartmentFrame and _G.AddonCompartmentFrame.RegisterAddOn then
        if ns.Settings and not ns.Settings:IsAddonCompartmentShown() then
            return
        end
        _G.AddonCompartmentFrame:RegisterAddOn({
            text = Constants.TITLE,
            icon = Constants.ASSETS.FALLBACK_ICON,
            notCheckable = true,
            func = function(button, menuInputData, menu)
                if button == "RightButton" then
                    JournalBase:OpenSettings()
                else
                    JournalBase:Toggle()
                end
            end,
            funcOnEnter = function(button)
                _G.AdventureJournal_OnAddonCompartmentEnter(addonName, button)
            end,
            funcOnLeave = function()
                _G.AdventureJournal_OnAddonCompartmentLeave()
            end,
        })
    end
end

-- Centralized Table-Driven Event Dispatcher
local EventDispatcher = CreateFrame("Frame")

function EventDispatcher:ADDON_LOADED(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")

    ns.Settings:Init()
    ns.ModuleRegistry:PurgeDisabledModules()
    ns.UI.MainFrame:Init()
    ns.UI.MinimapButton:Init()
    ns.UI.SettingsPanel:Init()
    RegisterAddonCompartment()
end

function EventDispatcher:PLAYER_ENTERING_WORLD()
    ns.UI.MinimapButton:RefreshVisibility()
    ns.UI.SettingsPanel:Refresh()
    ns.UI.MainFrame:OnModulesChanged()
end

EventDispatcher:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

EventDispatcher:RegisterEvent("ADDON_LOADED")
EventDispatcher:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Slash Commands (/journal, /jb, /aj)
_G.SLASH_JOURNALBASE1 = "/journal"
_G.SLASH_JOURNALBASE2 = "/jb"
_G.SLASH_JOURNALBASE3 = "/aj"

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

