-- ============================================================================
-- Utility_DataStore - Stores/NpcStore/Schema.lua
--
-- An NPC is any creature or character the game controls: bosses, their adds,
-- rares, quest givers, vendors. Keyed by the game's NPC ID. Holds levels,
-- portraits and where they stand. Whether an NPC is a boss, an add or someone
-- to protect depends on the fight, so that lives on the encounter.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local DataStore = ns.DataStore

-- ----------------------------------------------------------------------------
-- 2. Store Definition
-- ----------------------------------------------------------------------------
DataStore.StoreBase:New({
    name = "NpcStore",
    kind = "NPC",
    liveName = "npc",
    fields = {
        minLevel       = { type = "number", comment = "Minimum level; -1 is the skull level shown as ??." },
        maxLevel       = { type = "number", comment = "Maximum level; -1 is the skull level shown as ??." },
        classification = { type = "string", comment = "normal, elite, rare, rareelite or worldboss (the client's words)." },
        displayID      = { type = "number", comment = "Creature display ID, for portraits and models." },
        title          = { type = "string", comment = "The line under the name, for example Weapon Vendor." },
        spawns         = { type = "table",  list = true, comment = "Where it stands: { { uiMapID, x, y } }, 0-1 coordinates." },
        instanceID     = { type = "number", links = "InstanceStore", comment = "For NPCs inside an instance." },
        regionKey      = { type = "string", links = "LocationStore", comment = "Reserved (instance maps): landmark region." },
    },
})
