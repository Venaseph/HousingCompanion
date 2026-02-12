-- ============================================================================
-- Housing Companion - Reputations Tab
-- Track housing-related reputations and their rewards
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

local function GetColors()
    return HC.Constants:GetThemeColors() or {
        primary = {1, 1, 1},
        secondary = {0.7, 0.7, 0.7},
        accent = {0, 1, 0},
        warning = {1, 1, 0},
    }
end

function HC.UI.Tabs:CreateReputations(parent)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local frame = CreateFrame("Frame", "HC_ReputationsTab", parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.sectionSpacing, -UI.sectionSpacing)
    title:SetText("Housing Reputations")
    title:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    frame.title = title
    
    -- Filter/Options frame
    local optionsFrame = CreateFrame("Frame", nil, frame)
    optionsFrame:SetSize(400, 50)
    optionsFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    
    -- Account-wide checkbox
    local accountWideCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    accountWideCheck:SetSize(20, 20)
    accountWideCheck:SetPoint("LEFT", optionsFrame, "LEFT", 0, 0)
    accountWideCheck:SetChecked(HC.RepTracker:GetSetting("accountWide"))
    accountWideCheck:SetScript("OnClick", function(self)
        HC.RepTracker:SetSetting("accountWide", self:GetChecked())
        HC.UI.Tabs:RefreshReputationsContent()
    end)
    
    local accountWideText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    accountWideText:SetPoint("LEFT", accountWideCheck, "RIGHT", 5, 0)
    accountWideText:SetText("Account Wide")
    
    -- Hide completed checkbox
    local hideCompletedCheck = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    hideCompletedCheck:SetSize(20, 20)
    hideCompletedCheck:SetPoint("LEFT", accountWideText, "RIGHT", 20, 0)
    hideCompletedCheck:SetChecked(HC.RepTracker:GetSetting("hideCompleted"))
    hideCompletedCheck:SetScript("OnClick", function(self)
        HC.RepTracker:SetSetting("hideCompleted", self:GetChecked())
        HC.UI.Tabs:RefreshReputationsContent()
    end)
    
    local hideCompletedText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideCompletedText:SetPoint("LEFT", hideCompletedCheck, "RIGHT", 5, 0)
    hideCompletedText:SetText("Hide Completed")
    
    frame.accountWideCheck = accountWideCheck
    frame.hideCompletedCheck = hideCompletedCheck
    
    -- Content scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", optionsFrame, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.sectionSpacing, UI.sectionSpacing)
    
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    
    frame.scrollFrame = scrollFrame
    frame.contentFrame = contentFrame
    
    -- Populate initial content
    HC.UI.Tabs:RefreshReputationsContent()
    
    return frame
end

function HC.UI.Tabs:RefreshReputationsContent()
    local tab = _G["HC_ReputationsTab"]
    if not tab then return end
    
    local contentFrame = tab.contentFrame
    
    -- Clear existing content
    for _, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
    end
    contentFrame:SetHeight(1)
    
    -- Get reputations
    local reps = HC.RepTracker:GetHousingReputations()
    reps = HC.RepTracker:SortReputationsByExpansion(reps)
    
    -- Apply filters
    local hideCompleted = tab.hideCompletedCheck and tab.hideCompletedCheck:GetChecked() or false
    
    local filtered = HC.RepTracker:FilterReputations(function(rep)
        if hideCompleted and rep.standing == 7 then  -- Exalted
            return false
        end
        return true
    end)
    
    local yOffset = 0
    local lastExpansion = nil
    
    for i, rep in ipairs(filtered) do
        -- Add expansion header if needed
        if rep.expansion ~= lastExpansion then
            local expHeader = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            expHeader:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, -yOffset)
            expHeader:SetText(rep.expansion or "Unknown")
            expHeader:SetTextColor(1, 0.82, 0)
            yOffset = yOffset + 25
            lastExpansion = rep.expansion
        end
        
        -- Create rep line
        local repLine = HC.UI.Tabs:CreateRepLine(contentFrame, rep, i)
        repLine:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + 45
    end
    
    if yOffset == 0 then
        local emptyText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", contentFrame, "CENTER")
        emptyText:SetText("No housing reputations tracked")
        emptyText:SetTextColor(0.7, 0.7, 0.7)
        yOffset = 30
    end
    
    contentFrame:SetHeight(yOffset + 10)
end

function HC.UI.Tabs:CreateRepLine(parent, rep, index)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(parent:GetWidth() - 20, 40)
    line:SetHeight(40)
    
    -- Background
    local bg = line:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    else
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.1)
    end
    
    -- Rep name
    local name = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", line, "TOPLEFT", UI.sectionSpacing, -5)
    name:SetText(rep.name or "Unknown")
    name:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    
    -- Standing bar
    local barBg = line:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    barBg:SetSize(150, 15)
    barBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    -- Standing progress
    local barProgress = line:CreateTexture(nil, "ARTWORK")
    barProgress:SetPoint("TOPLEFT", barBg, "TOPLEFT", 1, -1)
    barProgress:SetHeight(13)
    
    if rep.barMax > 0 then
        local progress = (rep.barValue - rep.barMin) / (rep.barMax - rep.barMin)
        barProgress:SetWidth(148 * progress)
    else
        barProgress:SetWidth(0)
    end
    
    -- Use faction standing colors
    local standingColor = HC.RepTracker:GetStandingName(rep.standing)
    if standingColor == "Friendly" then
        barProgress:SetColorTexture(0, 1, 0, 0.8)
    elseif standingColor == "Honored" then
        barProgress:SetColorTexture(0, 0.5, 1, 0.8)
    elseif standingColor == "Revered" then
        barProgress:SetColorTexture(1, 0.5, 0, 0.8)
    elseif standingColor == "Exalted" then
        barProgress:SetColorTexture(1, 0.82, 0, 0.8)
    else
        barProgress:SetColorTexture(0.5, 0.5, 0.5, 0.8)
    end
    
    -- Standing text
    local standing = line:CreateFontString(nil, "OVERLAY", "GameFontSmall")
    standing:SetPoint("LEFT", barBg, "RIGHT", UI.sectionSpacing, 0)
    standing:SetText(HC.RepTracker:GetStandingName(rep.standing))
    standing:SetTextColor(0.7, 0.7, 0.7)
    
    -- Rewards button
    local rewardsBtn = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
    rewardsBtn:SetSize(80, 20)
    rewardsBtn:SetPoint("TOPRIGHT", line, "TOPRIGHT", -UI.sectionSpacing, -5)
    rewardsBtn:SetText("Rewards")
    rewardsBtn:SetScript("OnClick", function()
        HC.UI.Tabs:ShowRepRewards(rep)
    end)
    
    return line
end

function HC.UI.Tabs:ShowRepRewards(rep)
    if not rep or not rep.rewards then return end
    
    local popup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(450, 400)
    popup:SetPoint("CENTER", UIParent, "CENTER")
    popup:SetTitle(rep.name .. " - Housing Rewards")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -32, 12)
    
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    
    local yOffset = 0
    for i, reward in ipairs(rep.rewards) do
        -- Item name
        local itemName = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        itemName:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, -yOffset)
        itemName:SetText("[" .. reward.itemID .. "] " .. (reward.itemName or "Unknown Item"))
        itemName:SetTextColor(1, 1, 1)
        yOffset = yOffset + 20
        
        -- Required standing
        local standing = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontSmall")
        standing:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 15, -yOffset)
        standing:SetText("Requires: " .. (reward.requiredStanding or "Unknown"))
        standing:SetTextColor(0.7, 0.7, 0.7)
        yOffset = yOffset + 18
    end
    
    contentFrame:SetHeight(yOffset + 10)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
end

print("|cFF2aa198[HC]|r Reputations tab loaded")
