-- ============================================================================
-- Journal_Base - KeybindManager.lua
-- Combat-safe keybinding reader, formatter, conflict checker, and binder.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local table = table
local ipairs = ipairs
local select = select
local GetBindingKey = GetBindingKey
local GetBindingAction = GetBindingAction
local SetBinding = SetBinding
local SaveBindings = SaveBindings
local GetCurrentBindingSet = GetCurrentBindingSet
local InCombatLockdown = InCombatLockdown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local IsAltKeyDown = IsAltKeyDown
local Constants = ns.Constants

local BINDING_ACTION = Constants.BINDING_ACTION

local MODIFIER_KEYS = {
    LSHIFT = true,
    RSHIFT = true,
    LCTRL = true,
    RCTRL = true,
    LALT = true,
    RALT = true,
    LMETA = true,
    RMETA = true,
}

local PRETTY_MODIFIERS = {
    CTRL = "Ctrl",
    SHIFT = "Shift",
    ALT = "Alt",
    META = "Cmd",
}

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Persists the active binding set to disk via Blizzard's binding manager.
local function saveActiveBindingSet()
    if not SaveBindings or not GetCurrentBindingSet then
        return
    end
    local currentSet = GetCurrentBindingSet()
    if currentSet then
        SaveBindings(currentSet)
    end
end

--- Unbinds all keys currently assigned to `BINDING_ACTION`.
local function unbindAllCurrentKeys()
    if not GetBindingKey or not SetBinding then
        return
    end
    local numKeys = select("#", GetBindingKey(BINDING_ACTION))
    for i = numKeys, 1, -1 do
        local existingKey = select(i, GetBindingKey(BINDING_ACTION))
        if existingKey then
            SetBinding(existingKey)
        end
    end
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local KeybindManager = {}

--- Checks whether a raw key token is a standalone modifier key.
--- @param key string
--- @return boolean
function KeybindManager:IsModifierKey(key)
    return key ~= nil and MODIFIER_KEYS[key] == true
end

--- Builds a full WoW binding string (e.g., "CTRL-SHIFT-J") from the current
--- modifier state and the pressed key token.
--- @param key string
--- @return string
function KeybindManager:BuildKeyCombo(key)
    local combo = ""
    if IsControlKeyDown and IsControlKeyDown() then
        combo = combo .. "CTRL-"
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        combo = combo .. "SHIFT-"
    end
    if IsAltKeyDown and IsAltKeyDown() then
        combo = combo .. "ALT-"
    end
    return combo .. key
end

--- Formats a raw WoW binding string (e.g. "SHIFT-J") into clean UI text ("Shift-J").
--- @param combo string|nil
--- @return string|nil
function KeybindManager:FormatKeyCombo(combo)
    if not combo or combo == "" then
        return nil
    end

    local parts = {}
    for token in combo:gmatch("[^%-]+") do
        parts[#parts + 1] = token
    end
    if combo:sub(-1) == "-" then
        parts[#parts + 1] = "-"
    end

    local baseKey = table.remove(parts) or combo
    local formatted = {}
    for _, mod in ipairs(parts) do
        formatted[#formatted + 1] = PRETTY_MODIFIERS[mod] or mod
    end

    local localizedKey = (#baseKey > 1 and _G["KEY_" .. baseKey]) or baseKey
    formatted[#formatted + 1] = localizedKey
    return table.concat(formatted, "-")
end

--- Returns the formatted text of the currently bound key(s), or nil if unbound.
--- @return string|nil
function KeybindManager:GetCurrentBindingText()
    if not GetBindingKey then
        return nil
    end
    local key1, key2 = GetBindingKey(BINDING_ACTION)
    if key1 and key2 then
        return self:FormatKeyCombo(key1) .. ", " .. self:FormatKeyCombo(key2)
    end
    return self:FormatKeyCombo(key1)
end

--- Checks if `combo` is already bound to a different game action.
--- @param combo string
--- @return string|nil conflictingAction
function KeybindManager:GetConflictingAction(combo)
    if not GetBindingAction or not combo or combo == "" then
        return nil
    end
    local existingAction = GetBindingAction(combo)
    if existingAction and existingAction ~= "" and existingAction ~= BINDING_ACTION then
        return existingAction
    end
    return nil
end

--- Binds `combo` to toggle the Journal window.
--- Must be called on `OnKeyUp` (after key release) and outside of combat.
--- @param combo string
--- @return boolean success, string|nil errorMessage
function KeybindManager:BindKey(combo)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot change keybindings while in combat."
    end
    if not SetBinding or not combo or combo == "" then
        return false, "Invalid key combination."
    end

    local conflict = self:GetConflictingAction(combo)

    -- Unbind combo from any conflicting action
    SetBinding(combo)

    -- Unbind any old keys currently assigned to Journal toggle
    unbindAllCurrentKeys()

    -- Bind combo to Journal toggle
    SetBinding(combo, BINDING_ACTION)
    saveActiveBindingSet()

    if conflict and _G.JournalBase then
        local readableKey = self:FormatKeyCombo(combo) or combo
        _G.JournalBase:Print(readableKey .. " bound to Adventure Journal (rebound from '" .. conflict .. "').")
    end

    return true, nil
end

--- Clears all keybindings assigned to the Journal toggle action.
--- @return boolean success, string|nil errorMessage
function KeybindManager:ClearBindings()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot clear keybindings while in combat."
    end
    unbindAllCurrentKeys()
    saveActiveBindingSet()
    return true, nil
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.KeybindManager = KeybindManager

