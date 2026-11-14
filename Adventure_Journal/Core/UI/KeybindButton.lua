-- ============================================================================
-- Journal_Base - UI/KeybindButton.lua
-- Reusable combat-safe interactive keybind recorder button widget.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Constants
-- ----------------------------------------------------------------------------
local CreateFrame = CreateFrame
local Mixin = Mixin
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local Constants = ns.Constants

-- ----------------------------------------------------------------------------
-- 2. Private Helper Functions
-- ----------------------------------------------------------------------------

--- Applies the native dark keybind box backdrop matching Blizzard's Keybindings UI.
local function applyKeybindBackdrop(button)
    if not button.SetBackdrop then
        return
    end
    button:SetBackdrop({
        bgFile = Constants.ASSETS.WHITE_8X8,
        edgeFile = Constants.ASSETS.TOOLTIP_BORDER,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    button:SetBackdropColor(0.085, 0.066, 0.074, 1)
    button:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
end

-- ----------------------------------------------------------------------------
-- 3. Module / Mixin Definition
-- ----------------------------------------------------------------------------
local KeybindButtonMixin = {}

--- Initializes the keybind button state and event scripts.
--- Note: Binds on `OnKeyUp` so the key press used to record the binding does not
--- immediately trigger the newly bound Journal toggle action on the same press.
function KeybindButtonMixin:Init()
    self:SetSize(Constants.SETTINGS.KEYBIND_BUTTON_WIDTH, Constants.SETTINGS.KEYBIND_BUTTON_HEIGHT)
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    applyKeybindBackdrop(self)

    local text = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", self, "LEFT", 8, 0)
    text:SetPoint("RIGHT", self, "RIGHT", -8, 0)
    text:SetJustifyH("CENTER")
    self.Text = text

    self.isCapturing = false
    self.pendingBind = nil

    self:SetScript("OnClick", self.OnClick)
    self:SetScript("OnKeyDown", self.OnKeyDown)
    self:SetScript("OnKeyUp", self.OnKeyUp)
    self:SetScript("OnHide", self.StopCapture)
    self:SetScript("OnEnter", self.OnEnter)
    self:SetScript("OnLeave", self.OnLeave)

    -- Keep keyboard capture disabled until clicked so WASD movement is never blocked.
    self.isCapturing = false
    self.pendingBind = nil
    self:EnableKeyboard(false)
    self:Refresh()
end

--- Exits listening mode and restores normal keyboard propagation.
function KeybindButtonMixin:StopCapture()
    if not self.isCapturing and not self.pendingBind then
        return
    end
    self.isCapturing = false
    self.pendingBind = nil
    self:EnableKeyboard(false)
    if self.SetPropagateKeyboardInput then
        pcall(self.SetPropagateKeyboardInput, self, true)
    end
    self:Refresh()
end

function KeybindButtonMixin:OnClick(mouseButton)
    if InCombatLockdown and InCombatLockdown() then
        if _G.JournalBase then
            _G.JournalBase:Print("Cannot change keybindings while in combat.")
        end
        return
    end

    if mouseButton == "RightButton" then
        local ok, err = ns.KeybindManager:ClearBindings()
        if not ok and err and _G.JournalBase then
            _G.JournalBase:Print(err)
        end
        self:StopCapture()
        return
    end

    if self.isCapturing then
        self:StopCapture()
        return
    end

    self.isCapturing = true
    self.pendingBind = nil
    self:EnableKeyboard(true)
    if self.SetPropagateKeyboardInput then
        self:SetPropagateKeyboardInput(false)
    end
    self:Refresh()
end

function KeybindButtonMixin:OnKeyDown(key)
    if not self.isCapturing then
        return
    end
    if key == "ESCAPE" then
        self:StopCapture()
        return
    end
    if ns.KeybindManager:IsModifierKey(key) then
        return
    end

    local combo = ns.KeybindManager:BuildKeyCombo(key)
    local conflict = ns.KeybindManager:GetConflictingAction(combo)
    if conflict then
        local pretty = ns.KeybindManager:FormatKeyCombo(combo) or combo
        if _G.JournalBase then
            _G.JournalBase:Print(pretty .. " is already bound to '" .. conflict .. "'.")
        end
        self:StopCapture()
        return
    end

    self.pendingBind = { combo = combo, key = key }
end

function KeybindButtonMixin:OnKeyUp(key)
    if not self.isCapturing or not self.pendingBind or key ~= self.pendingBind.key then
        return
    end
    local combo = self.pendingBind.combo
    local ok, err = ns.KeybindManager:BindKey(combo)
    if not ok and err and _G.JournalBase then
        _G.JournalBase:Print(err)
    elseif PlaySound then
        PlaySound(Constants.SOUNDS.CHECKBOX_ON)
    end
    self:StopCapture()
end

function KeybindButtonMixin:OnEnter()
    if not GameTooltip then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Toggle Journal Keybind", 1.0, 0.82, 0.0)
    GameTooltip:AddLine("Left-Click to bind a key.\nRight-Click to clear the binding.\nPress ESC to cancel.", 1.0, 1.0, 1.0, true)
    GameTooltip:Show()
end

function KeybindButtonMixin:OnLeave()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

--- Updates the button text and border color to reflect the current binding state.
function KeybindButtonMixin:Refresh()
    local boundText = ns.KeybindManager:GetCurrentBindingText()
    if self.isCapturing then
        self.Text:SetText("Press a key...")
        self.Text:SetTextColor(1.0, 0.82, 0.0)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.95, 0.85, 0.35, 1)
        end
    elseif boundText then
        self.Text:SetText(boundText)
        self.Text:SetTextColor(1.0, 1.0, 1.0)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
        end
    else
        self.Text:SetText("Not Bound")
        self.Text:SetTextColor(0.55, 0.54, 0.52)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.46, 0.45, 0.43, 1)
        end
    end
end

local KeybindButton = {}

--- Factory method to create a new KeybindButton widget inside `parent`.
--- @param parent Frame
--- @return Button
function KeybindButton:Create(parent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    Mixin(button, KeybindButtonMixin)
    button:Init()
    return button
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.UI.KeybindButton = KeybindButton

