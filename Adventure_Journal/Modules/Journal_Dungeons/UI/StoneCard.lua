-- ============================================================================
-- Journal_Dungeons - UI/StoneCard.lua
-- The card button: the Group Finder's category card frame (bevel, inner
-- border and socket, with its pressed and hover states) around the journal
-- window's own stone or a picture, with a gold name and a second line. The
-- frame atlas is cut into pieces drawn at their own size; only its one middle
-- row stretches when the card is taller than the art.
-- ============================================================================
local addonName, parent = ...
local ns = parent.Dungeons or {} ; parent.Dungeons = ns

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pcall = pcall
local math = math
local CreateFrame = CreateFrame
local C_Texture = C_Texture
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local FRAME = "groupfinder-button-cover"
local PRESSED = "groupfinder-button-cover-down"
local HOVER = "groupfinder-button-cover-hover"
local LEFT_END = 190                    -- the frame is plain from here on; cuts land in the plain part
local RIGHT_END = 48                    -- the right end with its rounded corner
local WINDOW = { 5, 7, 5, 5 }           -- the frame's window: left, top, right, bottom
-- Pictures are drawn at one scale on every card (4:3 loading screens at the frame's full width), centered a
-- little below the middle (past the title banner), and cropped to the card's window
local PICTURE = { w = 418, h = 418 * 3 / 4, centerV = 0.53 }

local stoneTile -- { atlas } or { file }, read once from CollectionsBackgroundTemplate

--- The atlas's info and file, or nil when this client lacks it.
local function atlasFile(name)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    local file = info and (info.file or info.filename)
    if file and info.width and info.width > 0 then
        return info, file
    end
end

--- Columns { srcStart, srcSize, drawnSize, flip } across `width`. Normally the left end (with the dark fade
--- behind the name) and the matching right end. Without the fade (narrow cards, where cutting into the fade
--- leaves a seam): the right end mirrored as the left end, the plain middle, then the right end.
local function columns(artWidth, width, noFade)
    if noFade then
        return { { artWidth - RIGHT_END, RIGHT_END, RIGHT_END, true },
            { LEFT_END, width - 2 * RIGHT_END, width - 2 * RIGHT_END }, { artWidth - RIGHT_END, RIGHT_END, RIGHT_END } }
    end
    local first = math.min(LEFT_END, width)
    return { { 0, first, first }, { artWidth - (width - first), width - first, width - first } }
end

--- Draws `atlas` at width x height on `button`: across, see `columns`; down, its top and bottom halves with
--- the middle row stretched between them. Returns the pieces.
local function drawFrame(button, sublevel, atlas, width, height, noFade)
    local info, file = atlasFile(atlas)
    if not info then
        local tex = button:CreateTexture(nil, "ARTWORK", nil, sublevel)
        tex:SetAllPoints()
        tex:SetTexture(Constants.ASSETS.MISSING_ICON)
        return { tex }
    end
    width = math.min(width, info.width)
    height = math.max(height, info.height)
    local cols = columns(info.width, width, noFade)
    local mid = math.floor(info.height / 2)
    local rows = { { 0, mid, mid }, { mid, 1, height - info.height + 1 },
        { mid + 1, info.height - mid - 1, info.height - mid - 1 } }
    local u = (info.rightTexCoord - info.leftTexCoord) / info.width
    local v = (info.bottomTexCoord - info.topTexCoord) / info.height
    local pieces, y = {}, 0
    for _, row in ipairs(rows) do
        local x = 0
        for _, col in ipairs(cols) do
            if col[3] > 0 and row[3] > 0 then
                local tex = button:CreateTexture(nil, "ARTWORK", nil, sublevel)
                tex:SetSize(col[3], row[3])
                tex:SetPoint("TOPLEFT", x, -y)
                local left, right = info.leftTexCoord + col[1] * u, info.leftTexCoord + (col[1] + col[2]) * u
                if col[4] then
                    left, right = right, left
                end
                tex:SetTexture(file)
                tex:SetTexCoord(left, right, info.topTexCoord + row[1] * v, info.topTexCoord + (row[1] + row[2]) * v)
                pieces[#pieces + 1] = tex
            end
            x = x + col[3]
        end
        y = y + row[3]
    end
    return pieces
end

local function showPieces(pieces, shown)
    for _, tex in ipairs(pieces) do
        tex:SetShown(shown)
    end
end

--- Tiles the journal window's stone (CollectionsBackgroundTemplate's BackgroundTile) across `tex`.
local function setStone(tex)
    if not stoneTile then
        stoneTile = {}
        local loadAddOn = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
        if loadAddOn then
            pcall(loadAddOn, "Blizzard_Collections")
        end
        local ok, frame = pcall(CreateFrame, "Frame", nil, nil, "CollectionsBackgroundTemplate")
        local tile = ok and frame and frame.BackgroundTile
        if tile then
            stoneTile.atlas = tile.GetAtlas and tile:GetAtlas()
            stoneTile.file = tile:GetTexture()
            frame:Hide()
        end
    end
    if stoneTile.atlas then
        tex:SetAtlas(stoneTile.atlas)
    elseif stoneTile.file then
        tex:SetTexture(stoneTile.file, "REPEAT", "REPEAT")
    else
        tex:SetTexture(Constants.ASSETS.MISSING_ICON)
        return
    end
    tex:SetHorizTile(true)
    tex:SetVertTile(true)
end

local function shadowed(fontString)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
    return fontString
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local StoneCard = {}

--- Creates a card button of width x height on `parentFrame`. Hover lights the rim; pressing sinks the socket.
--- `options`: `noFade` (narrow cards), `picture` (the window is left for `SetPicture` instead of the stone),
--- `noText` (the caller lays out its own text). Unless `noText`, `button.nameText` (gold) and
--- `button.subText` (white) are there to fill. `button.window` is the texture in the frame's window.
--- @return Button
function StoneCard:Create(parentFrame, width, height, options)
    options = options or {}
    local button = CreateFrame("Button", nil, parentFrame)
    button:SetSize(width, height)

    local window = button:CreateTexture(nil, "BACKGROUND")
    window:SetPoint("TOPLEFT", WINDOW[1], -WINDOW[2])
    window:SetPoint("BOTTOMRIGHT", -WINDOW[3], WINDOW[4])
    if not options.picture then
        setStone(window)
    end
    button.window = window

    drawFrame(button, 0, FRAME, width, height, options.noFade)
    local pressed = drawFrame(button, 1, PRESSED, width, height, options.noFade)
    local hover = drawFrame(button, 2, HOVER, width, height, options.noFade)
    showPieces(pressed, false)
    showPieces(hover, false)
    button:HookScript("OnMouseDown", function() showPieces(pressed, true) end)
    button:HookScript("OnMouseUp", function() showPieces(pressed, false) end)
    button:HookScript("OnEnter", function() showPieces(hover, true) end)
    button:HookScript("OnLeave", function() showPieces(hover, false) end)
    button:HookScript("OnHide", function() showPieces(pressed, false) showPieces(hover, false) end)
    if options.noText then
        return button
    end

    local nameText = shadowed(button:CreateFontString(nil, "OVERLAY",
        GameFontNormalMed3 and "GameFontNormalMed3" or "GameFontNormal"))
    nameText:SetPoint("BOTTOMLEFT", button, "LEFT", 20, 1)
    nameText:SetPoint("RIGHT", button, "RIGHT", -16, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 0.82, 0)
    button.nameText = nameText

    local subText = shadowed(button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
    subText:SetJustifyH("LEFT")
    subText:SetTextColor(1, 1, 1)
    button.subText = subText

    return button
end

--- Shows a dungeon's (or wing's) loading screen in a picture card, cropped to it. With no art the window is
--- black and the missing-art question mark sits small in the top-right corner, clear of the text.
--- @param button Button a card created with `picture = true`
--- @param dungeon table a dungeon or wing view (DungeonAccess)
function StoneCard:SetDungeonPicture(button, dungeon)
    ns.UI.SharedWidgets:ApplyDungeonArtwork(button.window, dungeon)
    local missingIcon = button.window.missingIcon
    if missingIcon and missingIcon:IsShown() then
        missingIcon:ClearAllPoints()
        missingIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -10, -10)
        missingIcon:SetSize(18, 18)
    else
        self:CropPicture(button)
    end
end

--- Crops the picture already set on `button.window` to the card: drawn at one scale on every card, centered,
--- dimmed a little so the text reads.
function StoneCard:CropPicture(button)
    local windowW = button:GetWidth() - WINDOW[1] - WINDOW[3]
    local windowH = button:GetHeight() - WINDOW[2] - WINDOW[4]
    local halfU = math.min(windowW / PICTURE.w, 1) / 2
    local halfV = math.min(windowH / PICTURE.h, 1) / 2
    button.window:SetTexCoord(0.5 - halfU, 0.5 + halfU, PICTURE.centerV - halfV, PICTURE.centerV + halfV)
    button.window:SetVertexColor(0.6, 0.6, 0.6)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.StoneCard = StoneCard
