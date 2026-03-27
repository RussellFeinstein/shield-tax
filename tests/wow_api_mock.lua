--- WoW API Mock for busted tests
-- Provides minimal mocks of the WoW API surface used by ShieldTax.

local Mock = {}

-- Configurable state
Mock.playerClass = { "Warrior", "WARRIOR", 1 }  -- localized, token, classId
Mock.playerName = "TestWarrior"
Mock.playerRealm = "TestRealm"
Mock.playerGUID = "Player-1234-ABCDEF"

-- Inventory state
Mock.inventorySlots = {
    SecondaryHandSlot = 17,
}

-- Per-slot item links
Mock.equippedItems = {}

-- Per-slot durability: { current, max }
Mock.durability = {}

-- Item info cache: itemLink -> { name, link, quality, ilvl, ..., equipLoc, ... }
Mock.itemInfoCache = {}

-- Detailed ilvl overrides: itemLink -> effective ilvl
Mock.detailedIlvl = {}

-- Time
Mock.gameTime = 0       -- GetTime() monotonic
Mock.serverTime = 1700000000  -- GetServerTime() epoch

-- Instance state
Mock.inInstance = false
Mock.instanceType = nil  -- "party", "raid", "pvp", "arena", or nil
Mock.instanceInfo = { "Test Dungeon", "party", 1, "Normal", 0, 0, false, 1, 5 }

-- Combat lockdown
Mock.inCombatLockdown = false

-- Sound playback log
Mock.soundsPlayed = {}
Mock.soundFilesPlayed = {}

-- Registered events and their handlers
Mock.eventHandlers = {}
Mock.registeredEvents = {}

-- AceDB mock storage
Mock.savedVars = {}

----------------------------------------------------------------------
-- WoW Global API Mocks
----------------------------------------------------------------------

function _G.UnitClass(unit)
    return Mock.playerClass[1], Mock.playerClass[2], Mock.playerClass[3]
end

function _G.UnitName(unit)
    return Mock.playerName
end

function _G.GetRealmName()
    return Mock.playerRealm
end

function _G.UnitGUID(unit)
    return Mock.playerGUID
end

function _G.GetInventorySlotInfo(slotName)
    return Mock.inventorySlots[slotName]
end

function _G.GetInventoryItemLink(unit, slot)
    return Mock.equippedItems[slot]
end

function _G.GetInventoryItemDurability(slot)
    local dura = Mock.durability[slot]
    if dura then
        return dura[1], dura[2]
    end
    return nil, nil
end

function _G.GetDetailedItemLevelInfo(itemLink)
    return Mock.detailedIlvl[itemLink]
end

function _G.GetTime()
    return Mock.gameTime
end

function _G.GetServerTime()
    return Mock.serverTime
end

function _G.IsInInstance()
    return Mock.inInstance, Mock.instanceType
end

function _G.GetInstanceInfo()
    return unpack(Mock.instanceInfo)
end

function _G.InCombatLockdown()
    return Mock.inCombatLockdown
end

Mock.isDead = false
function _G.UnitIsDeadOrGhost(unit)
    return Mock.isDead
end

function _G.PlaySound(soundKitID, channel)
    table.insert(Mock.soundsPlayed, { id = soundKitID, channel = channel })
end

function _G.PlaySoundFile(path, channel)
    table.insert(Mock.soundFilesPlayed, { path = path, channel = channel })
end

function _G.GetAddOnMetadata(addon, field)
    if addon == "ShieldTax" and field == "Version" then
        return "0.2.0"
    end
    return nil
end

-- C_Item namespace
_G.C_Item = _G.C_Item or {}

function _G.C_Item.GetItemInfo(itemLink)
    local info = Mock.itemInfoCache[itemLink]
    if info then
        return unpack(info)
    end
    return nil
end

-- SOUNDKIT constants
_G.SOUNDKIT = {
    LOOT_WINDOW_COIN_SOUND = 120,
    MONEY_FRAME_OPEN = 891,
    MONEY_FRAME_CLOSE = 892,
}

-- C_ChallengeMode namespace
_G.C_ChallengeMode = _G.C_ChallengeMode or {}
function _G.C_ChallengeMode.GetActiveKeystoneInfo()
    return Mock.keystoneLevel or 0
end
Mock.keystoneLevel = nil

Mock.chatMessages = {}
function _G.SendChatMessage(msg, chatType, language, target)
    table.insert(Mock.chatMessages, { msg = msg, channel = chatType })
end

-- math.random seeding for reproducible tests
math.randomseed(12345)

----------------------------------------------------------------------
-- Frame Mock
----------------------------------------------------------------------

local FrameMT = {}
FrameMT.__index = FrameMT

function FrameMT:SetPoint() end
function FrameMT:SetSize() end
function FrameMT:SetWidth() end
function FrameMT:SetHeight() end
function FrameMT:SetMovable() end
function FrameMT:EnableMouse() end
function FrameMT:RegisterForDrag() end
function FrameMT:SetClampedToScreen() end
function FrameMT:Show() self._visible = true end
function FrameMT:Hide() self._visible = false end
function FrameMT:IsShown() return self._visible or false end
function FrameMT:SetAlpha() end
function FrameMT:SetScale() end
function FrameMT:SetBackdrop() end
function FrameMT:SetBackdropColor() end
function FrameMT:SetText() end
function FrameMT:SetFont() end
function FrameMT:SetJustifyH() end
function FrameMT:GetStringWidth() return 100 end

function FrameMT:SetFrameStrata() end
function FrameMT:StartMoving() end
function FrameMT:StopMovingOrSizing() end
function FrameMT:ClearAllPoints() end
function FrameMT:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function FrameMT:SetTextColor() end
function FrameMT:SetOwner() end
function FrameMT:AddLine() end
function FrameMT:AddDoubleLine() end
function FrameMT:SetBackdropBorderColor() end

function FrameMT:SetScript(event, handler)
    self.scripts = self.scripts or {}
    self.scripts[event] = handler
end

function FrameMT:RegisterEvent(event)
    Mock.registeredEvents[event] = true
end

function FrameMT:UnregisterEvent(event)
    Mock.registeredEvents[event] = nil
end

function FrameMT:CreateFontString(name, layer, template)
    return setmetatable({ scripts = {} }, FrameMT)
end

function FrameMT:CreateTexture(name, layer)
    return setmetatable({ scripts = {} }, FrameMT)
end

function FrameMT:SetTexture() end
function FrameMT:SetTexCoord() end

function _G.CreateFrame(frameType, name, parent, template)
    return setmetatable({ scripts = {} }, FrameMT)
end

_G.UIParent = setmetatable({ scripts = {} }, FrameMT)
_G.GameTooltip = setmetatable({ scripts = {} }, FrameMT)
_G.DEFAULT_CHAT_FRAME = setmetatable({ scripts = {} }, FrameMT)

----------------------------------------------------------------------
-- LibStub Mock
----------------------------------------------------------------------

local libs = {}
local libVersions = {}

_G.LibStub = setmetatable({}, {
    __call = function(self, libName, silent)
        if libs[libName] then
            return libs[libName], libVersions[libName]
        end
        if not silent then
            error("Cannot find lib '" .. libName .. "'")
        end
        return nil
    end,
})

function _G.LibStub:NewLibrary(libName, version)
    libs[libName] = {}
    libVersions[libName] = version
    return libs[libName]
end

function _G.LibStub:GetLibrary(libName, silent)
    return self(libName, silent)
end

----------------------------------------------------------------------
-- AceAddon-3.0 Mock
----------------------------------------------------------------------

local AceAddon = {}
local addons = {}
libs["AceAddon-3.0"] = AceAddon

function AceAddon:NewAddon(addonName, ...)
    local addon = {
        name = addonName,
        mixins = { ... },
        registeredEvents = {},
        chatCommands = {},
    }
    setmetatable(addon, { __index = AceAddon })
    addons[addonName] = addon
    return addon
end

function AceAddon:GetAddon(addonName)
    return addons[addonName]
end

function AceAddon:Print(msg)
    -- silent in tests
end

function AceAddon:RegisterEvent(event, handler)
    self.registeredEvents[event] = handler
end

function AceAddon:UnregisterEvent(event)
    self.registeredEvents[event] = nil
end

function AceAddon:RegisterChatCommand(cmd, method)
    self.chatCommands[cmd] = method
end

function AceAddon:GetArgs(str, num)
    if not str or str == "" then return nil end
    local args = {}
    for word in str:gmatch("%S+") do
        table.insert(args, word)
        if #args >= num then break end
    end
    return unpack(args)
end

--- Fire a mock event on an addon.
--- Matches AceEvent-3.0 dispatch: function handlers get (event, ...),
--- string method handlers get (self, event, ...).
function Mock.FireEvent(addonName, event, ...)
    local addon = addons[addonName]
    if not addon then return end
    local handler = addon.registeredEvents[event]
    if handler then
        if type(handler) == "function" then
            handler(event, ...)
        elseif type(handler) == "string" then
            addon[handler](addon, event, ...)
        end
    end
end

----------------------------------------------------------------------
-- AceDB-3.0 Mock
----------------------------------------------------------------------

local AceDB = {}
libs["AceDB-3.0"] = AceDB

function AceDB:New(savedVarName, defaults)
    local db = {
        global = {},
        profile = {},
    }
    -- Apply defaults
    if defaults then
        if defaults.global then
            for k, v in pairs(defaults.global) do
                if type(v) == "table" then
                    db.global[k] = Mock.deepCopy(v)
                else
                    db.global[k] = v
                end
            end
        end
        if defaults.profile then
            for k, v in pairs(defaults.profile) do
                if type(v) == "table" then
                    db.profile[k] = Mock.deepCopy(v)
                else
                    db.profile[k] = v
                end
            end
        end
    end
    return db
end

----------------------------------------------------------------------
-- LibDataBroker-1.1 Mock
----------------------------------------------------------------------

local LibDataBroker = {}
libs["LibDataBroker-1.1"] = LibDataBroker

function LibDataBroker:NewDataObject(name, obj)
    return obj or {}
end

----------------------------------------------------------------------
-- LibDBIcon-1.0 Mock
----------------------------------------------------------------------

local LibDBIcon = {}
libs["LibDBIcon-1.0"] = LibDBIcon

function LibDBIcon:Register() end
function LibDBIcon:Show() end
function LibDBIcon:Hide() end
function LibDBIcon:IsRegistered() return false end

----------------------------------------------------------------------
-- AceEvent-3.0 Mock (mixed into addons via NewAddon)
----------------------------------------------------------------------
-- Already handled by AceAddon RegisterEvent/UnregisterEvent

----------------------------------------------------------------------
-- AceConsole-3.0 Mock (mixed into addons via NewAddon)
----------------------------------------------------------------------
-- Already handled by AceAddon RegisterChatCommand/GetArgs/Print

----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------

function Mock.deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = Mock.deepCopy(v)
    end
    return copy
end

--- Reset all mock state to defaults.
function Mock.reset()
    Mock.playerClass = { "Warrior", "WARRIOR", 1 }
    Mock.playerName = "TestWarrior"
    Mock.playerRealm = "TestRealm"
    Mock.playerGUID = "Player-1234-ABCDEF"
    Mock.equippedItems = {}
    Mock.durability = {}
    Mock.itemInfoCache = {}
    Mock.detailedIlvl = {}
    Mock.gameTime = 0
    Mock.serverTime = 1700000000
    Mock.inInstance = false
    Mock.instanceType = nil
    Mock.keystoneLevel = nil
    Mock.inCombatLockdown = false
    Mock.isDead = false
    Mock.soundsPlayed = {}
    Mock.soundFilesPlayed = {}
    Mock.chatMessages = {}
    Mock.registeredEvents = {}
    Mock.savedVars = {}

    -- Reset addons
    for name, _ in pairs(addons) do
        addons[name] = nil
    end

    -- Clear global addon reference
    _G.ShieldTax = nil
end

--- Set up a standard shield in the mock.
---@param ilvl number Item level (default 639)
---@param quality number Item quality (default 4 = Epic)
---@param currentDura number Current durability (default 120)
---@param maxDura number Max durability (default 120)
function Mock.equipShield(ilvl, quality, currentDura, maxDura)
    ilvl = ilvl or 639
    quality = quality or 4
    currentDura = currentDura or 120
    maxDura = maxDura or 120

    local itemLink = "|cff0070dd|Hitem:12345:0:0:0:0:0:0:0:0|h[Test Shield]|h|r"
    Mock.equippedItems[17] = itemLink
    Mock.durability[17] = { currentDura, maxDura }
    Mock.itemInfoCache[itemLink] = {
        "Test Shield",       -- 1: name
        itemLink,            -- 2: link
        quality,             -- 3: quality
        ilvl,                -- 4: itemLevel
        1,                   -- 5: requiredLevel
        "Armor",             -- 6: itemType
        "Shields",           -- 7: itemSubType
        1,                   -- 8: maxStackSize
        "INVTYPE_SHIELD",    -- 9: itemEquipLoc
        132384,              -- 10: texture
        50000,               -- 11: sellPrice
        4,                   -- 12: classID (Armor)
        6,                   -- 13: subclassID (Shields)
    }
end

--- Set up a non-shield off-hand item.
function Mock.equipOffhand()
    local itemLink = "|cff0070dd|Hitem:99999:0:0:0:0:0:0:0:0|h[Test Offhand]|h|r"
    Mock.equippedItems[17] = itemLink
    Mock.durability[17] = { 100, 100 }
    Mock.itemInfoCache[itemLink] = {
        "Test Offhand",
        itemLink,
        4,
        639,
        1,
        "Armor",
        "Miscellaneous",
        1,
        "INVTYPE_HOLDABLE",  -- Held in off-hand, NOT a shield
        132384,
        50000,
        4,
        0,
    }
end

return Mock
