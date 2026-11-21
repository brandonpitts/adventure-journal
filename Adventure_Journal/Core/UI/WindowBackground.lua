-- ============================================================================
-- Adventure Journal - Core/UI/WindowBackground.lua
-- The journal window's theme, chosen in Settings: the Collections window's
-- stone (default), the spellbook's parchment page, or Forever (the Legacy
-- window's dark background, with pages using the game's own Forever widgets,
-- such as Reputation-style headers). The stone's corner filigree and edge
-- shading stay on every choice. Pictures cover the window at one scale and are
-- cropped, never stretched.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local pcall = pcall
local math = math
local C_Texture = C_Texture

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- region: the part of the atlas to show, in atlas pixels (the paper without the book's cover); the whole
-- atlas when absent. Forever uses the Legacy window's Progress Track page background; forever = true: pages
-- use the game's Forever widgets.
local OPTIONS = {
    { key = "stone", label = "Stone (Default)" },
    { key = "parchment", label = "Parchment", atlas = "spellbook-Page-Condensed-C60",
      region = { left = 17, right = 796, top = 65, bottom = 675 }, ink = true },
    { key = "forever", label = "Forever", atlas = "Legacy-Rewards-Tracker-Background", forever = true },
}
local DEFAULT_KEY = "stone"
-- Body text on a light background (ink = true): near-black, with no shadow
local INK = { 0.10, 0.07, 0.04 }

local function optionFor(key)
    for _, option in ipairs(OPTIONS) do
        if option.key == key then
            return option
        end
    end
    return OPTIONS[1]
end

--- Covers w x h with the option's region at one scale, keeping its top and cropping the sides evenly.
--- Returns false when the client lacks the atlas.
local function coverWith(tex, option, w, h)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(option.atlas)
    local file = info and (info.file or info.filename)
    if not (file and info.width and info.width > 0 and w > 0 and h > 0) then
        return false
    end
    local r = option.region or { left = 0, right = info.width, top = 0, bottom = info.height }
    local regionW, regionH = r.right - r.left, r.bottom - r.top
    local scale = math.max(w / regionW, h / regionH)
    local keepW, keepH = w / scale, h / scale
    local x0 = r.left + (regionW - keepW) / 2
    local u = (info.rightTexCoord - info.leftTexCoord) / info.width
    local v = (info.bottomTexCoord - info.topTexCoord) / info.height
    tex:SetTexture(file)
    tex:SetTexCoord(info.leftTexCoord + x0 * u, info.leftTexCoord + (x0 + keepW) * u,
        info.topTexCoord + r.top * v, info.topTexCoord + (r.top + keepH) * v)
    return true
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local WindowBackground = {
    inset = nil,
    picture = nil,
    listeners = {},
}

--- Whether the Forever theme is chosen, so pages use the game's Forever widgets.
--- @return boolean
function WindowBackground:IsForever()
    return optionFor(ns.Settings:GetWindowBackground()).forever == true
end

--- Whether the chosen background is light, so body text is drawn in ink.
--- @return boolean
function WindowBackground:UsesInk()
    return optionFor(ns.Settings:GetWindowBackground()).ink == true
end

--- Colors body text for the background: ink with no shadow on a light background, otherwise r, g, b with
--- the usual 1, -1 shadow. Headers and gold titles keep their own colors.
--- @param fontString FontString
function WindowBackground:ColorBodyText(fontString, r, g, b)
    if self:UsesInk() then
        fontString:SetTextColor(INK[1], INK[2], INK[3])
        fontString:SetShadowOffset(0, 0)
    else
        fontString:SetTextColor(r, g, b)
        fontString:SetShadowOffset(1, -1)
    end
end

--- Calls `fn` whenever the background changes, so pages can recolor their text.
--- @param fn function
function WindowBackground:OnChange(fn)
    self.listeners[#self.listeners + 1] = fn
end

--- Saves and shows background `key`, then tells the pages.
--- @param key string
function WindowBackground:Select(key)
    ns.Settings:SetWindowBackground(key)
    self:Apply()
    for _, listener in ipairs(self.listeners) do
        pcall(listener)
    end
end

--- The choices, in Settings order: { key, label }.
function WindowBackground:GetOptions()
    return OPTIONS
end

function WindowBackground:GetDefaultKey()
    return DEFAULT_KEY
end

--- Whether `key` names a background.
function WindowBackground:IsValidKey(key)
    return optionFor(key).key == key
end

--- Attaches to the window's inset (which already carries the Collections stone) and shows the saved choice.
--- @param inset Frame
function WindowBackground:Init(inset)
    self.inset = inset
    local picture = inset:CreateTexture(nil, "BACKGROUND", nil, -1)
    picture:SetAllPoints(inset)
    picture:Hide()
    self.picture = picture
    inset:HookScript("OnSizeChanged", function()
        self:Apply()
    end)
    self:Apply()
end

--- Shows the saved background and, if turned on, the corner filigree (every piece of the stone template but
--- its tile: the four corners and the dark edge shading). A picture the client lacks falls back to the stone.
function WindowBackground:Apply()
    if not self.inset then
        return
    end
    local option = optionFor(ns.Settings:GetWindowBackground())
    local stoneFrame = self.inset.CollectionsBg
    local showPicture = option.atlas ~= nil
        and coverWith(self.picture, option, self.inset:GetWidth(), self.inset:GetHeight())
    self.picture:SetShown(showPicture)
    if stoneFrame and stoneFrame.BackgroundTile then
        stoneFrame.BackgroundTile:SetShown(not showPicture)
    end
    if stoneFrame then
        -- The filigree is every piece of the template except its stone tile (the corners and edge shading)
        local showFiligree = ns.Settings:IsFiligreeShown()
        for _, region in ipairs({ stoneFrame:GetRegions() }) do
            if region ~= stoneFrame.BackgroundTile then
                region:SetShown(showFiligree)
            end
        end
        for _, child in ipairs({ stoneFrame:GetChildren() }) do
            child:SetShown(showFiligree)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI = ns.UI or {}
ns.UI.WindowBackground = WindowBackground
