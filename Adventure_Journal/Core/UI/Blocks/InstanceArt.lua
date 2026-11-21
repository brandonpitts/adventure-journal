-- ============================================================================
-- Adventure Journal - Core/UI/Blocks/InstanceArt.lua
-- An instance's loading-screen art on a texture: cropped past the art's own
-- header and footer, or a black panel with the missing-art question mark when
-- the instance has none.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local ipairs = ipairs
local type = type

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
local Styles = ns.UI.Styles
-- The loading screen's picture without its header and footer
local DEFAULT_CROP = { 0.02, 0.98, 0.25, 0.81 }

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin / UI Definitions
-- ----------------------------------------------------------------------------
local InstanceArt = {}

--- The instance's art (file ID or path), or nil when it has none.
--- @param view table an instance view (InstanceAccess)
function InstanceArt:Resolve(view)
    for _, candidate in ipairs(view and view.art or {}) do
        if (type(candidate) == "number" and candidate > 0) or (type(candidate) == "string" and candidate ~= "") then
            return candidate
        end
    end
end

--- Draws the instance's art on `texture`, or the missing-art panel (black, question mark centered).
--- @param texture Texture
--- @param view table an instance view
function InstanceArt:Apply(texture, view)
    if not texture or not view then
        return
    end
    local art = self:Resolve(view)
    if art then
        local crop = view.texCoord or DEFAULT_CROP
        texture:SetTexture(art)
        texture:SetTexCoord(crop[1], crop[2], crop[3], crop[4])
        if texture.missingIcon then
            texture.missingIcon:Hide()
        end
    else
        texture:SetColorTexture(0, 0, 0, 1)
        if not texture.missingIcon then
            local missingIcon = texture:GetParent():CreateTexture(nil, "OVERLAY")
            missingIcon:SetSize(40, 40)
            missingIcon:SetPoint("CENTER", texture, "CENTER", 0, 0)
            missingIcon:SetTexture(Styles.ASSETS.MISSING_ICON)
            texture.missingIcon = missingIcon
        end
        texture.missingIcon:Show()
    end
    texture:Show()
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment / Registration
-- ----------------------------------------------------------------------------
ns.UI.Blocks = ns.UI.Blocks or {}
ns.UI.Blocks.InstanceArt = InstanceArt
