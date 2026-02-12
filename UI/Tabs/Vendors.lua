-- ============================================================================
-- Housing Companion - Vendors Tab
-- Track housing decor vendors and their inventory
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

function HC.UI.Tabs:CreateVendors(parent)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local frame = CreateFrame("Frame", "HC_VendorsTab", parent)
    frame:SetAllPoints()
    frame:Hide()
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", UI.sectionSpacing, -UI.sectionSpacing)
    title:SetText("Decor Vendors")
    title:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    frame.title = title
    
    -- Search bar
    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetSize(200, 24)
    searchBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        HC.UI.Tabs:RefreshVendorsContent(self:GetText())
    end)
    frame.searchBox = searchBox
    
    -- Filter buttons
    local filterFrame = CreateFrame("Frame", nil, frame)
    filterFrame:SetSize(400, 40)
    filterFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    
    local allBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    allBtn:SetSize(80, 25)
    allBtn:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    allBtn:SetText("All Vendors")
    allBtn:SetScript("OnClick", function()
        HC.UI.Tabs:RefreshVendorsContent("")
    end)
    
    local favoritesBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    favoritesBtn:SetSize(80, 25)
    favoritesBtn:SetPoint("LEFT", allBtn, "RIGHT", UI.sectionSpacing, 0)
    favoritesBtn:SetText("Favorites")
    favoritesBtn:SetScript("OnClick", function()
        HC.UI.Tabs:RefreshVendorsContent("", true)
    end)
    
    local availableBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
    availableBtn:SetSize(100, 25)
    availableBtn:SetPoint("LEFT", favoritesBtn, "RIGHT", UI.sectionSpacing, 0)
    availableBtn:SetText("Now Available")
    availableBtn:SetScript("OnClick", function()
        HC.VendorFinder:SetFilter("showAvailable", true)
        HC.UI.Tabs:RefreshVendorsContent("")
    end)
    
    frame.filterFrame = filterFrame
    frame.allBtn = allBtn
    frame.favoritesBtn = favoritesBtn
    frame.availableBtn = availableBtn
    
    -- Content scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -UI.sectionSpacing)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -UI.sectionSpacing, UI.sectionSpacing)
    
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    
    frame.scrollFrame = scrollFrame
    frame.contentFrame = contentFrame
    frame.searchQuery = ""
    frame.showFavoritesOnly = false
    
    -- Populate initial content
    HC.UI.Tabs:RefreshVendorsContent("")
    
    return frame
end

function HC.UI.Tabs:RefreshVendorsContent(searchQuery, favoritesOnly)
    local tab = _G["HC_VendorsTab"]
    if not tab then return end
    
    tab.searchQuery = searchQuery or ""
    tab.showFavoritesOnly = favoritesOnly or false
    
    local contentFrame = tab.contentFrame
    
    -- Clear existing content
    for _, child in ipairs({contentFrame:GetChildren()}) do
        child:Hide()
    end
    contentFrame:SetHeight(1)
    
    -- Get vendors to display
    local vendors
    if searchQuery and searchQuery ~= "" then
        vendors = HC.VendorFinder:SearchVendors(searchQuery)
    else
        vendors = HC.VendorFinder:GetFilteredVendors()
    end
    
    -- Filter for favorites if needed
    if favoritesOnly then
        local filtered = {}
        for _, vendor in ipairs(vendors) do
            if HC.VendorFinder:IsFavoriteVendor(vendor.npcID) then
                table.insert(filtered, vendor)
            end
        end
        vendors = filtered
    end
    
    local yOffset = 0
    for i, vendor in ipairs(vendors) do
        local vendorLine = HC.UI.Tabs:CreateVendorLine(contentFrame, vendor, i)
        vendorLine:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + 35
    end
    
    if yOffset == 0 then
        local emptyText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("CENTER", contentFrame, "CENTER")
        emptyText:SetText("No vendors found")
        emptyText:SetTextColor(0.7, 0.7, 0.7)
        yOffset = 30
    end
    
    contentFrame:SetHeight(yOffset + 10)
end

function HC.UI.Tabs:CreateVendorLine(parent, vendor, index)
    local UI = HC.Constants.UI or {padding = 8}
    local colors = GetColors()
    
    local line = CreateFrame("Frame", nil, parent)
    line:SetSize(parent:GetWidth() - 20, 30)
    line:SetHeight(30)
    
    -- Background
    local bg = line:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    if index % 2 == 0 then
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.3)
    else
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.1)
    end
    
    -- Vendor icon
    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("LEFT", line, "LEFT", UI.sectionSpacing, 0)
    icon:SetTexture("Interface\\Icons\\Inv_box_petcarrier_01")
    
    -- Vendor name and item count
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", UI.sectionSpacing, 0)
    text:SetText("[" .. vendor.npcID .. "] Items: " .. vendor.itemCount)
    text:SetTextColor(colors.primary[1], colors.primary[2], colors.primary[3])
    
    -- Favorite button
    local isFavorite = HC.VendorFinder:IsFavoriteVendor(vendor.npcID)
    local favoriteBtn = CreateFrame("Button", nil, line)
    favoriteBtn:SetSize(24, 24)
    favoriteBtn:SetPoint("RIGHT", line, "RIGHT", -UI.sectionSpacing, 0)
    favoriteBtn:SetText(isFavorite and "♥" or "♡")
    favoriteBtn:SetNormalFontObject(GameFontNormal)
    favoriteBtn:SetScript("OnClick", function()
        HC.VendorFinder:ToggleFavoriteVendor(vendor.npcID)
        HC.UI.Tabs:RefreshVendorsContent(HC_VendorsTab.searchQuery, HC_VendorsTab.showFavoritesOnly)
    end)
    
    -- View items button
    local viewBtn = CreateFrame("Button", nil, line, "UIPanelButtonTemplate")
    viewBtn:SetSize(60, 20)
    viewBtn:SetPoint("RIGHT", favoriteBtn, "LEFT", -UI.sectionSpacing, 0)
    viewBtn:SetText("View")
    viewBtn:SetScript("OnClick", function()
        HC.UI.Tabs:ShowVendorItems(vendor.npcID)
    end)
    
    return line
end

function HC.UI.Tabs:ShowVendorItems(npcID)
    local items = HC.VendorFinder:GetVendorItems(npcID)
    
    -- Create a simple popup showing vendor items
    local popup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(400, 300)
    popup:SetPoint("CENTER", UIParent, "CENTER")
    popup:SetTitle("Vendor Items - " .. npcID)
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -32, 12)
    
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(contentFrame)
    
    local yOffset = 0
    for slotIndex, itemID in pairs(items) do
        local itemName, isLoading = HC.RewardsTracker:GetCachedItemName(itemID)
        
        local text = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        text:SetText("[" .. itemID .. "] " .. itemName)
        yOffset = yOffset + 20
    end
    
    contentFrame:SetHeight(yOffset + 10)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
end

print("|cFF2aa198[HC]|r Vendors tab loaded")
