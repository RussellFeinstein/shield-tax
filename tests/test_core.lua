local Mock = require("tests.wow_api_mock")

local function loadAddon()
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
    dofile("ShieldTax/ChatReporter.lua")
    dofile("ShieldTax/MinimapButton.lua")
end

describe("Core", function()
    local addon

    before_each(function()
        Mock.reset()
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
    end)

    describe("Slash Commands", function()
        it("handles /st version", function()
            -- Should not error
            addon:HandleSlashCommand("version")
        end)

        it("handles /st help", function()
            addon:HandleSlashCommand("help")
        end)

        it("handles /st with no args (toggle display)", function()
            addon.Display:Init()
            addon:HandleSlashCommand("")
        end)

        it("handles /st sound with no args (show current)", function()
            addon:HandleSlashCommand("sound")
        end)

        it("handles /st sound test", function()
            addon:HandleSlashCommand("sound test")
        end)

        it("handles /st sound with valid key", function()
            addon:HandleSlashCommand("sound register")
            assert.are.equal("register", addon.db.profile.soundEffect)
        end)

        it("handles /st sound with invalid key", function()
            local original = addon.db.profile.soundEffect
            addon:HandleSlashCommand("sound invalid_key")
            assert.are.equal(original, addon.db.profile.soundEffect)
        end)

        it("handles /st session", function()
            addon:HandleSlashCommand("session")
        end)

        it("handles /st lifetime", function()
            addon:HandleSlashCommand("lifetime")
        end)

        it("handles /st unknown command", function()
            addon:HandleSlashCommand("unknowncmd")
        end)
    end)

    describe("Reset Commands", function()
        it("resets dungeon counter", function()
            addon.Stats:RecordShieldTax(10000, 3)
            addon:HandleSlashCommand("reset")
            local dg = addon.Stats:GetDungeon()
            assert.are.equal(0, dg.costCopper)
        end)

        it("resets session counter", function()
            addon.Stats:RecordShieldTax(10000, 3)
            addon:HandleSlashCommand("reset session")
            local ss = addon.Stats:GetSession()
            assert.are.equal(0, ss.costCopper)
        end)

        it("resets all data", function()
            addon.Stats:RecordShieldTax(10000, 3)
            addon:OnShieldTaxEvent(10000, 3)
            addon:HandleSlashCommand("reset all")

            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
            assert.are.equal(0, charData.lifetime.totalDurabilityLost)

            local ss = addon.Stats:GetSession()
            assert.are.equal(0, ss.costCopper)
        end)
    end)

    describe("OnShieldTaxEvent", function()
        it("skips zero-cost events", function()
            addon:OnShieldTaxEvent(0, 1)
            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
            assert.are.equal(0, charData.lifetime.totalDurabilityEvents)
        end)

        it("skips negative-cost events", function()
            addon:OnShieldTaxEvent(-100, 1)
            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.totalCostCopper)
        end)

        it("records positive-cost events", function()
            addon:OnShieldTaxEvent(5000, 2)
            local charData = addon:GetCharData()
            assert.are.equal(5000, charData.lifetime.totalCostCopper)
            assert.are.equal(2, charData.lifetime.totalDurabilityLost)
            assert.are.equal(1, charData.lifetime.totalDurabilityEvents)
        end)

        it("plays sound on Shield Tax event", function()
            Mock.gameTime = 100
            addon.SoundManager:ResetThrottle()
            addon:OnShieldTaxEvent(5000, 2)
            assert.are.equal(1, #Mock.soundsPlayed)
        end)
    end)

    describe("Disabled for non-Warriors", function()
        it("rejects slash commands when disabled", function()
            Mock.reset()
            Mock.playerClass = { "Paladin", "PALADIN", 2 }
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()

            -- Should not error, just print a message
            addon:HandleSlashCommand("version")
        end)
    end)
end)
