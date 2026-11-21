-- ============================================================================
-- Utility_DataStore - Stores/InstanceStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.InstanceStore:SetOverrides({
    -- Onyxia's Lair: Blizzard's Forever raid overview (2026-10-20); not yet confirmed by the client
    { key = 249, field = "minLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = 249, field = "maxLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = 249, field = "lockoutDays", value = 7, type = "addition",
      note = "Blizzard's raid overview: every raid resets weekly." },
    { key = 249, field = "attunement", value = { itemID = 16309, questIDs = { 6502, 6602 } }, type = "addition",
      note = "Blizzard's raid overview: every member carries the Drakefire Amulet (needn't be equipped), the reward of \"Drakefire Amulet\" (Alliance, 6502) and \"Blood of the Black Dragon Champion\" (Horde, 6602)." },
    -- Hyjal Summit and The Barrow Deeps: Blizzard's raid overview; not in the client yet (no map ID). When the
    -- client ships their maps, these move to map-ID keys and the client's values replace these.
    { key = "hyjal_summit", field = "maxPlayers", value = 20, type = "addition", note = "Blizzard's raid overview: 20 players." },
    { key = "hyjal_summit", field = "minLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = "hyjal_summit", field = "maxLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = "hyjal_summit", field = "lockoutDays", value = 7, type = "addition",
      note = "Blizzard's raid overview: every raid resets weekly." },
    { key = "barrow_deeps", field = "maxPlayers", value = 10, type = "addition", note = "Blizzard's raid overview: 10 players." },
    { key = "barrow_deeps", field = "minLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = "barrow_deeps", field = "maxLevel", value = 60, type = "addition", note = "Blizzard's raid overview: level 60." },
    { key = "barrow_deeps", field = "lockoutDays", value = 7, type = "addition",
      note = "Blizzard's raid overview: every raid resets weekly." },
    { key = "stratholme_living", field = "aliases", value = { "strat live", "strat living", "living", "balnazzar" },
      type = "addition", note = "The wing's old name (Living) still finds it in search." },
    { key = "stratholme_undead", field = "aliases", value = { "strat ud", "strat undead", "undead", "rivendare" },
      type = "addition", note = "The wing's old name (Undead) still finds it in search." },
})
