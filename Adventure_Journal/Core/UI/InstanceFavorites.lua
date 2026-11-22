-- ============================================================================
-- Adventure Journal - Core/UI/InstanceFavorites.lua
-- Favorite instances and wings for templates with `favorites` (dungeons):
-- saved account-wide in the template's settings as view key -> true (an
-- instance's map ID or a wing's slug). Right-clicking a list or wing card
-- toggles one; favorites show a star (StoneCard:AddFavoriteStar).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local pairs = pairs
local type = type

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local InstanceFavorites = {}

--- Whether `template`'s lists have favorites.
function InstanceFavorites:IsOn(template)
    return template.favorites == true
end

--- The saved favorites (view key -> true); empty for a template without favorites.
function InstanceFavorites:Get(template)
    if not self:IsOn(template) then
        return {}
    end
    local saved = ns.Settings:GetModuleSetting(template.settings, template.settingKeys.favorites)
    return type(saved) == "table" and saved or {}
end

--- Whether `view` (an instance or wing view) is a favorite.
function InstanceFavorites:IsFavorite(template, view)
    return view ~= nil and view.key ~= nil and self:Get(template)[view.key] == true
end

--- Adds `view` to the favorites, or removes it. Saves a new table so the change reaches the settings' listeners
--- (the instance list redraws on it).
function InstanceFavorites:Toggle(template, view)
    if not (self:IsOn(template) and view and view.key ~= nil) then
        return
    end
    local favorites = {}
    for key in pairs(self:Get(template)) do
        favorites[key] = true
    end
    favorites[view.key] = not favorites[view.key] or nil
    ns.Settings:SetModuleSetting(template.settings, template.settingKeys.favorites, favorites)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.InstanceFavorites = InstanceFavorites
