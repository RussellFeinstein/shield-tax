std = "lua51"

globals = {
    -- Ace3
    "LibStub",

    -- WoW API
    "CreateFrame",
    "GetInventoryItemDurability",
    "GetInventoryItemLink",
    "GetInventorySlotInfo",
    "GetDetailedItemLevelInfo",
    "GetServerTime",
    "GetTime",
    "GetInstanceInfo",
    "GetSpecialization",
    "GetSpecializationInfo",
    "InCombatLockdown",
    "IsInInstance",
    "PlaySound",
    "PlaySoundFile",
    "SendChatMessage",
    "UnitClass",
    "UnitGUID",
    "UnitName",
    "UnitIsDeadOrGhost",

    -- WoW API namespaces
    "C_ChallengeMode",
    "C_Item",
    "C_Timer",

    -- WoW constants
    "SOUNDKIT",
    "INVSLOT_OFFHAND",

    -- WoW UI
    "GameFontNormal",
    "GameFontNormalLarge",
    "GameFontNormalSmall",
    "GameFontHighlight",
    "GameTooltip",
    "UIParent",

    -- WoW globals
    "DEFAULT_CHAT_FRAME",
    "RAID_CLASS_COLORS",
    "ITEM_QUALITY_COLORS",
    "GetRealmName",
    "GetAddOnMetadata",
    "SlashCmdList",
    "SLASH_SHIELDTAX1",
    "SLASH_SHIELDTAX2",
    "hash_SlashCmdList",

    -- SavedVariables
    "ShieldTaxDB",
}

exclude_files = {
    "ShieldTax/Libs/**",
}

files["tests/**"] = {
    std = "+busted",
    globals = {
        "package",
    },
}
