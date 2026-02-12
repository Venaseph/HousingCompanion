-- ============================================================================
-- Housing Companion - Vendor Finder
-- Tracks housing decor vendors and their inventory
-- Based on DecorVendor addon by Midnitedestiny
-- ============================================================================

HC = HC or {}
HC.VendorFinder = {}

local VendorFinder = HC.VendorFinder

function VendorFinder:Initialize()
    HC_DB = HC_DB or {}
    HC_DB.vendors = HC_DB.vendors or {
        favorites = {},
        searchHistory = {},
        vendorLocations = {},
        itemSources = {},
        filters = {
            showAll = true,
            showAvailable = true,
            hideUnavailable = false,
            faction = "all",
        },
    }
    
    self:RegisterEvents()
    self:BuildVendorDatabase()
end

function VendorFinder:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("PLAYER_LOGIN")
    
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "MERCHANT_SHOW" then
            VendorFinder:OnMerchantShow(...)
        elseif event == "MERCHANT_CLOSED" then
            VendorFinder:OnMerchantClosed()
        elseif event == "PLAYER_LOGIN" then
            VendorFinder:OnLogin()
        end
    end)
end

function VendorFinder:BuildVendorDatabase()
    -- Initialize vendor data structure
    self.vendors = {}
    self.vendorsByName = {}
    self.itemsByVendor = {}
end

function VendorFinder:OnMerchantShow()
    -- Get current merchant NPC ID
    local npcID = GetNPCID()
    if not npcID then return end
    
    -- Scan merchant inventory
    local itemCount = GetMerchantNumItems()
    for i = 1, itemCount do
        local link = GetMerchantItemLink(i)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                self:CacheVendorItem(npcID, itemID, i)
            end
        end
    end
    
    HC.EventBus:Trigger("HC_VENDOR_SCANNED", npcID)
end

function VendorFinder:OnMerchantClosed()
    HC.EventBus:Trigger("HC_VENDOR_CLOSED")
end

function VendorFinder:OnLogin()
    -- Verify vendor data on login
    self:SyncVendorData()
end

function VendorFinder:CacheVendorItem(npcID, itemID, slotIndex)
    if not self.itemsByVendor[npcID] then
        self.itemsByVendor[npcID] = {}
    end
    
    self.itemsByVendor[npcID][slotIndex] = itemID
    
    -- Track item source
    if not HC_DB.vendors.itemSources[itemID] then
        HC_DB.vendors.itemSources[itemID] = {}
    end
    
    if not HC_DB.vendors.itemSources[itemID][npcID] then
        HC_DB.vendors.itemSources[itemID][npcID] = {
            discovered = time(),
            lastSeen = time(),
        }
    else
        HC_DB.vendors.itemSources[itemID][npcID].lastSeen = time()
    end
end

function VendorFinder:GetVendorItems(npcID)
    return self.itemsByVendor[npcID] or {}
end

function VendorFinder:GetItemSources(itemID)
    return HC_DB.vendors.itemSources[itemID] or {}
end

function VendorFinder:SearchVendors(query)
    local results = {}
    
    for npcID, items in pairs(self.itemsByVendor) do
        -- Search by vendor name or items
        local match = false
        
        -- Get vendor name
        local vendorName, isLoading = HC.RewardsTracker:GetCachedNpcName(npcID)
        if vendorName and string.find(string.lower(vendorName), string.lower(query), 1, true) then
            match = true
        end
        
        -- Search items if vendor name doesn't match
        if not match then
            for _, itemID in pairs(items) do
                local itemName, _ = HC.RewardsTracker:GetCachedItemName(itemID)
                if itemName and string.find(string.lower(itemName), string.lower(query), 1, true) then
                    match = true
                    break
                end
            end
        end
        
        if match then
            table.insert(results, {
                npcID = npcID,
                name = vendorName,
                itemCount = #items,
            })
        end
    end
    
    return results
end

function VendorFinder:ToggleFavoriteVendor(npcID)
    local db = HC_DB.vendors
    db.favorites[npcID] = not db.favorites[npcID]
    HC.EventBus:Trigger("HC_VENDOR_FAVORITE_TOGGLED", npcID, db.favorites[npcID])
end

function VendorFinder:IsFavoriteVendor(npcID)
    return HC_DB.vendors.favorites[npcID] or false
end

function VendorFinder:SetFilter(filterName, value)
    HC_DB.vendors.filters[filterName] = value
    HC.EventBus:Trigger("HC_VENDOR_FILTER_CHANGED", filterName, value)
end

function VendorFinder:GetFilteredVendors()
    local results = {}
    local filters = HC_DB.vendors.filters
    
    for npcID, items in pairs(self.itemsByVendor) do
        local include = true
        
        -- Apply filters
        if filters.hideUnavailable then
            -- Check if vendor is still available
            local source = self:GetItemSources(items[1])
            if source and not source[npcID] then
                include = false
            end
        end
        
        if include then
            table.insert(results, {
                npcID = npcID,
                itemCount = #items,
                favorite = self:IsFavoriteVendor(npcID),
            })
        end
    end
    
    return results
end

function VendorFinder:SyncVendorData()
    -- Perform any necessary sync operations on login
end

function VendorFinder:GetVendorLocation(npcID)
    -- Returns vendor location if available
    return HC_DB.vendors.vendorLocations[npcID]
end

print("|cFF2aa198[HC]|r Vendor Finder module loaded")
