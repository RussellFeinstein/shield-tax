---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local Display = {}
ShieldTax.Display = Display

local frame
local dungeonText
local sessionText
local statusText
local shieldIcon
local isLocked = true

--- Create the display frame.
function Display:Init()
    if frame then return end

    -- Defer frame creation if in combat lockdown (secure template restriction)
    if InCombatLockdown() then
        ShieldTax:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            ShieldTax:UnregisterEvent("PLAYER_REGEN_ENABLED")
            Display:Init()
        end)
        return
    end

    frame = CreateFrame("Frame", "ShieldTaxFrame", UIParent, "BackdropTemplate")
    frame:SetSize(200, 60)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)

    -- Backdrop: semi-transparent dark background
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.7)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

    -- Shield icon
    shieldIcon = frame:CreateTexture(nil, "ARTWORK")
    shieldIcon:SetSize(24, 24)
    shieldIcon:SetPoint("LEFT", frame, "LEFT", 8, 0)
    shieldIcon:SetTexture("Interface\\Icons\\INV_Shield_04")
    shieldIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Dungeon cost (main line)
    dungeonText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dungeonText:SetPoint("TOPLEFT", shieldIcon, "TOPRIGHT", 6, 2)
    dungeonText:SetJustifyH("LEFT")
    dungeonText:SetText("0g")

    -- Session cost (secondary line)
    sessionText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionText:SetPoint("TOPLEFT", dungeonText, "BOTTOMLEFT", 0, -2)
    sessionText:SetJustifyH("LEFT")
    sessionText:SetTextColor(0.7, 0.7, 0.7)
    sessionText:SetText("Session: 0g")

    -- Status text (shown when no shield equipped)
    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("CENTER", frame, "CENTER", 12, 0)
    statusText:SetJustifyH("CENTER")
    statusText:SetTextColor(0.5, 0.5, 0.5)
    statusText:SetText("No shield equipped")
    statusText:Hide()

    -- Drag to move
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not isLocked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Display:SavePosition()
    end)

    -- Tooltip on hover
    frame:SetScript("OnEnter", function(self)
        Display:ShowTooltip()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Restore saved position
    self:RestorePosition()

    -- Apply scale
    local db = ShieldTax.db and ShieldTax.db.profile
    if db and db.displayScale then
        frame:SetScale(db.displayScale)
    end

    -- Show or hide based on setting
    if db and db.displayEnabled then
        frame:Show()
    else
        frame:Hide()
    end
end

--- Update the display with current stats.
function Display:Update()
    if not frame then return end

    local tracker = ShieldTax.Tracker
    if tracker and not tracker:HasShield() then
        -- No shield — show inactive state
        dungeonText:Hide()
        sessionText:Hide()
        statusText:Show()
        return
    end

    statusText:Hide()
    dungeonText:Show()
    sessionText:Show()

    local calc = ShieldTax.CostCalculator
    local stats = ShieldTax.Stats

    if stats then
        local dg = stats:GetDungeon()
        local ss = stats:GetSession()

        local dungeonCost = calc:FormatGold(dg.costCopper)
        dungeonText:SetText(dungeonCost)

        local sessionCost = calc:FormatGold(ss.costCopper)
        sessionText:SetText("Session: " .. sessionCost)
    end
end

--- Toggle frame visibility.
function Display:Toggle()
    if not frame then return end

    local db = ShieldTax.db and ShieldTax.db.profile
    if frame:IsShown() then
        frame:Hide()
        if db then db.displayEnabled = false end
    else
        frame:Show()
        if db then db.displayEnabled = true end
    end
end

--- Unlock frame for repositioning.
function Display:Unlock()
    if not frame then return end
    isLocked = false
    frame:SetBackdropBorderColor(0.2, 0.8, 0.2, 1.0) -- Green border = unlocked
    ShieldTax:Print("Display unlocked. Drag to move, then /st lock.")
end

--- Lock frame position.
function Display:Lock()
    if not frame then return end
    isLocked = true
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    self:SavePosition()
    ShieldTax:Print("Display locked.")
end

--- Save current frame position to profile.
function Display:SavePosition()
    if not frame then return end
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db then return end

    local point, _, relPoint, x, y = frame:GetPoint()
    db.displayPosition = { point = point, relPoint = relPoint, x = x, y = y }
end

--- Restore frame position from profile.
function Display:RestorePosition()
    if not frame then return end
    local db = ShieldTax.db and ShieldTax.db.profile
    if not db or not db.displayPosition then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        return
    end

    local pos = db.displayPosition
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

--- Show tooltip with extended stats on hover.
function Display:ShowTooltip()
    if not frame then return end

    GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("ShieldTax", 1, 0.82, 0)

    local stats = ShieldTax.Stats
    local calc = ShieldTax.CostCalculator
    local tracker = ShieldTax.Tracker

    if stats and calc then
        local dg = stats:GetDungeon()
        local ss = stats:GetSession()
        local charData = ShieldTax:GetCharData()

        GameTooltip:AddDoubleLine("Dungeon:", calc:FormatGold(dg.costCopper), 1, 1, 1, 1, 1, 1)
        if dg.deathTaxCopper > 0 then
            GameTooltip:AddDoubleLine("  Death Tax:", calc:FormatGold(dg.deathTaxCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end

        GameTooltip:AddDoubleLine("Session:", calc:FormatGold(ss.costCopper), 1, 1, 1, 1, 1, 1)
        if ss.deathTaxCopper > 0 then
            GameTooltip:AddDoubleLine("  Death Tax:", calc:FormatGold(ss.deathTaxCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end

        if charData then
            local lt = charData.lifetime
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Lifetime:", calc:FormatGold(lt.totalCostCopper), 0.7, 0.7, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("  Death Tax:", calc:FormatGold(lt.deathTaxCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)

            -- Per-content breakdown
            local byContent = lt.byContent
            if byContent then
                local labels = { mythicplus="M+", raid="Raid", dungeon="Dungeon", openworld="Open World", other="Other" }
                for key, label in pairs(labels) do
                    local ct = byContent[key]
                    if ct and ct.costCopper > 0 then
                        GameTooltip:AddDoubleLine("  " .. label .. ":", calc:FormatGold(ct.costCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
                    end
                end
            end
        end

        if tracker then
            local dura = tracker:GetShieldDurability()
            if dura then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine("Shield:", string.format("%.0f%%", dura * 100), 0.7, 0.7, 1, 1, 1, 1)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to drag (when unlocked)", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

--- Check if the display frame is currently shown.
---@return boolean
function Display:IsShown()
    return frame and frame:IsShown() or false
end
