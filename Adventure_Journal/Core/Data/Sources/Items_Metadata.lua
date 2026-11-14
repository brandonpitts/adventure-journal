-- ============================================================================
-- Journal_Base - Core/Data/Sources/Items_Metadata.lua
-- Metadata tracking synchronized item data sources, versions, and timestamps.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local ItemsMetadata = {
    sourceAddon = "AtlasLootClassic",
    syncedVersion = "v1.3.8",
    syncTimestamp = 1794550255,
    schemaVersion = 2,
}

-- ----------------------------------------------------------------------------
-- 2. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.ItemsMetadata = ItemsMetadata
