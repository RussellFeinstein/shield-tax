local Mock = require("tests.wow_api_mock")

local function loadAddon()
    package.loaded["ShieldTax.Core"] = nil
    package.loaded["ShieldTax.CostCalculator"] = nil
    package.loaded["ShieldTax.Tracker"] = nil
    package.loaded["ShieldTax.SoundManager"] = nil
    package.loaded["ShieldTax.Stats"] = nil
    package.loaded["ShieldTax.Display"] = nil
    package.loaded["ShieldTax.Options"] = nil
    dofile("ShieldTax/Core.lua")
    dofile("ShieldTax/CostCalculator.lua")
    dofile("ShieldTax/Tracker.lua")
    dofile("ShieldTax/SoundManager.lua")
    dofile("ShieldTax/Stats.lua")
    dofile("ShieldTax/Display.lua")
    dofile("ShieldTax/ChatReporter.lua")
    dofile("ShieldTax/MinimapButton.lua")
    dofile("ShieldTax/Options.lua")
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

        it("handles /st with no args (opens settings)", function()
            addon:HandleSlashCommand("")
        end)

        it("handles /st options", function()
            addon:HandleSlashCommand("options")
        end)

        it("handles /st config", function()
            addon:HandleSlashCommand("config")
        end)

        it("handles /st display (toggle)", function()
            addon.Display:Init()
            addon:HandleSlashCommand("display")
        end)

        it("handles /st sound with no args (show current)", function()
            addon:HandleSlashCommand("sound")
        end)

        it("handles /st sound test", function()
            addon:HandleSlashCommand("sound test")
        end)

        it("handles /st sound with valid key", function()
            addon:HandleSlashCommand("sound auction")
            assert.are.equal("auction", addon.db.profile.soundEffect)
        end)

        it("handles /st sound with invalid key", function()
            local original = addon.db.profile.soundEffect
            addon:HandleSlashCommand("sound invalid_key")
            assert.are.equal(original, addon.db.profile.soundEffect)
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

    describe("Protection Spec Guard", function()
        it("activates modules for Protection spec", function()
            addon:OnEnable()
            assert.is_true(addon.modulesActive)
            assert.is_true(addon.modulesInitialized)
        end)

        it("skips module activation for Fury spec", function()
            Mock.reset()
            Mock.specIndex = 2  -- Fury
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon:OnEnable()
            assert.is_falsy(addon.modulesActive)
            assert.is_falsy(addon.modulesInitialized)
        end)

        it("skips module activation for Arms spec", function()
            Mock.reset()
            Mock.specIndex = 1  -- Arms
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon:OnEnable()
            assert.is_falsy(addon.modulesActive)
        end)

        it("activates modules on spec switch to Protection", function()
            Mock.reset()
            Mock.specIndex = 2  -- Start as Fury
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon:OnEnable()
            assert.is_falsy(addon.modulesActive)

            -- Switch to Protection
            Mock.specIndex = 3
            addon:OnSpecChanged()
            assert.is_true(addon.modulesActive)
            assert.is_true(addon.modulesInitialized)
        end)

        it("deactivates modules on spec switch from Protection", function()
            addon:OnEnable()
            assert.is_true(addon.modulesActive)

            -- Switch to Fury
            Mock.specIndex = 2
            addon:OnSpecChanged()
            assert.is_falsy(addon.modulesActive)
        end)

        it("double activation is idempotent", function()
            addon:OnEnable()
            assert.is_true(addon.modulesActive)
            addon:ActivateModules()
            assert.is_true(addon.modulesActive)
        end)

        it("slash commands don't error on non-Prot Warriors", function()
            Mock.reset()
            Mock.specIndex = 2  -- Fury
            loadAddon()
            addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
            addon:OnInitialize()
            addon:OnEnable()

            -- All commands should not error even with no modules initialized
            addon:HandleSlashCommand("")
            addon:HandleSlashCommand("display")
            addon:HandleSlashCommand("sound")
            addon:HandleSlashCommand("lifetime")
            addon:HandleSlashCommand("report")
            addon:HandleSlashCommand("stats")
            addon:HandleSlashCommand("minimap")
        end)

        it("IsProtectionSpec returns false when spec is nil", function()
            Mock.specIndex = nil
            assert.is_false(addon:IsProtectionSpec())
        end)

        it("re-activation after deactivation shows UI without re-init", function()
            addon:OnEnable()
            assert.is_true(addon.modulesInitialized)

            -- Deactivate
            Mock.specIndex = 2
            addon:OnSpecChanged()
            assert.is_falsy(addon.modulesActive)

            -- Re-activate — should not re-init, just show UI
            Mock.specIndex = 3
            addon:OnSpecChanged()
            assert.is_true(addon.modulesActive)
            assert.is_true(addon.modulesInitialized)
        end)
    end)
end)
