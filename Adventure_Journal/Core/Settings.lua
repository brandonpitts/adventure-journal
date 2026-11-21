-- ============================================================================
-- Adventure Journal - Core/Settings.lua
-- Defensive SavedVariables initialization, schema migration, and state access.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local type = type
local pairs = pairs
local ipairs = ipairs
local xpcall = xpcall
local CallErrorHandler = CallErrorHandler
local Constants = ns.Constants

-- Modules that start disabled until the user enables them: moduleId -> true (filled as modules register)
local defaultDisabledModules = {}
-- Functions called after every module setting change: fn(moduleKey, settingKey, value)
local changeListeners = {}

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Non-destructively merges default values from `src` into `dst`.
--- Preserves any existing user settings already stored in `dst`.
--- @param src table Default schema table
--- @param dst table Target SavedVariables table
--- @return table dst
local function copyDefaults(src, dst)
    if type(dst) ~= "table" then
        dst = {}
    end

    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = copyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end

    return dst
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local Settings = {
    db = nil,
}

--- Initializes `JournalBaseDB` with defensive defaults on ADDON_LOADED.
function Settings:Init()
    _G.JournalBaseDB = copyDefaults(Constants.DB_DEFAULTS, _G.JournalBaseDB)

    -- Schema migration: ensure worldMapDungeonIcons defaults to "min_level" ("After minimum level")
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 3 then
        if _G.JournalBaseDB.dungeons and _G.JournalBaseDB.dungeons.worldMapDungeonIcons == "always" then
            _G.JournalBaseDB.dungeons.worldMapDungeonIcons = "min_level"
        end
        if _G.JournalBaseDB.map_icons and _G.JournalBaseDB.map_icons.worldMapDungeonIcons == "always" then
            _G.JournalBaseDB.map_icons.worldMapDungeonIcons = "min_level"
        end
        _G.JournalBaseDB.schemaVersion = 3
    end

    -- Schema 4 added a default landing tab; schema 8 removes it, so nothing is set here
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 4 then
        _G.JournalBaseDB.schemaVersion = 4
    end

    -- Schema migration: move settings saved under the former "plugin" key names to the "module" keys
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 5 then
        local db = _G.JournalBaseDB
        db.window = db.window or {}
        if db.disabledPlugins ~= nil then
            db.disabledModules = db.disabledPlugins
            db.disabledPlugins = nil
        end
        if db.pluginOrder ~= nil then
            db.moduleOrder = db.pluginOrder
            db.pluginOrder = nil
        end
        db.window.defaultLandingPluginId = nil
        if db.window.lastPluginId ~= nil then
            db.window.lastModuleId = db.window.lastPluginId
            db.window.lastPluginId = nil
        end
        db.window.homePluginId = nil
        db.schemaVersion = 5
    end

    -- Schema migration: the retired Quests module's one setting moves to the Dungeons settings
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 6 then
        local db = _G.JournalBaseDB
        if db.quests and db.quests.showBothFactionData ~= nil then
            db.dungeons.showBothFactionData = db.quests.showBothFactionData
        end
        db.quests = nil
        if db.disabledModules then
            db.disabledModules.utility_quests = nil
        end
        db.schemaVersion = 6
    end

    -- Schema migration: tabs can no longer be reordered, so the saved custom order is dropped
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 7 then
        _G.JournalBaseDB.moduleOrder = nil
        _G.JournalBaseDB.schemaVersion = 7
    end

    -- Schema migration: the default landing tab is gone; the window opens on the instance the player is in,
    -- else the tab used last
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 8 then
        if _G.JournalBaseDB.window then
            _G.JournalBaseDB.window.defaultLandingModuleId = nil
        end
        _G.JournalBaseDB.schemaVersion = 8
    end

    -- Schema migration: the "Legacy" window background is now the "Forever" theme
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 9 then
        local window = _G.JournalBaseDB.window
        if window and window.background == "legacy" then
            window.background = "forever"
        end
        _G.JournalBaseDB.schemaVersion = 9
    end

    -- Schema migration: the dungeon "grid" is the dungeon "list"; its saved sort and layout keep their values
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 10 then
        local dungeons = _G.JournalBaseDB.dungeons
        if dungeons then
            for old, new in pairs({ dungeonGridSort = "dungeonListSort", dungeonGridLayout = "dungeonListLayout" }) do
                if dungeons[old] ~= nil then
                    dungeons[new] = dungeons[old]
                    dungeons[old] = nil
                end
            end
        end
        _G.JournalBaseDB.schemaVersion = 10
    end

    self.db = _G.JournalBaseDB
end

--- Ensures a valid table is returned even if queried before ADDON_LOADED.
--- @return table
function Settings:GetStore()
    if not self.db then
        self:Init()
    end
    return self.db
end

--- @return boolean
function Settings:IsAddonCompartmentShown()
    local store = self:GetStore()
    if store.showInAddonCompartment ~= nil then
        return store.showInAddonCompartment == true
    end
    return false
end

--- @param isShown boolean
function Settings:SetAddonCompartmentShown(isShown)
    local store = self:GetStore()
    store.showInAddonCompartment = isShown and true or false
end

--- @return boolean
function Settings:IsAdvancedSearchEnabled()
    local store = self:GetStore()
    if store.enableAdvancedSearch ~= nil then
        return store.enableAdvancedSearch == true
    end
    return false
end

--- @param isEnabled boolean
function Settings:SetAdvancedSearchEnabled(isEnabled)
    local store = self:GetStore()
    store.enableAdvancedSearch = isEnabled and true or false
end

--- @return boolean
function Settings:IsMinimapShown()
    local store = self:GetStore()
    if store.minimap.show ~= nil then
        return store.minimap.show == true
    end
    if store.minimap.hide ~= nil then
        return store.minimap.hide == false
    end
    return true
end

--- @param isShown boolean
function Settings:SetMinimapShown(isShown)
    local store = self:GetStore()
    local val = isShown and true or false
    store.minimap.show = val
    store.minimap.hide = not val
end

--- @return boolean
function Settings:IsMinimapHidden()
    return not self:IsMinimapShown()
end

--- @param isHidden boolean
function Settings:SetMinimapHidden(isHidden)
    self:SetMinimapShown(not isHidden)
end

--- @return number Angle in degrees around the Minimap perimeter
function Settings:GetMinimapAngle()
    local store = self:GetStore()
    local angle = store.minimap.angle
    if type(angle) ~= "number" then
        return Constants.MINIMAP.DEFAULT_ANGLE
    end
    return angle
end

--- @param angle number Angle in degrees around the Minimap perimeter
function Settings:SetMinimapAngle(angle)
    if type(angle) ~= "number" then
        return
    end
    local store = self:GetStore()
    store.minimap.angle = angle
end

--- @return string|nil
function Settings:GetLastModuleId()
    local store = self:GetStore()
    return store.window.lastModuleId
end

--- @param moduleId string|nil
function Settings:SetLastModuleId(moduleId)
    local store = self:GetStore()
    store.window.lastModuleId = moduleId
end

--- @return table|nil Saved anchor point `{ point, relativePoint, x, y }`
function Settings:GetWindowPoint()
    local store = self:GetStore()
    return store.window.point
end

--- @param pointTable table|nil `{ point, relativePoint, x, y }`
function Settings:SetWindowPoint(pointTable)
    local store = self:GetStore()
    store.window.point = pointTable
end

--- Returns whether the main Adventure Journal window is locked against dragging.
--- @return boolean
function Settings:IsWindowLocked()
    local store = self:GetStore()
    if store.window and store.window.lockWindow ~= nil then
        return store.window.lockWindow == true
    end
    return false
end

--- Sets whether the main Adventure Journal window is locked against dragging.
--- @param isLocked boolean
function Settings:SetWindowLocked(isLocked)
    local store = self:GetStore()
    store.window = store.window or {}
    store.window.lockWindow = (isLocked == true)
end

--- Returns the window theme's key ("stone", "parchment" or "forever"; see Core/UI/WindowBackground.lua).
--- @return string
function Settings:GetWindowBackground()
    local store = self:GetStore()
    local key = store.window and store.window.background
    local backgrounds = ns.UI and ns.UI.WindowBackground
    if backgrounds and not backgrounds:IsValidKey(key) then
        return backgrounds:GetDefaultKey()
    end
    return key or "stone"
end

--- Saves the window background's key.
--- @param key string
function Settings:SetWindowBackground(key)
    local store = self:GetStore()
    store.window = store.window or {}
    store.window.background = key
end

--- Returns whether the window's corner filigree (with its edge shading, one texture) is shown.
--- @return boolean
function Settings:IsFiligreeShown()
    local store = self:GetStore()
    return not (store.window and store.window.showFiligree == false)
end

--- Sets whether the window's corner filigree is shown.
--- @param shown boolean
function Settings:SetFiligreeShown(shown)
    local store = self:GetStore()
    store.window = store.window or {}
    store.window.showFiligree = (shown == true)
end

--- Returns whether a registered module (`moduleId`) is disabled by the user in Settings.
--- @param moduleId string
--- @return boolean
function Settings:IsModuleDisabled(moduleId)
    if type(moduleId) ~= "string" or moduleId == "" then
        return false
    end
    local store = self:GetStore()
    local saved = store.disabledModules and store.disabledModules[moduleId]
    if saved == nil then
        return defaultDisabledModules[moduleId] == true
    end
    return saved == true
end

--- Marks a module as disabled until the user enables it (a module's `defaultDisabled`).
--- @param moduleId string
function Settings:SetModuleDefaultDisabled(moduleId)
    defaultDisabledModules[moduleId] = true
end

--- Enables or disables a registered module (`moduleId`) in Settings.
--- @param moduleId string
--- @param isDisabled boolean
function Settings:SetModuleDisabled(moduleId, isDisabled)
    if type(moduleId) ~= "string" or moduleId == "" then
        return
    end
    local store = self:GetStore()
    store.disabledModules = store.disabledModules or {}
    -- An enabled module is saved as false, so a module that starts disabled stays enabled once chosen
    store.disabledModules[moduleId] = isDisabled and true or false
end

--- Calls `fn(moduleKey, settingKey, value)` after every module setting change. Returns `fn`.
function Settings:AddChangeListener(fn)
    changeListeners[#changeListeners + 1] = fn
    return fn
end

--- Stops calling `fn` on setting changes.
function Settings:RemoveChangeListener(fn)
    for i = #changeListeners, 1, -1 do
        if changeListeners[i] == fn then
            table.remove(changeListeners, i)
        end
    end
end

--- Tells every listener a setting changed (or that something it depends on did, as when the holiday
--- calendar loads). One failing listener doesn't stop the others.
function Settings:NotifyChange(moduleKey, settingKey, value)
    for _, fn in ipairs(changeListeners) do
        xpcall(fn, CallErrorHandler, moduleKey, settingKey, value)
    end
end

--- Returns a module-specific setting (`store[moduleKey][settingKey]`); without a `defaultVal`, the default
--- from `Constants.DB_DEFAULTS`.
--- @param moduleKey string
--- @param settingKey string
--- @param defaultVal any
--- @return any
function Settings:GetModuleSetting(moduleKey, settingKey, defaultVal)
    if defaultVal == nil then
        local defaults = Constants.DB_DEFAULTS[moduleKey]
        defaultVal = type(defaults) == "table" and defaults[settingKey] or nil
    end
    if type(moduleKey) ~= "string" or type(settingKey) ~= "string" then
        return defaultVal
    end
    local store = self:GetStore()
    local moduleStore = store[moduleKey]
    if type(moduleStore) == "table" and moduleStore[settingKey] ~= nil then
        return moduleStore[settingKey]
    end
    return defaultVal
end

--- Persists a module-specific setting into `store[moduleKey][settingKey]`.
--- @param moduleKey string
--- @param settingKey string
--- @param val any
function Settings:SetModuleSetting(moduleKey, settingKey, val)
    if type(moduleKey) ~= "string" or type(settingKey) ~= "string" then
        return
    end
    local store = self:GetStore()
    store[moduleKey] = store[moduleKey] or {}
    store[moduleKey][settingKey] = val
    self:NotifyChange(moduleKey, settingKey, val)
end

--- Convenience getter for Dungeons module settings.
--- @param key string
--- @param defaultVal any
--- @return any
function Settings:GetDungeonSetting(key, defaultVal)
    return self:GetModuleSetting("dungeons", key, defaultVal)
end

--- Convenience setter for Dungeons module settings.
--- @param key string
--- @param val any
function Settings:SetDungeonSetting(key, val)
    self:SetModuleSetting("dungeons", key, val)
end

--- Convenience getter for Map Icons utility module settings.
--- @param key string
--- @param defaultVal any
--- @return any
function Settings:GetMapIconsSetting(key, defaultVal)
    local val = self:GetModuleSetting("map_icons", key, nil)
    if val ~= nil then
        return val
    end
    if key == "worldMapDungeonIcons" then
        return self:GetDungeonSetting(key, defaultVal)
    end
    return defaultVal
end

--- Convenience setter for Map Icons utility module settings.
--- @param key string
--- @param val any
function Settings:SetMapIconsSetting(key, val)
    self:SetModuleSetting("map_icons", key, val)
    if key == "worldMapDungeonIcons" then
        self:SetDungeonSetting(key, val)
    end
end

--- Returns whether instance quest lists show both factions' quests.
--- @return boolean
function Settings:IsBothFactionQuestsShown()
    return self:GetDungeonSetting("showBothFactionData", false) == true
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Settings = Settings
