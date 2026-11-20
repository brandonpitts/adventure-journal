-- ============================================================================
-- Utility_DataStore - Core/DataStore.lua
-- The DataStore root: holds every store, answers whether the DataStore is on,
-- and shuts everything down when the module is turned off.
-- Code reaches a store as ns.DataStore.ItemStore, ns.DataStore.TagRegistry, etc.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local DataStore = ns.DataStore
local Constants = DataStore.Constants

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- Stores in registration order
local stores = {}
-- Set by Shutdown; the module stays off until the next /reload
local isShutDown = false

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------

--- Adds a store and exposes it as DataStore[store.name].
function DataStore:RegisterStore(store)
    stores[#stores + 1] = store
    self[store.name] = store
end

--- Every registered store, in registration order.
function DataStore:GetStores()
    return stores
end

--- True when the DataStore module is enabled in settings and hasn't been shut down.
--- Turning it on or off takes effect after /reload.
function DataStore:IsEnabled()
    if isShutDown then
        return false
    end
    local settings = ns.Settings
    return not (settings and settings:IsModuleDisabled(Constants.MODULE_ID))
end

--- Empties every store, index, tag and live cache. Called when the module is disabled.
function DataStore:Shutdown()
    isShutDown = true
    for _, store in ipairs(stores) do
        store:Reset()
    end
    if self.Indexes then
        self.Indexes:Reset()
    end
    if self.Live then
        self.Live:Reset()
    end
    if self.TagRegistry then
        self.TagRegistry:Reset()
    end
end
