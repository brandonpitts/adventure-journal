-- ============================================================================
-- Adventure Journal - Core/Templates/Base.lua
-- The base template every other template extends: the words they all share
-- (level tags, loading items, the map pin's tooltips).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Template Definition
-- ----------------------------------------------------------------------------
ns.Templates:Register("base", {
    slots = {},
    text = {
        level = "Lv %s",
        loading = "Loading...",
        pinTitle = "Pin to Map",
        pinCoords = "Coordinates: %.1f, %.1f",
        pinHint = "Click to set waypoint and open the World Map.",
        pinUnavailable = "Pin Unavailable",
    },
})

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
-- (Registered with ns.Templates)
