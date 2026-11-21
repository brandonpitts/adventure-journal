-- ============================================================================
-- Utility_DataStore - Stores/QuestStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.QuestStore:SetOverrides({
    { key = 545, field = "requires", value = { { questID = 544 } }, type = "correction",
      note = "Dalaran Patrols completes without Now We're Cooking (92433), a side quest from the same giver. Prison Break In as its prerequisite is unconfirmed." },
})
