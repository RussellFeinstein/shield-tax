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

describe("Stats", function()
    local addon, stats

    before_each(function()
        Mock.reset()
        Mock.serverTime = 1700000000
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        stats = addon.Stats
    end)

    describe("Session", function()
        it("accumulates Shield Tax", function()
            stats:RecordShieldTax(10000, 3)
            stats:RecordShieldTax(5000, 2)

            local ss = stats:GetSession()
            assert.are.equal(15000, ss.costCopper)
            assert.are.equal(5, ss.durabilityLost)
            assert.are.equal(2, ss.durabilityEvents)
        end)

        it("tracks Death Tax separately", function()
            stats:RecordShieldTax(10000, 3)
            stats:RecordDeathTax(5000)

            local ss = stats:GetSession()
            assert.are.equal(10000, ss.costCopper)
            assert.are.equal(5000, ss.deathTaxCopper)
        end)

        it("resets session", function()
            stats:RecordShieldTax(10000, 3)
            stats:RecordDeathTax(5000)
            stats:ResetSession()

            local ss = stats:GetSession()
            assert.are.equal(0, ss.costCopper)
            assert.are.equal(0, ss.deathTaxCopper)
        end)
    end)

    describe("Dungeon", function()
        it("accumulates separately from session", function()
            stats:RecordShieldTax(10000, 3)

            local dg = stats:GetDungeon()
            local ss = stats:GetSession()
            assert.are.equal(10000, dg.costCopper)
            assert.are.equal(10000, ss.costCopper)
        end)

        it("resets dungeon without affecting session", function()
            stats:RecordShieldTax(10000, 3)
            stats:ResetDungeon()

            local dg = stats:GetDungeon()
            local ss = stats:GetSession()
            assert.are.equal(0, dg.costCopper)
            assert.are.equal(10000, ss.costCopper)
        end)
    end)

    describe("Dungeon History", function()
        it("saves dungeon to history on finalize", function()
            stats:RecordShieldTax(10000, 3)
            Mock.serverTime = 1700000100
            stats:FinalizeDungeon()

            local history = stats:GetHistory(5)
            assert.are.equal(1, #history)
            assert.are.equal(10000, history[1].costCopper)
        end)

        it("does not save empty dungeons", function()
            stats:FinalizeDungeon()
            local history = stats:GetHistory(5)
            assert.are.equal(0, #history)
        end)

        it("increments lifetime dungeon count", function()
            stats:RecordShieldTax(10000, 3)
            stats:FinalizeDungeon()

            local charData = addon:GetCharData()
            assert.are.equal(1, charData.lifetime.dungeonCount)
        end)

        it("evicts oldest when at cap (ring buffer)", function()
            -- Fill 50 entries
            for i = 1, 50 do
                stats:ResetDungeon()
                stats:RecordShieldTax(i * 100, 1)
                Mock.serverTime = 1700000000 + i
                stats:FinalizeDungeon()
            end

            -- 51st entry should overwrite the first
            stats:ResetDungeon()
            stats:RecordShieldTax(99999, 1)
            Mock.serverTime = 1700000051
            stats:FinalizeDungeon()

            local charData = addon:GetCharData()
            -- Entry at index 1 should now be the 51st (overwritten)
            assert.are.equal(99999, charData.dungeonHistory[1].costCopper)
            assert.are.equal(51, charData.lifetime.dungeonCount)
        end)

        it("returns history sorted most recent first", function()
            for i = 1, 3 do
                stats:ResetDungeon()
                stats:RecordShieldTax(i * 1000, 1)
                Mock.serverTime = 1700000000 + i
                stats:FinalizeDungeon()
            end

            local history = stats:GetHistory(3)
            assert.are.equal(3, #history)
            assert.are.equal(3000, history[1].costCopper) -- most recent
            assert.are.equal(1000, history[3].costCopper) -- oldest
        end)

        it("limits returned count", function()
            for i = 1, 10 do
                stats:ResetDungeon()
                stats:RecordShieldTax(i * 100, 1)
                Mock.serverTime = 1700000000 + i
                stats:FinalizeDungeon()
            end

            local history = stats:GetHistory(3)
            assert.are.equal(3, #history)
        end)
    end)

    describe("Dungeon Detection Events", function()
        it("starts a dungeon session on entering an instance", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.instanceInfo = { "The Stonevault", "party", 1, "Mythic", 0, 0, false, 1, 5 }
            Mock.serverTime = 1700001000

            stats:OnEnterWorld()
            local dg = stats:GetDungeon()
            assert.are.equal("The Stonevault", dg.instanceName)
            assert.are.equal(1700001000, dg.startTime)
        end)

        it("finalizes dungeon on leaving instance", function()
            -- Enter dungeon
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.instanceInfo = { "The Stonevault", "party", 1, "Mythic", 0, 0, false, 1, 5 }
            Mock.serverTime = 1700001000
            stats:OnEnterWorld()

            -- Accumulate cost
            stats:RecordShieldTax(5000, 2)

            -- Leave instance
            Mock.inInstance = false
            Mock.instanceType = nil
            Mock.serverTime = 1700002000
            stats:OnEnterWorld()

            -- Should have saved to history
            local history = stats:GetHistory(1)
            assert.are.equal(1, #history)
            assert.are.equal(5000, history[1].costCopper)
            assert.are.equal("The Stonevault", history[1].instanceName)
        end)

        it("resets dungeon counter on M+ start", function()
            -- Some leftover data
            stats:RecordShieldTax(9999, 5)

            -- M+ starts
            Mock.instanceInfo = { "Ara-Kara", "party", 1, "Mythic", 0, 0, false, 1, 5 }
            Mock.serverTime = 1700003000
            Mock.keystoneLevel = 12
            stats:OnKeystoneStart()

            local dg = stats:GetDungeon()
            assert.are.equal(0, dg.costCopper)
            assert.are.equal("Ara-Kara", dg.instanceName)
        end)

        it("does not reset on zone change within same instance (e.g., death)", function()
            Mock.inInstance = true
            Mock.instanceType = "party"
            Mock.instanceInfo = { "The Stonevault", "party", 1, "Mythic", 0, 0, false, 1, 5 }
            Mock.serverTime = 1700001000
            stats:OnEnterWorld()

            stats:RecordShieldTax(5000, 2)

            -- Zone change within same instance (death, graveyard, etc.)
            stats:OnZoneChanged()

            -- Should still have the same dungeon data — NOT reset
            local dg = stats:GetDungeon()
            assert.are.equal(5000, dg.costCopper)
            assert.are.equal(2, dg.durabilityLost)

            -- No dungeon finalized (still in progress)
            local charData = addon:GetCharData()
            assert.are.equal(0, charData.lifetime.dungeonCount)
        end)
    end)
end)
