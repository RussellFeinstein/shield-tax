---@class ShieldTax
local ShieldTax = LibStub("AceAddon-3.0"):GetAddon("ShieldTax")

local Display = {}
ShieldTax.Display = Display

local frame
local contentText
local lifetimeText
local statusText
local duraText
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
    frame:SetSize(220, 62)
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
    shieldIcon:SetSize(40, 40)
    shieldIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -10)
    shieldIcon:SetTexture("Interface\\Icons\\INV_Shield_04")
    shieldIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Title
    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", shieldIcon, "TOPRIGHT", 6, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(1, 0.82, 0)  -- Gold/yellow
    titleText:SetText("Shield Tax")

    -- Dungeon cost (shown only in instances)
    contentText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    contentText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
    contentText:SetJustifyH("LEFT")
    contentText:SetText("0g")

    -- Lifetime cost
    lifetimeText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lifetimeText:SetPoint("TOPLEFT", contentText, "BOTTOMLEFT", 0, -2)
    lifetimeText:SetJustifyH("LEFT")
    lifetimeText:SetTextColor(0.7, 0.7, 0.7)
    lifetimeText:SetText("Lifetime Total: 0g")

    -- Shield durability percentage (right side of title)
    duraText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    duraText:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    duraText:SetPoint("TOP", titleText, "TOP", 0, 0)
    duraText:SetJustifyH("RIGHT")
    duraText:SetTextColor(0.7, 0.7, 0.7)
    duraText:SetText("")

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

    -- Initial update to set correct state (hide dungeon line in cities, etc.)
    self:Update()
end

--- Update the display with current stats.
function Display:Update()
    if not frame then return end

    local tracker = ShieldTax.Tracker
    if tracker and not tracker:HasShield() then
        -- No shield — show inactive state
        contentText:Hide()
        lifetimeText:Hide()
        duraText:Hide()
        statusText:Show()
        return
    end

    statusText:Hide()
    lifetimeText:Show()

    local calc = ShieldTax.CostCalculator
    local stats = ShieldTax.Stats

    if stats and tracker then
        local dg = stats:GetDungeon()
        local inInstance = IsInInstance()
        local contentType = tracker:GetContentType()
        local contentLabels = ShieldTax.Tracker and ShieldTax.Tracker.CONTENT_LABELS or {}
        local contentLabel = contentLabels[contentType] or contentType

        -- Hide entire frame if current content type is disabled
        local db = ShieldTax.db and ShieldTax.db.profile
        local contentEnabled = not db or not db.contentToggles or db.contentToggles[contentType] ~= false

        if not contentEnabled then
            frame:Hide()
            return
        end

        -- Show frame (in case it was hidden by a disabled content type)
        if db and db.displayEnabled then
            frame:Show()
        end

        if inInstance and dg.startTime then
            contentText:SetText(contentLabel .. ": " .. calc:FormatGold(dg.costCopper))
            contentText:SetTextColor(1, 1, 1)
        else
            local ss = stats:GetSession()
            local ctCost = ss.byContent[contentType] and ss.byContent[contentType].costCopper or 0
            contentText:SetText(contentLabel .. ": " .. calc:FormatGold(ctCost))
            contentText:SetTextColor(1, 1, 1)
        end
        contentText:Show()
        lifetimeText:SetPoint("TOPLEFT", contentText, "BOTTOMLEFT", 0, -2)

        -- Calculate filtered lifetime total (only enabled content types)
        local charData = ShieldTax:GetCharData()
        if charData then
            local lt = charData.lifetime
            local filteredTotal = 0
            local byContent = lt.byContent or {}
            for key, ct in pairs(byContent) do
                local enabled = not db or not db.contentToggles or db.contentToggles[key] ~= false
                if enabled and ct.costCopper then
                    filteredTotal = filteredTotal + ct.costCopper
                end
            end
            lifetimeText:SetText("Lifetime Total: " .. calc:FormatGold(filteredTotal))
        end

        -- Shield durability
        if tracker then
            local dura = tracker:GetShieldDurability()
            if dura then
                duraText:SetText("Shield: " .. string.format("%.0f%%", dura * 100))
                duraText:Show()
            else
                duraText:Hide()
            end
        end

        -- Resize frame to fit content
        local textWidth = math.max(
            contentText:IsShown() and contentText:GetStringWidth() or 0,
            lifetimeText:GetStringWidth()
        )
        -- Account for dura text on the right side of the title
        local duraWidth = duraText:IsShown() and duraText:GetStringWidth() or 0
        local titleWidth = 60 + duraWidth + 10  -- "Shield Tax" + gap + dura
        textWidth = math.max(textWidth, titleWidth)
        local iconWidth = shieldIcon:GetWidth()
        frame:SetWidth(iconWidth + 6 + textWidth + 24)
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
    GameTooltip:SetText("Shield Tax", 1, 0.82, 0)

    local calc = ShieldTax.CostCalculator
    local tracker = ShieldTax.Tracker
    local charData = ShieldTax:GetCharData()

    if calc and charData then
        local lt = charData.lifetime

        -- Lifetime breakdown by content type
        GameTooltip:AddLine("Lifetime Breakdown", 0.7, 0.7, 1)

        local db = ShieldTax.db and ShieldTax.db.profile
        local byContent = lt.byContent
        local filteredTotal = 0
        if byContent then
            local labels = { mythicplus="M+", raid="Raid", dungeon="Dungeon", openworld="Open World", other="Other" }
            local hasData = false
            for key, label in pairs(labels) do
                local ct = byContent[key]
                local enabled = not db or not db.contentToggles or db.contentToggles[key] ~= false
                if ct and ct.costCopper > 0 and enabled then
                    GameTooltip:AddDoubleLine("  " .. label .. ":", calc:FormatGold(ct.costCopper), 1, 1, 1, 1, 1, 1)
                    filteredTotal = filteredTotal + ct.costCopper
                    hasData = true
                end
            end
            if not hasData then
                GameTooltip:AddLine("  No data yet", 0.5, 0.5, 0.5)
            end
        end

        GameTooltip:AddDoubleLine("Lifetime Total:", calc:FormatGold(filteredTotal), 1, 0.82, 0, 1, 1, 1)

        if lt.deathTaxCopper > 0 then
            GameTooltip:AddDoubleLine("Death Tax:", calc:FormatGold(lt.deathTaxCopper), 0.5, 0.5, 0.5, 0.5, 0.5, 0.5)
        end
    end

    GameTooltip:Show()
end

--- Set display visibility directly (for options panel / spec guard).
---@param enabled boolean
function Display:SetEnabled(enabled)
    if not frame then return end
    local db = ShieldTax.db and ShieldTax.db.profile
    if db then db.displayEnabled = enabled end
    if enabled then
        frame:Show()
    else
        frame:Hide()
    end
end

--- Apply scale to the display frame immediately.
---@param scale number
function Display:SetScale(scale)
    if not frame then return end
    frame:SetScale(scale)
end

--- Check if the display frame is currently shown.
---@return boolean
function Display:IsShown()
    return frame and frame:IsShown() or false
end
