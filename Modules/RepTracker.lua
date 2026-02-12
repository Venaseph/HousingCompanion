-- ============================================================================
-- Housing Companion - Reputation Tracker
-- Tracks housing-related reputations and their rewards
-- Based on Housing Reputations addon by tr0tsky
-- ============================================================================

HC = HC or {}
HC.RepTracker = {}

local RepTracker = HC.RepTracker

function RepTracker:Initialize()
    HC_DB = HC_DB or {}
    HC_DB.reputations = HC_DB.reputations or {
        characters = {},
        purchasedItems = {},
        settings = {
            accountWide = true,
            hideCompleted = false,
            showMinimap = true,
        }
    }
    
    self:RegisterEvents()
    self:SyncReputationData()
end

function RepTracker:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("UPDATE_FACTION")
    frame:RegisterEvent("PLAYER_LOGOUT")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_LOGIN" then
            RepTracker:OnLogin()
        elseif event == "UPDATE_FACTION" then
            RepTracker:OnFactionUpdated()
        elseif event == "PLAYER_LOGOUT" then
            RepTracker:OnLogout()
        end
    end)
end

function RepTracker:OnLogin()
    self:SyncReputationData()
end

function RepTracker:OnFactionUpdated()
    -- Update cached reputation data
    self:SyncReputationData()
    HC.EventBus:Trigger("HC_REPUTATION_UPDATED")
end

function RepTracker:OnLogout()
    -- Save any pending updates
end

function RepTracker:SyncReputationData()
    local db = HC_DB.reputations
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    
    if not db.characters[charKey] then
        db.characters[charKey] = {
            name = UnitName("player"),
            realm = GetRealmName(),
            faction = UnitFactionGroup("player"),
            lastUpdated = time(),
            reputations = {},
        }
    end
    
    local charData = db.characters[charKey]
    charData.lastUpdated = time()
    charData.faction = UnitFactionGroup("player")
    
    -- Scan reputation data
    self:ScanReputations(charData.reputations)
end

function RepTracker:ScanReputations(repTable)
    local numFactions = GetNumFactions()
    
    for i = 1, numFactions do
        local name, description, standingID, barMin, barMax, barValue = GetFactionInfo(i)
        
        if name then
            if not repTable[name] then
                repTable[name] = {}
            end
            
            repTable[name].standingID = standingID
            repTable[name].barMin = barMin
            repTable[name].barMax = barMax
            repTable[name].barValue = barValue
            repTable[name].lastUpdated = time()
        end
    end
end

function RepTracker:GetCharacterReputations(charKey)
    local db = HC_DB.reputations
    if charKey then
        return db.characters[charKey] and db.characters[charKey].reputations or {}
    end
    
    -- Return current character
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    return db.characters[charKey] and db.characters[charKey].reputations or {}
end

function RepTracker:GetAllCharacterReps()
    local db = HC_DB.reputations
    return db.characters or {}
end

function RepTracker:GetFactionStanding(factionName)
    local db = HC_DB.reputations
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    
    if db.characters[charKey] and db.characters[charKey].reputations[factionName] then
        return db.characters[charKey].reputations[factionName]
    end
    
    return nil
end

function RepTracker:IsHousingReputation(factionName)
    -- This checks if a reputation grants housing rewards
    -- We'll populate this with the data from HR_RepData
    
    if HC.HousingRepData and HC.HousingRepData.reputations then
        for _, repInfo in ipairs(HC.HousingRepData.reputations) do
            if repInfo.name == factionName then
                return true
            end
        end
    end
    
    return false
end

function RepTracker:GetHousingReputations()
    local db = HC_DB.reputations
    local charKey = UnitName("player") .. "-" .. GetRealmName()
    local charReps = db.characters[charKey] and db.characters[charKey].reputations or {}
    
    local housingReps = {}
    
    if HC.HousingRepData and HC.HousingRepData.reputations then
        for _, repInfo in ipairs(HC.HousingRepData.reputations) do
            local charRepData = charReps[repInfo.name]
            if charRepData then
                table.insert(housingReps, {
                    name = repInfo.name,
                    expansion = repInfo.expansion,
                    standing = charRepData.standingID,
                    barMin = charRepData.barMin,
                    barMax = charRepData.barMax,
                    barValue = charRepData.barValue,
                    rewards = repInfo.rewards,
                    vendor = repInfo.vendor,
                })
            end
        end
    end
    
    return housingReps
end

function RepTracker:MarkItemPurchased(itemID)
    local db = HC_DB.reputations
    db.purchasedItems[itemID] = time()
    HC.EventBus:Trigger("HC_ITEM_PURCHASED", itemID)
end

function RepTracker:IsItemPurchased(itemID)
    local db = HC_DB.reputations
    return db.purchasedItems[itemID] ~= nil
end

function RepTracker:SetSetting(settingName, value)
    local db = HC_DB.reputations
    db.settings[settingName] = value
    HC.EventBus:Trigger("HC_REP_SETTING_CHANGED", settingName, value)
end

function RepTracker:GetSetting(settingName)
    local db = HC_DB.reputations
    return db.settings[settingName]
end

function RepTracker:FilterReputations(filterFunc)
    local housingReps = self:GetHousingReputations()
    local filtered = {}
    
    for _, rep in ipairs(housingReps) do
        if not filterFunc or filterFunc(rep) then
            table.insert(filtered, rep)
        end
    end
    
    return filtered
end

function RepTracker:SortReputationsByExpansion(reps)
    local EXPANSION_ORDER = {
        ["Classic"] = 1,
        ["The Burning Crusade"] = 2,
        ["Wrath of the Lich King"] = 3,
        ["Cataclysm"] = 4,
        ["Mists of Pandaria"] = 5,
        ["Warlords of Draenor"] = 6,
        ["Legion"] = 7,
        ["Battle for Azeroth"] = 8,
        ["Shadowlands"] = 9,
        ["Dragonflight"] = 10,
        ["The War Within"] = 11,
    }
    
    table.sort(reps, function(a, b)
        local orderA = EXPANSION_ORDER[a.expansion] or 99
        local orderB = EXPANSION_ORDER[b.expansion] or 99
        if orderA ~= orderB then
            return orderA > orderB  -- Newest first
        end
        return a.name < b.name
    end)
    
    return reps
end

print("|cFF2aa198[HC]|r Reputation Tracker module loaded")
