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
local Constants = ns.Constants

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

    -- Schema migration: enforce a mandatory default landing tab ("dungeons" by default)
    if _G.JournalBaseDB and (_G.JournalBaseDB.schemaVersion or 0) < 4 then
        _G.JournalBaseDB.window = _G.JournalBaseDB.window or {}
        if not _G.JournalBaseDB.window.defaultLandingModuleId or _G.JournalBaseDB.window.defaultLandingModuleId == "" then
            _G.JournalBaseDB.window.defaultLandingModuleId = "dungeons"
        end
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
        if db.window.defaultLandingPluginId ~= nil then
            db.window.defaultLandingModuleId = db.window.defaultLandingPluginId
            db.window.defaultLandingPluginId = nil
        end
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

    if _G.JournalBaseDB and _G.JournalBaseDB.window and (not _G.JournalBaseDB.window.defaultLandingModuleId or _G.JournalBaseDB.window.defaultLandingModuleId == "") then
        _G.JournalBaseDB.window.defaultLandingModuleId = "dungeons"
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

--- Returns the window background's key ("stone", "parchment" or "legacy"; see Core/UI/WindowBackground.lua).
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
    return store.disabledModules and store.disabledModules[moduleId] == true
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
    if isDisabled then
        store.disabledModules[moduleId] = true
    else
        store.disabledModules[moduleId] = nil
    end
end

--- Returns the user's configured default opening / landing module ID.
--- Always returns a valid module ID (defaults to `"dungeons"`).
--- @return string
function Settings:GetDefaultLandingModuleId()
    local store = self:GetStore()
    local id = store.window and store.window.defaultLandingModuleId
    if type(id) == "string" and id ~= "" then
        return id
    end
    return "dungeons"
end

--- Sets the user's preferred default opening / landing module ID.
--- Radio semantics: always stores a non-empty module ID (falls back to `"dungeons"` if nil/empty).
--- @param moduleId string|nil
function Settings:SetDefaultLandingModuleId(moduleId)
    local resolved = (type(moduleId) == "string" and moduleId ~= "") and moduleId or "dungeons"
    local store = self:GetStore()
    store.window = store.window or {}
    store.window.defaultLandingModuleId = resolved
end

--- Returns a module-specific setting (`store[moduleKey][settingKey]`).
--- @param moduleKey string
--- @param settingKey string
--- @param defaultVal any
--- @return any
function Settings:GetModuleSetting(moduleKey, settingKey, defaultVal)
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
