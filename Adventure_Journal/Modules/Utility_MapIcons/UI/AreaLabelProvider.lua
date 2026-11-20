-- ============================================================================
-- Utility_MapIcons - UI/AreaLabelProvider.lua
-- World Map area label integration with stacked website-style headings:
-- Line 1: Blizzard Zone Name (H1)
-- Line 2: Zone Level Range (H2/H3 sub-header, custom difficulty colored)
-- Line 3: Fishing Skill Requirement (Muted, no colon, "Fishing 130 - 205")
--
-- Secure Execution & Non-Tainting Architecture:
-- Uses Blizzard's native MapAreaLabelDataProvider and post-hooks EvaluateLabels
-- via hooksecurefunc. Never replaces or modifies Blizzard script handlers.
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals
-- ----------------------------------------------------------------------------
local _G = _G
local UnitLevel = _G.UnitLevel
local C_Map = _G.C_Map
local string = string
local math = math
local pairs = pairs
local hooksecurefunc = _G.hooksecurefunc
local MAP_AREA_LABEL_TYPE = _G.MAP_AREA_LABEL_TYPE or { AREA_NAME = 1 }

local AreaLabelProvider = {
    isInitialized = false,
    levelText = nil,
    fishingText = nil,
    targetLabelFrame = nil,
    zoneLevelsByName = nil,
}

-- ----------------------------------------------------------------------------
-- 2. Zone Difficulty Coloring System
-- ----------------------------------------------------------------------------
--- Evaluates difficulty color considering both the top end and bottom end of the zone.
--- - If player is 5+ levels above maxLevel: Grey (Trivial)
--- - If player is 3-4 levels above maxLevel: Green
--- - If player is within or close to range (minLevel - 2 <= player <= maxLevel + 2): Yellow
--- - If player is 3-4 levels below minLevel: Orange
--- - If player is 5+ levels below minLevel: Red
--- @param playerLevel number
--- @param minLevel number
--- @param maxLevel number
--- @return number r, number g, number b, string hex
local function GetZoneDifficultyColor(playerLevel, minLevel, maxLevel)
    playerLevel = playerLevel or 1
    minLevel = minLevel or 1
    maxLevel = maxLevel or 60

    -- 5+ levels above maxLevel -> Grey (Trivial)
    if playerLevel - maxLevel >= 5 then
        return 0.60, 0.60, 0.60, "999999"
    -- 3-4 levels above maxLevel -> Green (Low Challenge)
    elseif playerLevel - maxLevel >= 3 then
        return 0.25, 0.90, 0.25, "40e640"
    -- Active bracket & buffer zone (within 2 levels of either bound) -> Yellow / Gold
    elseif playerLevel >= (minLevel - 2) and playerLevel <= (maxLevel + 2) then
        return 1.00, 0.82, 0.00, "ffd100"
    -- 3-4 levels below minLevel -> Orange (Challenging)
    elseif (minLevel - playerLevel) <= 4 then
        return 1.00, 0.50, 0.25, "ff8040"
    -- 5+ levels below minLevel -> Red (Very Difficult)
    else
        return 1.00, 0.20, 0.20, "ff3333"
    end
end

ns.GetZoneDifficultyColor = GetZoneDifficultyColor

-- ----------------------------------------------------------------------------
-- 3. Label Frame Setup & Stacked FontStrings
-- ----------------------------------------------------------------------------
local function EnsureCustomFontStrings(labelFrame)
    if AreaLabelProvider.levelText and AreaLabelProvider.fishingText then
        return AreaLabelProvider.levelText, AreaLabelProvider.fishingText
    end

    local titleFont, titleSize, titleFlags = "Fonts\\FRIZQT__.TTF", 20, "OUTLINE"
    if labelFrame.Name and labelFrame.Name.GetFont then
        local f, s, fl = labelFrame.Name:GetFont()
        if f then
            titleFont = f
            titleSize = s or 20
            titleFlags = (fl and fl ~= "") and fl or "OUTLINE"
        end
    end

    local levelSize = math.max(16, math.floor(titleSize * 0.81))
    local fishSize = math.max(13, math.floor(titleSize * 0.55))

    -- Sub-header (H2/H3): same font family and style (outline) as zone title
    local levelText = labelFrame:CreateFontString(nil, "OVERLAY")
    levelText:SetFont(titleFont, levelSize, titleFlags)
    levelText:SetJustifyH("CENTER")
    levelText:SetPoint("TOP", labelFrame.Name, "BOTTOM", 0, -2)
    levelText:Hide()
    AreaLabelProvider.levelText = levelText

    -- Fishing level: same font family and style (outline) as zone title, in smaller scale
    local fishText = labelFrame:CreateFontString(nil, "OVERLAY")
    fishText:SetFont(titleFont, fishSize, titleFlags)
    fishText:SetJustifyH("CENTER")
    fishText:SetTextColor(0.82, 0.78, 0.70)
    fishText:Hide()
    AreaLabelProvider.fishingText = fishText

    -- Inherit title shadow properties for pixel-perfect match
    if labelFrame.Name and labelFrame.Name.GetShadowOffset then
        local sx, sy = labelFrame.Name:GetShadowOffset()
        if sx and sy then
            levelText:SetShadowOffset(sx, sy)
            fishText:SetShadowOffset(sx, sy)
        end
        if labelFrame.Name.GetShadowColor then
            local sr, sg, sb, sa = labelFrame.Name:GetShadowColor()
            if sr then
                levelText:SetShadowColor(sr, sg, sb, sa)
                fishText:SetShadowColor(sr, sg, sb, sa)
            end
        end
    end

    AreaLabelProvider.targetLabelFrame = labelFrame
    return levelText, fishText
end

-- ----------------------------------------------------------------------------
-- 4. Zone Data Resolution (MapID & Name Matching)
-- ----------------------------------------------------------------------------
local function BuildZoneNameLookup()
    if AreaLabelProvider.zoneLevelsByName then
        return AreaLabelProvider.zoneLevelsByName
    end

    local lookup = {}
    for mapID, data in pairs(ns.MapAccess:GetZones()) do
        if C_Map and C_Map.GetMapInfo then
            local info = C_Map.GetMapInfo(mapID)
            if info and info.name and info.name ~= "" then
                lookup[info.name] = data
            end
        end
    end

    AreaLabelProvider.zoneLevelsByName = lookup
    return lookup
end

local function GetZoneData(map, zoneName)
    local zData = nil

    -- 1. Try resolving hovered child mapID from canvas cursor coordinates
    if map and map.GetMapID and map.GetNormalizedCursorPosition then
        local currentMapID = map:GetMapID()
        if currentMapID then
            local nx, ny = map:GetNormalizedCursorPosition()
            if nx and ny and nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
                local posInfo = C_Map and C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(currentMapID, nx, ny)
                if posInfo and posInfo.mapID and posInfo.mapID ~= currentMapID then
                    zData = ns.MapAccess:GetZone(posInfo.mapID)
                end
            end
        end
    end

    -- 2. Fallback to localized name-based lookup
    if not zData and zoneName and zoneName ~= "" then
        local nameLookup = BuildZoneNameLookup()
        zData = nameLookup[zoneName]
    end

    return zData
end

-- ----------------------------------------------------------------------------
-- 5. Secure Post-Hook Label Evaluation
-- ----------------------------------------------------------------------------
local function OnEvaluateLabels(provider, labelFrame)
    local levelText = AreaLabelProvider.levelText
    local fishText = AreaLabelProvider.fishingText

    if not levelText or not fishText then
        levelText, fishText = EnsureCustomFontStrings(labelFrame)
    end

    -- If labelFrame or labelFrame.Name is not shown, hide custom labels
    if not labelFrame:IsShown() or not labelFrame.Name or not labelFrame.Name:IsShown() then
        levelText:SetText("")
        levelText:Hide()
        fishText:SetText("")
        fishText:Hide()
        return
    end

    local zoneName = labelFrame.Name:GetText()
    if not zoneName or zoneName == "" then
        levelText:SetText("")
        levelText:Hide()
        fishText:SetText("")
        fishText:Hide()
        return
    end

    local showLevels = true
    local showFishing = true
    if ns.Settings and ns.Settings.GetMapIconsSetting then
        showLevels = ns.Settings:GetMapIconsSetting("showZoneLevels", true) ~= false
        showFishing = ns.Settings:GetMapIconsSetting("showFishingLevels", true) ~= false
    end

    local map = (provider and provider.GetMap and provider:GetMap()) or _G.WorldMapFrame
    local zData = GetZoneData(map, zoneName)

    if zData then
        local hasLevels = zData.minLevel and zData.maxLevel and zData.minLevel > 0 and zData.maxLevel > 0
        if showLevels and hasLevels then
            local pLevel = UnitLevel("player") or 1
            local r, g, b, hex = GetZoneDifficultyColor(pLevel, zData.minLevel, zData.maxLevel)
            local levelStr
            if zData.minLevel == zData.maxLevel then
                levelStr = string.format("%d", zData.maxLevel)
            else
                levelStr = string.format("%d - %d", zData.minLevel, zData.maxLevel)
            end
            levelText:SetText(string.format("|cff%s%s|r", hex, levelStr))
            levelText:ClearAllPoints()
            levelText:SetPoint("TOP", labelFrame.Name, "BOTTOM", 0, -2)
            levelText:Show()
        else
            levelText:SetText("")
            levelText:Hide()
        end

        if showFishing and zData.fishing and zData.fishing ~= "" then
            fishText:SetText(string.format("Fishing %s", zData.fishing))
            fishText:ClearAllPoints()
            if levelText:IsShown() then
                fishText:SetPoint("TOP", levelText, "BOTTOM", 0, -3)
            else
                fishText:SetPoint("TOP", labelFrame.Name, "BOTTOM", 0, -2)
            end
            fishText:Show()
        else
            fishText:SetText("")
            fishText:Hide()
        end
    else
        levelText:SetText("")
        levelText:Hide()
        fishText:SetText("")
        fishText:Hide()
    end
end

-- ----------------------------------------------------------------------------
-- 6. Hook Provider Registration (Secure & Non-Tainting)
-- ----------------------------------------------------------------------------
function AreaLabelProvider:Init()
    if self.isInitialized then return end
    if not _G.WorldMapFrame or not _G.WorldMapFrame.dataProviders then return end

    for provider in pairs(_G.WorldMapFrame.dataProviders) do
        if provider and provider.Label and provider.Label.EvaluateLabels then
            EnsureCustomFontStrings(provider.Label)

            -- Securely post-hook EvaluateLabels without modifying provider scripts
            if hooksecurefunc then
                hooksecurefunc(provider.Label, "EvaluateLabels", function(labelFrame)
                    OnEvaluateLabels(provider, labelFrame)
                end)

                if provider.Label.ClearLabel then
                    hooksecurefunc(provider.Label, "ClearLabel", function(labelFrame, labelType)
                        if labelType == MAP_AREA_LABEL_TYPE.AREA_NAME then
                            if AreaLabelProvider.levelText then AreaLabelProvider.levelText:Hide() end
                            if AreaLabelProvider.fishingText then AreaLabelProvider.fishingText:Hide() end
                        end
                    end)
                end
            end

            self.isInitialized = true
            break
        end
    end
end

ns.AreaLabelProvider = AreaLabelProvider
