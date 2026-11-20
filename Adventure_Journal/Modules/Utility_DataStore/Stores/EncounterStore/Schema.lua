-- ============================================================================
-- Utility_DataStore - Stores/EncounterStore/Schema.lua
--
-- An encounter is a fight shown in a dungeon's boss list: usually one boss, but
-- sometimes several NPCs at once (The Seven) or a friendly NPC to protect.
-- Keyed by the game's encounter ID, or by slug for fights the game doesn't
-- list (rares, minor and event bosses). Holds who is in the fight and what it
-- drops; the creatures themselves live in NpcStore. Some entries are groups
-- (The Seven, The Grim Guzzler): the group holds the shared loot, and members
-- with loot of their own are records here too, linked to their group.
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
    name = "EncounterStore",
    kind = "Encounter",
    fields = {
        instanceID  = { type = "number", links = "InstanceStore", comment = "The instance (client MapID)." },
        wingKey     = { type = "string", links = "InstanceStore", comment = "The wing, for instances with wings." },
        order       = { type = "number", comment = "Position in the boss list." },
        kind        = { type = "string", comment = "boss (default), rare, minor, challenge or event." },
        encounterID  = { type = "number", links = "EncounterStore", comment = "A group member's group (client encounter)." },
        encounterKey = { type = "string", links = "EncounterStore", comment = "A group member's group (slug)." },
        npcs        = { type = "table",  list = true, comment = "{ { npcID, role } }; roles: boss, add, friendly, protect." },
        itemIDs     = { type = "table",  list = true, links = "ItemStore", comment = "The loot." },
        lootSets    = { type = "table",  list = true, comment = "Loot that changes with circumstances: { { label, itemIDs } }, each shown under its own header." },
        itemDetails = { type = "table",  comment = "Extras per item on this fight: { [itemID] = { note, faction } }." },
        holidayID   = { type = "number", comment = "For holiday bosses: the client's Holidays ID." },
        icon        = { type = "string", comment = "Our chosen icon." },
        abilityIDs  = { type = "table",  list = true, links = "AbilityStore", comment = "The fight's abilities." },
        regionKey   = { type = "string", links = "LocationStore", comment = "Reserved (instance maps): the boss arena." },
    },
})
