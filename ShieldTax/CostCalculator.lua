---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local CostCalculator = {}
ShieldTax.CostCalculator = CostCalculator

-- Quality multipliers (silver per durability point per ilvl unit above 32.5)
local QUALITY_MULTIPLIERS = {
    [2] = 0.02,   -- Uncommon (Green)
    [3] = 0.025,  -- Rare (Blue)
    [4] = 0.05,   -- Epic (Purple)
    [5] = 0.05,   -- Legendary (Orange) — same as Epic for repair purposes
}

-- Fallback values when item info is unavailable
local FALLBACK_ILVL = 600
local FALLBACK_QUALITY = 4  -- Epic

--- Get the repair cost per durability point for the given item, in copper.
---@param itemLink string|nil The item link to calculate cost for
---@return number costCopper Cost per durability point in copper (1g = 10000 copper)
function CostCalculator:GetCostPerPoint(itemLink)
    if not itemLink then
        return self:CalculateCostPerPoint(FALLBACK_ILVL, FALLBACK_QUALITY)
    end

    -- Try to get effective item level (includes upgrades)
    local effectiveIlvl = nil
    if GetDetailedItemLevelInfo then
        effectiveIlvl = GetDetailedItemLevelInfo(itemLink)
    end

    -- Get base item info (C_Item.GetItemInfo deprecated in 12.0 but still functional)
    local info
    if C_Item and C_Item.GetItemInfo then
        info = { C_Item.GetItemInfo(itemLink) }
    end
    if not info or not info[1] then
        -- Item not cached or API unavailable, use fallback
        return self:CalculateCostPerPoint(FALLBACK_ILVL, FALLBACK_QUALITY)
    end

    local quality = info[3]   -- 3rd return: itemQuality
    local baseIlvl = info[4]  -- 4th return: itemLevel

    local ilvl = effectiveIlvl or baseIlvl or FALLBACK_ILVL

    return self:CalculateCostPerPoint(ilvl, quality or FALLBACK_QUALITY)
end

--- Calculate cost per durability point from item level and quality.
---@param ilvl number The item level
---@param quality number The item quality (2=Uncommon, 3=Rare, 4=Epic)
---@return number costCopper Cost per durability point in copper
function CostCalculator:CalculateCostPerPoint(ilvl, quality)
    local multiplier = QUALITY_MULTIPLIERS[quality] or QUALITY_MULTIPLIERS[FALLBACK_QUALITY]

    -- Formula: (ilvl - 32.5) * multiplier gives silver per point
    local costSilver = (ilvl - 32.5) * multiplier

    -- Clamp to 0 for very low ilvl items
    if costSilver < 0 then
        costSilver = 0
    end

    -- Convert silver to copper (1 silver = 100 copper)
    return costSilver * 100
end

--- Format a copper amount as a human-readable gold string.
---@param copper number Amount in copper
---@return string formatted e.g. "12g 34s 56c"
function CostCalculator:FormatGold(copper)
    if not copper or copper <= 0 then
        return "0g"
    end

    copper = math.floor(copper + 0.5)  -- Round to nearest copper

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperRemainder = copper % 100

    if gold > 0 and silver > 0 and copperRemainder > 0 then
        return string.format("%dg %ds %dc", gold, silver, copperRemainder)
    elseif gold > 0 and silver > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif gold > 0 and copperRemainder > 0 then
        return string.format("%dg %dc", gold, copperRemainder)
    elseif gold > 0 then
        return string.format("%dg", gold)
    elseif silver > 0 and copperRemainder > 0 then
        return string.format("%ds %dc", silver, copperRemainder)
    elseif silver > 0 then
        return string.format("%ds", silver)
    else
        return string.format("%dc", copperRemainder)
    end
end
