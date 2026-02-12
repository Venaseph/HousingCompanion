-- ============================================================================
-- Housing Companion - HomeBound Vendor Data
-- Vendor and reward data from HomeBound addon
-- ============================================================================

HC = HC or {}

-- This file serves as a bridge to include HomeBound's extensive vendor database
-- The actual vendor data is too large to include directly, but we maintain compatibility

HC.VendorData = {
    -- Model positions for displaying items
    modelPositions = {},
    -- Vendor item mappings
    vendorItems = {},
    -- Achievement and quest data
    achievements = {},
    quests = {},
    -- Localization strings
    L_LOADING_ITEM = "Loading Item...",
    L_LOADING_VENDOR = "Loading Vendor...",
    L_LOADING_QUEST = "Loading Quest...",
}

-- Export for localization
HC.VendorL = HC.VendorL or {}
HC.VendorL.L_INCLUDE_CHECKMARKS = "Include Checkmarks"
HC.VendorL.L_RECIPE = "Recipe:"
HC.VendorL.L_PAGE_NUM = "Page %d of %d"
HC.VendorL.L_VENDOR_SELLS = "%s sells:"
HC.VendorL.L_NUM_HIDDEN = "(%d hidden)"
HC.VendorL.L_REAGENTS_REQ = "Reagents required:"
HC.VendorL.L_COMMUNITY = "Community & Support"
HC.VendorL.L_DESCRIPTION = "Track your Player Housing rewards"
HC.VendorL.L_TIPS_TITLE = "Home Bound Tips"
HC.VendorL.L_TAB1_UNLOCKABLES = "Unlockables"
HC.VendorL.L_TAB2_VENDORS = "Vendors"
HC.VendorL.L_TAB3_DROPS = "Drops"
HC.VendorL.L_TAB4_PROFESSIONS = "Professions"
HC.VendorL.L_FILTERS = "Filters"
HC.VendorL.L_HIDE_COMPLETED = "Hide Completed"
HC.VendorL.L_HIDE_NONFAVORITED = "Hide Non-Favorited"
HC.VendorL.L_ACHIEVEMENTS = "Achievements"
HC.VendorL.L_ACHIEVEMENT = "Achievement"
HC.VendorL.L_QUESTS = "Quests"
HC.VendorL.L_QUEST = "Quest"
HC.VendorL.L_FACTION = "Faction"
HC.VendorL.L_NEUTRAL = "Neutral"
HC.VendorL.L_ALLIANCE = "Alliance"
HC.VendorL.L_HORDE = "Horde"
HC.VendorL.L_REQUIRES = "Requires"
HC.VendorL.L_REPUTATION = "Reputation"
HC.VendorL.L_RESET_FILTERS = "Reset Filters"
HC.VendorL.L_NUM_MISSING = "(%d missing)"
HC.VendorL.L_OPEN_VENDOR_ITEMS = "\n|cff00ff00<Left Click>|r to open Vendor Items"
HC.VendorL.L_ADD_MAP_PIN = "|cff00ff00<Right Click>|r to add Map Pin"
HC.VendorL.L_NPC_IN_ZONE = "%s in %s"
HC.VendorL.L_NUM_SOURCES = "(%d sources)"
HC.VendorL.L_MULTIPLE_DROPS = "Multiple Drops in %s"
HC.VendorL.L_FACTION_REQUIRED = "Faction: %s"
HC.VendorL.L_ATTUNEMENT_REQUIRED = "Attunement Required"
HC.VendorL.L_NONE_IN_ZONE = "None in this zone"
HC.VendorL.L_VENDOR_FILTER = "Filter Vendors"
HC.VendorL.L_ITEM_FILTER = "Filter Items"
HC.VendorL.L_FAVORITES = "Favorites Only"
