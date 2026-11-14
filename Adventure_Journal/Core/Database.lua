-- ============================================================================
-- Journal_Base - Database.lua
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
local Database = {
    db = nil,
}

--- Initializes `JournalBaseDB` with defensive defaults on ADDON_LOADED.
function Database:Init()
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
        if not _G.JournalBaseDB.window.defaultLandingPluginId or _G.JournalBaseDB.window.defaultLandingPluginId == "" then
            _G.JournalBaseDB.window.defaultLandingPluginId = "dungeons"
            _G.JournalBaseDB.window.homePluginId = "dungeons"
        end
        _G.JournalBaseDB.schemaVersion = 4
    end

    if _G.JournalBaseDB and _G.JournalBaseDB.window and (not _G.JournalBaseDB.window.defaultLandingPluginId or _G.JournalBaseDB.window.defaultLandingPluginId == "") then
        _G.JournalBaseDB.window.defaultLandingPluginId = "dungeons"
        _G.JournalBaseDB.window.homePluginId = "dungeons"
    end

    self.db = _G.JournalBaseDB
end

--- Ensures a valid table is returned even if queried before ADDON_LOADED.
--- @return table
function Database:GetStore()
    if not self.db then
        self:Init()
    end
    return self.db
end

--- @return boolean
function Database:IsAddonCompartmentShown()
    local store = self:GetStore()
    if store.showInAddonCompartment ~= nil then
        return store.showInAddonCompartment == true
    end
    return true
end

--- @param isShown boolean
function Database:SetAddonCompartmentShown(isShown)
    local store = self:GetStore()
    store.showInAddonCompartment = isShown and true or false
end

--- @return boolean
function Database:IsAdvancedSearchEnabled()
    local store = self:GetStore()
    if store.enableAdvancedSearch ~= nil then
        return store.enableAdvancedSearch == true
    end
    return false
end

--- @param isEnabled boolean
function Database:SetAdvancedSearchEnabled(isEnabled)
    local store = self:GetStore()
    store.enableAdvancedSearch = isEnabled and true or false
end

--- @return boolean
function Database:IsMinimapShown()
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
function Database:SetMinimapShown(isShown)
    local store = self:GetStore()
    local val = isShown and true or false
    store.minimap.show = val
    store.minimap.hide = not val
    if not val then
        self:SetAddonCompartmentShown(true)
    end
end

--- @return boolean
function Database:IsMinimapHidden()
    return not self:IsMinimapShown()
end

--- @param isHidden boolean
function Database:SetMinimapHidden(isHidden)
    self:SetMinimapShown(not isHidden)
end

--- @return number Angle in degrees around the Minimap perimeter
function Database:GetMinimapAngle()
    local store = self:GetStore()
    local angle = store.minimap.angle
    if type(angle) ~= "number" then
        return Constants.MINIMAP.DEFAULT_ANGLE
    end
    return angle
end

--- @param angle number Angle in degrees around the Minimap perimeter
function Database:SetMinimapAngle(angle)
    if type(angle) ~= "number" then
        return
    end
    local store = self:GetStore()
    store.minimap.angle = angle
end

--- @return string|nil
function Database:GetLastPluginId()
    local store = self:GetStore()
    return store.window.lastPluginId
end

--- @param pluginId string|nil
function Database:SetLastPluginId(pluginId)
    local store = self:GetStore()
    store.window.lastPluginId = pluginId
end

--- @return table|nil Saved anchor point `{ point, relativePoint, x, y }`
function Database:GetWindowPoint()
    local store = self:GetStore()
    return store.window.point
end

--- @param pointTable table|nil `{ point, relativePoint, x, y }`
function Database:SetWindowPoint(pointTable)
    local store = self:GetStore()
    store.window.point = pointTable
end

--- Returns whether a registered plugin (`pluginId`) is disabled by the user in Settings.
--- @param pluginId string
--- @return boolean
function Database:IsPluginDisabled(pluginId)
    if type(pluginId) ~= "string" or pluginId == "" then
        return false
    end
    local store = self:GetStore()
    return store.disabledPlugins and store.disabledPlugins[pluginId] == true
end

--- Enables or disables a registered plugin (`pluginId`) in Settings.
--- @param pluginId string
--- @param isDisabled boolean
function Database:SetPluginDisabled(pluginId, isDisabled)
    if type(pluginId) ~= "string" or pluginId == "" then
        return
    end
    local store = self:GetStore()
    store.disabledPlugins = store.disabledPlugins or {}
    if isDisabled then
        store.disabledPlugins[pluginId] = true
    else
        store.disabledPlugins[pluginId] = nil
    end
end

--- Returns the user's configured default opening / landing plugin ID.
--- Always returns a valid plugin ID (defaults to `"dungeons"`).
--- @return string
function Database:GetDefaultLandingPluginId()
    local store = self:GetStore()
    local id = store.window and (store.window.defaultLandingPluginId or store.window.homePluginId)
    if type(id) == "string" and id ~= "" then
        return id
    end
    return "dungeons"
end

--- Sets the user's preferred default opening / landing plugin ID.
--- Radio semantics: always stores a non-empty plugin ID (falls back to `"dungeons"` if nil/empty).
--- @param pluginId string|nil
function Database:SetDefaultLandingPluginId(pluginId)
    local resolved = (type(pluginId) == "string" and pluginId ~= "") and pluginId or "dungeons"
    local store = self:GetStore()
    store.window = store.window or {}
    store.window.defaultLandingPluginId = resolved
    store.window.homePluginId = resolved -- backwards compatibility
end

--- Backwards-compatibility wrapper for `GetDefaultLandingPluginId`.
--- @return string|nil
function Database:GetHomePluginId()
    return self:GetDefaultLandingPluginId()
end

--- Backwards-compatibility wrapper for `SetDefaultLandingPluginId`.
--- @param pluginId string|nil
function Database:SetHomePluginId(pluginId)
    self:SetDefaultLandingPluginId(pluginId)
end

--- Returns the custom sort order rank for `pluginId` (if the user has reordered plugins in Settings).
--- @param pluginId string
--- @return number|nil
function Database:GetPluginCustomOrder(pluginId)
    if type(pluginId) ~= "string" then
        return nil
    end
    local store = self:GetStore()
    local orderMap = store.pluginOrder
    if type(orderMap) == "table" and type(orderMap[pluginId]) == "number" then
        return orderMap[pluginId]
    end
    return nil
end

--- Persists a custom ordered array of plugin IDs (`{ "dungeons", "raids", ... }`)
--- into `store.pluginOrder` (`pluginId -> rank * 10`).
--- @param orderedIds string[]
function Database:SavePluginOrderList(orderedIds)
    if type(orderedIds) ~= "table" then
        return
    end
    local store = self:GetStore()
    store.pluginOrder = {}
    for index, id in ipairs(orderedIds) do
        if type(id) == "string" and id ~= "" then
            store.pluginOrder[id] = index * 10
        end
    end
end

--- Returns a module-specific setting (`store[moduleKey][settingKey]`).
--- @param moduleKey string
--- @param settingKey string
--- @param defaultVal any
--- @return any
function Database:GetModuleSetting(moduleKey, settingKey, defaultVal)
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
function Database:SetModuleSetting(moduleKey, settingKey, val)
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
function Database:GetDungeonSetting(key, defaultVal)
    return self:GetModuleSetting("dungeons", key, defaultVal)
end

--- Convenience setter for Dungeons module settings.
--- @param key string
--- @param val any
function Database:SetDungeonSetting(key, val)
    self:SetModuleSetting("dungeons", key, val)
end

--- Convenience getter for Map Icons utility module settings.
--- @param key string
--- @param defaultVal any
--- @return any
function Database:GetMapIconsSetting(key, defaultVal)
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
function Database:SetMapIconsSetting(key, val)
    self:SetModuleSetting("map_icons", key, val)
    if key == "worldMapDungeonIcons" then
        self:SetDungeonSetting(key, val)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.Database = Database
