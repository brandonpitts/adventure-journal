-- ============================================================================
-- Utility_DataStore - Stores/EncounterStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.EncounterStore:SetOverrides({
    -- Placeholder bosses for the raids the client hasn't shipped (Blizzard's raid overview gives the counts, not
    -- the names). Replaced by the client's encounters when the raids are re-keyed to their map IDs.
    { key = "hyjal_summit_boss_01", type = "addition", note = "Placeholder: Hyjal Summit boss 1 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 1 } },
    { key = "hyjal_summit_boss_02", type = "addition", note = "Placeholder: Hyjal Summit boss 2 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 2 } },
    { key = "hyjal_summit_boss_03", type = "addition", note = "Placeholder: Hyjal Summit boss 3 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 3 } },
    { key = "hyjal_summit_boss_04", type = "addition", note = "Placeholder: Hyjal Summit boss 4 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 4 } },
    { key = "hyjal_summit_boss_05", type = "addition", note = "Placeholder: Hyjal Summit boss 5 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 5 } },
    { key = "hyjal_summit_boss_06", type = "addition", note = "Placeholder: Hyjal Summit boss 6 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 6 } },
    { key = "hyjal_summit_boss_07", type = "addition", note = "Placeholder: Hyjal Summit boss 7 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 7 } },
    { key = "hyjal_summit_boss_08", type = "addition", note = "Placeholder: Hyjal Summit boss 8 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 8 } },
    { key = "hyjal_summit_boss_09", type = "addition", note = "Placeholder: Hyjal Summit boss 9 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 9 } },
    { key = "hyjal_summit_boss_10", type = "addition", note = "Placeholder: Hyjal Summit boss 10 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 10 } },
    { key = "hyjal_summit_boss_11", type = "addition", note = "Placeholder: Hyjal Summit boss 11 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 11 } },
    { key = "hyjal_summit_boss_12", type = "addition", note = "Placeholder: Hyjal Summit boss 12 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 12 } },
    { key = "hyjal_summit_boss_13", type = "addition", note = "Placeholder: Hyjal Summit boss 13 of 13.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "hyjal_summit", order = 13 } },
    { key = "barrow_deeps_boss_01", type = "addition", note = "Placeholder: The Barrow Deeps boss 1 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 1 } },
    { key = "barrow_deeps_boss_02", type = "addition", note = "Placeholder: The Barrow Deeps boss 2 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 2 } },
    { key = "barrow_deeps_boss_03", type = "addition", note = "Placeholder: The Barrow Deeps boss 3 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 3 } },
    { key = "barrow_deeps_boss_04", type = "addition", note = "Placeholder: The Barrow Deeps boss 4 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 4 } },
    { key = "barrow_deeps_boss_05", type = "addition", note = "Placeholder: The Barrow Deeps boss 5 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 5 } },
    { key = "barrow_deeps_boss_06", type = "addition", note = "Placeholder: The Barrow Deeps boss 6 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 6 } },
    { key = "barrow_deeps_boss_07", type = "addition", note = "Placeholder: The Barrow Deeps boss 7 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 7 } },
    { key = "barrow_deeps_boss_08", type = "addition", note = "Placeholder: The Barrow Deeps boss 8 of 8.",
      value = { label = "Unknown Boss", verified = false, source = "manual", instanceID = "barrow_deeps", order = 8 } },
})
