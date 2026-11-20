-- ============================================================================
-- Utility_DataStore - Constants.lua
-- Creates the DataStore namespace and holds its shared constants.
-- The DataStore is a reference library: it knows which game records the
-- addon uses and how to ask the client for them, plus our own layer
-- (links, hints, tags) that the client doesn't have.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
-- (none)

-- ----------------------------------------------------------------------------
-- 2. Constants
-- ----------------------------------------------------------------------------
local Constants = {
    MODULE_ID = "datastore",

    -- Where a record's data came from
    SOURCES = { client = true, game = true, manual = true, legacy = true, reference = true },

    -- What kind of override an entry is
    OVERRIDE_TYPES = { correction = true, addition = true, faction = true },

    FACTIONS = { Alliance = true, Horde = true },

    -- Where texts came from
    TEXT_ORIGINS = { legacy = true, retail = true, official = true, manual = true },

    -- Shown after a label whose game record the client says doesn't exist
    MISSING_REFERENCE_SUFFIX = " (missing reference)",
    -- Shown for a link to a record the store doesn't have: kind, then key
    UNKNOWN_RECORD_FORMAT = "Unknown %s %s",

    -- The client's skull level ("??")
    SKULL_LEVEL = -1,
    SKULL_LEVEL_TEXT = "??",
}

-- ----------------------------------------------------------------------------
-- 3. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.DataStore = ns.DataStore or {}
ns.DataStore.Constants = Constants
