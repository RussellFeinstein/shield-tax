---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):NewAddon("ShieldTax", "AceEvent-3.0", "AceConsole-3.0")
_G.ShieldTax = ShieldTax

ShieldTax.VERSION = "0.3.0"

local DB_DEFAULTS = {
    global = {
        characters = {},
        schemaVersion = 1,
    },
    profile = {
        soundEffect = "coin",
        soundThrottle = 0.5,
        soundChannel = "SFX",
        displayEnabled = true,
        displayScale = 1.0,
        displayPosition = nil,
        minimapIcon = true,
        chatReportChannel = "PARTY",
    },
}

function ShieldTax:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ShieldTaxDB", DB_DEFAULTS)

    -- Class guard: only activate for Warriors (locale-independent check)
    local _, classToken = UnitClass("player")
    if classToken ~= "WARRIOR" then
        self.disabled = true
        return
    end

    self.disabled = false

    -- Initialize character key
    local name = UnitName("player")
    local realm = GetRealmName()
    self.charKey = name .. "-" .. realm

    -- Ensure character entry exists
    if not self.db.global.characters[self.charKey] then
        self.db.global.characters[self.charKey] = {
            class = classToken,
            lifetime = {
                totalCostCopper = 0,
                totalDurabilityLost = 0,
                totalDurabilityEvents = 0,
                deathTaxCopper = 0,
                dungeonCount = 0,
                firstSeen = nil,
            },
            dungeonHistory = {},
            dungeonHistoryIndex = 1,
        }
    end

    self:RegisterChatCommand("shieldtax", "HandleSlashCommand")
    self:RegisterChatCommand("st", "HandleSlashCommand")
end

function ShieldTax:OnEnable()
    if self.disabled then return end

    -- Initialize modules
    if self.Tracker then
        self.Tracker:Init()
    end
    if self.Stats then
        self.Stats:Init()
    end
    if self.Display then
        self.Display:Init()
    end
    if self.MinimapButton then
        self.MinimapButton:Init()
    end
end

function ShieldTax:OnDisable()
    -- Clean up if needed
end

function ShieldTax:GetCharData()
    if not self.charKey then return nil end
    return self.db.global.characters[self.charKey]
end

function ShieldTax:HandleSlashCommand(input)
    if self.disabled then
        self:Print("ShieldTax is only active on Warrior characters.")
        return
    end

    local cmd, arg1 = self:GetArgs(input, 2)
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        if self.Display then self.Display:Toggle() end
    elseif cmd == "version" then
        self:Print("ShieldTax v" .. self.VERSION)
    elseif cmd == "help" or cmd == "?" then
        self:PrintHelp()
    elseif cmd == "sound" then
        self:HandleSoundCommand(arg1)
    elseif cmd == "display" then
        if self.Display then self.Display:Toggle() end
    elseif cmd == "move" then
        if self.Display then self.Display:Unlock() end
    elseif cmd == "lock" then
        if self.Display then self.Display:Lock() end
    elseif cmd == "reset" then
        self:HandleResetCommand(arg1)
    elseif cmd == "session" then
        self:PrintSessionStats()
    elseif cmd == "lifetime" then
        self:PrintLifetimeStats()
    elseif cmd == "report" then
        if self.ChatReporter then self.ChatReporter:Report(arg1) end
    elseif cmd == "history" then
        if self.ChatReporter then self.ChatReporter:PrintHistory() end
    elseif cmd == "minimap" then
        if self.MinimapButton then self.MinimapButton:Toggle() end
    else
        self:Print("Unknown command: " .. cmd .. ". Type /st help for commands.")
    end
end

function ShieldTax:HandleSoundCommand(arg)
    if not self.SoundManager then return end

    if not arg or arg == "" then
        self:Print("Current sound: " .. self.SoundManager:GetEffect())
        self:Print("Options: " .. table.concat(self.SoundManager:GetEffectKeys(), ", "))
        return
    end

    arg = arg:lower()
    if arg == "test" then
        self.SoundManager:PlayTest()
    elseif self.SoundManager:SetEffect(arg) then
        self:Print("Sound set to: " .. arg)
    else
        self:Print("Unknown sound: " .. arg)
        self:Print("Options: " .. table.concat(self.SoundManager:GetEffectKeys(), ", "))
    end
end

function ShieldTax:HandleResetCommand(arg)
    if not arg or arg == "" then
        if self.Stats then
            self.Stats:ResetDungeon()
            self:Print("Dungeon counter reset.")
        end
        if self.Display then self.Display:Update() end
    elseif arg:lower() == "session" then
        if self.Stats then
            self.Stats:ResetSession()
            self:Print("Session counter reset.")
        end
        if self.Display then self.Display:Update() end
    elseif arg:lower() == "all" then
        local charData = self:GetCharData()
        if charData then
            charData.lifetime.totalCostCopper = 0
            charData.lifetime.totalDurabilityLost = 0
            charData.lifetime.totalDurabilityEvents = 0
            charData.lifetime.deathTaxCopper = 0
            charData.lifetime.dungeonCount = 0
            charData.lifetime.firstSeen = nil
            charData.dungeonHistory = {}
            charData.dungeonHistoryIndex = 1
        end
        if self.Stats then
            self.Stats:ResetSession()
            self.Stats:ResetDungeon()
        end
        if self.Display then self.Display:Update() end
        self:Print("All data reset.")
    end
end

function ShieldTax:PrintSessionStats()
    if not self.Stats then return end
    local calc = self.CostCalculator
    local ss = self.Stats:GetSession()

    self:Print("--- Session Stats ---")
    self:Print("  Shield Tax: " .. calc:FormatGold(ss.costCopper))
    self:Print("  Death Tax: " .. calc:FormatGold(ss.deathTaxCopper))
    self:Print("  Durability lost: " .. ss.durabilityLost .. " (" .. ss.durabilityEvents .. " events)")
end

function ShieldTax:PrintLifetimeStats()
    local charData = self:GetCharData()
    if not charData then return end
    local calc = self.CostCalculator
    local lt = charData.lifetime

    self:Print("--- Lifetime Stats ---")
    self:Print("  Shield Tax: " .. calc:FormatGold(lt.totalCostCopper))
    self:Print("  Death Tax: " .. calc:FormatGold(lt.deathTaxCopper))
    self:Print("  Durability lost: " .. lt.totalDurabilityLost .. " (" .. lt.totalDurabilityEvents .. " events)")
    self:Print("  Dungeons: " .. lt.dungeonCount)
end

function ShieldTax:PrintHelp()
    self:Print("ShieldTax v" .. self.VERSION .. " Commands:")
    self:Print("  /st — Toggle display frame")
    self:Print("  /st sound [coin|money_open|register|coins|none] — Set sound")
    self:Print("  /st sound test — Play current sound")
    self:Print("  /st session — Session stats")
    self:Print("  /st lifetime — Lifetime stats")
    self:Print("  /st reset — Reset dungeon counter")
    self:Print("  /st reset session — Reset session")
    self:Print("  /st reset all — Reset everything")
    self:Print("  /st report [party|guild|say] — Report to chat")
    self:Print("  /st history — Last 5 dungeons")
    self:Print("  /st move / lock — Unlock/lock display")
    self:Print("  /st minimap — Toggle minimap icon")
    self:Print("  /st version — Show version")
end

--- Callback fired by Tracker when shield durability is lost during combat.
---@param costCopper number Gold cost of the durability loss in copper
---@param durabilityLost number Number of durability points lost
function ShieldTax:OnShieldTaxEvent(costCopper, durabilityLost)
    if not costCopper or costCopper <= 0 then return end

    local charData = self:GetCharData()
    if not charData then return end

    -- Update lifetime stats
    local lifetime = charData.lifetime
    local oldTotal = lifetime.totalCostCopper
    lifetime.totalCostCopper = lifetime.totalCostCopper + costCopper
    lifetime.totalDurabilityLost = lifetime.totalDurabilityLost + durabilityLost
    lifetime.totalDurabilityEvents = lifetime.totalDurabilityEvents + 1

    if not lifetime.firstSeen then
        lifetime.firstSeen = GetServerTime()
    end

    -- Update session/dungeon stats
    if self.Stats then
        self.Stats:RecordShieldTax(costCopper, durabilityLost)
    end

    -- Play sound
    if self.SoundManager then
        self.SoundManager:Play()
    end

    -- Update display
    if self.Display then
        self.Display:Update()
    end

    -- Update minimap button text
    if self.MinimapButton then
        self.MinimapButton:Update()
    end

    -- Check milestones
    if self.ChatReporter then
        self.ChatReporter:CheckMilestones(oldTotal, lifetime.totalCostCopper)
    end
end

--- Callback fired by Tracker when durability is lost due to death.
---@param costCopper number Gold cost of the death durability loss in copper
function ShieldTax:OnDeathTaxEvent(costCopper)
    local charData = self:GetCharData()
    if not charData then return end

    charData.lifetime.deathTaxCopper = charData.lifetime.deathTaxCopper + costCopper

    -- Update session/dungeon stats
    if self.Stats then
        self.Stats:RecordDeathTax(costCopper)
    end

    -- Update display
    if self.Display then
        self.Display:Update()
    end
end
