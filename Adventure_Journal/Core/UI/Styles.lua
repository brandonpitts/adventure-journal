-- ============================================================================
-- Adventure Journal - Core/UI/Styles.lua
-- The named styles every block draws with: colors, fonts, sizes, art and
-- sounds. Values are the ones the Dungeons screens have always used; a block
-- asks for a style by name instead of writing its own numbers.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local SOUNDKIT = SOUNDKIT

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local Styles = {
    -- A major section header in the instance lists ("Tier 1"): centered between the two halves of its line, `gap`
    -- px from each; outlined for weight (Friz Quadrata has no bold face)
    LIST_HEADER = { font = "GameFontNormalLarge", size = 18, flags = "OUTLINE", gap = 12 },

    -- Colors: { r, g, b } or { r, g, b, a }
    COLORS = {
        -- Signature divider: bronze highlight line and recessed shadow line
        DIVIDER_HIGHLIGHT = { 0.65, 0.52, 0.28, 0.80 },
        DIVIDER_SHADOW = { 0.08, 0.06, 0.04, 0.55 },
        -- Medallion: the dark well behind the icon and the hover glow
        MEDALLION_WELL = { 0.04, 0.04, 0.03, 0.96 },
        MEDALLION_GLOW = { 1.0, 0.92, 0.65, 0.35 },
        MEDALLION_RING_GLOW = { 1.0, 0.90, 0.60, 0.70 },
    },

    SIZES = {
        DIVIDER_FADE = 28,         -- length of the fade at each end of a divider
        DIVIDER_THICKNESS = 4,
        -- A book page's header, from the left page's top: the medallion, the title's drop below the medallion's
        -- top, and the divider under it. The right page sits RIGHT_PAGE_DROP lower; its headers add it back.
        HEADER_MEDALLION_Y = -7,
        HEADER_MEDALLION = 38,
        HEADER_RING = 52,
        HEADER_TITLE_DROP = 2,
        HEADER_DIVIDER_Y = -52,
        RIGHT_PAGE_DROP = 10,
    },

    ASSETS = {
        WHITE_8X8 = "Interface\\Buttons\\WHITE8X8",
        MISSING_ICON = "Interface\\Icons\\INV_Misc_QuestionMark",
        PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        -- The Settings panel's horizontal line, under section headers in the instance lists
        SECTION_LINE_ATLAS = "Options_HorizontalDivider",
        -- The game's favorites star (the Pet Journal's; Wowpedia Iconsmall-obj111), on favorite instance cards
        FAVORITE_ATLAS = "PetJournal-FavoritesIcon",
    },

    SOUNDS = {
        CLICK = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON,
        PAGE_TURN = SOUNDKIT.IG_ABILITY_PAGE_TURN,
        TAB = SOUNDKIT.IG_CHARACTER_INFO_TAB,
    },
}

--- Applies a named color to a texture's vertex color.
function Styles:Tint(texture, name)
    local c = self.COLORS[name]
    texture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
end

--- A named color as r, g, b, a.
function Styles:Color(name)
    local c = self.COLORS[name]
    return c[1], c[2], c[3], c[4] or 1
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.Styles = Styles
