-- ============================================================================
-- Utility_DataStore - Stores/FixtureStore/TextOverrides.lua
-- Hand-kept text and hint fixes; sync scripts never touch this file (Texts.lua
-- is generated). Each entry names exactly what it changes:
--   { key = <key>, text = "description", value = "...", type = "correction", note = "<why>" }
--   { key = <key>, hint = "<field>", value = "...", type = "correction" | "addition", note = "<why>" }
-- A hint correction replaces every hint on that field; an addition adds one.
-- Optional: faction = "Alliance" | "Horde", from (default "manual").
-- ============================================================================
local addonName, ns = ...

ns.DataStore.FixtureStore:SetTextOverrides({
})
