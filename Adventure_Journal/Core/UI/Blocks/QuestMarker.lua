-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/QuestMarker.lua
-- A quest's status icon: a green check when done, the greyed turn-in "?"
-- while in the player's log, the yellow "!" while available; a questline uses
-- the game's questline marker the same way. Used by the quest list and the
-- questline banners, each at its own size.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local DONE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local IN_PROGRESS = "QuestTurnin"
local AVAILABLE = "QuestNormal"
-- A questline: the campaign quest shield (Wowpedia Iconsmall-obj311 with "!"; obj312 with "?" while in
-- progress, greyed whole)
local QUESTLINE_IN_PROGRESS = "quest-campaign-turnin"
local QUESTLINE_AVAILABLE = "quest-campaign-available"

-- Marker sizes: `done` for the check; `size` for the others. `resetDoneCoords` resets the check's texture
-- coordinates (the list does; the banner keeps whatever its icon last had).
local STYLES = {
    list = { size = 24, done = 20, resetDoneCoords = true },
    banner = { size = 18, done = 18 },
}

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local QuestMarker = {}

--- The status of a quest: "done", "active" or "available".
function QuestMarker:Status(isCompleted, isActive)
    if isCompleted then
        return "done"
    end
    return isActive and "active" or "available"
end

--- Shows `status` on `texture` in `style` ("list" or "banner"); `isQuestline` uses the questline marker.
function QuestMarker:Apply(texture, status, style, isQuestline)
    local s = STYLES[style]
    if status == "done" then
        texture:SetTexture(DONE)
        texture:SetSize(s.done, s.done)
        if s.resetDoneCoords then
            texture:SetTexCoord(0, 1, 0, 1)
        end
        texture:SetDesaturated(false)
        texture:SetVertexColor(1.0, 1.0, 1.0)
    elseif status == "active" then
        texture:SetSize(s.size, s.size)
        texture:SetAtlas(isQuestline and QUESTLINE_IN_PROGRESS or IN_PROGRESS)
        texture:SetDesaturated(true)
        texture:SetVertexColor(0.85, 0.85, 0.85)
    else
        texture:SetSize(s.size, s.size)
        texture:SetDesaturated(false)
        texture:SetVertexColor(1.0, 1.0, 1.0)
        texture:SetAtlas(isQuestline and QUESTLINE_AVAILABLE or AVAILABLE)
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.QuestMarker = QuestMarker
