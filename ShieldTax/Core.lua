---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):NewAddon("ShieldTax", "AceEvent-3.0", "AceConsole-3.0")
_G.ShieldTax = ShieldTax

ShieldTax.VERSION = "0.1.0"

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

    -- Initialize tracker
    if self.Tracker then
        self.Tracker:Init()
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

    local cmd = self:GetArgs(input, 1)
    cmd = cmd and cmd:lower() or ""

    if cmd == "version" then
        self:Print("ShieldTax v" .. self.VERSION)
    elseif cmd == "help" or cmd == "?" then
        self:PrintHelp()
    else
        -- Default: show version for now (display toggle in M2)
        self:Print("ShieldTax v" .. self.VERSION .. " — Type /st help for commands.")
    end
end

function ShieldTax:PrintHelp()
    self:Print("ShieldTax v" .. self.VERSION .. " — Commands:")
    self:Print("  /st — Toggle display frame")
    self:Print("  /st version — Show addon version")
    self:Print("  /st help — Show this help")
end

--- Callback fired by Tracker when shield durability is lost during combat.
---@param costCopper number Gold cost of the durability loss in copper
---@param durabilityLost number Number of durability points lost
function ShieldTax:OnShieldTaxEvent(costCopper, durabilityLost)
    local charData = self:GetCharData()
    if not charData then return end

    local lifetime = charData.lifetime
    lifetime.totalCostCopper = lifetime.totalCostCopper + costCopper
    lifetime.totalDurabilityLost = lifetime.totalDurabilityLost + durabilityLost
    lifetime.totalDurabilityEvents = lifetime.totalDurabilityEvents + 1

    if not lifetime.firstSeen then
        lifetime.firstSeen = GetServerTime()
    end
end

--- Callback fired by Tracker when durability is lost due to death.
---@param costCopper number Gold cost of the death durability loss in copper
function ShieldTax:OnDeathTaxEvent(costCopper)
    local charData = self:GetCharData()
    if not charData then return end

    charData.lifetime.deathTaxCopper = charData.lifetime.deathTaxCopper + costCopper
end
