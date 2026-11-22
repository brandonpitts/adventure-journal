-- ============================================================================
-- Adventure Journal - Core/GameApi.lua
-- The client calls the Journal's screens make, each wrapped once: item info,
-- quality colors, item tooltips and clicks, creature portraits, atlases, the
-- world map and waypoints, the player's quest log, and shift-clicked item
-- links. Each wrapper uses the
-- one call Forever (1.60.1) provides, checked against the client's own API
-- lists (BlizzardInterfaceResources, forever branch).
-- ============================================================================
local addonName, ns = ...

-- ----------------------------------------------------------------------------
-- 1. Upvalued Globals & Engine APIs
-- ----------------------------------------------------------------------------
local pcall = pcall
local type = type
local hooksecurefunc = hooksecurefunc
local C_Item = C_Item
local C_Map = C_Map
local C_QuestLog = C_QuestLog
local C_SuperTrack = C_SuperTrack
local C_Texture = C_Texture
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local UIErrorsFrame = UIErrorsFrame
local ERR_NOT_IN_COMBAT = ERR_NOT_IN_COMBAT
local UiMapPoint = UiMapPoint
local SetPortraitTextureFromCreatureDisplayID = SetPortraitTextureFromCreatureDisplayID

-- ----------------------------------------------------------------------------
-- 2. Private File Helpers & Constants
-- ----------------------------------------------------------------------------
-- (None required)

-- ----------------------------------------------------------------------------
-- 3. Module Definition
-- ----------------------------------------------------------------------------
local GameApi = {}

--- An item's info (C_Item.GetItemInfo's 13 returns). An item the client hasn't loaded yet is requested, and
--- answered from its instant info instead: name, link, level and price are nil, quality 1.
--- @param itemID number
function GameApi:GetItemInfo(itemID)
    if not itemID then
        return nil
    end
    C_Item.RequestLoadItemDataByID(itemID)
    local name, link, quality, itemLevel, reqLevel, itemType, subType, maxStack, equipLoc, texture, price,
        classID, subclassID = C_Item.GetItemInfo(itemID)
    if name then
        return name, link, quality, itemLevel, reqLevel, itemType, subType, maxStack, equipLoc, texture, price,
            classID, subclassID
    end
    local _, instType, instSubType, instEquipLoc, icon, instClassID, instSubclassID = C_Item.GetItemInfoInstant(itemID)
    if instType or instClassID then
        return nil, nil, 1, nil, nil, instType, instSubType, nil, instEquipLoc, icon, nil, instClassID, instSubclassID
    end
    return nil
end

--- An item's icon, or nil.
function GameApi:GetItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID)
end

--- The color of an item quality (default 1, common).
--- @return number r, number g, number b
function GameApi:GetQualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor(quality or 1)
    return r or 1, g or 1, b or 1
end

--- Shows the item tooltip for `owner`: the item link when there is one, else the item ID.
function GameApi:ShowItemTooltip(owner, itemID, itemLink)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if itemLink and itemLink:find("|Hitem:") then
        GameTooltip:SetHyperlink(itemLink)
    else
        GameTooltip:SetItemByID(itemID)
    end
    GameTooltip:Show()
end

--- A click on an item: Shift links it in chat, Ctrl previews it in the dressing room (the game's own handling).
function GameApi:HandleItemClick(itemLink)
    if itemLink then
        HandleModifiedItemClick(itemLink)
    end
end

--- Draws a creature's 2D portrait into `texture`; false when the display ID is unusable.
--- @return boolean
function GameApi:SetCreaturePortrait(texture, displayID)
    if type(displayID) ~= "number" or displayID <= 0 then
        return false
    end
    return (pcall(SetPortraitTextureFromCreatureDisplayID, texture, displayID))
end

--- An atlas's info and file, or nil when this client lacks the atlas.
--- @return table|nil info, number|string|nil file
function GameApi:GetAtlasInfo(name)
    local info = C_Texture.GetAtlasInfo(name)
    local file = info and (info.file or info.filename)
    if file and info.width and info.width > 0 then
        return info, file
    end
end

--- Opens the world map on `uiMapID` (the Journal stays open). Out of combat only.
-- Opens through C_Map, never OpenWorldMap or WorldMapFrame:SetMapID: those taint the map's pins, and the
-- game then blocks the map's own SetPassThroughButtons calls.
function GameApi:OpenWorldMap(uiMapID)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1)
        return
    end
    C_Map.OpenWorldMap(uiMapID)
end

--- Places and tracks the game's own map pin at x, y on `uiMapID` (x and y as 0-1 or 0-100).
function GameApi:SetWaypoint(uiMapID, x, y)
    if not (uiMapID and x and y) then
        return
    end
    local normX = (x > 1) and (x / 100) or x
    local normY = (y > 1) and (y / 100) or y
    C_Map.ClearUserWaypoint()
    if C_Map.CanSetUserWaypointOnMap(uiMapID) then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(uiMapID, normX, normY))
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

--- Whether the player has completed the quest.
function GameApi:IsQuestCompleted(questID)
    return C_QuestLog.IsQuestFlaggedCompleted(questID) == true
end

--- Whether the quest is in the player's quest log.
function GameApi:IsQuestActive(questID)
    return C_QuestLog.IsOnQuest(questID) == true
end

--- Opens the world map and quest log to one quest's details, showing only that quest on the map (what clicking
--- a quest's title in the objective tracker does). The quest must be in the player's quest log.
function GameApi:OpenQuestInLog(questID)
    if questID and QuestMapFrame_OpenToQuestDetails and self:IsQuestActive(questID) then
        pcall(QuestMapFrame_OpenToQuestDetails, questID)
    end
end

--- Calls `handler(itemName)` when the player shift-clicks an item link anywhere and no chat box is open to take
--- it (a chat box keeps priority). Runs after the game's own link handling; `handler` decides whether to use it.
function GameApi:OnItemLinkInserted(handler)
    if not (ChatFrameUtil and ChatFrameUtil.InsertLink) then
        return
    end
    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link)
        if type(link) ~= "string" or not link:find("|Hitem:", 1, true) then
            return
        end
        if ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow() then
            return
        end
        local name = link:match("|h%[(.-)%]|h")
        if name and name ~= "" then
            handler(name)
        end
    end)
end

-- ----------------------------------------------------------------------------
-- 4. Namespace Attachment
-- ----------------------------------------------------------------------------
ns.GameApi = GameApi
