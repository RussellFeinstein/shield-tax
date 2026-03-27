---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local ChatReporter = {}
ShieldTax.ChatReporter = ChatReporter

-- Gold cost milestones tied to real vendor prices
local MILESTONES = {
    { gold = 100,     copper = 1000000,     msg = "100 gold in Shield Tax. Other tanks pay exactly 0g for their active mitigation. Just saying." },
    { gold = 5000,    copper = 50000000,    msg = "5,000 gold! You could have learned Master Riding instead of pressing Shield Block." },
    { gold = 10000,   copper = 100000000,   msg = "10,000 gold in Shield Tax. That's a Wooly Mammoth. A whole mammoth, lost to blocking." },
    { gold = 20000,   copper = 200000000,   msg = "20,000 gold. You've blocked away an entire Traveler's Tundra Mammoth. With vendors on it." },
    { gold = 120000,  copper = 1200000000,  msg = "120,000 gold. A Grand Expedition Yak. Gone. Absorbed by your shield. The transmog vendor weeps." },
    { gold = 5000000, copper = 50000000000, msg = "5 million gold. You've Shield Blocked away a Mighty Caravan Brutosaur. You are the final boss of repair bills." },
}

-- Humorous report templates. {dungeon}, {session}, {lifetime}, {dura_lost}, {events} are substituted.
local REPORT_TEMPLATES = {
    "[ShieldTax] My shield repair bill this dungeon: {dungeon}. Thanks, Shield Block.",
    "[ShieldTax] Shield Block has cost me {dungeon} this dungeon. Other tanks pay 0g for their active mitigation.",
    "[ShieldTax] Dungeon Shield Tax: {dungeon} ({dura_lost} durability hits). Blizzard pls.",
    "[ShieldTax] Session Shield Tax so far: {session}. Every block has a price.",
    "[ShieldTax] Lifetime Shield Tax: {lifetime}. I could have bought a mount with that.",
    "[ShieldTax] {dungeon} this dungeon. {session} this session. Shield Block isn't free, folks.",
    "[ShieldTax] Other tanks press their mitigation for free. I just paid {dungeon} to press mine.",
}

local VALID_CHANNELS = {
    PARTY = true,
    GUILD = true,
    SAY = true,
    RAID = true,
    INSTANCE_CHAT = true,
}

--- Send a humorous report to a chat channel.
---@param channel string|nil Chat channel (default from profile)
function ChatReporter:Report(channel)
    local db = ShieldTax.db and ShieldTax.db.profile
    channel = channel and channel:upper() or (db and db.chatReportChannel or "PARTY")

    if not VALID_CHANNELS[channel] then
        ShieldTax:Print("Invalid channel: " .. channel .. ". Use: party, guild, say, raid")
        return
    end

    local stats = ShieldTax.Stats
    local calc = ShieldTax.CostCalculator
    if not stats or not calc then return end

    local dg = stats:GetDungeon()
    local ss = stats:GetSession()
    local charData = ShieldTax:GetCharData()
    local lt = charData and charData.lifetime

    -- Pick a random template
    local template = REPORT_TEMPLATES[math.random(#REPORT_TEMPLATES)]

    -- Substitute variables
    local msg = template
    msg = msg:gsub("{dungeon}", calc:FormatGold(dg.costCopper))
    msg = msg:gsub("{session}", calc:FormatGold(ss.costCopper))
    msg = msg:gsub("{lifetime}", lt and calc:FormatGold(lt.totalCostCopper) or "0g")
    msg = msg:gsub("{dura_lost}", tostring(dg.durabilityLost))
    msg = msg:gsub("{events}", tostring(dg.durabilityEvents))

    SendChatMessage(msg, channel)
end

--- Print dungeon history to local chat.
---@param count number|nil Number of entries (default 5)
function ChatReporter:PrintHistory(count)
    local stats = ShieldTax.Stats
    local calc = ShieldTax.CostCalculator
    if not stats or not calc then return end

    local history = stats:GetHistory(count or 5)
    if #history == 0 then
        ShieldTax:Print("No dungeon history yet.")
        return
    end

    ShieldTax:Print("--- Dungeon History ---")
    for i, entry in ipairs(history) do
        local name = entry.instanceName or "Unknown"
        local level = entry.keystoneLevel and (" +" .. entry.keystoneLevel) or ""
        local cost = calc:FormatGold(entry.costCopper)
        local death = entry.deathTaxCopper and entry.deathTaxCopper > 0
            and (" (Death: " .. calc:FormatGold(entry.deathTaxCopper) .. ")")
            or ""
        ShieldTax:Print(string.format("  %d. %s%s — %s%s", i, name, level, cost, death))
    end
end

--- Check if a lifetime cost milestone was just crossed and announce it.
---@param oldTotal number Previous lifetime cost in copper
---@param newTotal number New lifetime cost in copper
function ChatReporter:CheckMilestones(oldTotal, newTotal)
    for _, milestone in ipairs(MILESTONES) do
        if oldTotal < milestone.copper and newTotal >= milestone.copper then
            ShieldTax:Print("|cffFFD700" .. milestone.msg .. "|r")
        end
    end
end

--- Get the milestones table (for testing).
function ChatReporter:GetMilestones()
    return MILESTONES
end

--- Get the report templates (for testing).
function ChatReporter:GetTemplates()
    return REPORT_TEMPLATES
end

--- Get the valid channels table (for testing).
function ChatReporter:GetValidChannels()
    return VALID_CHANNELS
end
