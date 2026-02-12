-- ============================================================================
-- Housing Companion - Rewards Tab
-- Track achievements, quests, and housing rewards
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

local function GetColors()
    return HC.Constants:GetThemeColors() or {
        primary = {1, 1, 1},
        secondary = {0.7, 0.7, 0.7},
        accent = {0, 1, 0},
        danger = {1, 0, 0},
    }
end

function HC.UI.Tabs:CreateRewards(parent)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local frame = CreateFrame("Frame", "HC_RewardsTab", parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.sectionSpacing, -UI.sectionSpacing)
    title:SetText("Housing Rewards")
    title:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    frame.title = title
    
    -- Filter buttons
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

function HC.UI.Tabs:RefreshRewardsContent(rewardType)
    local tab = _G["HC_RewardsTab"]
    if not tab then return end
    
    tab.currentFilter = rewardType
    local contentFrame = tab.contentFrame
    
    -- Clear existing content
    for _, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
    end
    contentFrame:SetHeight(1)
    
    -- Get rewards to display
    local rewards = HC.RewardsTracker:FilterRewards(rewardType, {
        hideCompleted = false,
        hideNonFavorited = false,
    })
    
    local yOffset = 0
    for i, reward in ipairs(rewards) do
        local rewardLine = HC.UI.Tabs:CreateRewardLine(contentFrame, reward, rewardType, i)
        rewardLine:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + 30
    end
    
    contentFrame:SetHeight(yOffset + 10)
end

function HC.UI.Tabs:CreateRewardLine(parent, reward, rewardType, index)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(parent:GetWidth() - 20, 25)
    line:SetHeight(25)
    
    -- Background
    local bg = line:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    else
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.1)
    end
    
    -- Completed checkbox
    local checkbox = CreateFrame("CheckButton", nil, line, "UICheckButtonTemplate")
    checkbox:SetSize(20, 20)
    checkbox:SetPoint("LEFT", line, "LEFT", UI.sectionSpacing, 0)
    checkbox:SetChecked(reward.completed)
    checkbox:SetScript("OnClick", function(self)
        if rewardType == "achievement" then
            HC.RewardsTracker:OnAchievementEarned(reward.id)
        elseif rewardType == "quest" then
            HC.RewardsTracker:OnQuestCompleted(reward.id)
        end
    end)
    
    -- Reward name/ID
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", checkbox, "RIGHT", UI.sectionSpacing, 0)
    text:SetText("[" .. reward.id .. "] " .. (reward.name or "Unknown"))
    text:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    
    -- Favorite button
    local favoriteBtn = CreateFrame("Button", nil, line)
    favoriteBtn:SetSize(20, 20)
    favoriteBtn:SetPoint("RIGHT", line, "RIGHT", -UI.sectionSpacing, 0)
    favoriteBtn:SetText(reward.favorite and "♥" or "♡")
    favoriteBtn:SetScript("OnClick", function()
        HC.RewardsTracker:ToggleFavorite(rewardType, reward.id)
        HC.UI.Tabs:RefreshRewardsContent(rewardType)
    end)
    
    return line
end

print("|cFF2aa198[HC]|r Rewards tab loaded")
