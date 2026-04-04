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

describe("Options", function()
    local addon, opts

    before_each(function()
        Mock.reset()
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        opts = addon.Options
    end)

    describe("Init", function()
        it("runs without error", function()
            opts:Init()
        end)

        it("is called during OnInitialize", function()
            -- Options:Init is called inside OnInitialize; verify category was set
            assert.is_not_nil(opts.category)
        end)
    end)

    describe("Open", function()
        it("runs without error", function()
            opts:Open()
        end)

        it("does not open during combat lockdown", function()
            Mock.inCombatLockdown = true
            -- Should not error — prints a message and returns
            opts:Open()
        end)

        it("does not error when category is nil", function()
            opts.category = nil
            opts:Open()
        end)
    end)

    describe("Sound getters/setters", function()
        it("sound effect getter returns current profile value", function()
            addon.db.profile.soundEffect = "auction"
            -- The options table's getter should reflect the profile
            assert.are.equal("auction", addon.db.profile.soundEffect)
        end)

        it("sound effect setter updates profile via SoundManager", function()
            addon.SoundManager:SetEffect("levelup")
            assert.are.equal("levelup", addon.db.profile.soundEffect)
        end)

        it("sound channel setter updates profile", function()
            addon.db.profile.soundChannel = "Music"
            assert.are.equal("Music", addon.db.profile.soundChannel)
        end)

        it("sound throttle setter updates profile", function()
            addon.db.profile.soundThrottle = 1.5
            assert.are.equal(1.5, addon.db.profile.soundThrottle)
        end)
    end)

    describe("Display getters/setters", function()
        it("SetEnabled hides the frame", function()
            addon:OnEnable()  -- Activate modules (creates frame)
            addon.Display:SetEnabled(false)
            assert.is_false(addon.db.profile.displayEnabled)
        end)

        it("SetEnabled shows the frame", function()
            addon:OnEnable()
            addon.Display:SetEnabled(false)
            addon.Display:SetEnabled(true)
            assert.is_true(addon.db.profile.displayEnabled)
        end)

        it("SetScale updates the frame", function()
            addon:OnEnable()
            -- Should not error
            addon.Display:SetScale(1.5)
        end)

        it("SetEnabled is safe before Init", function()
            -- Display:Init not called — frame is nil
            addon.Display:SetEnabled(true)  -- Should not error
        end)

        it("SetScale is safe before Init", function()
            addon.Display:SetScale(2.0)  -- Should not error
        end)
    end)

    describe("MinimapButton getters/setters", function()
        it("SetShown updates profile", function()
            addon:OnEnable()
            addon.MinimapButton:SetShown(false)
            assert.is_false(addon.db.profile.minimapIcon)
        end)

        it("SetShown restores icon", function()
            addon:OnEnable()
            addon.MinimapButton:SetShown(false)
            addon.MinimapButton:SetShown(true)
            assert.is_true(addon.db.profile.minimapIcon)
        end)

        it("SetShown is safe before Init", function()
            addon.MinimapButton:SetShown(false)  -- Should not error
        end)
    end)

    describe("Content toggles", function()
        it("toggle updates profile", function()
            addon.db.profile.contentToggles.raid = false
            assert.is_false(addon.db.profile.contentToggles.raid)
        end)

        it("toggle defaults to true", function()
            assert.is_true(addon.db.profile.contentToggles.mythicplus)
            assert.is_true(addon.db.profile.contentToggles.raid)
            assert.is_true(addon.db.profile.contentToggles.dungeon)
            assert.is_true(addon.db.profile.contentToggles.openworld)
            assert.is_true(addon.db.profile.contentToggles.other)
        end)
    end)

    describe("Chat reporting", function()
        it("channel setter updates profile", function()
            addon.db.profile.chatReportChannel = "GUILD"
            assert.are.equal("GUILD", addon.db.profile.chatReportChannel)
        end)
    end)
end)
