-- ============================================================================
-- Utility_DataStore - Stores/LocationStore/Overrides.lua
-- Hand-kept fixes and additions; sync scripts never touch this file. Each entry
-- names exactly what it changes:
--   { key = <key>, field = "<field>", value = <value>, type = "correction" | "addition" | "faction",
--     faction = "Alliance" | "Horde" (faction type only), note = "<why>" }
-- Leave out field to add or replace a whole record (value is the record).
-- ============================================================================
local addonName, ns = ...

ns.DataStore.LocationStore:SetOverrides({
    { key = "onyxias_lair_entrance", type = "addition",
      value = { label = "Onyxia's Lair", verified = false, source = "manual", kind = "entrance", instanceID = 249,
          uiMapID = 1445 },
      note = "Blizzard's raid overview: \"Deep in Dustwallow Marsh\". Exact position unknown (no map point)." },
    { key = "hyjal_summit_entrance", type = "addition",
      value = { label = "Hyjal Summit", verified = false, source = "manual", kind = "entrance",
          instanceID = "hyjal_summit", uiMapID = 2482, place = "Summit" },
      note = "Blizzard's raid overview: the summit of Mount Hyjal, near Nordrassil. Position unknown." },
    { key = "barrow_deeps_entrance_hyjal", type = "addition",
      value = { label = "The Barrow Deeps", verified = false, source = "manual", kind = "entrance",
          instanceID = "barrow_deeps", uiMapID = 2482, order = 1 },
      note = "Blizzard's raid overview: entrances through Mount Hyjal, Winterspring and Blackmaw Hold." },
    { key = "barrow_deeps_entrance_winterspring", type = "addition",
      value = { label = "The Barrow Deeps", verified = false, source = "manual", kind = "entrance",
          instanceID = "barrow_deeps", uiMapID = 1452, order = 2 },
      note = "Blizzard's raid overview: entrances through Mount Hyjal, Winterspring and Blackmaw Hold." },
    { key = "barrow_deeps_entrance_blackmaw", type = "addition",
      value = { label = "The Barrow Deeps", verified = false, source = "manual", kind = "entrance",
          instanceID = "barrow_deeps", areaID = 16554, order = 3 },
      note = "Blizzard's raid overview: entrances through Mount Hyjal, Winterspring and Blackmaw Hold." },
})
