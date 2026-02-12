-- ============================================================================
-- Housing Companion - Rewards Tracker
-- Tracks player housing rewards, achievements, quests, and unlockables
-- Based on HomeBound addon by Bettiold
-- ============================================================================

HC = HC or {}
HC.RewardsTracker = {}

local RewardsTracker = HC.RewardsTracker

-- Initialize rewards tracking
function RewardsTracker:Initialize()
    HC_DB = HC_DB or {}
    HC_DB.rewards = HC_DB.rewards or {
        completedAchievements = {},
        completedQuests = {},
        completedDrops = {},
        favorites = {},
        showMinimapButton = true,
        tabFilters = {},
        showVendorCheckmarks = true,
        showMerchantCheckmarks = false,
        hideTwitchDrop = false,
    }
    
    -- Register event listeners
    self:RegisterEvents()
    self:CacheRewardData()
end

function RewardsTracker:RegisterEvents()
    -- Register for achievement and quest completion events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ACHIEVEMENT_EARNED")
    frame:RegisterEvent("QUEST_COMPLETE")
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_LOGOUT")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "ACHIEVEMENT_EARNED" then
            RewardsTracker:OnAchievementEarned(...)
        elseif event == "QUEST_COMPLETE" or event == "QUEST_TURNED_IN" then
            RewardsTracker:OnQuestCompleted(...)
        elseif event == "PLAYER_LOGIN" then
            RewardsTracker:OnLogin()
        elseif event == "PLAYER_LOGOUT" then
            RewardsTracker:OnLogout()
        end
    end)
end

function RewardsTracker:CacheRewardData()
    -- Cache item and vendor information
    self.itemCache = {}
    self.vendorCache = {}
    self.npcCache = {}
    self.questCache = {}
end

function RewardsTracker:OnAchievementEarned(achievementID)
    local db = HC_DB.rewards
    if not db.completedAchievements[achievementID] then
        db.completedAchievements[achievementID] = time()
        HC.EventBus:Trigger("HC_REWARD_EARNED", "achievement", achievementID)
    end
end

function RewardsTracker:OnQuestCompleted(questID)
    local db = HC_DB.rewards
    if not db.completedQuests[questID] then
        db.completedQuests[questID] = time()
        HC.EventBus:Trigger("HC_REWARD_EARNED", "quest", questID)
    end
end

function RewardsTracker:OnLogin()
    -- Verify achievement data on login
    self:SyncAchievementData()
end

function RewardsTracker:OnLogout()
    -- Save any pending updates
end

function RewardsTracker:SyncAchievementData()
    -- Compare server data with local cache
    local numAchievements = GetNumAchievements()
    for i = 1, numAchievements do
        local achievementID = GetAchievementInfo(i)
        if achievementID then
            local _, _, _, completed, month, day, year = GetAchievementInfo(achievementID)
            if completed then
                self:OnAchievementEarned(achievementID)
            end
        end
    end
end

function RewardsTracker:GetCachedItemName(itemID)
    if not itemID then return "Unknown Item", false end
    if self.itemCache[itemID] then return self.itemCache[itemID], false end
    
    local item = Item:CreateFromItemID(itemID)
    if not item:IsItemEmpty() then
        item:ContinueOnItemLoad(function() 
            self.itemCache[itemID] = item:GetItemName() 
            HC.EventBus:Trigger("HC_ITEM_LOADED", itemID)
        end)
    end
    return "Loading...", true
end

function RewardsTracker:GetCachedNpcName(npcID)
    if self.npcCache[npcID] then return self.npcCache[npcID], false end
    
    local link = "unit:Creature-0-0-0-0-" .. npcID
    local data = C_TooltipInfo.GetHyperlink(link)
    if data and data.lines and data.lines[1] then
        local lineText = data.lines[1].leftText
        if lineText and lineText ~= "" and lineText ~= UNKNOWN and lineText ~= "Unknown" then
            self.npcCache[npcID] = lineText
            return lineText, false
        end
    end
    return "Loading...", true
end

function RewardsTracker:GetCompletionStatus(rewardType, rewardID)
    local db = HC_DB.rewards
    
    if rewardType == "achievement" then
        return db.completedAchievements[rewardID] ~= nil
    elseif rewardType == "quest" then
        return db.completedQuests[rewardID] ~= nil
    elseif rewardType == "drop" then
        return db.completedDrops[rewardID] ~= nil
    end
    
    return false
end

function RewardsTracker:ToggleFavorite(rewardType, rewardID)
    local db = HC_DB.rewards
    local key = rewardType .. "_" .. rewardID
    
    db.favorites[key] = not db.favorites[key]
    HC.EventBus:Trigger("HC_FAVORITE_TOGGLED", rewardType, rewardID, db.favorites[key])
end

function RewardsTracker:IsFavorite(rewardType, rewardID)
    local db = HC_DB.rewards
    local key = rewardType .. "_" .. rewardID
    return db.favorites[key] or false
end

function RewardsTracker:FilterRewards(rewardType, filters)
    local db = HC_DB.rewards
    local results = {}
    
    if rewardType == "achievement" then
        for achievementID, timestamp in pairs(db.completedAchievements) do
            if not filters.hideCompleted or timestamp == nil then
                table.insert(results, {
                    id = achievementID,
                    type = "achievement",
                    completed = timestamp ~= nil,
                    favorite = self:IsFavorite("achievement", achievementID),
                })
            end
        end
    elseif rewardType == "quest" then
        for questID, timestamp in pairs(db.completedQuests) do
            if not filters.hideCompleted or timestamp == nil then
                table.insert(results, {
                    id = questID,
                    type = "quest",
                    completed = timestamp ~= nil,
                    favorite = self:IsFavorite("quest", questID),
                })
            end
        end
    end
    
    return results
end

print("|cFF2aa198[HC]|r Rewards Tracker module loaded")
