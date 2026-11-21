-- ============================================================================
-- Utility_DataStore - Stores/InstanceStore/Schema.lua
--
-- An instance is a dungeon or raid: a private copy of a place your group zones
-- into through a portal. Keyed by the game's instance map ID. Some instances
-- are split into wings with separate entrances (Scarlet Monastery's Graveyard,
-- Library, Armory and Cathedral); wings are records here too, keyed by slug and
-- linked to their instance. Bosses live in EncounterStore; entrances on the
-- world map live in LocationStore.
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
    name = "InstanceStore",
    kind = "Instance",
    liveName = "instance",
    fields = {
        type          = { type = "string",  comment = "dungeon or raid (instances only), from the client's Map table." },
        maxPlayers    = { type = "number",  comment = "Group size (instances only). Generated from the client's MapDifficulty table; never hand-written." },
        minLevel      = { type = "number",  comment = "Recommended minimum level (wings, or instances without wings)." },
        maxLevel      = { type = "number",  comment = "Recommended maximum level (wings, or instances without wings)." },
        loadingScreen = { type = "number",  comment = "Loading screen art file ID, from the client's LoadingScreens table." },
        icon          = { type = "string",  comment = "Our chosen icon." },
        aliases       = { type = "table",   list = true, comment = "Search words." },
        release       = { type = "string",  comment = "classic or forever (instances only)." },
        comingSoon    = { type = "boolean", comment = "Announced but not released (instances only)." },
        order         = { type = "number",  comment = "A wing's position within its instance." },
        instanceID    = { type = "number",  links = "InstanceStore", comment = "A wing's instance." },
        itemIDs       = { type = "table",   list = true, links = "ItemStore", comment = "Instance-wide drops." },
        -- Raids
        tier          = { type = "number",  comment = "Raids: the raid tier it belongs to (1 for Forever's first raids). Optional: a raid may belong to no tier. Our classification; the sync never writes it." },
        lockoutDays   = { type = "number",  comment = "Raids: lockout period in days." },
        attunement    = { type = "table",   comment = "Raids: what every member needs to enter: { itemID, questIDs } (the item, and the quests that award it, shown under Attunement on the Quests tab)." },
        itemSetIDs    = { type = "table",   list = true, comment = "Reserved (raids): tier sets." },
        -- Reserved for instance maps
        floorMaps     = { type = "table",   list = true, comment = "Reserved (instance maps): floor-plan art, in order." },
    },
})
