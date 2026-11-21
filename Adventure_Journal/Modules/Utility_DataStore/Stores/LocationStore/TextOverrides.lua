-- ============================================================================
-- Utility_DataStore - Stores/LocationStore/TextOverrides.lua
-- Hand-kept text and hint fixes; sync scripts never touch this file (Texts.lua
-- is generated). Each entry names exactly what it changes:
--   { key = <key>, text = "description", value = "...", type = "correction", note = "<why>" }
--   { key = <key>, hint = "<field>", value = "...", type = "correction" | "addition", note = "<why>" }
-- A hint correction replaces every hint on that field; an addition adds one.
-- Optional: faction = "Alliance" | "Horde", from (default "manual").
-- ============================================================================
local addonName, ns = ...

ns.DataStore.LocationStore:SetTextOverrides({
    { key = "hyjal_summit_entrance", hint = "place", value = "near Nordrassil", type = "addition",
      note = "Blizzard's raid overview: \"near the World Tree Nordrassil\"." },
})
