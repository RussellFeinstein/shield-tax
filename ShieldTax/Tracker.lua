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

function Tracker:Init()
    -- Get shield slot ID from API (not hardcoded)
    shieldSlot = GetInventorySlotInfo("SecondaryHandSlot")

    -- Take initial snapshot
    self:UpdateShieldInfo()
    self:SnapshotDurability()

    -- Register events
    ShieldTax:RegisterEvent("PLAYER_REGEN_DISABLED", function() Tracker:OnCombatStart() end)
    ShieldTax:RegisterEvent("PLAYER_REGEN_ENABLED", function() Tracker:OnCombatEnd() end)
    ShieldTax:RegisterEvent("UPDATE_INVENTORY_DURABILITY", function() Tracker:OnDurabilityChanged() end)
    ShieldTax:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slot) Tracker:OnEquipmentChanged(slot) end)
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
        ShieldTax:RegisterEvent("ITEM_DATA_LOAD_RESULT", function()
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
end

function Tracker:OnEquipmentChanged(slot)
    -- Only care about shield slot changes
    if slot ~= shieldSlot then return end

    self:UpdateShieldInfo()
    self:SnapshotDurability()
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
        -- Check death guard: ignore durability loss within DEATH_GUARD_DURATION of death
        if recentDeath and (GetTime() - deathTime) < DEATH_GUARD_DURATION then
            -- Attribute to death, not combat
            local costCopper = ShieldTax.CostCalculator:GetCostPerPoint(shieldItemLink) * durabilityLost
            ShieldTax:OnDeathTaxEvent(costCopper)
        elseif inCombat then
            -- Shield Tax! Durability lost during combat
            local costCopper = ShieldTax.CostCalculator:GetCostPerPoint(shieldItemLink) * durabilityLost
            ShieldTax:OnShieldTaxEvent(costCopper, durabilityLost)
        end
        -- Out-of-combat, non-death durability loss is ignored (shouldn't really happen for shields)
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
