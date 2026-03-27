local Mock = require("tests.wow_api_mock")

local function loadAddon()
    Mock.reset()
    package.loaded["ShieldTax.Core"] = nil
    package.loaded["ShieldTax.CostCalculator"] = nil
    package.loaded["ShieldTax.Tracker"] = nil
    package.loaded["ShieldTax.SoundManager"] = nil
    package.loaded["ShieldTax.Stats"] = nil
    package.loaded["ShieldTax.Display"] = nil
    dofile("ShieldTax/Core.lua")
    dofile("ShieldTax/CostCalculator.lua")
    dofile("ShieldTax/Tracker.lua")
    dofile("ShieldTax/SoundManager.lua")
    dofile("ShieldTax/Stats.lua")
    dofile("ShieldTax/Display.lua")
end

describe("CostCalculator", function()
    local calc

    before_each(function()
        Mock.reset()
        loadAddon()
        local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        calc = addon.CostCalculator
    end)

    describe("CalculateCostPerPoint", function()
        it("calculates correct cost for Epic ilvl 639 shield", function()
            -- (639 - 32.5) * 0.05 = 30.325 silver = 3032.5 copper
            local cost = calc:CalculateCostPerPoint(639, 4)
            assert.are.near(3032.5, cost, 0.1)
        end)

        it("calculates correct cost for Rare ilvl 639 shield", function()
            -- (639 - 32.5) * 0.025 = 15.1625 silver = 1516.25 copper
            local cost = calc:CalculateCostPerPoint(639, 3)
            assert.are.near(1516.25, cost, 0.1)
        end)

        it("calculates correct cost for Uncommon ilvl 639 shield", function()
            -- (639 - 32.5) * 0.02 = 12.13 silver = 1213 copper
            local cost = calc:CalculateCostPerPoint(639, 2)
            assert.are.near(1213.0, cost, 0.1)
        end)

        it("clamps to 0 for very low ilvl", function()
            -- ilvl 30 < 32.5, would be negative
            local cost = calc:CalculateCostPerPoint(30, 4)
            assert.are.equal(0, cost)
        end)

        it("handles ilvl exactly at 32.5", function()
            -- Edge case: cost should be approximately 0
            local cost = calc:CalculateCostPerPoint(33, 4)
            assert.is_true(cost >= 0)
        end)

        it("uses Epic multiplier for Legendary quality", function()
            -- Quality 5 (Legendary) should use same multiplier as Epic
            local epicCost = calc:CalculateCostPerPoint(639, 4)
            local legendaryCost = calc:CalculateCostPerPoint(639, 5)
            assert.are.equal(epicCost, legendaryCost)
        end)
    end)

    describe("GetCostPerPoint", function()
        it("uses item link to determine cost", function()
            Mock.equipShield(639, 4, 120, 120)
            local itemLink = Mock.equippedItems[17]
            local cost = calc:GetCostPerPoint(itemLink)
            assert.are.near(3032.5, cost, 0.1)
        end)

        it("uses GetDetailedItemLevelInfo when available", function()
            Mock.equipShield(600, 4, 120, 120)
            local itemLink = Mock.equippedItems[17]

            -- Override with upgraded ilvl
            Mock.detailedIlvl[itemLink] = 639

            local cost = calc:GetCostPerPoint(itemLink)
            -- Should use 639, not 600
            assert.are.near(3032.5, cost, 0.1)
        end)

        it("falls back to base ilvl when GetDetailedItemLevelInfo returns nil", function()
            Mock.equipShield(600, 4, 120, 120)
            local itemLink = Mock.equippedItems[17]
            -- detailedIlvl not set, so nil

            local cost = calc:GetCostPerPoint(itemLink)
            -- Should use base ilvl 600
            local expected = (600 - 32.5) * 0.05 * 100
            assert.are.near(expected, cost, 0.1)
        end)

        it("uses fallback for nil item link", function()
            local cost = calc:GetCostPerPoint(nil)
            -- Fallback: ilvl 600, Epic
            local expected = (600 - 32.5) * 0.05 * 100
            assert.are.near(expected, cost, 0.1)
        end)

        it("uses fallback for uncached item", function()
            local unknownLink = "|cff0070dd|Hitem:99999:0|h[Unknown]|h|r"
            -- Not in itemInfoCache
            local cost = calc:GetCostPerPoint(unknownLink)
            local expected = (600 - 32.5) * 0.05 * 100
            assert.are.near(expected, cost, 0.1)
        end)
    end)

    describe("FormatGold", function()
        it("formats 0 copper", function()
            assert.are.equal("0g", calc:FormatGold(0))
        end)

        it("formats nil as 0g", function()
            assert.are.equal("0g", calc:FormatGold(nil))
        end)

        it("formats copper only", function()
            assert.are.equal("50c", calc:FormatGold(50))
        end)

        it("formats silver only", function()
            assert.are.equal("5s", calc:FormatGold(500))
        end)

        it("formats silver and copper", function()
            assert.are.equal("5s 50c", calc:FormatGold(550))
        end)

        it("formats gold only", function()
            assert.are.equal("1g", calc:FormatGold(10000))
        end)

        it("formats gold and silver", function()
            assert.are.equal("1g 23s", calc:FormatGold(12300))
        end)

        it("formats gold, silver, and copper", function()
            assert.are.equal("1g 23s 45c", calc:FormatGold(12345))
        end)

        it("formats large gold amounts", function()
            assert.are.equal("1000g", calc:FormatGold(10000000))
        end)

        it("formats gold and copper (no silver)", function()
            assert.are.equal("1g 1c", calc:FormatGold(10001))
        end)

        it("rounds fractional copper", function()
            -- 3032.5 copper should round to 3033 = 30s 33c
            assert.are.equal("30s 33c", calc:FormatGold(3032.5))
        end)
    end)
end)
