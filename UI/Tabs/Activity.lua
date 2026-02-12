-- ============================================================================
-- Vamoose's Endeavors - Activity Tab
-- Shows top 5 activities and recent activity feed
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

-- Helper to get current theme colors
local function GetColors()
    return HC.Constants:GetThemeColors()
end

function HC.UI.Tabs:CreateActivity(parent)
    local UI = HC.Constants.UI

    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local padding = 0  -- Container edge padding (0 for full-bleed atlas backgrounds)

    -- ========================================================================
    -- TOP ACTIVITIES SECTION
    -- ========================================================================

    local topHeader = HC.UI:CreateSectionHeader(container, "Top 5 Tasks")
    topHeader:SetPoint("TOPLEFT", 0, UI.sectionHeaderYOffset)
    topHeader:SetPoint("TOPRIGHT", 0, UI.sectionHeaderYOffset)

    -- Refresh button (left side of header)
    local refreshBtn = CreateFrame("Button", nil, topHeader)
    refreshBtn:SetSize(16, 16)
    refreshBtn:SetPoint("LEFT", topHeader, "LEFT", 8, 0)

    local refreshIcon = refreshBtn:CreateTexture(nil, "ARTWORK")
    refreshIcon:SetAllPoints()
    refreshIcon:SetAtlas("UI-RefreshButton")
    refreshIcon:SetAlpha(0.6)
    refreshBtn.icon = refreshIcon

    -- Timestamp (right of refresh button)
    local refreshColors = HC.Constants:GetThemeColors()
    local lastUpdateText = topHeader:CreateFontString(nil, "OVERLAY")
    lastUpdateText:SetPoint("LEFT", refreshBtn, "RIGHT", 4, 0)
    HC.Theme.ApplyFont(lastUpdateText, refreshColors, "tiny")
    lastUpdateText:SetText("--:--")
    lastUpdateText:SetTextColor(refreshColors.text_dim.r, refreshColors.text_dim.g, refreshColors.text_dim.b, 0.7)
    container.lastUpdateText = lastUpdateText

    refreshBtn:SetScript("OnEnter", function(self)
        refreshIcon:SetAlpha(1.0)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Refresh Activity Log", 1, 1, 1)
        local stale = HC.EndeavorTracker and HC.EndeavorTracker.activityLogStale
        if stale then
            GameTooltip:AddLine("New data available", 0.2, 0.8, 0.2)
        else
            GameTooltip:AddLine("Click to fetch latest data", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)

    refreshBtn:SetScript("OnLeave", function()
        refreshIcon:SetAlpha(0.6)
        GameTooltip_Hide()
    end)

    refreshBtn:SetScript("OnClick", function()
        if HC.EndeavorTracker then
            HC.EndeavorTracker:RefreshActivityLogCache()
        end
    end)

    -- Update timestamp when activity log refreshes
    HC.EventBus:Register("HC_ACTIVITY_LOG_UPDATED", function()
        lastUpdateText:SetText(date("%H:%M"))
    end)

    local topContainer = CreateFrame("Frame", nil, container, "BackdropTemplate")
    topContainer:SetPoint("TOPLEFT", topHeader, "BOTTOMLEFT", 0, 0)
    topContainer:SetPoint("TOPRIGHT", topHeader, "BOTTOMRIGHT", 0, 0)
    topContainer:SetHeight(130) -- 5 rows x 24 + padding
    topContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    container.topContainer = topContainer

    -- Atlas background support
    local ApplyTopContainerColors = HC.UI:AddAtlasBackground(topContainer)

    -- ========================================================================
    -- ACTIVITY FEED SECTION
    -- ========================================================================

    local feedHeader = HC.UI:CreateSectionHeader(container, "Recent Activity")
    feedHeader:SetPoint("TOPLEFT", topContainer, "BOTTOMLEFT", 0, 0)
    feedHeader:SetPoint("TOPRIGHT", topContainer, "BOTTOMRIGHT", 0, 0)

    -- Decimal precision control (1-3)
    container.decimalPrecision = 1

    -- Filter state
    container.filterMeOnly = false
    container.filterMyChars = false  -- Filter for all player's known characters
    container.filterTaskName = nil  -- nil = "All Tasks"
    container.uniqueTaskNames = {}  -- Populated during update

    -- "Me Only" filter toggle (icon button)
    local meOnlyBtn = CreateFrame("Button", nil, feedHeader, "BackdropTemplate")
    meOnlyBtn:SetSize(18, 14)
    meOnlyBtn:SetPoint("LEFT", feedHeader, "LEFT", 8, 0)
    meOnlyBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local C = GetColors()
    meOnlyBtn:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.8)
    meOnlyBtn:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.5)

    local meOnlyIcon = meOnlyBtn:CreateTexture(nil, "ARTWORK")
    meOnlyIcon:SetSize(12, 12)
    meOnlyIcon:SetPoint("CENTER", 0, 0)
    meOnlyIcon:SetAtlas("housefinder_neighborhood-list-friend-icon")
    meOnlyIcon:SetDesaturated(true)
    meOnlyIcon:SetAlpha(0.5)
    meOnlyBtn.icon = meOnlyIcon

    function meOnlyBtn:UpdateAppearance()
        local colors = GetColors()
        if container.filterMeOnly then
            self:SetBackdropColor(colors.success.r, colors.success.g, colors.success.b, 0.4)
            self:SetBackdropBorderColor(colors.success.r, colors.success.g, colors.success.b, 0.8)
            self.icon:SetDesaturated(false)
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.8)
            self:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 0.5)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.5)
        end
    end

    meOnlyBtn:SetScript("OnClick", function()
        container.filterMeOnly = not container.filterMeOnly
        meOnlyBtn:UpdateAppearance()
        container:Update(true)
    end)
    meOnlyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Filter: Current Character Only")
        GameTooltip:AddLine(container.filterMeOnly and "Click to show all players" or "Click to show only your activities", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    meOnlyBtn:SetScript("OnLeave", GameTooltip_Hide)
    container.meOnlyBtn = meOnlyBtn

    -- "My Chars" filter toggle (all player's alts)
    local myCharsBtn = CreateFrame("Button", nil, feedHeader, "BackdropTemplate")
    myCharsBtn:SetSize(18, 14)
    myCharsBtn:SetPoint("LEFT", meOnlyBtn, "RIGHT", 2, 0)
    myCharsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    myCharsBtn:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.8)
    myCharsBtn:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.5)

    local myCharsIcon = myCharsBtn:CreateTexture(nil, "ARTWORK")
    myCharsIcon:SetSize(12, 12)
    myCharsIcon:SetPoint("CENTER", 0, 0)
    myCharsIcon:SetAtlas("housefinder_neighborhood-friends-icon")
    myCharsIcon:SetDesaturated(true)
    myCharsIcon:SetAlpha(0.5)
    myCharsBtn.icon = myCharsIcon

    function myCharsBtn:UpdateAppearance()
        local colors = GetColors()
        if container.filterMyChars then
            self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.4)
            self:SetBackdropBorderColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.8)
            self.icon:SetDesaturated(false)
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.8)
            self:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 0.5)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.5)
        end
    end

    myCharsBtn:SetScript("OnClick", function()
        container.filterMyChars = not container.filterMyChars
        -- Disable "Me Only" if "My Chars" is enabled (mutually exclusive)
        if container.filterMyChars then
            container.filterMeOnly = false
            meOnlyBtn:UpdateAppearance()
        end
        myCharsBtn:UpdateAppearance()
        container:Update(true)
    end)
    myCharsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Filter: My Characters")
        GameTooltip:AddLine(container.filterMyChars and "Click to show all players" or "Click to show only your alts", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    myCharsBtn:SetScript("OnLeave", GameTooltip_Hide)
    container.myCharsBtn = myCharsBtn

    -- Export to CSV button
    local exportBtn = CreateFrame("Button", nil, feedHeader)
    exportBtn:SetSize(14, 14)
    exportBtn:SetPoint("LEFT", myCharsBtn, "RIGHT", 4, 0)
    local exportIcon = exportBtn:CreateTexture(nil, "ARTWORK")
    exportIcon:SetAllPoints()
    exportIcon:SetAtlas("communities-icon-searchmagnifyingglass")
    exportIcon:SetVertexColor(0.85, 0.85, 0.85)
    exportBtn.icon = exportIcon
    exportBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Export to CSV")
        GameTooltip:AddLine("Click to view activity data in CSV format", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.85, 0.85, 0.85)
        GameTooltip_Hide()
    end)
    exportBtn:SetScript("OnClick", function()
        local activityData = HC.EndeavorTracker:GetActivityLogData()
        if not activityData or not activityData.taskActivity or #activityData.taskActivity == 0 then
            print("|cffff9900VE:|r No activity data to export.")
            return
        end
        -- Build taskID -> isRepeatable lookup from Store
        local repeatableLookup = {}
        local tasks = HC.Store:GetState().tasks or {}
        for _, t in ipairs(tasks) do
            if t.id then repeatableLookup[t.id] = t.isRepeatable end
        end
        -- Build CSV string with all available API fields (matches Blizzard API names)
        local csv = "playerName,taskName,taskID,amount,completionTime,timestamp,Repeatable\n"
        for _, entry in ipairs(activityData.taskActivity) do
            local player = entry.playerName or "Unknown"
            local task = entry.taskName or "Unknown"
            local taskID = entry.taskID or 0
            local xp = entry.amount or 0
            local timestamp = entry.completionTime or 0
            local timeStr = ""
            if timestamp > 0 then
                timeStr = date("%Y-%m-%d %H:%M:%S", timestamp)
            end
            -- Escape commas in task names
            task = task:gsub(",", ";")
            local repeatable = repeatableLookup[entry.taskID] and "Yes" or "No"
            csv = csv .. string.format("%s,%s,%d,%.3f,%s,%d,%s\n", player, task, taskID, xp, timeStr, timestamp, repeatable)
        end
        -- Show in popup window
        HC.UI:ShowCSVExportWindow(csv, #activityData.taskActivity)
    end)
    container.exportBtn = exportBtn

    -- Coupon view toggle button (uses currency texture)
    container.showCouponView = false
    local couponBtn = CreateFrame("Button", nil, feedHeader, "BackdropTemplate")
    couponBtn:SetSize(18, 14)
    couponBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    couponBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    couponBtn:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.8)
    couponBtn:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.5)

    -- Get currency texture for Community Coupons
    local couponIcon = couponBtn:CreateTexture(nil, "ARTWORK")
    couponIcon:SetSize(12, 12)
    couponIcon:SetPoint("CENTER", 0, 0)
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(HC.Constants.CURRENCY_IDS.COMMUNITY_COUPONS or 3363)
    if currencyInfo and currencyInfo.iconFileID then
        couponIcon:SetTexture(currencyInfo.iconFileID)
    else
        couponIcon:SetAtlas("legionarmy-circle-button")  -- Fallback
    end
    couponIcon:SetDesaturated(true)
    couponIcon:SetAlpha(0.5)
    couponBtn.icon = couponIcon

    function couponBtn:UpdateAppearance()
        local colors = GetColors()
        -- Use cyan for coupons (fallback to accent if not defined)
        local couponColor = colors.coupon or {r=0.16, g=0.63, b=0.60, a=1}  -- Cyan fallback
        if container.showCouponView then
            self:SetBackdropColor(couponColor.r, couponColor.g, couponColor.b, 0.4)
            self:SetBackdropBorderColor(couponColor.r, couponColor.g, couponColor.b, 0.8)
            self.icon:SetDesaturated(false)
            self.icon:SetAlpha(1)
        else
            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.8)
            self:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 0.5)
            self.icon:SetDesaturated(true)
            self.icon:SetAlpha(0.5)
        end
    end

    couponBtn:SetScript("OnClick", function()
        container.showCouponView = not container.showCouponView
        couponBtn:UpdateAppearance()
        container:Update(true)
    end)
    couponBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Toggle: Coupon Earnings")
        local gainCount = HC_DB and HC_DB.couponGains and #HC_DB.couponGains or 0
        GameTooltip:AddLine(container.showCouponView
            and "Click to show activity log"
            or ("Click to show coupon earnings (" .. gainCount .. " tracked)"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    couponBtn:SetScript("OnLeave", GameTooltip_Hide)
    container.couponBtn = couponBtn

    -- Update meOnlyBtn to disable myChars when enabled
    meOnlyBtn:SetScript("OnClick", function()
        container.filterMeOnly = not container.filterMeOnly
        -- Disable "My Chars" if "Me Only" is enabled (mutually exclusive)
        if container.filterMeOnly then
            container.filterMyChars = false
            myCharsBtn:UpdateAppearance()
        end
        meOnlyBtn:UpdateAppearance()
        container:Update(true)
    end)

    -- Task filter dropdown button (right side of header)
    local taskFilterBtn = CreateFrame("Button", nil, feedHeader, "BackdropTemplate")
    taskFilterBtn:SetSize(90, 14)
    taskFilterBtn:SetPoint("RIGHT", feedHeader, "RIGHT", -30, 1)
    taskFilterBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    taskFilterBtn:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.8)
    taskFilterBtn:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.5)

    local taskFilterText = taskFilterBtn:CreateFontString(nil, "OVERLAY")
    taskFilterText:SetPoint("LEFT", 4, 0)
    taskFilterText:SetPoint("RIGHT", -12, 0)
    taskFilterText:SetJustifyH("LEFT")
    taskFilterText:SetWordWrap(false)
    HC.Theme.ApplyFont(taskFilterText, C)  -- Apply font before SetText
    taskFilterText:SetText("All Tasks")
    taskFilterText:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
    taskFilterBtn.text = taskFilterText

    local taskFilterArrow = taskFilterBtn:CreateTexture(nil, "OVERLAY")
    taskFilterArrow:SetSize(8, 8)
    taskFilterArrow:SetPoint("RIGHT", -2, 0)
    taskFilterArrow:SetAtlas("housing-stair-arrow-down-default")
    taskFilterBtn.arrow = taskFilterArrow

    function taskFilterBtn:UpdateAppearance()
        local colors = GetColors()
        if container.filterTaskName then
            self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.3)
            self:SetBackdropBorderColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.8)
            self.text:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
            -- Truncate long task names
            local displayName = container.filterTaskName or ""
            if #displayName > 12 then
                displayName = string.sub(displayName, 1, 11) .. "…"
            end
            self.text:SetText(displayName)
        else
            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.8)
            self:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 0.5)
            self.text:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            self.text:SetText("All Tasks")
        end
        HC.Theme.ApplyFont(self.text, colors)
    end

    -- Task filter dropdown menu
    local taskDropdown = CreateFrame("Frame", "HC_TaskFilterDropdown", taskFilterBtn, "BackdropTemplate")
    taskDropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    taskDropdown:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.95)
    taskDropdown:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
    taskDropdown:SetFrameStrata("DIALOG")
    taskDropdown:SetPoint("TOPLEFT", taskFilterBtn, "BOTTOMLEFT", 0, -2)
    taskDropdown:SetSize(180, 100)
    taskDropdown:Hide()
    taskDropdown.items = {}
    container.taskDropdown = taskDropdown

    local function BuildTaskDropdown()
        local colors = GetColors()
        -- Hide existing items
        for _, item in ipairs(taskDropdown.items) do
            item:Hide()
        end

        -- Build list: "All Tasks" + unique task names
        local tasks = { { name = nil, display = "All Tasks" } }
        for _, taskName in ipairs(container.uniqueTaskNames) do
            table.insert(tasks, { name = taskName, display = taskName })
        end

        local yOffset = 2
        local itemHeight = 16
        for i, taskData in ipairs(tasks) do
            local item = taskDropdown.items[i]
            if not item then
                item = CreateFrame("Button", nil, taskDropdown, "BackdropTemplate")
                item:SetHeight(itemHeight)
                item:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                item:SetBackdropColor(0, 0, 0, 0)
                local itemText = item:CreateFontString(nil, "OVERLAY")
                itemText:SetPoint("LEFT", 4, 0)
                itemText:SetPoint("RIGHT", -4, 0)
                itemText:SetJustifyH("LEFT")
                itemText:SetWordWrap(false)
                item.text = itemText
                item:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.3)
                end)
                item:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(0, 0, 0, 0)
                end)
                taskDropdown.items[i] = item
            end

            item:SetPoint("TOPLEFT", 2, -yOffset)
            item:SetPoint("TOPRIGHT", -2, -yOffset)
            HC.Theme.ApplyFont(item.text, colors)  -- Apply font before SetText
            item.text:SetText(taskData.display)

            if taskData.name == container.filterTaskName then
                item.text:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
            else
                item.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
            end

            item:SetScript("OnClick", function()
                container.filterTaskName = taskData.name
                taskFilterBtn:UpdateAppearance()
                taskDropdown:Hide()
                container:Update(true)
            end)
            item:Show()

            yOffset = yOffset + itemHeight
        end

        taskDropdown:SetHeight(yOffset + 4)
        taskDropdown:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.95)
        taskDropdown:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 1)
    end

    taskFilterBtn:SetScript("OnClick", function()
        if taskDropdown:IsShown() then
            taskDropdown:Hide()
        else
            BuildTaskDropdown()
            taskDropdown:Show()
        end
    end)
    taskFilterBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Filter: By Task Type")
        GameTooltip:AddLine("Click to select a specific task", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    taskFilterBtn:SetScript("OnLeave", GameTooltip_Hide)
    container.taskFilterBtn = taskFilterBtn

    -- Close dropdown when clicking elsewhere
    taskDropdown:SetScript("OnShow", function()
        taskDropdown:SetPropagateKeyboardInput(true)
    end)
    taskDropdown:SetScript("OnHide", function() end)

    -- Decrease decimals arrow (rotated left)
    local decArrow = CreateFrame("Button", nil, feedHeader)
    decArrow:SetSize(12, 12)
    decArrow:SetPoint("RIGHT", feedHeader, "RIGHT", -18, 0)
    local decTex = decArrow:CreateTexture(nil, "ARTWORK")
    decTex:SetAllPoints()
    decTex:SetAtlas("housing-floor-arrow-up-disabled")
    decTex:SetRotation(math.rad(90)) -- Rotate to point left
    decArrow.tex = decTex
    decArrow:SetScript("OnClick", function()
        if container.decimalPrecision > 1 then
            container.decimalPrecision = container.decimalPrecision - 1
            container:Update(true)
        end
    end)
    decArrow:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Decrease decimal places")
        GameTooltip:Show()
    end)
    decArrow:SetScript("OnLeave", function(self)
        self.tex:SetAlpha(0.7)
        GameTooltip:Hide()
    end)
    decTex:SetAlpha(0.7)

    -- Increase decimals arrow (rotated right)
    local incArrow = CreateFrame("Button", nil, feedHeader)
    incArrow:SetSize(12, 12)
    incArrow:SetPoint("RIGHT", feedHeader, "RIGHT", -4, 0)
    local incTex = incArrow:CreateTexture(nil, "ARTWORK")
    incTex:SetAllPoints()
    incTex:SetAtlas("housing-floor-arrow-up-disabled")
    incTex:SetRotation(math.rad(-90)) -- Rotate to point right
    incArrow.tex = incTex
    incArrow:SetScript("OnClick", function()
        if container.decimalPrecision < 3 then
            container.decimalPrecision = container.decimalPrecision + 1
            container:Update(true)
        end
    end)
    incArrow:SetScript("OnEnter", function(self)
        self.tex:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Increase decimal places")
        GameTooltip:Show()
    end)
    incArrow:SetScript("OnLeave", function(self)
        self.tex:SetAlpha(0.7)
        GameTooltip:Hide()
    end)
    incTex:SetAlpha(0.7)

    local feedContainer = CreateFrame("Frame", nil, container, "BackdropTemplate")
    feedContainer:SetPoint("TOPLEFT", feedHeader, "BOTTOMLEFT", 0, 0)
    feedContainer:SetPoint("BOTTOMRIGHT", -padding, padding)
    feedContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    container.feedContainer = feedContainer

    -- Atlas background support
    local ApplyFeedContainerColors = HC.UI:AddAtlasBackground(feedContainer)

    -- Apply container colors (both containers)
    local function ApplyContainerColors()
        ApplyTopContainerColors()
        ApplyFeedContainerColors()
    end
    ApplyContainerColors()

    local _, scrollContent = HC.UI:CreateScrollFrame(feedContainer)
    container.scrollContent = scrollContent

    -- Pool for top task rows
    container.topRows = {}

    -- Pool for feed rows
    container.feedRows = {}

    -- ========================================================================
    -- CREATE TOP TASK ROW
    -- ========================================================================

    local function CreateTopTaskRow(parentFrame)
        local C = GetColors()
        local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        row:SetHeight(24)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
        })
        row:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, C.panel.a * 0.5)

        -- Rank
        local rank = row:CreateFontString(nil, "OVERLAY")
        rank:SetPoint("LEFT", 8, 0)
        rank:SetWidth(24)
        rank:SetJustifyH("CENTER")
        rank:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        HC.Theme.ApplyFont(rank, C)
        row.rank = rank

        -- Task name
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", rank, "RIGHT", 8, 0)
        name:SetPoint("RIGHT", -80, 0)
        name:SetJustifyH("LEFT")
        name:SetTextColor(C.text.r, C.text.g, C.text.b)
        HC.Theme.ApplyFont(name, C)
        row.name = name

        -- Completion count
        local count = row:CreateFontString(nil, "OVERLAY")
        count:SetPoint("RIGHT", -8, 0)
        count:SetJustifyH("RIGHT")
        count:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
        HC.Theme.ApplyFont(count, C)
        row.count = count

        function row:SetData(rankNum, taskName, completions)
            local colors = GetColors()
            self.rank:SetText("#" .. rankNum)
            self.name:SetText(taskName)
            self.count:SetText(completions .. "x")

            if rankNum == 1 then
                self.rank:SetTextColor(colors.gold.r, colors.gold.g, colors.gold.b)
            elseif rankNum == 2 then
                self.rank:SetTextColor(colors.silver.r, colors.silver.g, colors.silver.b)
            elseif rankNum == 3 then
                self.rank:SetTextColor(colors.bronze.r, colors.bronze.g, colors.bronze.b)
            else
                self.rank:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            end
            HC.Theme.ApplyFont(self.rank, colors)

            self.name:SetTextColor(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
            HC.Theme.ApplyFont(self.name, colors)

            self.count:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a)
            HC.Theme.ApplyFont(self.count, colors)

            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.5)
        end

        return row
    end

    -- ========================================================================
    -- CREATE FEED ROW
    -- ========================================================================

    local function CreateFeedRow(parentFrame)
        local C = GetColors()
        local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        row:SetHeight(20)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
        })
        row:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, C.panel.a * 0.3)

        -- Time ago
        local timeText = row:CreateFontString(nil, "OVERLAY")
        timeText:SetPoint("LEFT", 6, 0)
        timeText:SetWidth(40)
        timeText:SetJustifyH("LEFT")
        timeText:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
        HC.Theme.ApplyFont(timeText, C)
        row.timeText = timeText

        -- Player name
        local playerName = row:CreateFontString(nil, "OVERLAY")
        playerName:SetPoint("LEFT", timeText, "RIGHT", 4, 0)
        playerName:SetWidth(70)
        playerName:SetJustifyH("LEFT")
        playerName:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
        HC.Theme.ApplyFont(playerName, C)
        row.playerName = playerName

        -- Task name
        local taskName = row:CreateFontString(nil, "OVERLAY")
        taskName:SetPoint("LEFT", playerName, "RIGHT", 4, 0)
        taskName:SetPoint("RIGHT", -40, 0)
        taskName:SetJustifyH("LEFT")
        taskName:SetTextColor(C.text.r, C.text.g, C.text.b)
        HC.Theme.ApplyFont(taskName, C)
        row.taskName = taskName

        -- Amount
        local amount = row:CreateFontString(nil, "OVERLAY")
        amount:SetPoint("RIGHT", -6, 0)
        amount:SetJustifyH("RIGHT")
        amount:SetTextColor(C.endeavor.r, C.endeavor.g, C.endeavor.b)
        HC.Theme.ApplyFont(amount, C)
        row.amount = amount

        function row:SetData(entry)
            local colors = GetColors()

            -- Format time ago
            local timeAgo = ""
            if entry.completionTime then
                local now = time()
                local diff = now - entry.completionTime
                if diff < 60 then
                    timeAgo = "<1m"
                elseif diff < 3600 then
                    timeAgo = math.floor(diff / 60) .. "m"
                elseif diff < 86400 then
                    timeAgo = math.floor(diff / 3600) .. "h"
                else
                    timeAgo = math.floor(diff / 86400) .. "d"
                end
            end

            self.timeText:SetText(timeAgo)
            self.playerName:SetText(entry.playerName or "Unknown")
            self.taskName:SetText(entry.taskName or "Unknown Task")
            local precision = container.decimalPrecision or 1
            self.amount:SetText(string.format("+%." .. precision .. "f", entry.amount or 0))

            -- Apply theme colors + fonts
            self.timeText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a)
            HC.Theme.ApplyFont(self.timeText, colors)

            self.taskName:SetTextColor(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
            HC.Theme.ApplyFont(self.taskName, colors)

            self.amount:SetTextColor(colors.endeavor.r, colors.endeavor.g, colors.endeavor.b, colors.endeavor.a)
            HC.Theme.ApplyFont(self.amount, colors)

            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.3)

            -- Highlight current player
            local currentPlayer = UnitName("player")
            if entry.playerName == currentPlayer then
                self.playerName:SetTextColor(colors.success.r, colors.success.g, colors.success.b, colors.success.a)
            else
                self.playerName:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a)
            end
            HC.Theme.ApplyFont(self.playerName, colors)
        end

        return row
    end

    -- ========================================================================
    -- CREATE COUPON ROW (for coupon earnings view)
    -- ========================================================================

    -- Pool for coupon rows
    container.couponRows = {}

    local function CreateCouponRow(parentFrame)
        local C = GetColors()
        local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        row:SetHeight(20)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
        })
        row:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, C.panel.a * 0.3)

        -- Time ago
        local timeText = row:CreateFontString(nil, "OVERLAY")
        timeText:SetPoint("LEFT", 6, 0)
        timeText:SetWidth(40)
        timeText:SetJustifyH("LEFT")
        timeText:SetTextColor(C.text_dim.r, C.text_dim.g, C.text_dim.b)
        HC.Theme.ApplyFont(timeText, C)
        row.timeText = timeText

        -- Character name
        local charName = row:CreateFontString(nil, "OVERLAY")
        charName:SetPoint("LEFT", timeText, "RIGHT", 4, 0)
        charName:SetWidth(70)
        charName:SetJustifyH("LEFT")
        charName:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
        HC.Theme.ApplyFont(charName, C)
        row.charName = charName

        -- Task name
        local taskName = row:CreateFontString(nil, "OVERLAY")
        taskName:SetPoint("LEFT", charName, "RIGHT", 4, 0)
        taskName:SetPoint("RIGHT", -40, 0)
        taskName:SetJustifyH("LEFT")
        taskName:SetTextColor(C.text.r, C.text.g, C.text.b)
        HC.Theme.ApplyFont(taskName, C)
        row.taskName = taskName

        -- Coupon amount (cyan fallback if no coupon color defined)
        local couponColor = C.coupon or {r=0.16, g=0.63, b=0.60, a=1}
        local amount = row:CreateFontString(nil, "OVERLAY")
        amount:SetPoint("RIGHT", -6, 0)
        amount:SetJustifyH("RIGHT")
        amount:SetTextColor(couponColor.r, couponColor.g, couponColor.b)
        HC.Theme.ApplyFont(amount, C)
        row.amount = amount

        function row:SetData(entry)
            local colors = GetColors()

            -- Format time ago
            local timeAgo = ""
            if entry.timestamp then
                local now = time()
                local diff = now - entry.timestamp
                if diff < 60 then
                    timeAgo = "<1m"
                elseif diff < 3600 then
                    timeAgo = math.floor(diff / 60) .. "m"
                elseif diff < 86400 then
                    timeAgo = math.floor(diff / 3600) .. "h"
                else
                    timeAgo = math.floor(diff / 86400) .. "d"
                end
            end

            self.timeText:SetText(timeAgo)
            self.charName:SetText(entry.character or "Unknown")
            self.taskName:SetText(entry.taskName or "Unknown Task")
            self.amount:SetText("+" .. (entry.amount or 0))

            -- Apply theme colors + fonts
            self.timeText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a)
            HC.Theme.ApplyFont(self.timeText, colors)

            self.taskName:SetTextColor(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
            HC.Theme.ApplyFont(self.taskName, colors)

            local couponColor = colors.coupon or {r=0.16, g=0.63, b=0.60, a=1}
            self.amount:SetTextColor(couponColor.r, couponColor.g, couponColor.b, couponColor.a or 1)
            HC.Theme.ApplyFont(self.amount, colors)

            self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.3)

            -- Highlight current player
            local currentPlayer = UnitName("player")
            if entry.character == currentPlayer then
                self.charName:SetTextColor(colors.success.r, colors.success.g, colors.success.b, colors.success.a)
            else
                self.charName:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a)
            end
            HC.Theme.ApplyFont(self.charName, colors)
        end

        return row
    end

    -- ========================================================================
    -- UPDATE FUNCTION
    -- ========================================================================

    function container:Update(forceUpdate)
        -- Skip rebuild if data hasn't changed (optimization)
        local currentTimestamp = HC.EndeavorTracker and HC.EndeavorTracker.activityLogLastUpdated
        if not forceUpdate and self.lastActivityUpdate and self.lastActivityUpdate == currentTimestamp then
            return
        end
        self.lastActivityUpdate = currentTimestamp

        -- Hide all existing rows
        for _, row in ipairs(self.topRows) do
            row:Hide()
        end
        for _, row in ipairs(self.feedRows) do
            row:Hide()
        end
        for _, row in ipairs(self.couponRows) do
            row:Hide()
        end

        -- ================================================================
        -- COUPON VIEW MODE
        -- ================================================================
        if self.showCouponView then
            -- Hide empty text and activity-specific elements
            if self.emptyText then self.emptyText:Hide() end
            if self.setActiveButton then self.setActiveButton:Hide() end
            if self.noResultsText then self.noResultsText:Hide() end

            -- Get coupon gains data
            HC_DB = HC_DB or {}
            local couponGains = HC_DB.couponGains or {}

            if #couponGains == 0 then
                -- Show "no data" message
                if not self.noCouponText then
                    self.noCouponText = self.scrollContent:CreateFontString(nil, "OVERLAY")
                    self.noCouponText:SetPoint("CENTER", self.scrollContent, "CENTER", 0, 0)
                end
                local colors = GetColors()
                HC.Theme.ApplyFont(self.noCouponText, colors)
                self.noCouponText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a)
                self.noCouponText:SetText("No coupon earnings tracked yet.\nComplete tasks to see actual rewards.")
                self.noCouponText:Show()
                self.scrollContent:SetHeight(60)
                return
            end

            if self.noCouponText then self.noCouponText:Hide() end

            -- Filter to only show task-correlated gains (ignore weekly rewards, etc.)
            local sortedGains = {}
            for _, gain in ipairs(couponGains) do
                if gain.taskName then  -- Only show entries with known task
                    table.insert(sortedGains, gain)
                end
            end
            table.sort(sortedGains, function(a, b)
                return (a.timestamp or 0) > (b.timestamp or 0)
            end)

            -- Display coupon rows
            local yOffset = 0
            local rowHeight = 20
            local rowSpacing = 1

            for i, gain in ipairs(sortedGains) do
                local row = self.couponRows[i]
                if not row then
                    row = CreateCouponRow(self.scrollContent)
                    self.couponRows[i] = row
                end

                row:SetPoint("TOPLEFT", 0, -yOffset)
                row:SetPoint("TOPRIGHT", 0, -yOffset)
                row:SetData(gain)
                row:Show()

                yOffset = yOffset + rowHeight + rowSpacing
            end

            self.scrollContent:SetHeight(yOffset + 10)
            return
        end

        -- Hide coupon-specific elements when in activity view
        if self.noCouponText then self.noCouponText:Hide() end

        -- Get activity log data
        local activityData = HC.EndeavorTracker:GetActivityLogData()
        if not activityData or not activityData.taskActivity or #activityData.taskActivity == 0 then
            -- Show loading or empty state
            if not self.emptyText then
                self.emptyText = self.scrollContent:CreateFontString(nil, "OVERLAY")
                self.emptyText:SetPoint("CENTER", self.scrollContent, "CENTER", 0, 0)
            end

            -- Apply theme color and font to empty text
            local colors = GetColors()
            HC.Theme.ApplyFont(self.emptyText, colors)
            self.emptyText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a)

            -- Check fetch status to show appropriate message
            local fetchStatus = HC.EndeavorTracker and HC.EndeavorTracker.fetchStatus
            local isFetching = fetchStatus and (fetchStatus.state == "fetching" or fetchStatus.state == "retrying" or fetchStatus.state == "pending")

            if isFetching then
                self.emptyText:SetText("Loading activity data...")
                if self.setActiveButton then self.setActiveButton:Hide() end
            else
                self.emptyText:SetText("No activity data available.\nThis house is not set as your active endeavor.")
                -- Create button via factory (once)
                if not self.setActiveButton then
                    self.setActiveButton = HC.UI:CreateSetAsActiveButton(self.scrollContent, self.emptyText)
                end
                self.setActiveButton:Show()
            end
            self.emptyText:Show()
            self.scrollContent:SetHeight(100)
            return
        end

        if self.emptyText then
            self.emptyText:Hide()
        end
        if self.setActiveButton then
            self.setActiveButton:Hide()
        end

        -- ====================================================================
        -- TOP 5 TASKS
        -- ====================================================================

        -- Aggregate completions by task
        local taskCounts = {}
        for _, entry in ipairs(activityData.taskActivity) do
            local taskName = entry.taskName or "Unknown"
            taskCounts[taskName] = (taskCounts[taskName] or 0) + 1
        end

        -- Sort by count (highest first)
        local sortedTasks = {}
        for taskName, taskCount in pairs(taskCounts) do
            table.insert(sortedTasks, { name = taskName, count = taskCount })
        end
        table.sort(sortedTasks, function(a, b) return a.count > b.count end)

        -- Display top 5
        local yOffset = 2
        local rowHeight = 24
        local rowSpacing = 2

        for i = 1, math.min(5, #sortedTasks) do
            local data = sortedTasks[i]
            local row = self.topRows[i]
            if not row then
                row = CreateTopTaskRow(self.topContainer)
                self.topRows[i] = row
            end

            row:SetPoint("TOPLEFT", 2, -yOffset)
            row:SetPoint("TOPRIGHT", -2, -yOffset)
            row:SetData(i, data.name, data.count)
            row:Show()

            yOffset = yOffset + rowHeight + rowSpacing
        end

        -- ====================================================================
        -- ACTIVITY FEED (most recent first)
        -- ====================================================================

        -- Build unique task names from task list (faster than activity log)
        local state = HC.Store:GetState()
        if state.tasks and #state.tasks > 0 then
            self.uniqueTaskNames = {}
            for _, task in ipairs(state.tasks) do
                if task.name then
                    table.insert(self.uniqueTaskNames, task.name)
                end
            end
            table.sort(self.uniqueTaskNames)
        end

        -- Sort by completionTime (most recent first) and apply filters
        local sortedActivity = {}
        local currentPlayer = UnitName("player")

        -- Build set of known character names for "My Chars" filter
        -- Uses HC_DB.myCharacters (same as Leaderboard tab) which persists all logged-in alts
        local myCharNames = {}
        if self.filterMyChars then
            HC_DB = HC_DB or {}
            HC_DB.myCharacters = HC_DB.myCharacters or {}
            for charName, _ in pairs(HC_DB.myCharacters) do
                myCharNames[charName] = true
            end
            -- Always include current player
            myCharNames[currentPlayer] = true
        end

        for _, entry in ipairs(activityData.taskActivity) do
            -- Apply "Me Only" filter
            if self.filterMeOnly and entry.playerName ~= currentPlayer then
                -- Skip non-player entries
            -- Apply "My Chars" filter
            elseif self.filterMyChars and not myCharNames[entry.playerName] then
                -- Skip non-player-alt entries
            -- Apply task name filter
            elseif self.filterTaskName and entry.taskName ~= self.filterTaskName then
                -- Skip non-matching tasks
            else
                table.insert(sortedActivity, entry)
            end
        end
        table.sort(sortedActivity, function(a, b)
            return (a.completionTime or 0) > (b.completionTime or 0)
        end)

        -- Display feed
        yOffset = 0
        rowHeight = 20
        rowSpacing = 1

        -- Show "no results" if filters excluded everything
        if #sortedActivity == 0 then
            if not self.noResultsText then
                self.noResultsText = self.scrollContent:CreateFontString(nil, "OVERLAY")
                self.noResultsText:SetPoint("CENTER", self.scrollContent, "CENTER", 0, 0)
            end
            local colors = GetColors()
            HC.Theme.ApplyFont(self.noResultsText, colors)
            self.noResultsText:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a)
            self.noResultsText:SetText("No activity matches your filters.")
            self.noResultsText:Show()
            self.scrollContent:SetHeight(60)
            return
        end

        if self.noResultsText then
            self.noResultsText:Hide()
        end

        for i, entry in ipairs(sortedActivity) do
            local row = self.feedRows[i]
            if not row then
                row = CreateFeedRow(self.scrollContent)
                self.feedRows[i] = row
            end

            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", 0, -yOffset)
            row:SetData(entry)
            row:Show()

            yOffset = yOffset + rowHeight + rowSpacing
        end

        self.scrollContent:SetHeight(yOffset + 10)
    end

    -- Initial update when shown
    container:SetScript("OnShow", function(self)
        -- Request fresh data
        if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestInitiativeActivityLog then
            C_NeighborhoodInitiative.RequestInitiativeActivityLog()
        end
        -- Force update — cache may have refreshed while tab was hidden (stale check would skip)
        self:Update(true)
    end)

    -- Listen for activity log updates
    HC.EventBus:Register("HC_ACTIVITY_LOG_UPDATED", function()
        if container:IsShown() then
            container:Update()
        end
    end)

    -- Listen for active neighborhood changes (when user clicks "Set as Active")
    HC.EventBus:Register("HC_ACTIHC_NEIGHBORHOOD_CHANGED", function()
        if container:IsShown() then
            container:Update()
        end
    end)

    -- Listen for theme updates to refresh colors
    HC.EventBus:Register("HC_THEME_UPDATE", function()
        ApplyContainerColors()
        -- Update filter button appearances
        if container.meOnlyBtn then container.meOnlyBtn:UpdateAppearance() end
        if container.myCharsBtn then container.myCharsBtn:UpdateAppearance() end
        if container.couponBtn then container.couponBtn:UpdateAppearance() end
        if container.taskFilterBtn then container.taskFilterBtn:UpdateAppearance() end
        -- Update dropdown colors
        if container.taskDropdown then
            local colors = GetColors()
            container.taskDropdown:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.95)
            container.taskDropdown:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, 1)
        end
        if container:IsShown() then
            container:Update()
        end
    end)

    return container
end
