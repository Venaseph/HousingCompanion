-- ============================================================================
-- Housing Companion - Rewards Tab
-- Track achievements, quests, and housing rewards
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

local function GetColors()
    local theme = HC.Constants:GetThemeColors() or {}
    return {
        primary   = theme.text_header or {1, 1, 1},     -- white fallback
        secondary = theme.text_dim   or {0.7, 0.7, 0.7},
        accent    = theme.success    or {0, 1, 0},
        danger    = theme.error      or {1, 0, 0},
    }
end

function HC.UI.Tabs:CreateRewards(parent)
    local UI = HC.Constants.UI or { sectionSpacing = 8 }
    local colors = GetColors()
    
    local frame = CreateFrame("Frame", "HC_RewardsTab", parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.sectionSpacing, -UI.sectionSpacing)
    title:SetText("Housing Rewards")
    title:SetTextColor(unpack(colors.primary))
    frame.title = title
    
    -- Filter buttons (Achievements / Quests / Special Items)
    local filterFrame = CreateFrame("Frame", nil, frame)
    filterFrame:SetSize(400, 40)
    filterFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    
    local achievementsBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    achievementsBtn:SetSize(100, 25)
    achievementsBtn:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    achievementsBtn:SetText("Achievements")
    achievementsBtn:SetScript("OnClick", function()
        HC.UI.Tabs:RefreshRewardsContent("achievements")
    end)
    
    local questsBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    questsBtn:SetSize(100, 25)
    questsBtn:SetPoint("LEFT", achievementsBtn, "RIGHT", UI.sectionSpacing, 0)
    questsBtn:SetText("Quests")
    questsBtn:SetScript("OnClick", function()
        HC.UI.Tabs:RefreshRewardsContent("quests")
    end)
    
    local dropsBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    dropsBtn:SetSize(100, 25)
    dropsBtn:SetPoint("LEFT", questsBtn, "RIGHT", UI.sectionSpacing, 0)
    dropsBtn:SetText("Special Items")
    dropsBtn:SetScript("OnClick", function()
        HC.UI.Tabs:RefreshRewardsContent("drops")
    end)
    
    frame.filterFrame = filterFrame
    frame.achievementsBtn = achievementsBtn
    frame.questsBtn = questsBtn
    frame.dropsBtn = dropsBtn
    
    -- Content scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.sectionSpacing, UI.sectionSpacing)
    
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    
    frame.scrollFrame = scrollFrame
    frame.contentFrame = contentFrame
    frame.currentFilter = "achievements"
    
    -- Populate initial content
    HC.UI.Tabs:RefreshRewardsContent("achievements")
    
    return frame
end

-- Keep your existing RefreshRewardsContent / CreateRewardLine / etc. functions here unchanged
-- (they were not in the error, so assuming they're fine unless you see new issues)