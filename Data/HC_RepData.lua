-- ============================================================================
-- Housing Companion - Housing Reputations Data Bridge
-- Reputation data from Housing Reputations addon by tr0tsky
-- ============================================================================

HC = HC or {}
HC.HousingRepData = {}

-- This file bridges the Housing Reputations addon data
-- We'll load the actual data file and convert it to our format

local function ConvertRepConfig()
    local reputations = {}
    
    -- If HOUSING_REP_CONFIG exists (from data.lua), convert it
    if HOUSING_REP_CONFIG then
        for factionID, config in pairs(HOUSING_REP_CONFIG) do
            table.insert(reputations, {
                factionID = factionID,
                name = config.label,
                kind = config.kind,
                expansion = config.expansion,
                faction = config.faction,
                vendor = config.vendor,
                rewards = config.rewards or {},
            })
        end
    end
    
    return reputations
end

-- Store the converted data
HC.HousingRepData.reputations = ConvertRepConfig()

-- Reputation kind constants
HC.HousingRepData.KIND_STANDARD = "standard"
HC.HousingRepData.KIND_RENOWN = "renown"
HC.HousingRepData.KIND_FRIENDSHIP = "friendship"

-- Standing levels
HC.HousingRepData.STANDING = {
    HATED = 0,
    HOSTILE = 1,
    UNFRIENDLY = 2,
    NEUTRAL = 3,
    FRIENDLY = 4,
    HONORED = 5,
    REVERED = 6,
    EXALTED = 7,
}

HC.HousingRepData.STANDING_NAMES = {
    [0] = "Hated",
    [1] = "Hostile",
    [2] = "Unfriendly",
    [3] = "Neutral",
    [4] = "Friendly",
    [5] = "Honored",
    [6] = "Revered",
    [7] = "Exalted",
}

-- Friendship levels
HC.HousingRepData.FRIENDSHIP = {
    STRANGER = 1,
    ACQUAINTANCE = 2,
    BUDDY = 3,
    FRIEND = 4,
    GOOD_FRIEND = 5,
    BEST_FRIEND = 6,
}

HC.HousingRepData.FRIENDSHIP_NAMES = {
    [1] = "Stranger",
    [2] = "Acquaintance",
    [3] = "Buddy",
    [4] = "Friend",
    [5] = "Good Friend",
    [6] = "Best Friend",
}

-- Localization
HC.HousingRepL = HC.HousingRepL or {}
HC.HousingRepL.L_TITLE = "Housing Reputations"
HC.HousingRepL.L_DESCRIPTION = "Track reputations that grant housing rewards"
HC.HousingRepL.L_REPUTATIONS = "Reputations"
HC.HousingRepL.L_STANDING = "Standing"
HC.HousingRepL.L_PROGRESS = "Progress"
HC.HousingRepL.L_REWARDS = "Rewards"
HC.HousingRepL.L_VENDOR = "Vendor"
HC.HousingRepL.L_FRIENDLY = "Friendly"
HC.HousingRepL.L_HONORED = "Honored"
HC.HousingRepL.L_REVERED = "Revered"
HC.HousingRepL.L_EXALTED = "Exalted"
HC.HousingRepL.L_FILTER = "Filter"
HC.HousingRepL.L_HIDE_COMPLETED = "Hide Completed"
HC.HousingRepL.L_ACCOUNT_WIDE = "Account Wide"
HC.HousingRepL.L_SHOW_ALL = "Show All"
HC.HousingRepL.L_EXPANSION = "Expansion"
HC.HousingRepL.L_DRAGONFLIGHT = "Dragonflight"
HC.HousingRepL.L_WAR_WITHIN = "The War Within"
HC.HousingRepL.L_PURCHASED = "Purchased"
HC.HousingRepL.L_AVAILABLE = "Available"
HC.HousingRepL.L_COMING_SOON = "Coming Soon"
HC.HousingRepL.L_ITEM_SOURCES = "Item Sources"
HC.HousingRepL.L_REQUIRED_STANDING = "Required Standing: %s"
HC.HousingRepL.L_REPUTATION_REWARDS = "%s Reputation Rewards"
HC.HousingRepL.L_VIEW_REWARDS = "View Rewards"
HC.HousingRepL.L_NO_HOUSING_REPS = "No housing reputation data available"
HC.HousingRepL.L_ACCOUNT_WIDE_TRACKING = "Track across all characters"
HC.HousingRepL.L_INDIVIDUAL_TRACKING = "Track per character"

-- Helper function to get rep info by name
function HC.HousingRepData:GetRepByName(name)
    for _, rep in ipairs(self.reputations) do
        if rep.name == name then
            return rep
        end
    end
    return nil
end

-- Helper function to get rep info by faction ID
function HC.HousingRepData:GetRepByID(factionID)
    for _, rep in ipairs(self.reputations) do
        if rep.factionID == factionID then
            return rep
        end
    end
    return nil
end

-- Helper function to get all housing reps by expansion
function HC.HousingRepData:GetRepsByExpansion(expansion)
    local results = {}
    for _, rep in ipairs(self.reputations) do
        if rep.expansion == expansion then
            table.insert(results, rep)
        end
    end
    return results
end

-- Helper function to get standing name
function HC.HousingRepData:GetStandingName(standingID)
    return self.STANDING_NAMES[standingID] or "Unknown"
end

-- Helper function to get friendship name
function HC.HousingRepData:GetFriendshipName(level)
    return self.FRIENDSHIP_NAMES[level] or "Unknown"
end

print("|cFF2aa198[HC]|r Housing Reputations data loaded")
