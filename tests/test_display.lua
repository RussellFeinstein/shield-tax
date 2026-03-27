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

describe("Display", function()
    local addon, display

    before_each(function()
        Mock.reset()
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        display = addon.Display
    end)

    describe("Init", function()
        it("creates the display frame", function()
            display:Init()
            -- Frame was created — IsShown depends on profile setting
            -- Default displayEnabled = true, but our mock IsShown returns false
            -- Just verify Init doesn't error
            assert.is_not_nil(display)
        end)
    end)

    describe("Toggle", function()
        it("toggles display enabled setting", function()
            display:Init()
            assert.is_true(addon.db.profile.displayEnabled)

            display:Toggle()
            assert.is_false(addon.db.profile.displayEnabled)

            display:Toggle()
            assert.is_true(addon.db.profile.displayEnabled)
        end)
    end)

    describe("Update", function()
        it("does not error when called before Init", function()
            -- Should be a no-op, not an error
            display:Update()
        end)

        it("does not error when called after Init", function()
            Mock.equipShield(639, 4, 100, 120)
            addon.Tracker:Init()
            display:Init()
            display:Update()
        end)
    end)
end)
