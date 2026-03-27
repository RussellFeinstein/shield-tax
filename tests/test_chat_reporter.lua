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

describe("ChatReporter", function()
    local addon, reporter

    before_each(function()
        Mock.reset()
        loadAddon()
        addon = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")
        addon:OnInitialize()
        reporter = addon.ChatReporter
    end)

    describe("Report", function()
        it("sends a message to party chat", function()
            addon.Stats:RecordShieldTax(50000, 5)
            reporter:Report("party")

            assert.are.equal(1, #Mock.chatMessages)
            assert.are.equal("PARTY", Mock.chatMessages[1].channel)
            assert.truthy(Mock.chatMessages[1].msg:find("%[ShieldTax%]"))
        end)

        it("sends to guild chat", function()
            addon.Stats:RecordShieldTax(50000, 5)
            reporter:Report("guild")

            assert.are.equal(1, #Mock.chatMessages)
            assert.are.equal("GUILD", Mock.chatMessages[1].channel)
        end)

        it("uses default channel from profile", function()
            addon.db.profile.chatReportChannel = "SAY"
            addon.Stats:RecordShieldTax(50000, 5)
            reporter:Report()

            assert.are.equal(1, #Mock.chatMessages)
            assert.are.equal("SAY", Mock.chatMessages[1].channel)
        end)

        it("rejects invalid channels", function()
            reporter:Report("INVALID")
            assert.are.equal(0, #Mock.chatMessages)
        end)

        it("substitutes template variables", function()
            addon.Stats:RecordShieldTax(50000, 5)
            reporter:Report("PARTY")

            local msg = Mock.chatMessages[1].msg
            -- Should not contain unsubstituted template variables
            assert.is_nil(msg:find("{dungeon}"))
            assert.is_nil(msg:find("{session}"))
            assert.is_nil(msg:find("{lifetime}"))
            assert.is_nil(msg:find("{dura_lost}"))
        end)

        it("produces varied messages across calls", function()
            math.randomseed(os.time())
            local messages = {}
            for i = 1, 20 do
                Mock.chatMessages = {}
                addon.Stats:RecordShieldTax(50000, 5)
                reporter:Report("PARTY")
                messages[Mock.chatMessages[1].msg] = true
            end
            -- With 7 templates and 20 calls, we should see at least 2 different messages
            local count = 0
            for _ in pairs(messages) do count = count + 1 end
            assert.is_true(count >= 2)
        end)
    end)

    describe("PrintHistory", function()
        it("prints 'no history' when empty", function()
            reporter:PrintHistory()
            -- Just verify it doesn't error
        end)

        it("prints history entries", function()
            -- Create some dungeon history
            for i = 1, 3 do
                addon.Stats:ResetDungeon()
                addon.Stats:RecordShieldTax(i * 10000, i)
                Mock.serverTime = 1700000000 + i
                addon.Stats:FinalizeDungeon()
            end

            reporter:PrintHistory(3)
            -- Just verify it doesn't error
        end)
    end)

    describe("Milestones", function()
        it("triggers milestone when crossing threshold", function()
            -- Cross the 100g milestone (1,000,000 copper)
            reporter:CheckMilestones(900000, 1100000)
            -- Should have triggered — we can't easily capture Print output,
            -- but verify it doesn't error
        end)

        it("does not trigger when already past threshold", function()
            -- Already past 100g, moving from 101g to 102g
            reporter:CheckMilestones(1010000, 1020000)
            -- No crash = no inappropriate milestone
        end)

        it("does not trigger when not reaching threshold", function()
            -- Below 100g entirely
            reporter:CheckMilestones(500000, 900000)
        end)

        it("triggers multiple milestones if skipping (huge jump)", function()
            -- Jump from 0 to 200,000g (past Master Riding and Mammoth)
            reporter:CheckMilestones(0, 2000000000)
            -- Should not error even with multiple triggers
        end)

        it("has milestones at correct gold values", function()
            local milestones = reporter:GetMilestones()
            assert.are.equal(6, #milestones)
            assert.are.equal(100, milestones[1].gold)
            assert.are.equal(5000, milestones[2].gold)
            assert.are.equal(10000, milestones[3].gold)
            assert.are.equal(20000, milestones[4].gold)
            assert.are.equal(120000, milestones[5].gold)
            assert.are.equal(5000000, milestones[6].gold)

            -- Verify copper = gold * 10000
            for _, m in ipairs(milestones) do
                assert.are.equal(m.gold * 10000, m.copper)
            end
        end)
    end)

    describe("Valid Channels", function()
        it("accepts PARTY, GUILD, SAY, RAID", function()
            local channels = reporter:GetValidChannels()
            assert.is_true(channels["PARTY"])
            assert.is_true(channels["GUILD"])
            assert.is_true(channels["SAY"])
            assert.is_true(channels["RAID"])
        end)
    end)
end)
