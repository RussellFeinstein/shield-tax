---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local SoundManager = {}
ShieldTax.SoundManager = SoundManager

-- Last time a sound was played (monotonic via GetTime)
local lastSoundTime = 0

-- Sound definitions: key -> { type = "kit"|"file", id/path }
local SOUND_DEFS = {
    coin       = { type = "kit", id = 120 },   -- SOUNDKIT.LOOT_WINDOW_COIN_SOUND
    money_open = { type = "kit", id = 891 },   -- SOUNDKIT.MONEY_FRAME_OPEN
    register   = { type = "file", path = "Interface\\AddOns\\ShieldTax\\Sounds\\register.ogg" },
    coins      = { type = "file", path = "Interface\\AddOns\\ShieldTax\\Sounds\\coins.ogg" },
    none       = { type = "none" },
}

--- Play the configured sound effect, respecting throttle.
---@return boolean played Whether the sound was actually played
function SoundManager:Play()
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db then return false end

    local effectKey = db.soundEffect or "coin"
    local throttle = db.soundThrottle or 0.5
    local channel = db.soundChannel or "SFX"

    -- Check throttle
    local now = GetTime()
    if (now - lastSoundTime) < throttle then
        return false
    end

    local def = SOUND_DEFS[effectKey]
    if not def or def.type == "none" then
        return false
    end

    if def.type == "kit" then
        PlaySound(def.id, channel)
    elseif def.type == "file" then
        PlaySoundFile(def.path, channel)
    end

    lastSoundTime = now
    return true
end

--- Play the current sound effect ignoring throttle (for /st sound test).
function SoundManager:PlayTest()
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db then return end

    local effectKey = db.soundEffect or "coin"
    local channel = db.soundChannel or "SFX"

    local def = SOUND_DEFS[effectKey]
    if not def or def.type == "none" then
        ShieldTax:Print("Sound is set to 'none' (muted).")
        return
    end

    if def.type == "kit" then
        PlaySound(def.id, channel)
    elseif def.type == "file" then
        PlaySoundFile(def.path, channel)
    end
end

--- Set the sound effect by key.
---@param key string One of: "coin", "money_open", "register", "coins", "none"
---@return boolean valid Whether the key was valid
function SoundManager:SetEffect(key)
    if not SOUND_DEFS[key] then
        return false
    end

    if ShieldTax.db and ShieldTax.db.profile then
        ShieldTax.db.profile.soundEffect = key
    end
    return true
end

--- Get the current sound effect key.
---@return string key
function SoundManager:GetEffect()
    local db = ShieldTax.db and ShieldTax.db.profile
    return db and db.soundEffect or "coin"
end

--- Get the list of valid sound effect keys.
---@return table keys
function SoundManager:GetEffectKeys()
    local keys = {}
    for k in pairs(SOUND_DEFS) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

--- Reset the throttle timer (for testing).
function SoundManager:ResetThrottle()
    lastSoundTime = 0
end
