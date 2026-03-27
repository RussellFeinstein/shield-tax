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
end

describe("SoundManager", function()
    local addon, sm

    before_each(function()
        Mock.reset()
        Mock.gameTime = 100
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        sm = addon.SoundManager
        sm:ResetThrottle()
    end)

    describe("Play", function()
        it("plays sound on first call", function()
            Mock.gameTime = 100
            local played = sm:Play()
            assert.is_true(played)
            assert.are.equal(1, #Mock.soundsPlayed)
        end)

        it("throttles within interval", function()
            Mock.gameTime = 100
            sm:Play()

            -- 0.3s later — within 0.5s throttle
            Mock.gameTime = 100.3
            local played = sm:Play()
            assert.is_false(played)
            assert.are.equal(1, #Mock.soundsPlayed)
        end)

        it("allows sound after throttle expires", function()
            Mock.gameTime = 100
            sm:Play()

            -- 0.6s later — past 0.5s throttle
            Mock.gameTime = 100.6
            local played = sm:Play()
            assert.is_true(played)
            assert.are.equal(2, #Mock.soundsPlayed)
        end)

        it("plays nothing when set to none", function()
            addon.db.profile.soundEffect = "none"
            local played = sm:Play()
            assert.is_false(played)
            assert.are.equal(0, #Mock.soundsPlayed)
            assert.are.equal(0, #Mock.soundFilesPlayed)
        end)

        it("uses PlaySoundFile for custom sounds", function()
            addon.db.profile.soundEffect = "register"
            Mock.gameTime = 100
            sm:Play()
            assert.are.equal(0, #Mock.soundsPlayed)
            assert.are.equal(1, #Mock.soundFilesPlayed)
            assert.truthy(Mock.soundFilesPlayed[1].path:find("register%.ogg"))
        end)

        it("uses PlaySound for kit sounds with correct channel", function()
            addon.db.profile.soundEffect = "coin"
            Mock.gameTime = 100
            sm:Play()
            assert.are.equal(1, #Mock.soundsPlayed)
            assert.are.equal(120, Mock.soundsPlayed[1].id)
            assert.are.equal("SFX", Mock.soundsPlayed[1].channel)
        end)
    end)

    describe("SetEffect", function()
        it("accepts valid keys", function()
            assert.is_true(sm:SetEffect("coin"))
            assert.is_true(sm:SetEffect("register"))
            assert.is_true(sm:SetEffect("coins"))
            assert.is_true(sm:SetEffect("none"))
            assert.is_true(sm:SetEffect("money_open"))
        end)

        it("rejects invalid keys", function()
            assert.is_false(sm:SetEffect("invalid"))
            assert.is_false(sm:SetEffect(""))
        end)

        it("persists to profile", function()
            sm:SetEffect("register")
            assert.are.equal("register", addon.db.profile.soundEffect)
        end)
    end)

    describe("GetEffectKeys", function()
        it("returns all valid keys", function()
            local keys = sm:GetEffectKeys()
            assert.is_true(#keys >= 5)
            -- Check that known keys are present
            local keySet = {}
            for _, k in ipairs(keys) do keySet[k] = true end
            assert.is_true(keySet["coin"])
            assert.is_true(keySet["none"])
            assert.is_true(keySet["register"])
        end)
    end)
end)
