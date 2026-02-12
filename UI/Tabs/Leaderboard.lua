-- ============================================================================
-- Vamoose's Endeavors - Leaderboard Tab
-- Shows neighborhood contribution rankings
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

-- Helper to get current theme colors
local function GetColors()
    return HC.Constants:GetThemeColors()
end

-- My characters tracking (highlights all player's alts in leaderboard)
local function GetMyCharacters()
    HC_DB = HC_DB or {}
    HC_DB.myCharacters = HC_DB.myCharacters or {}
    return HC_DB.myCharacters
end

local function RegisterCurrentCharacter()
    local charName = UnitName("player")
    if charName then
        local myChars = GetMyCharacters()
        myChars[charName] = true
    end
end

local function IsMyCharacter(name)
    local myChars = GetMyCharacters()
    return myChars[name] == true
end

function HC.UI.Tabs:CreateLeaderboard(parent)
    local UI = HC.Constants.UI

    -- Register current character for multi-char highlighting
    RegisterCurrentCharacter()

    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    local padding = 0  -- Container edge padding (0 for full-bleed atlas backgrounds)

    -- ========================================================================
    -- LEADERBOARD HEADER (with contribution pip icon)
    -- ========================================================================

    local header = HC.UI:CreateSectionHeader(container, "Leaderboard")
    header:SetPoint("TOPLEFT", 0, UI.sectionHeaderYOffset)
    header:SetPoint("TOPRIGHT", 0, UI.sectionHeaderYOffset)

    -- Refresh button (left side of header)
    local refreshBtn = CreateFrame("Button", nil, header)
    refreshBtn:SetSize(16, 16)
    refreshBtn:SetPoint("LEFT", header, "LEFT", 8, 0)

    local refreshIcon = refreshBtn:CreateTexture(nil, "ARTWORK")
    refreshIcon:SetAllPoints()
    refreshIcon:SetAtlas("UI-RefreshButton")
    refreshIcon:SetAlpha(0.6)
    refreshBtn.icon = refreshIcon

    -- Timestamp (right of refresh button)
    local refreshColors = GetColors()
    local lastUpdateText = header:CreateFontString(nil, "OVERLAY")
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

    -- Grouping toggle button (top-right of header)
    local groupBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    groupBtn:SetSize(75, 16)
    groupBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    groupBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    local groupColors = GetColors()
    groupBtn:SetBackdropColor(groupColors.panel.r, groupColors.panel.g, groupColors.panel.b, 0.5)

    local groupLabel = groupBtn:CreateFontString(nil, "OVERLAY")
    groupLabel:SetPoint("LEFT", 6, 0)
    HC.Theme.ApplyFont(groupLabel, groupColors, "small")
    groupLabel:SetText("Grouping")
    groupLabel:SetTextColor(groupColors.text_dim.r, groupColors.text_dim.g, groupColors.text_dim.b)
    groupBtn.label = groupLabel

    local groupIcon = groupBtn:CreateTexture(nil, "ARTWORK")
    groupIcon:SetSize(14, 14)
    groupIcon:SetPoint("LEFT", groupLabel, "RIGHT", 0, 0)
    groupIcon:SetAtlas("housefinder_neighborhood-friends-icon")
    groupBtn.icon = groupIcon

    local function UpdateGroupBtnState()
        local state = HC.Store:GetState()
        local mode = state.altSharing.groupingMode or "individual"
        local colors = GetColors()
        if mode == "byMain" then
            groupBtn:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.4)
            groupIcon:SetAlpha(1.0)
            groupLabel:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
        else
            groupBtn:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, 0.5)
            groupIcon:SetAlpha(0.5)
            groupLabel:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
        end
    end
    UpdateGroupBtnState()
    container.groupBtn = groupBtn
    container.UpdateGroupBtnState = UpdateGroupBtnState

    groupBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local state = HC.Store:GetState()
        local mode = state.altSharing.groupingMode or "individual"
        if mode == "individual" then
            GameTooltip:AddLine("Group by Player", 1, 1, 1)
            GameTooltip:AddLine("Click to combine alt contributions", 0.7, 0.7, 0.7)
        else
            GameTooltip:AddLine("Individual View", 1, 1, 1)
            GameTooltip:AddLine("Click to show individual characters", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)

    groupBtn:SetScript("OnLeave", GameTooltip_Hide)

    groupBtn:SetScript("OnClick", function()
        local state = HC.Store:GetState()
        local current = state.altSharing.groupingMode or "individual"
        local newMode = current == "individual" and "byMain" or "individual"
        HC.Store:Dispatch("SET_GROUPING_MODE", { mode = newMode })
        UpdateGroupBtnState()
        if state.config.debug then
            print("|cFF2aa198[VE Leaderboard]|r Grouping mode changed to:", newMode)
        end
        HC.EventBus:Trigger("HC_GROUPING_MODE_CHANGED")  -- Sync with config checkbox
        container:Update(true)  -- Force update to re-render with new grouping
    end)

    -- Export button (left of title)
    local exportBtn = CreateFrame("Button", nil, header)
    exportBtn:SetSize(14, 14)
    exportBtn:SetPoint("RIGHT", header.label, "LEFT", -4, 0)

    local exportIcon = exportBtn:CreateTexture(nil, "ARTWORK")
    exportIcon:SetAllPoints()
    exportIcon:SetAtlas("communities-icon-searchmagnifyingglass")
    exportIcon:SetVertexColor(0.85, 0.85, 0.85)
    exportBtn.icon = exportIcon

    exportBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Export to CSV")
        GameTooltip:AddLine("Copy leaderboard data for spreadsheets", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    exportBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.85, 0.85, 0.85)
        GameTooltip_Hide()
    end)

    exportBtn:SetScript("OnClick", function()
        container:ExportCSV()
    end)

    -- CSV Export function
    function container:ExportCSV()
        local activityData = HC.EndeavorTracker and HC.EndeavorTracker:GetActivityLogData()
        if not activityData or not activityData.taskActivity then
            print("|cFFdc322f[VE]|r No activity data to export")
            return
        end

        -- Build raw contributions per character
        local rawContributions = {}
        for _, entry in ipairs(activityData.taskActivity) do
            local playerName = entry.playerName or "Unknown"
            local amt = entry.amount or 0
            rawContributions[playerName] = (rawContributions[playerName] or 0) + amt
        end
        -- Remove characters with no contribution
        for name, amt in pairs(rawContributions) do
            if amt <= 0 then rawContributions[name] = nil end
        end

        -- Get grouped data for warband associations
        local groupedContributions, groupedNames = rawContributions, nil
        if HC.AltSharing and HC.AltSharing.GroupContributions then
            groupedContributions, groupedNames = HC.AltSharing:GroupContributions(rawContributions)
        end

        -- Build sorted warband list
        local sortedWarbands = {}
        for groupKey, amt in pairs(groupedContributions) do
            local displayName = groupKey
            if groupedNames and groupedNames[groupKey] then
                local groupData = groupedNames[groupKey]
                displayName = groupData.displayName or groupKey
                if #groupData > 1 then
                    displayName = displayName .. "'s Warband"
                end
            end
            table.insert(sortedWarbands, { key = groupKey, displayName = displayName, amount = amt })
        end
        table.sort(sortedWarbands, function(a, b) return a.amount > b.amount end)

        -- Build rank lookup
        local warbandRanks = {}
        for i, wb in ipairs(sortedWarbands) do
            warbandRanks[wb.key] = i
        end

        -- Build CSV rows (one per character)
        local csvLines = { "Rank,Character,Warband Group,Character Contribution,Warband Total" }

        for charName, charAmount in pairs(rawContributions) do
            -- Find which warband this character belongs to
            local warbandKey = charName
            local warbandDisplay = charName
            local warbandTotal = charAmount
            local rank = 0

            if groupedNames then
                -- Find the warband this character belongs to
                for key, groupData in pairs(groupedNames) do
                    for _, entry in ipairs(groupData) do
                        local entryName = type(entry) == "table" and entry.name or entry
                        if entryName == charName then
                            warbandKey = key
                            warbandDisplay = groupData.displayName or key
                            if #groupData > 1 then
                                warbandDisplay = warbandDisplay .. "'s Warband (" .. #groupData .. " chars)"
                            end
                            warbandTotal = groupedContributions[key] or charAmount
                            break
                        end
                    end
                end
            end

            rank = warbandRanks[warbandKey] or 0

            -- Escape any commas in names
            local safeChar = charName:gsub(",", ";")
            local safeWarband = warbandDisplay:gsub(",", ";")

            table.insert(csvLines, string.format("%d,%s,%s,%.1f,%.1f",
                rank, safeChar, safeWarband, charAmount, warbandTotal))
        end

        -- Sort by rank, then by character contribution
        table.sort(csvLines, function(a, b)
            if a == csvLines[1] then return true end  -- Header stays first
            if b == csvLines[1] then return false end
            return a < b
        end)

        local csvText = table.concat(csvLines, "\n")

        -- Show in copy dialog
        local rowCount = #csvLines - 1  -- Exclude header
        HC.UI:ShowCSVExportWindow(csvText, rowCount)
    end

    -- ========================================================================
    -- LEADERBOARD LIST (Scrollable)
    -- ========================================================================

    local listContainer = CreateFrame("Frame", nil, container, "BackdropTemplate")
    listContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    listContainer:SetPoint("BOTTOMRIGHT", -padding, padding)
    listContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    container.listContainer = listContainer

    -- Atlas background support
    local ApplyListContainerColors = HC.UI:AddAtlasBackground(listContainer)
    ApplyListContainerColors()

    local _, scrollContent = HC.UI:CreateScrollFrame(listContainer)
    container.scrollContent = scrollContent

    -- Pool of leaderboard rows
    container.rows = {}

    -- ========================================================================
    -- SUMMARY ROW (Total for all player characters)
    -- ========================================================================

    local summaryRow = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    summaryRow:SetHeight(26)
    summaryRow:SetPoint("TOPLEFT", 0, 0)
    summaryRow:SetPoint("TOPRIGHT", 0, 0)
    summaryRow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container.summaryRow = summaryRow

    local summaryC = GetColors()
    summaryRow:SetBackdropColor(summaryC.accent.r, summaryC.accent.g, summaryC.accent.b, 0.2)
    summaryRow:SetBackdropBorderColor(summaryC.accent.r, summaryC.accent.g, summaryC.accent.b, 0.4)

    -- Sum icon
    local summaryIcon = summaryRow:CreateTexture(nil, "ARTWORK")
    summaryIcon:SetSize(16, 16)
    summaryIcon:SetPoint("LEFT", 6, 0)
    summaryIcon:SetAtlas("housefinder_neighborhood-friends-icon")
    summaryRow.icon = summaryIcon

    -- Sum label
    local summaryLabel = summaryRow:CreateFontString(nil, "OVERLAY")
    summaryLabel:SetPoint("LEFT", summaryIcon, "RIGHT", 4, 0)
    HC.Theme.ApplyFont(summaryLabel, summaryC)
    summaryLabel:SetText("My Total")
    summaryLabel:SetTextColor(summaryC.accent.r, summaryC.accent.g, summaryC.accent.b)
    summaryRow.label = summaryLabel

    -- Character count
    local summaryCount = summaryRow:CreateFontString(nil, "OVERLAY")
    summaryCount:SetPoint("LEFT", summaryLabel, "RIGHT", 6, 0)
    HC.Theme.ApplyFont(summaryCount, summaryC, "small")
    summaryCount:SetTextColor(summaryC.text_dim.r, summaryC.text_dim.g, summaryC.text_dim.b)
    summaryRow.charCount = summaryCount

    -- Total amount
    local summaryAmount = summaryRow:CreateFontString(nil, "OVERLAY")
    summaryAmount:SetPoint("RIGHT", -8, 0)
    summaryAmount:SetJustifyH("RIGHT")
    HC.Theme.ApplyFont(summaryAmount, summaryC)
    summaryAmount:SetTextColor(summaryC.endeavor.r, summaryC.endeavor.g, summaryC.endeavor.b)
    summaryRow.amount = summaryAmount

    summaryRow:Hide()

    function container:UpdateSummaryRow(contributions)
        local myChars = GetMyCharacters()
        local totalContrib = 0
        local charCount = 0

        for name, _ in pairs(myChars) do
            if contributions[name] then
                totalContrib = totalContrib + contributions[name]
                charCount = charCount + 1
            end
        end

        if charCount > 0 then
            local colors = GetColors()
            local state = HC.Store:GetState()
            local isGrouped = state.altSharing.groupingMode == "byMain"
            self.summaryRow:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.2)
            self.summaryRow:SetBackdropBorderColor(colors.accent.r, colors.accent.g, colors.accent.b, 0.4)
            self.summaryRow.label:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
            HC.Theme.ApplyFont(self.summaryRow.label, colors)
            if isGrouped then
                self.summaryRow.charCount:SetText("(Consolidated)")
            else
                self.summaryRow.charCount:SetText("(" .. charCount .. " char" .. (charCount > 1 and "s" or "") .. ")")
            end
            self.summaryRow.charCount:SetTextColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b)
            HC.Theme.ApplyFont(self.summaryRow.charCount, colors, "small")
            self.summaryRow.amount:SetText(string.format("%.1f", totalContrib))
            self.summaryRow.amount:SetTextColor(colors.endeavor.r, colors.endeavor.g, colors.endeavor.b)
            HC.Theme.ApplyFont(self.summaryRow.amount, colors)
            self.summaryRow:Show()
            return true
        else
            self.summaryRow:Hide()
            return false
        end
    end

    -- ========================================================================
    -- CREATE LEADERBOARD ROW
    -- ========================================================================

    local function CreateLeaderboardRow(parentFrame)
        local C = GetColors()
        local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        row:SetHeight(24)
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = nil,
        })
        row:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, C.panel.a * 0.5)

        -- Addon indicator (vertical green line on left edge)
        local addonIndicator = row:CreateTexture(nil, "OVERLAY")
        addonIndicator:SetPoint("TOPLEFT", 4, 0)
        addonIndicator:SetPoint("BOTTOMLEFT", 4, 0)
        addonIndicator:SetWidth(3)
        addonIndicator:SetColorTexture(0.2, 0.8, 0.2, 1)  -- Green
        addonIndicator:Hide()
        row.addonIndicator = addonIndicator

        -- Rank number
        local rank = row:CreateFontString(nil, "OVERLAY")
        rank:SetPoint("LEFT", 8, 0)
        rank:SetWidth(32)
        rank:SetJustifyH("CENTER")
        rank:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        HC.Theme.ApplyFont(rank, C)
        row.rank = rank

        -- Player name
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", rank, "RIGHT", 8, 0)
        name:SetPoint("RIGHT", -80, 0)
        name:SetJustifyH("LEFT")
        name:SetTextColor(C.text.r, C.text.g, C.text.b)
        HC.Theme.ApplyFont(name, C)
        row.name = name

        -- Contribution amount
        local amount = row:CreateFontString(nil, "OVERLAY")
        amount:SetPoint("RIGHT", -8, 0)
        amount:SetJustifyH("RIGHT")
        amount:SetTextColor(C.endeavor.r, C.endeavor.g, C.endeavor.b)
        HC.Theme.ApplyFont(amount, C)
        row.amount = amount

        -- Track if this is the current player for hover states
        row.isCurrentPlayer = false
        row.groupedChars = nil  -- List of character names if this is a grouped warband

        -- Hover effect (uses fresh colors) + tooltip for grouped warbands
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local colors = GetColors()
            if self.isCurrentPlayer then
                self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a * 0.25)
            else
                self:SetBackdropColor(colors.text_dim.r, colors.text_dim.g, colors.text_dim.b, colors.text_dim.a * 0.3)
            end
            -- Show tooltip with character names and contributions for grouped warbands
            if self.groupedChars and #self.groupedChars > 1 then
                local MAX_TOOLTIP = 5
                local total = #self.groupedChars
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("Characters (" .. total .. "):", 1, 0.82, 0)
                for i, entry in ipairs(self.groupedChars) do
                    if i > MAX_TOOLTIP then break end
                    local name = type(entry) == "table" and entry.name or entry
                    local amount = type(entry) == "table" and entry.amount or nil
                    if amount then
                        GameTooltip:AddDoubleLine("  " .. name, string.format("%.1f", amount), 1, 1, 1, 0.7, 0.9, 0.7)
                    else
                        GameTooltip:AddLine("  " .. name, 1, 1, 1)
                    end
                end
                if total > MAX_TOOLTIP then
                    GameTooltip:AddLine("  ... and " .. (total - MAX_TOOLTIP) .. " more", 0.6, 0.6, 0.6)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            local colors = GetColors()
            if self.isCurrentPlayer then
                self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a * 0.15)
            else
                self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.5)
            end
            GameTooltip:Hide()
        end)

        function row:SetData(rankNum, displayName, contribution, originalName, hasAddon, groupedChars)
            local colors = GetColors()
            self.rank:SetText("#" .. rankNum)
            self.name:SetText(displayName)
            self.amount:SetText(string.format("%.1f", contribution))

            -- Store grouped characters for tooltip
            self.groupedChars = groupedChars

            -- Show addon indicator for players who have broadcasted
            if hasAddon then
                self.addonIndicator:Show()
            else
                self.addonIndicator:Hide()
            end

            -- Gold/Silver/Bronze colors for top 3, otherwise use text_dim
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

            self.amount:SetTextColor(colors.endeavor.r, colors.endeavor.g, colors.endeavor.b)
            HC.Theme.ApplyFont(self.amount, colors)

            -- Highlight player's characters (use original name for lookup)
            local checkName = originalName or displayName
            self.isCurrentPlayer = IsMyCharacter(checkName)
            if self.isCurrentPlayer then
                self.name:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a)
                self:SetBackdropColor(colors.accent.r, colors.accent.g, colors.accent.b, colors.accent.a * 0.15)
            else
                self.name:SetTextColor(colors.text.r, colors.text.g, colors.text.b, colors.text.a)
                self:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a * 0.5)
            end
            HC.Theme.ApplyFont(self.name, colors)
        end

        return row
    end

    -- ========================================================================
    -- UPDATE FUNCTION
    -- ========================================================================

    -- Loading text
    local loadingColors = GetColors()
    container.loadingText = container.scrollContent:CreateFontString(nil, "OVERLAY")
    container.loadingText:SetPoint("CENTER", container.scrollContent, "CENTER", 0, 0)
    HC.Theme.ApplyFont(container.loadingText, loadingColors)
    container.loadingText:SetText("Loading activity data...")
    container.loadingText:SetTextColor(loadingColors.text_dim.r, loadingColors.text_dim.g, loadingColors.text_dim.b)
    container.loadingText:Hide()

    function container:Update(forceUpdate)
        -- Skip rebuild if data hasn't changed (optimization)
        local currentTimestamp = HC.EndeavorTracker and HC.EndeavorTracker.activityLogLastUpdated
        if not forceUpdate and self.lastActivityUpdate and self.lastActivityUpdate == currentTimestamp then
            return
        end
        self.lastActivityUpdate = currentTimestamp

        -- Hide all existing rows
        for _, row in ipairs(self.rows) do
            row:Hide()
        end

        -- Get activity log data
        local activityData = HC.EndeavorTracker:GetActivityLogData()
        if not activityData or not activityData.taskActivity then
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

        -- Aggregate contributions by player
        local contributions = {}
        for _, entry in ipairs(activityData.taskActivity) do
            local playerName = entry.playerName or "Unknown"
            local amt = entry.amount or 0
            contributions[playerName] = (contributions[playerName] or 0) + amt
        end
        -- Remove characters with no contribution
        for name, amt in pairs(contributions) do
            if amt <= 0 then contributions[name] = nil end
        end

        -- Apply grouping if enabled
        local groupedNames = nil
        if HC.AltSharing and HC.AltSharing.GroupContributions then
            contributions, groupedNames = HC.AltSharing:GroupContributions(contributions)
        end

        -- Sort by contribution (highest first)
        local sorted = {}
        for playerName, amt in pairs(contributions) do
            -- Build display name: use "Main's Warband" format if grouping multiple chars
            local displayName = playerName
            if groupedNames and groupedNames[playerName] then
                local groupData = groupedNames[playerName]
                -- Always use displayName when available (resolves BT:hash to character name)
                displayName = groupData.displayName or playerName
                if #groupData > 1 then
                    displayName = displayName .. "'s Warband (" .. #groupData .. ")"
                end
            end
            table.insert(sorted, { name = playerName, displayName = displayName, amount = amt })
        end
        table.sort(sorted, function(a, b) return a.amount > b.amount end)

        -- Update summary row (shows total for all player characters)
        local hasSummary = self:UpdateSummaryRow(contributions)

        -- Display rows
        local yOffset = hasSummary and 30 or 0  -- Leave room for summary row
        local rowHeight = 24
        local rowSpacing = 2

        for i, data in ipairs(sorted) do
            local row = self.rows[i]
            if not row then
                row = CreateLeaderboardRow(self.scrollContent)
                self.rows[i] = row
            end

            -- Check if this player (or any grouped alt) has the addon
            local hasAddon = false
            if HC.AltSharing and HC.AltSharing.HasAddon then
                if groupedNames and groupedNames[data.name] then
                    -- Check all characters in the group (entries are {name, amount} tables)
                    for _, entry in ipairs(groupedNames[data.name]) do
                        local charName = type(entry) == "table" and entry.name or entry
                        if HC.AltSharing:HasAddon(charName) then
                            hasAddon = true
                            break
                        end
                    end
                else
                    hasAddon = HC.AltSharing:HasAddon(data.name)
                end
            end

            -- Get grouped character names for tooltip (if grouping is active)
            local groupedChars = groupedNames and groupedNames[data.name] or nil

            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("TOPRIGHT", 0, -yOffset)
            row:SetData(i, data.displayName or data.name, data.amount, data.name, hasAddon, groupedChars)
            row:Show()

            yOffset = yOffset + rowHeight + rowSpacing
        end

        -- Hide any extra rows from previous update
        for i = #sorted + 1, #self.rows do
            if self.rows[i] then
                self.rows[i]:Hide()
            end
        end

        self.scrollContent:SetHeight(yOffset + 10)
    end

    -- Initial update when shown
    container:SetScript("OnShow", function(self)
        -- Request fresh data
        if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestInitiativeActivityLog then
            C_NeighborhoodInitiative.RequestInitiativeActivityLog()
        end
        -- Show loading state immediately
        self:Update()
    end)

    -- Listen for activity log updates
    HC.EventBus:Register("HC_ACTIVITY_LOG_UPDATED", function()
        if container:IsShown() then
            container:Update()
        end
    end)

    -- Listen for alt mapping updates (refresh grouped view)
    HC.EventBus:Register("HC_ALT_MAPPING_UPDATED", function()
        if container.UpdateGroupBtnState then
            container.UpdateGroupBtnState()
        end
        if container:IsShown() then
            container:Update(true)
        end
    end)

    -- Listen for theme updates to refresh colors
    HC.EventBus:Register("HC_THEME_UPDATE", function()
        ApplyListContainerColors()
        if container.UpdateGroupBtnState then
            container.UpdateGroupBtnState()
        end
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

    return container
end
