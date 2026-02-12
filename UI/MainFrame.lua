-- ============================================================================
-- Vamoose's Endeavors - MainFrame
-- Main window creation and management with tab switching
-- ============================================================================

HC = HC or {}

-- ============================================================================
-- WINDOW POSITION PERSISTENCE
-- ============================================================================

local function SaveWindowPosition(frame)
    if not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    HC_DB = HC_DB or {}
    HC_DB.windowPos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
    }
end

local function RestoreWindowPosition(frame)
    if not frame then return end
    if HC_DB and HC_DB.windowPos then
        local pos = HC_DB.windowPos
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

-- ============================================================================
-- MAIN WINDOW CREATION
-- ============================================================================

function HC:CreateMainWindow()
    if self.MainFrame then return self.MainFrame end

    local version = C_AddOns.GetAddOnMetadata("HousingCompanion", "Version") or "Dev"
    local frame = HC.UI:CreateMainFrame("HC_MainFrame", "Housing Companion v" .. version)
    frame:Hide()

    -- Escape closes window only when mouse is over it (not when interacting with other UI)
    frame:EnableKeyboard(true)
    frame:SetScript("OnKeyDown", function(f, key)
        if key == "ESCAPE" and f:IsMouseOver() then
            f:SetPropagateKeyboardInput(false)
            f:Hide()
        else
            f:SetPropagateKeyboardInput(true)
        end
    end)

    -- Restore saved position
    RestoreWindowPosition(frame)

    -- Apply saved UI scale
    local uiScale = HC.Store:GetState().config.uiScale or 1.0
    frame:SetScale(uiScale)

    -- Save position on drag stop
    frame:HookScript("OnDragStop", function(self)
        SaveWindowPosition(self)
    end)

    -- ========================================================================
    -- SQUIRREL MASCOT (Title Bar)
    -- Small 3D squirrel head shown when quotes are enabled
    -- ========================================================================

    local squirrelMascot = CreateFrame("PlayerModel", nil, frame.titleBar)
    squirrelMascot:SetSize(32, 32)
    squirrelMascot:SetPoint("LEFT", frame.titleBar.titleLogo, "RIGHT", -20, 8)
    squirrelMascot:SetFrameStrata("DIALOG")
    squirrelMascot:SetFrameLevel(100)
    squirrelMascot:SetDisplayInfo(64016)  -- Squirrel displayID
    squirrelMascot:SetPortraitZoom(0.9)
    squirrelMascot:SetCamDistanceScale(0.8)
    squirrelMascot:SetPosition(0, 0, 0)
    squirrelMascot:SetAnimation(0)  -- Idle animation

    -- Tooltip on hover
    squirrelMascot:EnableMouse(true)
    squirrelMascot:SetScript("OnEnter", function(self)
        if self.isAnimating then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local name = self.displayID == 64016 and "Nestor" or "Robo-Nestor"
        GameTooltip:AddLine(name, 1, 0.82, 0)
        GameTooltip:AddLine("Your endeavor cheerleader!", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Click me!", 0.5, 0.8, 0.5)
        GameTooltip:Show()
    end)
    squirrelMascot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Bounce animation state
    squirrelMascot.isAnimating = false
    squirrelMascot.animStartTime = 0
    squirrelMascot.baseX = -20  -- Original X offset
    squirrelMascot.baseY = 8    -- Original Y offset
    squirrelMascot.displayID = 64016  -- Default squirrel
    squirrelMascot.altDisplayID = 7937  -- Alternate display

    -- Bounce animation update function
    local function UpdateBounceAnimation(self, elapsed)
        if not self.isAnimating then return end

        local now = GetTime()
        local duration = now - self.animStartTime
        local totalDuration = 1.2  -- Total animation time in seconds

        if duration >= totalDuration then
            -- Animation complete - hide and schedule reappear
            self:SetScript("OnUpdate", nil)
            self:Hide()
            self.isAnimating = false

            C_Timer.After(1.0, function()
                -- Reset position and show
                self:ClearAllPoints()
                self:SetPoint("LEFT", frame.titleBar.titleLogo, "RIGHT", self.baseX, self.baseY)
                self:SetAlpha(1)
                self:Show()
            end)
            return
        end

        -- Calculate horizontal movement (accelerating to the left)
        local progress = duration / totalDuration
        local xOffset = self.baseX - (progress * progress * 150)  -- Accelerating leftward

        -- Calculate vertical bounce (sine wave for bounce effect)
        local bounceHeight = 12
        local bounceFrequency = 4  -- Number of bounces
        local yOffset = self.baseY + math.abs(math.sin(progress * bounceFrequency * math.pi)) * bounceHeight * (1 - progress)

        -- Fade out near the end
        local alpha = 1
        if progress > 0.7 then
            alpha = 1 - ((progress - 0.7) / 0.3)
        end

        -- Apply position and alpha
        self:ClearAllPoints()
        self:SetPoint("LEFT", frame.titleBar.titleLogo, "RIGHT", xOffset, yOffset)
        self:SetAlpha(alpha)
    end

    -- Click to trigger animation and quote (left), toggle display (right)
    squirrelMascot:SetScript("OnMouseUp", function(self, button)
        if self.isAnimating then return end  -- Don't interrupt animation

        if button == "RightButton" then
            -- Toggle display ID
            if self.displayID == 64016 then
                self.displayID = self.altDisplayID
            else
                self.displayID = 64016
            end
            self:SetDisplayInfo(self.displayID)
            -- Sync to VE namespace for talking head
            HC.MascotDisplayID = self.displayID
            return
        end

        -- Left click: Trigger the quote
        if HC.Vamoose and HC.Vamoose.TestQuote then
            HC.Vamoose.TestQuote()
        end

        -- Start bounce animation
        GameTooltip:Hide()
        self.isAnimating = true
        self.animStartTime = GetTime()
        self:SetScript("OnUpdate", UpdateBounceAnimation)
    end)

    frame.squirrelMascot = squirrelMascot

    -- Update visibility based on config
    function frame:UpdateSquirrelMascot()
        local state = HC.Store:GetState()
        local quotesEnabled = state.config.quotesEnabled ~= false
        if quotesEnabled then
            self.squirrelMascot:Show()
        else
            self.squirrelMascot:Hide()
        end
    end

    -- Initial visibility
    frame:UpdateSquirrelMascot()

    -- ========================================================================
    -- TAB BAR
    -- ========================================================================

    local tabBar = CreateFrame("Frame", nil, frame)
    local uiConsts = HC.Constants.UI or {}
    tabBar:SetHeight(uiConsts.tabHeight or 24)
    tabBar:SetPoint("TOPLEFT", 0, -uiConsts.titleBarHeight)
    tabBar:SetPoint("TOPRIGHT", 0, -uiConsts.titleBarHeight)
    frame.tabBar = tabBar

    -- Tab bar background (atlas for Housing Theme)
    local tabBarBg = tabBar:CreateTexture(nil, "BACKGROUND")
    tabBarBg:SetAllPoints()
    local Colors = HC.Constants:GetThemeColors()
    if Colors.atlas and Colors.atlas.tabSectionBg then
        tabBarBg:SetAtlas(Colors.atlas.tabSectionBg)
    else
        tabBarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        tabBarBg:SetVertexColor(0, 0, 0, 0)  -- Transparent for non-atlas themes
    end
    tabBar.bg = tabBarBg
    HC.Theme:Register(tabBar, "TabBar")

    -- Create tab buttons (via factory method with Theme Engine registration)
    local NUM_TABS = 8
    local tabHeight = uiConsts.tabHeight or 24
    local isHousingTheme = Colors.atlas and Colors.atlas.tabSectionBg

    -- Housing theme: full-width tabs; other themes: text-fit tabs
    local tabWidth = isHousingTheme and ((uiConsts.mainWidth / NUM_TABS) + 8) or nil
    local tabSpacing = isHousingTheme and -10 or 2
    local tabPadding = 16  -- Padding on each side of text for non-housing themes

    local endeavorsTabBtn = HC.UI:CreateTabButton(tabBar, "Endeavors")
    if tabWidth then
        endeavorsTabBtn:SetSize(tabWidth, tabHeight)
    else
        endeavorsTabBtn:SetSize((endeavorsTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    endeavorsTabBtn:SetPoint("LEFT", 4, 0)

    local rewardsTabBtn = HC.UI:CreateTabButton(tabBar, "Rewards")
    if tabWidth then
        rewardsTabBtn:SetSize(tabWidth, tabHeight)
    else
        rewardsTabBtn:SetSize((rewardsTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    rewardsTabBtn:SetPoint("LEFT", endeavorsTabBtn, "RIGHT", tabSpacing, 0)

    local vendorsTabBtn = HC.UI:CreateTabButton(tabBar, "Vendors")
    if tabWidth then
        vendorsTabBtn:SetSize(tabWidth, tabHeight)
    else
        vendorsTabBtn:SetSize((vendorsTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    vendorsTabBtn:SetPoint("LEFT", rewardsTabBtn, "RIGHT", tabSpacing, 0)

    local reputationsTabBtn = HC.UI:CreateTabButton(tabBar, "Reputations")
    if tabWidth then
        reputationsTabBtn:SetSize(tabWidth, tabHeight)
    else
        reputationsTabBtn:SetSize((reputationsTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    reputationsTabBtn:SetPoint("LEFT", vendorsTabBtn, "RIGHT", tabSpacing, 0)

    local leaderboardTabBtn = HC.UI:CreateTabButton(tabBar, "Rankings")
    if tabWidth then
        leaderboardTabBtn:SetSize(tabWidth, tabHeight)
    else
        leaderboardTabBtn:SetSize((leaderboardTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    leaderboardTabBtn:SetPoint("LEFT", reputationsTabBtn, "RIGHT", tabSpacing, 0)

    local activityTabBtn = HC.UI:CreateTabButton(tabBar, "Activity")
    if tabWidth then
        activityTabBtn:SetSize(tabWidth, tabHeight)
    else
        activityTabBtn:SetSize((activityTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    activityTabBtn:SetPoint("LEFT", leaderboardTabBtn, "RIGHT", tabSpacing, 0)

    local infoTabBtn = HC.UI:CreateTabButton(tabBar, "Info")
    if tabWidth then
        infoTabBtn:SetSize(tabWidth, tabHeight)
    else
        infoTabBtn:SetSize((infoTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    infoTabBtn:SetPoint("LEFT", activityTabBtn, "RIGHT", tabSpacing, 0)

    local configTabBtn = HC.UI:CreateTabButton(tabBar, "Config")
    if tabWidth then
        configTabBtn:SetSize(tabWidth, tabHeight)
    else
        configTabBtn:SetSize((configTabBtn.label:GetStringWidth() or 50) + tabPadding, tabHeight)
    end
    configTabBtn:SetPoint("LEFT", infoTabBtn, "RIGHT", tabSpacing, 0)

    frame.endeavorsTabBtn = endeavorsTabBtn
    frame.rewardsTabBtn = rewardsTabBtn
    frame.vendorsTabBtn = vendorsTabBtn
    frame.reputationsTabBtn = reputationsTabBtn
    frame.leaderboardTabBtn = leaderboardTabBtn
    frame.activityTabBtn = activityTabBtn
    frame.infoTabBtn = infoTabBtn
    frame.configTabBtn = configTabBtn

    -- Update housing display (coupons + house level) from Store
    function frame:UpdateHousingDisplay()
        local state = HC.Store:GetState()
        local housing = state.housing
        local C = HC.Constants:GetThemeColors()

        -- Update coupons
        if housing.coupons and housing.coupons > 0 then
            if housing.couponsIcon then
                self.couponsIcon:SetTexture(housing.couponsIcon)
            end
            self.couponsText:SetText(housing.coupons)
            self.couponsIcon:Show()
            self.couponsText:Show()
        else
            -- Fallback to direct API call if Store not populated yet
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(HC.Constants.CURRENCY_IDS.COMMUNITY_COUPONS)
            if currencyInfo and currencyInfo.quantity then
                self.couponsIcon:SetTexture(currencyInfo.iconFileID)
                self.couponsText:SetText(currencyInfo.quantity)
                self.couponsIcon:Show()
                self.couponsText:Show()
            else
                self.couponsIcon:Hide()
                self.couponsText:Hide()
            end
        end

        -- Update house level
        local level = housing.level or 0
        local xp = housing.xp or 0
        local xpForNextLevel = housing.xpForNextLevel or 0
        local maxLevel = housing.maxLevel or 50

        if level > 0 then
            -- Generate hex from RGB for current theme colors
            local accentHex = string.format("%02x%02x%02x", math.floor(C.accent.r * 255), math.floor(C.accent.g * 255), math.floor(C.accent.b * 255))
            local dimHex = string.format("%02x%02x%02x", math.floor(C.text_dim.r * 255), math.floor(C.text_dim.g * 255), math.floor(C.text_dim.b * 255))
            local houseIcon = "|A:housing-map-plot-occupied-highlight:12:12|a"
            if level >= maxLevel then
                self.houseLevelText:SetText(string.format("%s |cFF%sLv %d|r |cFF%s(Max)|r", houseIcon, accentHex, level, dimHex))
            else
                self.houseLevelText:SetText(string.format("%s |cFF%sLv %d|r |cFF%s%d/%d XP|r", houseIcon, accentHex, level, dimHex, xp, xpForNextLevel))
            end
        else
            self.houseLevelText:SetText("")
        end
    end

    -- Legacy alias for UpdateCoupons
    frame.UpdateCoupons = frame.UpdateHousingDisplay

    -- ========================================================================
    -- PERSISTENT HEADER (always visible, even when minimized)
    -- ========================================================================

    local UI = HC.Constants.UI
    local C = HC.Constants.Colors
    local padding = UI.panelPadding

    local headerSection = CreateFrame("Frame", nil, frame)
    headerSection:SetHeight(UI.headerSectionHeight)
    local headerOffset = -(UI.titleBarHeight + UI.tabHeight)
    headerSection:SetPoint("TOPLEFT", padding, headerOffset)
    headerSection:SetPoint("TOPRIGHT", -padding, headerOffset)
    frame.headerSection = headerSection

    -- Atlas background will be positioned after rows are created
    local headerBg = headerSection:CreateTexture(nil, "BACKGROUND")
    headerBg:SetAtlas("housing-basic-panel--stone-background")
    headerSection.atlasBg = headerBg
    HC.Theme:Register(headerSection, "HeaderSection")

    -- Season name (top left)
    local seasonName = headerSection:CreateFontString(nil, "OVERLAY")
    seasonName:SetPoint("TOPLEFT", 2, -2)
    HC.Theme.ApplyFont(seasonName, C)
    seasonName:SetTextColor(C.text.r, C.text.g, C.text.b)
    seasonName._colorType = "text"
    HC.Theme:Register(seasonName, "HeaderText")
    frame.seasonName = seasonName

    -- Days remaining (top right)
    local daysRemaining = headerSection:CreateFontString(nil, "OVERLAY")
    daysRemaining:SetPoint("TOPRIGHT", 0, -2)
    HC.Theme.ApplyFont(daysRemaining, C, "small")
    daysRemaining:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
    daysRemaining._colorType = "text_dim"
    HC.Theme:Register(daysRemaining, "HeaderText")
    frame.daysRemaining = daysRemaining

    -- Progress bar (full width, below season name)
    local progressBar = HC.UI:CreateProgressBar(headerSection, {
        width = 100,
        height = UI.progressBarHeight,
    })
    progressBar:SetPoint("TOPLEFT", seasonName, "BOTTOMLEFT", 0, -4)
    progressBar:SetPoint("TOPRIGHT", 0, 0)
    frame.progressBar = progressBar

    -- ========================================================================
    -- ROW 1: Dropdown (left), House Level + XP (right) / Fetch Status (right)
    -- ========================================================================
    local dropdownRow = CreateFrame("Frame", nil, headerSection)
    dropdownRow:SetHeight(20)
    dropdownRow:SetPoint("TOPLEFT", progressBar, "BOTTOMLEFT", 0, -4)
    dropdownRow:SetPoint("TOPRIGHT", progressBar, "BOTTOMRIGHT", 0, -4)
    frame.dropdownRow = dropdownRow

    -- House icon (left side)
    local houseIcon = dropdownRow:CreateTexture(nil, "ARTWORK")
    houseIcon:SetSize(16, 16)
    houseIcon:SetPoint("LEFT", 3, 0)
    houseIcon:SetAtlas("housefinder_main-icon")
    frame.houseIcon = houseIcon

    -- House selector dropdown (after icon) - uses custom styled dropdown
    local houseDropdown = HC.UI:CreateDropdown(dropdownRow, {
        width = 140,
        height = 20,
        onSelect = function(key, data)
            if HC.EndeavorTracker then
                HC.EndeavorTracker:SelectHouse(key)
            end
        end,
    })
    houseDropdown:SetPoint("LEFT", houseIcon, "RIGHT", 4, 0)
    frame.houseDropdown = houseDropdown

    -- House Level display (right side) - shares space with fetch status
    -- Note: houseLevelText uses inline color codes, so we don't register it with HeaderText
    local houseLevelText = dropdownRow:CreateFontString(nil, "OVERLAY")
    houseLevelText:SetPoint("LEFT", houseDropdown, "RIGHT", 8, 0)
    houseLevelText:SetPoint("RIGHT", -4, 0)
    houseLevelText:SetJustifyH("RIGHT")
    HC.Theme.ApplyFont(houseLevelText, C, "small")
    houseLevelText:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
    houseLevelText:SetText("")
    frame.houseLevelText = houseLevelText

    -- Active neighborhood container
    local activeContainer = CreateFrame("Frame", nil, dropdownRow)
    activeContainer:SetPoint("TOPLEFT", dropdownRow, "BOTTOMLEFT", 0, 0)
    activeContainer:SetSize(165, 20)
    frame.activeContainer = activeContainer

    -- Active neighborhood icon (below dropdown, aligned to left edge)
    local activeIcon = activeContainer:CreateTexture(nil, "ARTWORK")
    activeIcon:SetSize(16, 16)
    activeIcon:SetPoint("LEFT", 3, 0)
    activeIcon:SetAtlas("housing-map-plot-player-house-highlight")
    frame.activeIcon = activeIcon

    -- Active neighborhood text (after icon, width-limited)
    local activeNeighborhoodText = activeContainer:CreateFontString(nil, "OVERLAY")
    activeNeighborhoodText:SetPoint("LEFT", activeIcon, "RIGHT", 4, 0)
    activeNeighborhoodText:SetJustifyH("LEFT")
    activeNeighborhoodText:SetWidth(140)
    activeNeighborhoodText:SetWordWrap(false)
    activeNeighborhoodText:SetNonSpaceWrap(false)
    HC.Theme.ApplyFont(activeNeighborhoodText, C, "small")
    activeNeighborhoodText:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
    activeNeighborhoodText._colorType = "text_dim"
    HC.Theme:Register(activeNeighborhoodText, "HeaderText")
    frame.activeNeighborhoodText = activeNeighborhoodText

    -- ========================================================================
    -- ROW 2: Coupons (left), Contribution (right)
    -- ========================================================================
    local statsRow = CreateFrame("Frame", nil, headerSection)
    statsRow:SetHeight(16)
    statsRow:SetPoint("TOPLEFT", dropdownRow, "BOTTOMLEFT", -4, -2)
    statsRow:SetPoint("TOPRIGHT", dropdownRow, "BOTTOMRIGHT", -4, -2)
    frame.statsRow = statsRow

    -- Contribution value (right-most)
    local xpValue = statsRow:CreateFontString(nil, "OVERLAY")
    xpValue:SetPoint("RIGHT", 0, 0)
    HC.Theme.ApplyFont(xpValue, C, "small")
    xpValue:SetTextColor(C.endeavor.r, C.endeavor.g, C.endeavor.b)
    xpValue._colorType = "endeavor"
    HC.Theme:Register(xpValue, "HeaderText")
    frame.xpValue = xpValue

    -- Contribution pip icon
    local contribIcon = statsRow:CreateTexture(nil, "ARTWORK")
    contribIcon:SetSize(14, 14)
    contribIcon:SetPoint("RIGHT", xpValue, "LEFT", -4, 0)
    contribIcon:SetAtlas("housing-dashboard-fillbar-pip-complete")
    frame.contribIcon = contribIcon

    -- Tooltip hover area for contribution
    local contribHover = CreateFrame("Frame", nil, statsRow)
    contribHover:SetPoint("LEFT", contribIcon, "LEFT", -2, 0)
    contribHover:SetPoint("RIGHT", xpValue, "RIGHT", 2, 0)
    contribHover:SetPoint("TOP", contribIcon, "TOP", 0, 2)
    contribHover:SetPoint("BOTTOM", contribIcon, "BOTTOM", 0, -2)
    contribHover:EnableMouse(true)
    contribHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Neighborhood Contribution", 1, 1, 1)
        GameTooltip:AddLine("Your contribution to the neighborhood initiative (this character).", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    contribHover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- House XP text
    local houseXpText = statsRow:CreateFontString(nil, "OVERLAY")
    houseXpText:SetPoint("RIGHT", contribIcon, "LEFT", -12, 0)
    HC.Theme.ApplyFont(houseXpText, C, "small")
    houseXpText:SetTextColor(C.endeavor.r, C.endeavor.g, C.endeavor.b)
    houseXpText._colorType = "endeavor"
    HC.Theme:Register(houseXpText, "HeaderText")
    frame.houseXpText = houseXpText

    -- House XP icon
    local houseXpIcon = statsRow:CreateTexture(nil, "ARTWORK")
    houseXpIcon:SetSize(14, 14)
    houseXpIcon:SetPoint("RIGHT", houseXpText, "LEFT", -4, 0)
    houseXpIcon:SetAtlas("house-reward-increase-arrows")
    houseXpIcon:SetRotation(math.pi / 2) -- 90 degrees counter-clockwise
    frame.houseXpIcon = houseXpIcon

    -- Tooltip hover area for house XP
    local houseXpHover = CreateFrame("Frame", nil, statsRow)
    houseXpHover:SetPoint("LEFT", houseXpIcon, "LEFT", -2, 0)
    houseXpHover:SetPoint("RIGHT", houseXpText, "RIGHT", 2, 0)
    houseXpHover:SetPoint("TOP", houseXpIcon, "TOP", 0, 2)
    houseXpHover:SetPoint("BOTTOM", houseXpIcon, "BOTTOM", 0, -2)
    houseXpHover:EnableMouse(true)
    houseXpHover:SetScript("OnEnter", function(self)
        local colors = HC.Constants:GetThemeColors()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("House XP Earned", 1, 1, 1)
        GameTooltip:AddLine("Total from activity log (all your chars).", 0.7, 0.7, 0.7, true)

        local bd = frame.houseXpBreakdown
        if bd then
            GameTooltip:AddLine(" ")
            -- Pre cap increase (capped at 1000)
            local preColor = bd.preCapped >= bd.preCap and colors.text_dim or colors.endeavor
            GameTooltip:AddDoubleLine(
                "Pre cap increase:",
                string.format("%.0f / %d", bd.preCapped, bd.preCap),
                0.7, 0.7, 0.7,
                preColor.r, preColor.g, preColor.b
            )
            -- Post cap increase (cumulative total toward 2250 cap)
            local cumulative = bd.preCapped + bd.post
            local postColor = cumulative >= bd.postCap and colors.text_dim or colors.endeavor
            GameTooltip:AddDoubleLine(
                "Post cap increase:",
                string.format("%.0f / %d", cumulative, bd.postCap),
                0.7, 0.7, 0.7,
                postColor.r, postColor.g, postColor.b
            )

            if frame.houseXpCapped then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Endeavor cap reached!", colors.warning.r, colors.warning.g, colors.warning.b)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Calculated from the server activity feed, which may take a few minutes to update.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    houseXpHover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Coupons count
    local couponsText = statsRow:CreateFontString(nil, "OVERLAY")
    couponsText:SetPoint("RIGHT", houseXpIcon, "LEFT", -12, 0)
    HC.Theme.ApplyFont(couponsText, C, "small")
    couponsText:SetTextColor(C.warning.r, C.warning.g, C.warning.b)
    couponsText._colorType = "warning"
    HC.Theme:Register(couponsText, "HeaderText")
    frame.couponsText = couponsText

    -- Coupons icon
    local couponsIcon = statsRow:CreateTexture(nil, "ARTWORK")
    couponsIcon:SetSize(14, 14)
    couponsIcon:SetPoint("RIGHT", couponsText, "LEFT", -4, 0)
    frame.couponsIcon = couponsIcon

    -- Position header background to cover entire headerSection
    headerBg:SetPoint("TOPLEFT", headerSection, "TOPLEFT", -padding, 0)
    headerBg:SetPoint("BOTTOMRIGHT", statsRow, "BOTTOMRIGHT", padding, -2)

    -- Update house dropdown when house list changes
    function frame:UpdateHouseDropdown(houseList, selectedIndex)
        if houseList and #houseList > 0 then
            -- Build items for the dropdown
            local items = {}
            for i, houseInfo in ipairs(houseList) do
                table.insert(items, {
                    key = i,
                    label = houseInfo.houseName or ("House " .. i),
                })
            end
            self.houseDropdown:SetItems(items)

            -- Set selected house
            local selectedHouse = houseList[selectedIndex or 1]
            local houseName = selectedHouse and selectedHouse.houseName or "Select House"
            self.houseDropdown:SetSelected(selectedIndex or 1, { label = houseName })
        else
            self.houseDropdown:SetItems({})
            self.houseDropdown:SetSelected(nil, { label = "No houses" })
        end
    end

    -- Show which neighborhood is the active endeavor destination
    function frame:UpdateActiveNeighborhood()
        if not C_NeighborhoodInitiative then
            self.activeIcon:Hide()
            self.activeNeighborhoodText:SetText("")
            return
        end

        local activeGUID = C_NeighborhoodInitiative.GetActiveNeighborhood and C_NeighborhoodInitiative.GetActiveNeighborhood()
        if not activeGUID then
            self.activeIcon:Hide()
            self.activeNeighborhoodText:SetText("None")
            return
        end

        -- Find the house name for the active neighborhood
        local activeName = nil
        if HC.EndeavorTracker and HC.EndeavorTracker.houseList then
            for _, houseInfo in ipairs(HC.EndeavorTracker.houseList) do
                if houseInfo.neighborhoodGUID == activeGUID then
                    activeName = houseInfo.houseName or houseInfo.neighborhoodName
                    break
                end
            end
        end

        self.activeIcon:Show()
        local colors = HC.Constants:GetThemeColors()
        local accentHex = string.format("%02x%02x%02x", colors.accent.r*255, colors.accent.g*255, colors.accent.b*255)
        self.activeNeighborhoodText:SetText("|cFF" .. accentHex .. (activeName or "Unknown") .. "|r")
    end

    -- Listen for activity log updates (refresh contribution)
    HC.EventBus:Register("HC_ACTIVITY_LOG_UPDATED", function(payload)
        local debug = HC.Store:GetState().config.debug
        if debug then
            print("|cFF00ffff[VE MainFrame]|r HC_ACTIVITY_LOG_UPDATED received, frame visible:", frame:IsVisible())
        end
        -- Refresh contribution display (calculated from activity log)
        if frame.UpdateHeader then
            frame:UpdateHeader()
            if debug then
                local houseXP = HC.EndeavorTracker:GetCachedHouseXP()
                print(string.format("|cFF00ffff[VE MainFrame]|r UpdateHeader called, houseXP cache: %.1f, display: %s",
                    houseXP, frame.houseXpText and frame.houseXpText:GetText() or "nil"))
            end
        end
    end)

    -- Listen for house list updates
    HC.EventBus:Register("HC_HOUSE_LIST_UPDATED", function(payload)
        if frame.UpdateHouseDropdown and payload then
            frame:UpdateHouseDropdown(payload.houseList, payload.selectedIndex)
        end
        if frame.UpdateActiveNeighborhood then
            frame:UpdateActiveNeighborhood()
        end
    end)

    -- Listen for active neighborhood changes (from VE button or Blizzard's dashboard)
    HC.EventBus:Register("HC_ACTIHC_NEIGHBORHOOD_CHANGED", function()
        if frame.UpdateActiveNeighborhood then
            frame:UpdateActiveNeighborhood()
        end
        -- Also refresh header (XP/contribution display) when active house changes
        if frame.UpdateHeader then
            frame:UpdateHeader()
        end
    end)

    -- Request fresh data on show
    frame:HookScript("OnShow", function()
        -- Immediately update UI from current state (in case updates happened while hidden)
        frame:UpdateHousingDisplay()
        frame:UpdateHeader()

        -- Request fresh housing data via HousingTracker module
        -- Use levelOnly=true if we have a cached houseGUID to avoid stale house list race condition
        if HC.HousingTracker then
            local hasHouseGUID = HC.Store:GetState().housing.houseGUID ~= nil
            HC.HousingTracker:RequestHouseInfo(hasHouseGUID)  -- levelOnly if we have a cached house
            HC.HousingTracker:UpdateCoupons()
        end
        -- Refresh activity log cache on window open (controlled trigger for performance)
        if HC.EndeavorTracker then
            HC.EndeavorTracker:RefreshActivityLogCache()
            HC.EndeavorTracker:QueueDataRefresh()
        end
        -- Update house dropdown
        if HC.EndeavorTracker then
            frame:UpdateHouseDropdown(HC.EndeavorTracker:GetHouseList(), HC.EndeavorTracker:GetSelectedHouseIndex())
        end
        -- Update active neighborhood display
        frame:UpdateActiveNeighborhood()
    end)

    -- Hide tooltip on hide
    frame:HookScript("OnHide", function()
        if GameTooltip:IsOwned(frame) then
            GameTooltip:Hide()
        end
    end)

    -- Update header function
    function frame:UpdateHeader()
        local state = HC.Store:GetState()

        self.seasonName:SetText(state.endeavor.seasonName or "Housing Endeavors")

        if state.endeavor.daysRemaining and state.endeavor.daysRemaining > 0 then
            self.daysRemaining:SetText(state.endeavor.daysRemaining .. " Days Remaining")
        else
            self.daysRemaining:SetText("")
        end

        -- Set final reward texture from last milestone (for maxed display)
        local milestones = state.endeavor.milestones
        if milestones and #milestones > 0 then
            local finalMilestone = milestones[#milestones]
            if finalMilestone.rewards and finalMilestone.rewards[1] then
                self.progressBar:SetFinalReward(finalMilestone.rewards[1].rewardQuestID)
            end
        end

        self.progressBar:SetProgress(
            state.endeavor.currentProgress or 0,
            state.endeavor.maxProgress or 100
        )
        self.progressBar:SetMilestones(
            milestones,
            state.endeavor.maxProgress or 100
        )

        -- Update contribution display (from pre-calculated cache - instant lookup)
        local playerContribution = HC.EndeavorTracker:GetCachedPlayerContribution()
        self.xpValue:SetText(string.format("%.1f", playerContribution))

        -- Dim contribution when initiative progress is maxed (no more contribution possible)
        local colors = HC.Constants:GetThemeColors()
        local currentProgress = state.endeavor.currentProgress or 0
        local maxProgress = state.endeavor.maxProgress or 100
        if maxProgress > 0 and currentProgress >= maxProgress then
            self.xpValue:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            self.xpValue._colorType = "text_dim"
            self.contribIcon:SetAlpha(0.4)
        else
            self.xpValue:SetTextColor(colors.endeavor.r, colors.endeavor.g, colors.endeavor.b)
            self.xpValue._colorType = "endeavor"
            self.contribIcon:SetAlpha(1.0)
        end

        -- House XP from pre-calculated cache (instant lookup, no iteration)
        local houseXpEarned, breakdown = HC.EndeavorTracker:GetCachedHouseXP()
        self.houseXpText:SetText(string.format("%.1f", houseXpEarned))
        self.houseXpBreakdown = breakdown  -- Store for tooltip

        -- Grey out only if cumulative XP has hit the endeavor cap (2250)
        local cumulative = breakdown and (breakdown.preCapped + breakdown.post) or 0
        local postCapped = cumulative >= (breakdown and breakdown.postCap or 2250)
        if postCapped then
            self.houseXpText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            self.houseXpText._colorType = "text_dim"
            self.houseXpCapped = true
        else
            self.houseXpText:SetTextColor(colors.endeavor.r, colors.endeavor.g, colors.endeavor.b)
            self.houseXpText._colorType = "endeavor"
            self.houseXpCapped = false
        end
    end

    -- ========================================================================
    -- CONTENT CONTAINER (collapsible)
    -- ========================================================================

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -UI.headerContentOffset)
    content:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.content = content

    -- ========================================================================
    -- MINIMIZED FAVOURITES PANEL
    -- ========================================================================

    local miniFavPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    miniFavPanel:SetPoint("TOPLEFT", 0, -UI.headerContentOffset)
    miniFavPanel:SetPoint("RIGHT", 0, 0)
    miniFavPanel:SetHeight(1)  -- Dynamic height based on favourites
    miniFavPanel:Hide()
    frame.miniFavPanel = miniFavPanel

    -- Pool of mini task rows (reuse to avoid allocations)
    local miniRowPool = {}
    local MAX_MINI_ROWS = 5
    local MINI_ROW_HEIGHT = 22

    -- Create mini rows upfront
    for i = 1, MAX_MINI_ROWS do
        local row = CreateFrame("Button", nil, miniFavPanel, "BackdropTemplate")
        row:SetHeight(MINI_ROW_HEIGHT)
        row:SetBackdrop(HC.Theme.BACKDROP_BORDERLESS)
        local colors = HC.Constants:GetThemeColors()
        row:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.5)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Status icon
        local status = row:CreateTexture(nil, "ARTWORK")
        status:SetSize(12, 12)
        status:SetPoint("LEFT", 4, 0)
        status:SetTexture("Interface\\COMMON\\Indicator-Gray")
        row.status = status

        -- Task name
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", status, "RIGHT", 4, 0)
        name:SetPoint("RIGHT", -50, 0)
        name:SetJustifyH("LEFT")
        HC.Theme.ApplyFont(name, colors, "small")
        name:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        row.name = name

        -- Progress text
        local progress = row:CreateFontString(nil, "OVERLAY")
        progress:SetPoint("RIGHT", -4, 0)
        HC.Theme.ApplyFont(progress, colors, "small")
        progress:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
        row.progress = progress

        -- Star icon
        local star = row:CreateTexture(nil, "OVERLAY")
        star:SetSize(12, 12)
        star:SetPoint("RIGHT", progress, "LEFT", -4, 0)
        star:SetAtlas("ParagonReputation_Glow")
        star:SetVertexColor(1, 0.82, 0, 0.9)
        row.star = star

        -- Click to unfavourite
        row:SetScript("OnClick", function(self)
            if self.taskName and IsShiftKeyDown() then
                HC_DB.ui.favouriteTasks[self.taskName] = nil
                HC.EventBus:Trigger("HC_FAVOURITES_CHANGED")
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            end
        end)

        row:SetScript("OnEnter", function(self)
            local c = HC.Constants:GetThemeColors()
            self:SetBackdropColor(c.button_hover.r, c.button_hover.g, c.button_hover.b, c.button_hover.a * 0.3)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.taskName or "Task", 1, 1, 1)
            GameTooltip:AddLine("Shift-click to unfavourite", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            local c = HC.Constants:GetThemeColors()
            self:SetBackdropColor(c.panel.r, c.panel.g, c.panel.b, c.panel.a * 0.5)
            GameTooltip:Hide()
        end)

        row:Hide()
        miniRowPool[i] = row
    end

    -- Empty state message for mini panel
    local emptyText = miniFavPanel:CreateFontString(nil, "OVERLAY")
    emptyText:SetPoint("CENTER", miniFavPanel, "CENTER", 0, 0)
    local colors = HC.Constants:GetThemeColors()
    HC.Theme.ApplyFont(emptyText, colors, "small")
    emptyText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
    emptyText:SetText("Shift-click tasks to add favourites")
    emptyText:Hide()
    miniFavPanel.emptyText = emptyText

    -- Update mini favourites panel
    function frame:UpdateMiniFavourites()
        HC_DB = HC_DB or {}
        HC_DB.ui = HC_DB.ui or {}
        HC_DB.ui.favouriteTasks = HC_DB.ui.favouriteTasks or {}

        local state = HC.Store:GetState()
        local tasks = state.tasks or {}
        local colors = HC.Constants:GetThemeColors()

        -- Build list of favourite tasks (match by name)
        local favTasks = {}
        for _, task in ipairs(tasks) do
            if HC_DB.ui.favouriteTasks[task.name] then
                table.insert(favTasks, task)
                if #favTasks >= MAX_MINI_ROWS then break end
            end
        end

        -- Hide all rows first
        for i = 1, MAX_MINI_ROWS do
            miniRowPool[i]:Hide()
        end

        -- Populate rows
        local yOffset = 0
        for i, task in ipairs(favTasks) do
            local row = miniRowPool[i]
            row.taskName = task.name
            row.name:SetText(task.name)

            -- Status indicator
            if task.completed then
                row.status:SetTexture("Interface\\COMMON\\Indicator-Green")
                row.name:SetTextColor(colors.success.r, colors.success.g, colors.success.b)
                row.progress:SetText("Done")
                row.progress:SetTextColor(colors.success.r, colors.success.g, colors.success.b)
            else
                row.status:SetTexture("Interface\\COMMON\\Indicator-Gray")
                row.name:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
                if task.max and task.max > 1 then
                    row.progress:SetText(string.format("%d/%d", task.current or 0, task.max))
                else
                    row.progress:SetText("")
                end
                row.progress:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            end

            row:SetPoint("TOPLEFT", miniFavPanel, "TOPLEFT", padding, -yOffset)
            row:SetPoint("TOPRIGHT", miniFavPanel, "TOPRIGHT", -padding, -yOffset)
            row:Show()
            yOffset = yOffset + MINI_ROW_HEIGHT + 2
        end

        -- Handle empty state
        if #favTasks == 0 then
            miniFavPanel.emptyText:Show()
            miniFavPanel:SetHeight(24)
        else
            miniFavPanel.emptyText:Hide()
            miniFavPanel:SetHeight(yOffset + 4)
        end

        return #favTasks
    end

    -- Listen for favourites changes
    HC.EventBus:Register("HC_FAVOURITES_CHANGED", function()
        if frame.isMinimized then
            frame:UpdateMiniFavourites()
            -- Minimized base height: title bar + progress bar + stats row + padding
            local miniBaseHeight = UI.titleBarHeight + UI.progressBarHeight + 16 + 14
            frame:SetHeight(miniBaseHeight + miniFavPanel:GetHeight())
        end
        -- Also refresh full UI if visible
        if frame.endeavorsTab and frame.endeavorsTab:IsShown() then
            HC:RefreshUI()
        end
    end)

    -- ========================================================================
    -- TAB PANELS
    -- ========================================================================

    -- Endeavors tab (main view)
    local endeavorsTab = HC.UI.Tabs:CreateEndeavors(content)
    endeavorsTab:SetAllPoints()
    frame.endeavorsTab = endeavorsTab

    -- Leaderboard tab
    local leaderboardTab = HC.UI.Tabs:CreateLeaderboard(content)
    leaderboardTab:SetAllPoints()
    leaderboardTab:Hide()
    frame.leaderboardTab = leaderboardTab

    -- Activity tab
    local activityTab = HC.UI.Tabs:CreateActivity(content)
    activityTab:SetAllPoints()
    activityTab:Hide()
    frame.activityTab = activityTab

    -- Config tab (settings)
    local configTab = HC.UI.Tabs:CreateConfig(content)
    configTab:SetAllPoints()
    configTab:Hide()
    frame.configTab = configTab

    -- Info tab (initiative collection)
    local infoTab = HC.UI.Tabs:CreateInfo(content)
    infoTab:SetAllPoints()
    infoTab:Hide()
    frame.infoTab = infoTab

    -- Rewards tab (NEW - HomeBound)
    local rewardsTab = HC.UI.Tabs:CreateRewards(content)
    rewardsTab:SetAllPoints()
    rewardsTab:Hide()
    frame.rewardsTab = rewardsTab

    -- Vendors tab (NEW - DecorVendor)
    local vendorsTab = HC.UI.Tabs:CreateVendors(content)
    vendorsTab:SetAllPoints()
    vendorsTab:Hide()
    frame.vendorsTab = vendorsTab

    -- Reputations tab (NEW - Housing Reputations)
    local reputationsTab = HC.UI.Tabs:CreateReputations(content)
    reputationsTab:SetAllPoints()
    reputationsTab:Hide()
    frame.reputationsTab = reputationsTab

    -- ========================================================================
    -- TAB SWITCHING
    -- ========================================================================

    local function ShowTab(tabName)
        -- Hide all tabs
        endeavorsTab:Hide()
        rewardsTab:Hide()
        vendorsTab:Hide()
        reputationsTab:Hide()
        leaderboardTab:Hide()
        activityTab:Hide()
        infoTab:Hide()
        configTab:Hide()

        -- Deactivate all buttons
        endeavorsTabBtn:SetActive(false)
        rewardsTabBtn:SetActive(false)
        vendorsTabBtn:SetActive(false)
        reputationsTabBtn:SetActive(false)
        leaderboardTabBtn:SetActive(false)
        activityTabBtn:SetActive(false)
        infoTabBtn:SetActive(false)
        configTabBtn:SetActive(false)

        -- Show selected tab
        if tabName == "endeavors" then
            endeavorsTab:Show()
            endeavorsTabBtn:SetActive(true)
            HC:RefreshUI()
        elseif tabName == "rewards" then
            rewardsTab:Show()
            rewardsTabBtn:SetActive(true)
        elseif tabName == "vendors" then
            vendorsTab:Show()
            vendorsTabBtn:SetActive(true)
        elseif tabName == "reputations" then
            reputationsTab:Show()
            reputationsTabBtn:SetActive(true)
        elseif tabName == "leaderboard" then
            leaderboardTab:Show()
            leaderboardTabBtn:SetActive(true)
        elseif tabName == "activity" then
            activityTab:Show()
            activityTabBtn:SetActive(true)
        elseif tabName == "info" then
            infoTab:Show()
            infoTabBtn:SetActive(true)
        elseif tabName == "config" then
            configTab:Show()
            configTabBtn:SetActive(true)
        end
    end

    endeavorsTabBtn:SetScript("OnClick", function()
        ShowTab("endeavors")
    end)

    rewardsTabBtn:SetScript("OnClick", function()
        ShowTab("rewards")
    end)

    vendorsTabBtn:SetScript("OnClick", function()
        ShowTab("vendors")
    end)

    reputationsTabBtn:SetScript("OnClick", function()
        ShowTab("reputations")
    end)

    leaderboardTabBtn:SetScript("OnClick", function()
        ShowTab("leaderboard")
    end)

    activityTabBtn:SetScript("OnClick", function()
        ShowTab("activity")
    end)

    infoTabBtn:SetScript("OnClick", function()
        ShowTab("info")
    end)

    configTabBtn:SetScript("OnClick", function()
        ShowTab("config")
    end)

    -- Default to endeavors tab
    ShowTab("endeavors")

    -- Initial updates
    frame:UpdateHousingDisplay()
    frame:UpdateHeader()

    frame.ShowTab = ShowTab

    self.MainFrame = frame

    -- Listen for state changes to refresh UI (updates even when hidden so data is fresh on show)
    HC.EventBus:Register("HC_STATE_CHANGED", function(payload)
        -- Always update housing display on housing state changes
        if payload.action == "SET_HOUSE_LEVEL" or payload.action == "SET_COUPONS" then
            frame:UpdateHousingDisplay()
        end

        -- Update header (progress bar) when endeavor info changes
        if payload.action == "SET_ENDEAVOR_INFO" or payload.action == "SET_TASKS" then
            frame:UpdateHeader()
        end

        -- Update squirrel mascot visibility when config changes
        if payload.action == "SET_CONFIG" then
            frame:UpdateSquirrelMascot()
        end

        -- Refresh endeavors tab only if visible (heavy operation)
        if frame.endeavorsTab:IsShown() then
            HC:RefreshUI()
        end

        -- Update mini favourites when tasks change while minimized
        if payload.action == "SET_TASKS" and frame.isMinimized then
            frame:UpdateMiniFavourites()
        end
    end)

    -- Listen for theme updates
    -- Note: Most theming is handled by Theme Engine via registered widgets
    -- We only need to update houseLevelText here because it uses inline color codes
    HC.EventBus:Register("HC_THEME_UPDATE", function()
        local colors = HC.Constants:GetThemeColors()
        HC.Theme.ApplyFont(frame.houseLevelText, colors, "small")
        frame:UpdateHousingDisplay()
        -- Refresh active neighborhood text (uses inline color codes)
        if frame.UpdateActiveNeighborhood then
            frame:UpdateActiveNeighborhood()
        end

        -- Resize tabs based on theme (housing = full-width, others = text-fit)
        local housingTheme = colors.atlas and colors.atlas.tabSectionBg
        local fullTabWidth = housingTheme and ((uiConsts.mainWidth / 5) + 8) or nil
        local spacing = housingTheme and -10 or 2
        local padding = 16

        local tabs = { frame.endeavorsTabBtn, frame.leaderboardTabBtn, frame.activityTabBtn, frame.infoTabBtn, frame.configTabBtn }
        for i, tab in ipairs(tabs) do
            if fullTabWidth then
                tab:SetWidth(fullTabWidth)
            elseif tab.label then
                tab:SetWidth((tab.label:GetStringWidth() or 50) + padding)
            end
            -- Update spacing (skip first tab)
            if i > 1 then
                tab:SetPoint("LEFT", tabs[i-1], "RIGHT", spacing, 0)
            end
        end
    end)

    -- Listen for UI scale changes
    HC.EventBus:Register("HC_UI_SCALE_UPDATE", function()
        local scale = HC.Store:GetState().config.uiScale or 1.0
        frame:SetScale(scale)
    end)

    -- Hook minimize button to show/hide favourites panel and compact header
    if frame.minimizeBtn then
        frame.minimizeBtn:HookScript("OnClick", function()
            if frame.isMinimized then
                -- Hide header elements (keep progress bar and stats row)
                frame.seasonName:Hide()
                frame.daysRemaining:Hide()
                frame.dropdownRow:Hide()
                frame.activeContainer:Hide()
                -- Reposition progress bar directly under title bar
                frame.progressBar:ClearAllPoints()
                frame.progressBar:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -(UI.titleBarHeight + 4))
                frame.progressBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -(UI.titleBarHeight + 4))
                -- Reposition stats row below progress bar
                frame.statsRow:ClearAllPoints()
                frame.statsRow:SetPoint("TOPLEFT", frame.progressBar, "BOTTOMLEFT", 0, -4)
                frame.statsRow:SetPoint("TOPRIGHT", frame.progressBar, "BOTTOMRIGHT", 0, -4)
                -- Minimized base height: title bar + progress bar + stats row + padding
                local miniBaseHeight = UI.titleBarHeight + UI.progressBarHeight + 16 + 14
                -- Position mini favourites below stats row
                frame.miniFavPanel:ClearAllPoints()
                frame.miniFavPanel:SetPoint("TOPLEFT", frame.statsRow, "BOTTOMLEFT", 0, -4)
                frame.miniFavPanel:SetPoint("RIGHT", frame, "RIGHT", -padding, 0)
                -- Update and show favourites (always show panel for empty state message)
                frame:UpdateMiniFavourites()
                frame.miniFavPanel:Show()
                frame:SetHeight(miniBaseHeight + frame.miniFavPanel:GetHeight())
            else
                -- Restore header elements
                frame.seasonName:Show()
                frame.daysRemaining:Show()
                frame.dropdownRow:Show()
                frame.activeContainer:Show()
                -- Restore progress bar position
                frame.progressBar:ClearAllPoints()
                frame.progressBar:SetPoint("TOPLEFT", frame.seasonName, "BOTTOMLEFT", 0, -4)
                frame.progressBar:SetPoint("TOPRIGHT", frame.headerSection, "TOPRIGHT", 0, 0)
                -- Restore stats row position
                frame.statsRow:ClearAllPoints()
                frame.statsRow:SetPoint("TOPLEFT", frame.dropdownRow, "BOTTOMLEFT", -4, -2)
                frame.statsRow:SetPoint("TOPRIGHT", frame.dropdownRow, "BOTTOMRIGHT", -4, -2)
                -- Restore mini fav panel position
                frame.miniFavPanel:ClearAllPoints()
                frame.miniFavPanel:SetPoint("TOPLEFT", 0, -UI.headerContentOffset)
                frame.miniFavPanel:SetPoint("RIGHT", 0, 0)
                -- Hide mini favourites when expanded
                frame.miniFavPanel:Hide()
            end
        end)
    end

    return frame
end
