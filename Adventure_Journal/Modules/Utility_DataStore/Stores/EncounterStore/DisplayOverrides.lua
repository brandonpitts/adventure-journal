-- ============================================================================
-- Utility_DataStore - Stores/EncounterStore/DisplayOverrides.lua
-- Hand-kept display overrides: how an encounter shows, never what it is (data
-- fixes go in Overrides.lua). Sync scripts never touch this file. Format
-- (Core/StoreDisplay.lua):
--   { key = <key>, kind = "note" | "replace" | "hide" | "banner" | "place" | "layout",
--     target = "<slot or slot.field>", value = <what the kind needs>, note = "<why>" }
-- A `place` entry on target "bossList" shows the encounter on a wing's page: value = { wingKey = "<wing>" }.
-- A `replace` entry on target "encounter.icon" sets the medallion's icon for an encounter with no creature
-- portrait (a portrait always wins). `fallback = true` marks a stand-in, to be replaced by a portrait or a
-- better icon.
-- ============================================================================
local addonName, ns = ...

local FALLBACK = "Fallback icon chosen 2026-11-21; no creature portrait known yet."

ns.DataStore.EncounterStore:SetDisplayOverrides({
    { key = 2797, kind = "place", target = "bossList", value = { wingKey = "stratholme_living" },
      note = "Ezra Grimm: client-only fight with no wing in the data; placed on the Living side by hand." },

    -- Fallback icons (no creature portrait known)
    { key = 2797, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
    { key = 3644, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\INV_Misc_Root_01" },
    { key = "sunken_temple_balcony_minibosses", kind = "replace", target = "encounter.icon", fallback = true,
      note = FALLBACK .. " The Atal'ai troll priests; the troll head is Zul'Farrak's icon in the client's data.",
      value = "Interface\\Icons\\INV_Misc_Head_Troll_01" },
    { key = "strat_jarien_and_sothos", kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
    { key = 3511, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Spell_Frost_SummonWaterElemental_2" },
    { key = 3499, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Ability_Hunter_Pet_Raptor" },
    { key = 3310, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Spell_Shadow_Charm" },
    { key = "brd_grim_guzzler", kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\INV_Drink_05" },
    { key = 243, kind = "replace", target = "encounter.icon", fallback = true,
      note = FALLBACK .. " The instance's icon.", value = "Interface\\Icons\\INV_Hammer_Unique_Sulfuras" },
    { key = 3409, kind = "replace", target = "encounter.icon", fallback = true,
      note = FALLBACK .. " The instance's icon.", value = "Interface\\Icons\\INV_Misc_Key_07" },
    { key = 3312, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\Spell_Arcane_ArcaneTorrent" },
    { key = 2791, kind = "replace", target = "encounter.icon", fallback = true, note = FALLBACK,
      value = "Interface\\Icons\\INV_Misc_Key_10" },
})
