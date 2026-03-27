---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local Tracker = {}
ShieldTax.Tracker = Tracker

-- State
local shieldSlot
local previousDurability
local maxDurability
local inCombat = false
local recentDeath = false
local deathTime = 0
local hasShield = false
local shieldItemLink = nil

-- Constants
local DEATH_GUARD_DURATION = 5  -- seconds to ignore durability loss after death

-- Content type constants
Tracker.CONTENT_TYPES = {
    MYTHICPLUS = "mythicplus",
    RAID = "raid",
    DUNGEON = "dungeon",
    OPENWORLD = "openworld",
    OTHER = "other",
}

--- Classify the current content type based on instance info.
---@return string contentType One of the CONTENT_TYPES values
function Tracker:GetContentType()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return self.CONTENT_TYPES.OPENWORLD
    end

    -- Check for M+ first (C_ChallengeMode)
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        if level and level > 0 then
            return self.CONTENT_TYPES.MYTHICPLUS
        end
    end

    if instanceType == "raid" then
        return self.CONTENT_TYPES.RAID
    elseif instanceType == "party" then
        return self.CONTENT_TYPES.DUNGEON
    else
        return self.CONTENT_TYPES.OTHER
    end
end

--- Check if tracking is enabled for the given content type.
---@param contentType string
---@return boolean
function Tracker:IsContentEnabled(contentType)
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db or not db.contentToggles then return true end
    local enabled = db.contentToggles[contentType]
    if enabled == nil then return true end  -- default on
    return enabled
end

function Tracker:Init()
    -- Get shield slot ID from API (not hardcoded)
    shieldSlot = GetInventorySlotInfo("SecondaryHandSlot")

    -- Take initial snapshot
    self:UpdateShieldInfo()
    self:SnapshotDurability()

    -- Register events (AceEvent passes event name as first arg to function handlers)
    ShieldTax:RegisterEvent("PLAYER_REGEN_DISABLED", function() Tracker:OnCombatStart() end)
    ShieldTax:RegisterEvent("PLAYER_REGEN_ENABLED", function() Tracker:OnCombatEnd() end)
    ShieldTax:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() Tracker:OnDurabilityChanged() end)
    ShieldTax:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(event, slot) Tracker:OnEquipmentChanged(slot) end)
    ShieldTax:RegisterEvent("PLAYER_DEAD", function() Tracker:OnPlayerDead() end)
    ShieldTax:RegisterEvent("PLAYER_ALIVE", function() Tracker:OnPlayerAlive() end)
    ShieldTax:RegisterEvent("PLAYER_UNGHOST", function() Tracker:OnPlayerAlive() end)
end

--- Check if a shield is equipped and update item info.
function Tracker:UpdateShieldInfo()
    local itemLink = GetInventoryItemLink("player", shieldSlot)
    if not itemLink then
        hasShield = false
        shieldItemLink = nil
        return
    end

    -- Validate it is actually a shield (not an off-hand weapon/held item)
    local info = { C_Item.GetItemInfo(itemLink) }
    if not info[1] then
        -- Item data not cached yet; assume shield for now, retry on ITEM_DATA_LOAD_RESULT
        hasShield = true
        shieldItemLink = itemLink
        ShieldTax:RegisterEvent("ITEM_DATA_LOAD_RESULT", function(event)
            Tracker:UpdateShieldInfo()
            Tracker:SnapshotDurability()
            ShieldTax:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
        end)
        return
    end

    local itemEquipLoc = info[9]  -- 9th return value of GetItemInfo
    if itemEquipLoc == "INVTYPE_SHIELD" then
        hasShield = true
        shieldItemLink = itemLink
    else
        hasShield = false
        shieldItemLink = nil
    end
end

--- Snapshot current shield durability.
function Tracker:SnapshotDurability()
    if not shieldSlot then return end

    local current, maximum = GetInventoryItemDurability(shieldSlot)
    if current and maximum then
        previousDurability = current
        maxDurability = maximum
    else
        previousDurability = nil
        maxDurability = nil
    end
end

function Tracker:OnCombatStart()
    inCombat = true
end

function Tracker:OnCombatEnd()
    inCombat = false
end

function Tracker:OnPlayerDead()
    recentDeath = true
    deathTime = GetTime()
end

function Tracker:OnPlayerAlive()
    recentDeath = false
    -- Re-snapshot durability after resurrection to prevent phantom costs
    -- from the death durability hit being double-counted
    self:SnapshotDurability()
end

function Tracker:OnEquipmentChanged(slot)
    -- Only care about shield slot changes
    if slot ~= shieldSlot then return end

    self:UpdateShieldInfo()
    self:SnapshotDurability()

    -- Refresh display to show/hide "No shield equipped" state
    if ShieldTax.Display then
        ShieldTax.Display:Update()
    end
end

function Tracker:OnDurabilityChanged()
    if not hasShield or not previousDurability then
        self:SnapshotDurability()
        return
    end

    local current, maximum = GetInventoryItemDurability(shieldSlot)
    if not current then
        -- Shield may have been unequipped
        previousDurability = nil
        maxDurability = nil
        return
    end

    local durabilityLost = previousDurability - current

    if durabilityLost > 0 then
        local contentType = self:GetContentType()

        -- Death guard: check both the flag AND UnitIsDeadOrGhost as a fallback.
        -- UPDATE_INVENTORY_DURABILITY can fire before PLAYER_DEAD in the same frame,
        -- so recentDeath may not be set yet when durability loss from death arrives.
        local isDead = (recentDeath and (GetTime() - deathTime) < DEATH_GUARD_DURATION)
            or UnitIsDeadOrGhost("player")

        if isDead then
            -- Attribute to death, not combat
            local costCopper = ShieldTax.CostCalculator:GetCostPerPoint(shieldItemLink) * durabilityLost
            ShieldTax:OnDeathTaxEvent(costCopper, contentType)
        elseif inCombat and self:IsContentEnabled(contentType) then
            -- Shield Tax! Durability lost during combat in enabled content
            local costCopper = ShieldTax.CostCalculator:GetCostPerPoint(shieldItemLink) * durabilityLost
            ShieldTax:OnShieldTaxEvent(costCopper, durabilityLost, contentType)
        end
        -- Out-of-combat, non-death, or disabled-content durability loss is ignored
    end

    -- Update snapshot
    previousDurability = current
    maxDurability = maximum
end

--- Get current shield durability as a fraction (0-1), or nil if no shield.
function Tracker:GetShieldDurability()
    if not hasShield or not shieldSlot then return nil end

    local current, maximum = GetInventoryItemDurability(shieldSlot)
    if not current or not maximum or maximum == 0 then return nil end

    return current / maximum
end

--- Check if a shield is currently equipped and valid.
function Tracker:HasShield()
    return hasShield
end

--- Get the current shield item link, or nil.
function Tracker:GetShieldItemLink()
    return shieldItemLink
end

-- Expose state for testing
function Tracker:IsInCombat()
    return inCombat
end

function Tracker:IsRecentDeath()
    return recentDeath
end

-- Reset state (for testing)
function Tracker:Reset()
    previousDurability = nil
    maxDurability = nil
    inCombat = false
    recentDeath = false
    deathTime = 0
    hasShield = false
    shieldItemLink = nil
end
