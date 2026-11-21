-- ============================================================================
-- Utility_DataStore - Core.lua
-- Registers the DataStore as a utility module (no tab). It is the only data
-- module that can be turned off; turning it off empties every store after
-- the next /reload. Also exposes it to developer tools as JournalBase.DataStore.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local _G = _G
local DataStore = ns.DataStore
local Constants = DataStore.Constants

-- ----------------------------------------------------------------------------
-- 2. Module Definition
-- ----------------------------------------------------------------------------
local DataStoreModule = {
    id = Constants.MODULE_ID,
    title = "DataStore",
    addonName = "Utility_DataStore",
    description = "The game data the Journal shows: items, dungeons, bosses, NPCs, quests and places. Turning it off leaves every page with placeholders and turns off Search.",
    icon = "Interface\\Icons\\INV_Misc_Book_11",
    order = 800,
    isUtility = true,
}

--- Empties every store when the module is disabled (runs at load, after a /reload).
function DataStoreModule:OnUnload()
    DataStore:Shutdown()
end

-- ----------------------------------------------------------------------------
-- 3. Registration
-- ----------------------------------------------------------------------------
if _G.JournalBase and _G.JournalBase.RegisterModule then
    _G.JournalBase:RegisterModule(DataStoreModule)
elseif ns.ModuleRegistry and ns.ModuleRegistry.Register then
    ns.ModuleRegistry:Register(DataStoreModule)
end

-- Read access for developer tools (one field on the existing global; no new global)
if _G.JournalBase then
    _G.JournalBase.DataStore = DataStore
end

DataStore.Module = DataStoreModule
