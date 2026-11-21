-- ============================================================================
-- Utility_DataStore - Stores/InstanceStore/DisplayOverrides.lua
-- Hand-kept display overrides: how an instance's page shows, never what the
-- instance is (data fixes go in Overrides.lua). Sync scripts never touch this
-- file. Format (Core/StoreDisplay.lua):
--   { key = <key>, kind = "note" | "replace" | "hide" | "banner" | "place" | "layout",
--     target = "<slot or slot.field>", value = <what the kind needs>, note = "<why>" }
-- ============================================================================
local addonName, ns = ...

ns.DataStore.InstanceStore:SetDisplayOverrides({
    -- Capital-city dungeons show their city's faction crest by the title
    { key = 34, kind = "replace", target = "header.crest", value = "Alliance",
      note = "Stormwind Stockade lies under Stormwind City." },
    { key = 389, kind = "replace", target = "header.crest", value = "Horde",
      note = "Ragefire Chasm lies under Orgrimmar." },
    { key = 2999, kind = "replace", target = "header.crest", value = "Horde",
      note = "Ruins of Lordaeron lies under the Undercity." },
    { key = 3065, kind = "replace", target = "header.crest", value = "Alliance",
      note = "The Hall of Thanes lies in Ironforge." },
    -- List cards: where a card's picture crop centers down the art (standard 0.53)
    { key = 249, kind = "replace", target = "card.crop", value = { centerV = 0.40 },
      note = "Onyxia's Lair: cropped higher to show the adventurers and the dragon's head." },
})
