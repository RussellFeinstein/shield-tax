local Mock = require("tests.wow_api_mock")

-- Load the addon source files (after mock is in place).
-- Call Mock.reset() BEFORE this to set up desired state.
local function loadAddon()
    -- Clear previously loaded addon modules
    package.loaded["ShieldTax.Core"] = nil
    package.loaded["ShieldTax.CostCalculator"] = nil
    package.loaded["ShieldTax.Tracker"] = nil
    dofile("ShieldTax/Core.lua")
    dofile("ShieldTax/CostCalculator.lua")
    dofile("ShieldTax/Tracker.lua")
end

describe("Tracker", function()

    describe("Class Guard", function()
        it("allows Warriors (uses classToken, not localized name)", function()
            Mock.reset()
            Mock.playerClass = { "Guerrier", "WARRIOR", 1 }  -- French localization
            loadAddon()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            assert.is_false(addon.disabled)
        end)

        it("rejects non-Warriors", function()
            Mock.reset()
            Mock.playerClass = { "Paladin", "PALADIN", 2 }
            loadAddon()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            assert.is_true(addon.disabled)
        end)

        it("rejects Mage", function()
            Mock.reset()
            Mock.playerClass = { "Mage", "MAGE", 8 }
            loadAddon()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            assert.is_true(addon.disabled)
        end)
    end)

    describe("Shield Detection", function()
        before_each(function()
            Mock.reset()
            loadAddon()
        end)

        it("detects a shield in slot 17", function()
            Mock.equipShield(639, 4, 120, 120)
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
            assert.is_true(addon.Tracker:HasShield())
        end)

        it("rejects a non-shield off-hand", function()
            Mock.equipOffhand()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
            assert.is_false(addon.Tracker:HasShield())
        end)

        it("handles empty slot 17", function()
            -- No item equipped in slot 17
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
            assert.is_false(addon.Tracker:HasShield())
        end)
    end)

    describe("Durability Snapshot", function()
        before_each(function()
            Mock.reset()
            Mock.equipShield(639, 4, 100, 120)
            loadAddon()
        end)

        it("snapshots current shield durability on init", function()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
            -- Shield is at 100/120
            assert.is_not_nil(addon.Tracker:GetShieldDurability())
            assert.are.near(100/120, addon.Tracker:GetShieldDurability(), 0.01)
        end)
    end)

    describe("Combat Attribution", function()
        local addon

        before_each(function()
            Mock.reset()
            Mock.equipShield(639, 4, 100, 120)
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
        end)

        it("attributes durability loss during combat to Shield Tax", function()
            -- Enter combat
            addon.Tracker:OnCombatStart()
            assert.is_true(addon.Tracker:IsInCombat())

            -- Lose 1 durability
            Mock.durability[17] = { 99, 120 }
            addon.Tracker:OnDurabilityChanged()

            -- Check that Shield Tax was recorded
            local charData = addon:GetCharData()
            assert.is_true(charData.lifetime.totalCostCopper > 0)
            assert.are.equal(1, charData.lifetime.totalDurabilityLost)
            assert.are.equal(1, charData.lifetime.totalDurabilityEvents)
        end)

        it("ignores durability loss outside combat", function()
            -- Not in combat
            assert.is_false(addon.Tracker:IsInCombat())

            -- Lose 1 durability
            Mock.durability[17] = { 99, 120 }
            addon.Tracker:OnDurabilityChanged()

            -- No Shield Tax recorded
            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
            assert.are.equal(0, charData.lifetime.totalDurabilityLost)
        end)

        it("tracks multiple durability losses", function()
            addon.Tracker:OnCombatStart()

            -- Lose 2 durability
            Mock.durability[17] = { 98, 120 }
            addon.Tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.are.equal(2, charData.lifetime.totalDurabilityLost)
            assert.are.equal(1, charData.lifetime.totalDurabilityEvents)

            -- Lose 1 more
            Mock.durability[17] = { 97, 120 }
            addon.Tracker:OnDurabilityChanged()

            assert.are.equal(3, charData.lifetime.totalDurabilityLost)
            assert.are.equal(2, charData.lifetime.totalDurabilityEvents)
        end)

        it("does not count durability increases (repair)", function()
            addon.Tracker:OnCombatStart()

            -- Lose some first
            Mock.durability[17] = { 95, 120 }
            addon.Tracker:OnDurabilityChanged()

            local costAfterLoss = addon:GetCharData().lifetime.totalCostCopper

            -- Repair (durability goes up)
            Mock.durability[17] = { 120, 120 }
            addon.Tracker:OnDurabilityChanged()

            -- Cost should not have changed
            assert.are.equal(costAfterLoss, addon:GetCharData().lifetime.totalCostCopper)
        end)
    end)

    describe("Death Guard", function()
        local addon

        before_each(function()
            Mock.reset()
            Mock.equipShield(639, 4, 100, 120)
            Mock.gameTime = 100
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
        end)

        it("attributes durability loss near death to Death Tax", function()
            addon.Tracker:OnCombatStart()

            -- Player dies
            Mock.gameTime = 200
            addon.Tracker:OnPlayerDead()
            assert.is_true(addon.Tracker:IsRecentDeath())

            -- Durability loss within 5s of death
            Mock.gameTime = 201
            Mock.durability[17] = { 90, 120 }
            addon.Tracker:OnDurabilityChanged()

            -- Should be Death Tax, not Shield Tax
            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
            assert.is_true(charData.lifetime.deathTaxCopper > 0)
        end)

        it("clears death guard on PLAYER_ALIVE", function()
            addon.Tracker:OnPlayerDead()
            assert.is_true(addon.Tracker:IsRecentDeath())

            addon.Tracker:OnPlayerAlive()
            assert.is_false(addon.Tracker:IsRecentDeath())
        end)

        it("clears death guard on PLAYER_UNGHOST (covers corpse run path)", function()
            addon.Tracker:OnPlayerDead()
            assert.is_true(addon.Tracker:IsRecentDeath())

            -- PLAYER_UNGHOST fires on corpse run
            addon.Tracker:OnPlayerAlive()  -- same handler for both events
            assert.is_false(addon.Tracker:IsRecentDeath())
        end)

        it("resumes Shield Tax tracking after death guard clears", function()
            addon.Tracker:OnCombatStart()

            -- Die and clear death
            Mock.gameTime = 200
            addon.Tracker:OnPlayerDead()
            addon.Tracker:OnPlayerAlive()

            -- Now lose durability in combat — should be Shield Tax
            Mock.gameTime = 210
            Mock.durability[17] = { 99, 120 }
            addon.Tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.is_true(charData.lifetime.totalCostCopper > 0)
        end)
    end)

    describe("Equipment Change", function()
        local addon

        before_each(function()
            Mock.reset()
            Mock.equipShield(639, 4, 100, 120)
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()
        end)

        it("re-snapshots on shield slot change", function()
            -- Initially at 100/120
            assert.is_true(addon.Tracker:HasShield())

            -- Swap to a different shield with different durability
            local newLink = "|cff0070dd|Hitem:67890:0:0:0:0:0:0:0:0|h[New Shield]|h|r"
            Mock.equippedItems[17] = newLink
            Mock.durability[17] = { 80, 100 }
            Mock.itemInfoCache[newLink] = {
                "New Shield", newLink, 4, 600, 1, "Armor", "Shields", 1,
                "INVTYPE_SHIELD", 132384, 40000, 4, 6,
            }

            addon.Tracker:OnEquipmentChanged(17)
            assert.is_true(addon.Tracker:HasShield())
            assert.are.near(80/100, addon.Tracker:GetShieldDurability(), 0.01)
        end)

        it("ignores non-shield slot changes", function()
            -- Change helm (slot 1), should NOT trigger re-snapshot
            addon.Tracker:OnEquipmentChanged(1)
            -- Still has original shield
            assert.is_true(addon.Tracker:HasShield())
        end)

        it("detects shield unequip", function()
            -- Remove shield
            Mock.equippedItems[17] = nil
            Mock.durability[17] = nil

            addon.Tracker:OnEquipmentChanged(17)
            assert.is_false(addon.Tracker:HasShield())
        end)
    end)

    describe("firstSeen", function()
        it("sets firstSeen on first Shield Tax event", function()
            Mock.reset()
            Mock.equipShield(639, 4, 100, 120)
            Mock.serverTime = 1700000500
            loadAddon()
            local addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon.Tracker:Init()

            local charData = addon:GetCharData()
            assert.is_nil(charData.lifetime.firstSeen)

            -- Trigger a Shield Tax event
            addon.Tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            addon.Tracker:OnDurabilityChanged()

            assert.are.equal(1700000500, charData.lifetime.firstSeen)
        end)
    end)
end)
