---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local Stats = {}
ShieldTax.Stats = Stats

-- Per-content-type stat template
local function newContentStats()
    return { costCopper = 0, durabilityLost = 0, events = 0 }
end

local EMPTY_SESSION = {
    costCopper = 0,
    durabilityLost = 0,
    durabilityEvents = 0,
    deathTaxCopper = 0,
    byContent = {},
}

--- Get (or create) the persisted session data from SavedVariables.
--- Persists through /reload, resets on fresh login.
local function getSession()
    local charData = ShieldTax:GetCharData()
    if not charData then return EMPTY_SESSION end
    if not charData.currentSession then
        charData.currentSession = {
            costCopper = 0,
            durabilityLost = 0,
            durabilityEvents = 0,
            deathTaxCopper = 0,
            byContent = {},
        }
    end
    return charData.currentSession
end

local EMPTY_DUNGEON = {
    costCopper = 0,
    durabilityLost = 0,
    durabilityEvents = 0,
    deathTaxCopper = 0,
    contentType = nil,
    instanceName = nil,
    keystoneLevel = nil,
    startTime = nil,
}

--- Get (or create) the persisted dungeon data from SavedVariables.
--- Persists through /reload, resets on instance change.
local function getDungeon()
    local charData = ShieldTax:GetCharData()
    if not charData then return EMPTY_DUNGEON end
    if not charData.currentDungeon then
        charData.currentDungeon = {
            costCopper = 0,
            durabilityLost = 0,
            durabilityEvents = 0,
            deathTaxCopper = 0,
            contentType = nil,
            instanceName = nil,
            keystoneLevel = nil,
            startTime = nil,
        }
    end
    return charData.currentDungeon
end

local DUNGEON_HISTORY_CAP = 50

function Stats:Init()
    -- Restore currentInstanceName from persisted dungeon data (survives /reload)
    local dungeon = getDungeon()
    if dungeon.instanceName then
        currentInstanceName = dungeon.instanceName
    end

    -- Register dungeon detection events
    -- PLAYER_ENTERING_WORLD passes (isInitialLogin, isReloadingUi)
    ShieldTax:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
        if isInitialLogin then
            -- Fresh login — reset session and dungeon data
            Stats:ResetSession()
            Stats:ResetDungeon()
            currentInstanceName = nil
        end
        Stats:OnEnterWorld()
    end)
    ShieldTax:RegisterEvent("ZONE_CHANGED_NEW_AREA", function() Stats:OnZoneChanged() end)
    ShieldTax:RegisterEvent("CHALLENGE_MODE_START", function() Stats:OnKeystoneStart() end)
    ShieldTax:RegisterEvent("CHALLENGE_MODE_COMPLETED", function() Stats:OnKeystoneCompleted() end)
end

--- Record a Shield Tax event (called from Core.lua).
---@param costCopper number
---@param durabilityLost number
---@param contentType string|nil Content type
function Stats:RecordShieldTax(costCopper, durabilityLost, contentType)
    contentType = contentType or "other"
    local session = getSession()
    local dungeon = getDungeon()

    session.costCopper = session.costCopper + costCopper
    session.durabilityLost = session.durabilityLost + durabilityLost
    session.durabilityEvents = session.durabilityEvents + 1

    -- Per-content session stats
    if not session.byContent[contentType] then
        session.byContent[contentType] = newContentStats()
    end
    local sc = session.byContent[contentType]
    sc.costCopper = sc.costCopper + costCopper
    sc.durabilityLost = sc.durabilityLost + durabilityLost
    sc.events = sc.events + 1

    dungeon.costCopper = dungeon.costCopper + costCopper
    dungeon.durabilityLost = dungeon.durabilityLost + durabilityLost
    dungeon.durabilityEvents = dungeon.durabilityEvents + 1
    dungeon.contentType = contentType
end

--- Record a Death Tax event (called from Core.lua).
---@param costCopper number
---@param contentType string|nil Content type
function Stats:RecordDeathTax(costCopper, contentType)
    local session = getSession()
    local dungeon = getDungeon()
    session.deathTaxCopper = session.deathTaxCopper + costCopper
    dungeon.deathTaxCopper = dungeon.deathTaxCopper + costCopper
end

--- Get current session stats.
---@return table session Copy of session data
function Stats:GetSession()
    local session = getSession()
    return {
        costCopper = session.costCopper,
        durabilityLost = session.durabilityLost,
        durabilityEvents = session.durabilityEvents,
        deathTaxCopper = session.deathTaxCopper,
        byContent = session.byContent,
    }
end

--- Get current dungeon stats.
---@return table dungeon Copy of dungeon data
function Stats:GetDungeon()
    local dungeon = getDungeon()
    return {
        costCopper = dungeon.costCopper,
        durabilityLost = dungeon.durabilityLost,
        durabilityEvents = dungeon.durabilityEvents,
        deathTaxCopper = dungeon.deathTaxCopper,
        contentType = dungeon.contentType,
        instanceName = dungeon.instanceName,
        keystoneLevel = dungeon.keystoneLevel,
        startTime = dungeon.startTime,
    }
end

--- Reset current dungeon counter.
function Stats:ResetDungeon()
    local charData = ShieldTax:GetCharData()
    if charData then
        charData.currentDungeon = {
            costCopper = 0,
            durabilityLost = 0,
            durabilityEvents = 0,
            deathTaxCopper = 0,
            contentType = nil,
            instanceName = nil,
            keystoneLevel = nil,
            startTime = nil,
        }
    end
end

--- Reset session counter.
function Stats:ResetSession()
    local charData = ShieldTax:GetCharData()
    if charData then
        charData.currentSession = {
            costCopper = 0,
            durabilityLost = 0,
            durabilityEvents = 0,
            deathTaxCopper = 0,
            byContent = {},
        }
    end
end

--- Save current dungeon to history ring buffer.
function Stats:FinalizeDungeon()
    local dungeon = getDungeon()
    if dungeon.costCopper <= 0 and dungeon.deathTaxCopper <= 0 then
        return -- Nothing to save
    end

    local charData = ShieldTax:GetCharData()
    if not charData then return end

    local entry = {
        instanceName = dungeon.instanceName or "Unknown",
        keystoneLevel = dungeon.keystoneLevel,
        contentType = dungeon.contentType,
        costCopper = dungeon.costCopper,
        durabilityLost = dungeon.durabilityLost,
        deathTaxCopper = dungeon.deathTaxCopper,
        duration = dungeon.startTime and (GetServerTime() - dungeon.startTime) or 0,
        timestamp = GetServerTime(),
    }

    -- Circular buffer insertion
    local idx = charData.dungeonHistoryIndex or 1
    charData.dungeonHistory[idx] = entry
    charData.dungeonHistoryIndex = (idx % DUNGEON_HISTORY_CAP) + 1

    -- Increment lifetime dungeon count
    charData.lifetime.dungeonCount = charData.lifetime.dungeonCount + 1
end

--- Get dungeon history entries, most recent first.
---@param count number|nil Max entries to return (default 5)
---@return table entries
function Stats:GetHistory(count)
    count = count or 5
    local charData = ShieldTax:GetCharData()
    if not charData or not charData.dungeonHistory then return {} end

    -- Collect all non-nil entries
    local all = {}
    for i = 1, DUNGEON_HISTORY_CAP do
        if charData.dungeonHistory[i] then
            table.insert(all, charData.dungeonHistory[i])
        end
    end

    -- Sort by timestamp descending (most recent first)
    table.sort(all, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)

    -- Return requested count
    local result = {}
    for i = 1, math.min(count, #all) do
        result[i] = all[i]
    end
    return result
end

-- Track current instance to avoid resetting on zone changes within the same instance
-- (e.g., dying and going to graveyard, or moving between dungeon wings)
local currentInstanceName = nil

function Stats:OnEnterWorld()
    local inInstance, instanceType = IsInInstance()
    local dungeon = getDungeon()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        local name = select(1, GetInstanceInfo())

        -- Only reset if entering a DIFFERENT instance (not same dungeon after death/zone change)
        if name ~= currentInstanceName then
            if dungeon.startTime then
                self:FinalizeDungeon()
            end
            self:ResetDungeon()

            local newDungeon = getDungeon()
            currentInstanceName = name
            newDungeon.instanceName = name
            newDungeon.startTime = GetServerTime()
        end
    elseif not inInstance then
        if dungeon.startTime then
            -- Actually left the instance
            self:FinalizeDungeon()
            self:ResetDungeon()
        end
        currentInstanceName = nil
    end

    -- Refresh display to reflect content type change
    if ShieldTax.Display then
        ShieldTax.Display:Update()
    end
end

function Stats:OnZoneChanged()
    -- Only act on zone changes that actually change instance context
    -- (ignore graveyard transitions, sub-zone changes within same instance)
    local inInstance, instanceType = IsInInstance()
    if not inInstance and currentInstanceName then
        -- Left instance via zone change
        self:OnEnterWorld()
    elseif inInstance and not currentInstanceName then
        -- Entered instance via zone change
        self:OnEnterWorld()
    end
    -- If in same instance or same non-instance, do nothing
end

function Stats:OnKeystoneStart()
    -- M+ start — reset dungeon counter with keystone info
    local dungeon = getDungeon()
    if dungeon.startTime then
        self:FinalizeDungeon()
    end
    self:ResetDungeon()

    local newDungeon = getDungeon()
    local name = select(1, GetInstanceInfo())
    newDungeon.instanceName = name
    newDungeon.startTime = GetServerTime()
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        newDungeon.keystoneLevel = select(1, C_ChallengeMode.GetActiveKeystoneInfo())
    end
end

function Stats:OnKeystoneCompleted()
    -- M+ completed — finalize and optionally auto-report
    self:FinalizeDungeon()
    local dungeon = getDungeon()
    local cost = dungeon.costCopper
    local deathCost = dungeon.deathTaxCopper
    if cost > 0 or deathCost > 0 then
        local msg = "Dungeon Shield Tax: " ..
            ShieldTax.CostCalculator:FormatGold(cost) ..
            " (" .. dungeon.durabilityLost .. " durability lost)"
        if deathCost > 0 then
            msg = msg .. ". Death Tax: " .. ShieldTax.CostCalculator:FormatGold(deathCost)
        end
        ShieldTax:Print(msg)
    end
    self:ResetDungeon()
end
