local Mock = require("tests.wow_api_mock")

local function loadAddon()
    package.loaded["ShieldTax.Core"] = nil
    package.loaded["ShieldTax.CostCalculator"] = nil
    package.loaded["ShieldTax.Tracker"] = nil
    package.loaded["ShieldTax.SoundManager"] = nil
    package.loaded["ShieldTax.Stats"] = nil
    package.loaded["ShieldTax.Display"] = nil
    package.loaded["ShieldTax.ChatReporter"] = nil
    package.loaded["ShieldTax.MinimapButton"] = nil
    dofile("ShieldTax/Core.lua")
    dofile("ShieldTax/CostCalculator.lua")
    dofile("ShieldTax/Tracker.lua")
    dofile("ShieldTax/SoundManager.lua")
    dofile("ShieldTax/Stats.lua")
    dofile("ShieldTax/Display.lua")
    dofile("ShieldTax/ChatReporter.lua")
    dofile("ShieldTax/MinimapButton.lua")
end

describe("Content Types", function()
    local addon, tracker

    before_each(function()
        Mock.reset()
        Mock.equipShield(639, 4, 100, 120)
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        tracker = addon.Tracker
        tracker:Init()
    end)

    describe("GetContentType", function()
        it("returns openworld when not in instance", function()
            Mock.inInstance = false
            Mock.instanceType = nil
            assert.are.equal("openworld", tracker:GetContentType())
        end)

        it("returns dungeon in a party instance", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = nil
            assert.are.equal("dungeon", tracker:GetContentType())
        end)

        it("returns mythicplus when keystone is active", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 12
            assert.are.equal("mythicplus", tracker:GetContentType())
        end)

        it("returns raid in a raid instance", function()
            Mock.inInstance = true
            Mock.instanceType = "raid"
            assert.are.equal("raid", tracker:GetContentType())
        end)

        it("returns other for pvp/arena", function()
            Mock.inInstance = true
            Mock.instanceType = "pvp"
            assert.are.equal("other", tracker:GetContentType())
        end)
    end)

    describe("Content Toggles", function()
        it("tracks when content type is enabled (default)", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 12

            tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.is_true(charData.lifetime.totalCostCopper > 0)
        end)

        it("skips tracking when content type is disabled", function()
            addon.db.profile.contentToggles.openworld = false
            Mock.inInstance = false
            Mock.instanceType = nil

            tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
        end)

        it("still tracks other enabled content when one is disabled", function()
            addon.db.profile.contentToggles.openworld = false

            -- In M+ (enabled)
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 15

            tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.is_true(charData.lifetime.totalCostCopper > 0)
        end)
    end)

    describe("Per-Content Stats", function()
        it("records content type in lifetime byContent", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 12

            tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            local mpStats = charData.lifetime.byContent.mythicplus
            assert.is_not_nil(mpStats)
            assert.is_true(mpStats.costCopper > 0)
            assert.are.equal(1, mpStats.durabilityLost)
            assert.are.equal(1, mpStats.events)
        end)

        it("records content type in session byContent", function()
            Mock.inInstance = true
            Mock.instanceType = "raid"
            Mock.keystoneLevel = nil

            tracker:OnCombatStart()
            Mock.durability[17] = { 98, 120 }
            tracker:OnDurabilityChanged()

            local ss = addon.Stats:GetSession()
            assert.is_not_nil(ss.byContent.raid)
            assert.is_true(ss.byContent.raid.costCopper > 0)
            assert.are.equal(2, ss.byContent.raid.durabilityLost)
        end)

        it("tracks multiple content types independently", function()
            -- Open world combat
            Mock.inInstance = false
            Mock.instanceType = nil
            tracker:OnCombatStart()
            Mock.durability[17] = { 99, 120 }
            tracker:OnDurabilityChanged()
            tracker:OnCombatEnd()

            -- Then M+ combat
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 10
            tracker:OnCombatStart()
            Mock.durability[17] = { 97, 120 }
            tracker:OnDurabilityChanged()

            local charData = addon:GetCharData()
            assert.is_true(charData.lifetime.byContent.openworld.costCopper > 0)
            assert.is_true(charData.lifetime.byContent.mythicplus.costCopper > 0)
            assert.are.equal(1, charData.lifetime.byContent.openworld.durabilityLost)
            assert.are.equal(2, charData.lifetime.byContent.mythicplus.durabilityLost)
        end)

        it("records contentType on dungeon history entries", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.keystoneLevel = 15
            Mock.instanceInfo = { "The Stonevault", "party", 1, "Mythic", 0, 0, false, 1, 5 }
            Mock.serverTime = 1700001000

            addon.Stats:OnKeystoneStart()
            addon.Stats:RecordShieldTax(50000, 5, "mythicplus")
            Mock.serverTime = 1700002000
            addon.Stats:FinalizeDungeon()

            local history = addon.Stats:GetHistory(1)
            assert.are.equal(1, #history)
            assert.are.equal("mythicplus", history[1].contentType)
        end)
    end)

    describe("Slash Commands", function()
        it("/st content shows toggle status", function()
            addon:HandleSlashCommand("content")
            -- No error = success
        end)

        it("/st content toggles a content type", function()
            addon:HandleSlashCommand("content mythicplus")
            assert.is_false(addon.db.profile.contentToggles.mythicplus)

            addon:HandleSlashCommand("content mythicplus")
            assert.is_true(addon.db.profile.contentToggles.mythicplus)
        end)

        it("/st content rejects invalid types", function()
            addon:HandleSlashCommand("content invalid")
            -- No error, no change to toggles
        end)

        it("/st stats shows content breakdown", function()
            -- Add some data
            addon:OnShieldTaxEvent(50000, 5, "mythicplus")
            addon:OnShieldTaxEvent(30000, 3, "raid")
            addon:HandleSlashCommand("stats")
            -- No error = success
        end)
    end)
end)
