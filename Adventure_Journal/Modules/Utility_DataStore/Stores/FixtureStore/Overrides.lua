-- ============================================================================
-- Utility_DataStore - Stores/FixtureStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.FixtureStore:SetOverrides({
})
