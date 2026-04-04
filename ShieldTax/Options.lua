---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local Options = {}
ShieldTax.Options = Options

-- Stable iteration order for content toggles
local CONTENT_ORDER = { "mythicplus", "raid", "dungeon", "openworld", "other" }

local function getProfile()
    return ShieldTax.db and ShieldTax.db.profile
end

--- Build the AceConfig options table.
local function buildOptions()
    local options = {
        type = "group",
        name = "ShieldTax",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                inline = true,
                args = {
                    displayEnabled = {
                        type = "toggle",
                        name = "Show Display Frame",
                        desc = "Show or hide the Shield Tax display frame.",
                        order = 1,
                        width = "full",
                        get = function() local db = getProfile(); return db and db.displayEnabled end,
                        set = function(_, val)
                            if ShieldTax.Display then ShieldTax.Display:SetEnabled(val) end
                        end,
                    },
                    displayScale = {
                        type = "range",
                        name = "Display Scale",
                        desc = "Scale of the Shield Tax display frame.",
                        order = 2,
                        min = 0.5,
                        max = 2.0,
                        step = 0.05,
                        isPercent = false,
                        get = function() local db = getProfile(); return db and db.displayScale or 1.0 end,
                        set = function(_, val)
                            local db = getProfile()
                            if db then db.displayScale = val end
                            if ShieldTax.Display then ShieldTax.Display:SetScale(val) end
                        end,
                    },
                    minimapIcon = {
                        type = "toggle",
                        name = "Show Minimap Icon",
                        desc = "Show or hide the minimap button.",
                        order = 3,
                        width = "full",
                        get = function() local db = getProfile(); return db and db.minimapIcon end,
                        set = function(_, val)
                            if ShieldTax.MinimapButton then ShieldTax.MinimapButton:SetShown(val) end
                        end,
                    },
                    resetPosition = {
                        type = "execute",
                        name = "Reset Display Position",
                        desc = "Move the display frame back to the center of the screen.",
                        order = 4,
                        func = function()
                            local db = getProfile()
                            if db then db.displayPosition = nil end
                            if ShieldTax.Display then ShieldTax.Display:RestorePosition() end
                        end,
                    },
                },
            },
            sound = {
                type = "group",
                name = "Sound",
                order = 2,
                inline = true,
                args = {
                    soundEffect = {
                        type = "select",
                        name = "Sound Effect",
                        desc = "Sound to play when your shield takes durability damage.",
                        order = 1,
                        values = function()
                            local vals = {}
                            if ShieldTax.SoundManager then
                                for _, key in ipairs(ShieldTax.SoundManager:GetEffectKeys()) do
                                    vals[key] = ShieldTax.SoundManager:GetEffectLabel(key)
                                end
                            end
                            return vals
                        end,
                        get = function() local db = getProfile(); return db and db.soundEffect or "coin" end,
                        set = function(_, val)
                            if ShieldTax.SoundManager then ShieldTax.SoundManager:SetEffect(val) end
                        end,
                    },
                    soundChannel = {
                        type = "select",
                        name = "Audio Channel",
                        desc = "WoW audio channel used for playback.",
                        order = 2,
                        values = {
                            Master = "Master",
                            SFX = "Sound Effects",
                            Music = "Music",
                            Ambience = "Ambience",
                            Dialog = "Dialog",
                        },
                        get = function() local db = getProfile(); return db and db.soundChannel or "SFX" end,
                        set = function(_, val)
                            local db = getProfile()
                            if db then db.soundChannel = val end
                        end,
                    },
                    soundThrottle = {
                        type = "range",
                        name = "Sound Throttle",
                        desc = "Minimum time between sound plays (seconds).",
                        order = 3,
                        min = 0,
                        max = 2.0,
                        step = 0.1,
                        get = function() local db = getProfile(); return db and db.soundThrottle or 0.5 end,
                        set = function(_, val)
                            local db = getProfile()
                            if db then db.soundThrottle = val end
                        end,
                    },
                    testSound = {
                        type = "execute",
                        name = "Test Sound",
                        desc = "Play the current sound effect.",
                        order = 4,
                        func = function()
                            if ShieldTax.SoundManager then ShieldTax.SoundManager:PlayTest() end
                        end,
                    },
                },
            },
            contentTracking = {
                type = "group",
                name = "Content Tracking",
                order = 3,
                inline = true,
                args = {
                    desc = {
                        type = "description",
                        name = "Choose which content types appear on the display frame. Data is always recorded regardless of these toggles.",
                        order = 0,
                    },
                },
            },
            chatReporting = {
                type = "group",
                name = "Chat / Reporting",
                order = 4,
                inline = true,
                args = {
                    chatReportChannel = {
                        type = "select",
                        name = "Report Channel",
                        desc = "Default chat channel for Shield Tax reports.",
                        order = 1,
                        values = {
                            PARTY = "Party",
                            GUILD = "Guild",
                            SAY = "Say",
                            RAID = "Raid",
                            INSTANCE_CHAT = "Instance",
                        },
                        get = function() local db = getProfile(); return db and db.chatReportChannel or "PARTY" end,
                        set = function(_, val)
                            local db = getProfile()
                            if db then db.chatReportChannel = val end
                        end,
                    },
                    sendReport = {
                        type = "execute",
                        name = "Send Report",
                        desc = "Send a Shield Tax report to your selected chat channel.",
                        order = 2,
                        func = function()
                            if ShieldTax.ChatReporter then ShieldTax.ChatReporter:Report() end
                        end,
                    },
                },
            },
        },
    }

    -- Build content toggles from Tracker labels in stable order
    local labels = ShieldTax.Tracker and ShieldTax.Tracker.CONTENT_LABELS or {}
    for i, key in ipairs(CONTENT_ORDER) do
        local label = labels[key] or key
        options.args.contentTracking.args[key] = {
            type = "toggle",
            name = label,
            order = i,
            get = function()
                local db = getProfile()
                return db and db.contentToggles and db.contentToggles[key] ~= false
            end,
            set = function(_, val)
                local db = getProfile()
                if db and db.contentToggles then
                    db.contentToggles[key] = val
                end
                if ShieldTax.Display then ShieldTax.Display:Update() end
            end,
        }
    end

    return options
end

--- Register the options table and add to Blizzard Interface Options.
function Options:Init()
    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not AceConfig or not AceConfigDialog then return end

    AceConfig:RegisterOptionsTable("ShieldTax", buildOptions())
    self.category = AceConfigDialog:AddToBlizOptions("ShieldTax", "ShieldTax")
end

--- Open the Blizzard Interface Options to the ShieldTax panel.
function Options:Open()
    if InCombatLockdown() then
        ShieldTax:Print("Cannot open settings during combat.")
        return
    end
    if self.category then
        Settings.OpenToCategory(self.category)
    end
end
