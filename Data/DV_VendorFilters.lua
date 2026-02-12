-- ============================================================================
-- Housing Companion - DecorVendor Filters
-- Vendor filters and categorization from DecorVendor addon
-- ============================================================================

HC = HC or {}

HC.VendorFilters = {
    -- Vendor categories
    categories = {
        "All Vendors",
        "Housing Vendors",
        "Profession Vendors",
        "Special Vendors",
        "Limited Time",
    },
    
    -- Filter presets
    filters = {
        showAll = true,
        showHousingVendors = true,
        showProfessionVendors = true,
        showAvailable = true,
        hideUnavailable = false,
    },
    
    -- Vendor locations
    locations = {},
    
    -- Item source tracking
    sources = {
        vendor = "Vendor",
        drop = "Drop",
        quest = "Quest",
        achievement = "Achievement",
        event = "Event",
        profession = "Profession",
    },
}

HC.DecorL = HC.DecorL or {}
HC.DecorL.L_TITLE = "Decor Vendors"
HC.DecorL.L_DESCRIPTION = "Tracks vendors that sell housing decor"
HC.DecorL.L_VENDORS = "Vendors"
HC.DecorL.L_ITEMS = "Items"
HC.DecorL.L_LOCATION = "Location"
HC.DecorL.L_FACTION_VENDOR = "Faction Vendor"
HC.DecorL.L_QUEST_VENDOR = "Quest Vendor"
HC.DecorL.L_REPUTATION_VENDOR = "Reputation Vendor"
HC.DecorL.L_PROFESSION_VENDOR = "Profession Vendor"
HC.DecorL.L_LIMITED_TIME = "Limited Time"
HC.DecorL.L_NOW_AVAILABLE = "Now Available"
HC.DecorL.L_COMING_SOON = "Coming Soon"
HC.DecorL.L_NO_LONGER_AVAILABLE = "No Longer Available"
HC.DecorL.L_FILTER_VENDORS = "Filter Vendors"
HC.DecorL.L_FILTER_ITEMS = "Filter Items"
HC.DecorL.L_SEARCH = "Search"
HC.DecorL.L_SORT_BY = "Sort By"
HC.DecorL.L_VENDOR_NAME = "Vendor Name"
HC.DecorL.L_LOCATION_NAME = "Location"
HC.DecorL.L_ITEM_NAME = "Item Name"
HC.DecorL.L_ITEM_TYPE = "Item Type"
HC.DecorL.L_PRICE = "Price"
HC.DecorL.L_CURRENCY = "Currency"
HC.DecorL.L_GOLD = "Gold"
HC.DecorL.L_REPUTATION_POINTS = "Reputation Points"
HC.DecorL.L_KNOWLEDGE_POINTS = "Knowledge Points"
HC.DecorL.L_RENOWN = "Renown"
