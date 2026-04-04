---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local MinimapButton = {}
ShieldTax.MinimapButton = MinimapButton

local ldb
local icon

function MinimapButton:Init()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if not LDB or not LDBIcon then return end

    ldb = LDB:NewDataObject("ShieldTax", {
        type = "data source",
        text = "0g",
        icon = "Interface\\Icons\\INV_Shield_04",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if ShieldTax.Display then
                    ShieldTax.Display:Toggle()
                end
            elseif button == "RightButton" then
                if ShieldTax.Options then
                    ShieldTax.Options:Open()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            MinimapButton:ShowTooltip(tooltip)
        end,
    })

    -- Register icon with saved show/hide state
    if not ShieldTax.db.global.minimapIconDB then
        ShieldTax.db.global.minimapIconDB = {}
    end

    LDBIcon:Register("ShieldTax", ldb, ShieldTax.db.global.minimapIconDB)

    -- Apply profile setting
    local db = ShieldTax.db and ShieldTax.db.profile
    if db and not db.minimapIcon then
        LDBIcon:Hide("ShieldTax")
    end

    icon = LDBIcon
end

--- Update the LDB text with current content cost (matches display frame).
function MinimapButton:Update()
    if not ldb then return end

    local stats = ShieldTax.Stats
    local calc = ShieldTax.CostCalculator
    local tracker = ShieldTax.Tracker
    if not stats or not calc or not tracker then return end

    local dg = stats:GetDungeon()
    local inInstance = IsInInstance()
    if inInstance and dg.startTime then
        ldb.text = calc:FormatGold(dg.costCopper)
    else
        local contentType = tracker:GetContentType()
        local ss = stats:GetSession()
        local ctCost = ss.byContent[contentType] and ss.byContent[contentType].costCopper or 0
        ldb.text = calc:FormatGold(ctCost)
    end
end

--- Toggle minimap icon visibility.
function MinimapButton:Toggle()
    if not icon then return end

    local db = ShieldTax.db and ShieldTax.db.profile
    if not db then return end

    db.minimapIcon = not db.minimapIcon
    if db.minimapIcon then
        icon:Show("ShieldTax")
        ShieldTax:Print("Minimap icon shown.")
    else
        icon:Hide("ShieldTax")
        ShieldTax:Print("Minimap icon hidden.")
    end
end

--- Set minimap icon visibility directly (for options panel / spec guard).
---@param shown boolean
function MinimapButton:SetShown(shown)
    if not icon then return end
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db then return end
    db.minimapIcon = shown
    if shown then
        icon:Show("ShieldTax")
    else
        icon:Hide("ShieldTax")
    end
end

--- Show tooltip with stats summary.
function MinimapButton:ShowTooltip(tooltip)
    if not tooltip then return end

    tooltip:SetText("ShieldTax", 1, 0.82, 0)
    tooltip:AddLine("v" .. ShieldTax.VERSION, 0.5, 0.5, 0.5)
    tooltip:AddLine(" ")

    local stats = ShieldTax.Stats
    local calc = ShieldTax.CostCalculator
    local tracker = ShieldTax.Tracker

    if stats and calc then
        local dg = stats:GetDungeon()
        local charData = ShieldTax:GetCharData()

        tooltip:AddDoubleLine("Dungeon:", calc:FormatGold(dg.costCopper), 1, 1, 1, 1, 1, 1)

        if charData then
            local lt = charData.lifetime
            tooltip:AddDoubleLine("Lifetime:", calc:FormatGold(lt.totalCostCopper), 0.7, 0.7, 1, 1, 1, 1)
            if lt.deathTaxCopper > 0 then
                tooltip:AddDoubleLine("  Death Tax:", calc:FormatGold(lt.deathTaxCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
            end
        end

        if tracker then
            local dura = tracker:GetShieldDurability()
            if dura then
                tooltip:AddLine(" ")
                tooltip:AddDoubleLine("Shield:", string.format("%.0f%%", dura * 100), 0.7, 0.7, 1, 1, 1, 1)
            end
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click: Toggle display", 0.5, 0.5, 0.5)
    tooltip:AddLine("Right-click: Settings", 0.5, 0.5, 0.5)
    tooltip:Show()
end
