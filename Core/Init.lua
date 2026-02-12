-- ============================================================================
-- Vamoose's Endeavors - Init
-- Addon initialization and slash commands
-- ============================================================================

HC = HC or {}
HC.frame = CreateFrame("Frame")
HC.frame:RegisterEvent("ADDON_LOADED")
HC.frame:RegisterEvent("PLAYER_LOGIN")
HC.frame:RegisterEvent("PLAYER_LOGOUT")

function HC:OnInitialize()
    -- Initialize SavedVariables
    HC_DB = HC_DB or {}

    -- Load persisted state
    HC.Store:LoadFromSavedVariables()

    -- Apply saved theme
    HC.Constants:ApplyTheme()

    -- Initialize Theme Engine (must be after theme is applied)
    if HC.Theme and HC.Theme.Initialize then
        HC.Theme:Initialize()
    end

    self.db = HC_DB

    local version = C_AddOns.GetAddOnMetadata("HousingCompanion", "Version") or "Dev"
    print("|cFF2aa198[HC]|r Housing Companion v" .. version .. " loaded. Type /hc to open.")
end

function HC:OnEnable()
    -- Track session start time for coupon gain tracking
    HC._sessionStart = time()

    -- Trigger addon enabled event
    HC.EventBus:Trigger("HC_ADDON_ENABLED")

    -- Initialize UI
    if HC.CreateMainWindow then
        HC:CreateMainWindow()
    end

    -- Initialize Endeavor Tracker
    if HC.EndeavorTracker and HC.EndeavorTracker.Initialize then
        HC.EndeavorTracker:Initialize()
    end

    -- Initialize Housing Tracker
    if HC.HousingTracker and HC.HousingTracker.Initialize then
        HC.HousingTracker:Initialize()
    end

    -- Initialize Alt Sharing
    if HC.AltSharing and HC.AltSharing.Initialize then
        HC.AltSharing:Initialize()
    end

    -- Initialize Rewards Tracker
    if HC.RewardsTracker and HC.RewardsTracker.Initialize then
        HC.RewardsTracker:Initialize()
    end

    -- Initialize Vendor Finder
    if HC.VendorFinder and HC.VendorFinder.Initialize then
        HC.VendorFinder:Initialize()
    end

    -- Initialize Reputation Tracker
    if HC.RepTracker and HC.RepTracker.Initialize then
        HC.RepTracker:Initialize()
    end

    -- Initialize Minimap Button
    if HC.Minimap and HC.Minimap.Initialize then
        HC.Minimap:Initialize()
    end
end

-- Event Handler
HC.frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "HousingCompanion" then
            HC:OnInitialize()
        elseif arg1 == "Blizzard_HousingDashboard" then
            HC:HookHousingDashboard()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        HC:OnEnable()
        -- Check if Housing Dashboard is already loaded
        if C_AddOns.IsAddOnLoaded("Blizzard_HousingDashboard") then
            HC:HookHousingDashboard()
            HC.frame:UnregisterEvent("ADDON_LOADED")
        end
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_LOGOUT" then
        HC.Store:Flush()
    end
end)

-- Hook into Blizzard Housing Dashboard to add HC button
function HC:HookHousingDashboard()
    if self.dashboardHooked then return end

    -- Find the Housing Dashboard frame (HousingDashboardFrame.HouseInfoContent.ContentFrame.InitiativesFrame)
    local dashboard = HousingDashboardFrame
    if not dashboard or not dashboard.HouseInfoContent then return end

    local houseInfo = dashboard.HouseInfoContent
    if not houseInfo.ContentFrame then return end

    local contentFrame = houseInfo.ContentFrame
    if not contentFrame.InitiativesFrame then return end

    local initiativesFrame = contentFrame.InitiativesFrame

    -- Create HC toggle button with wood sign background
    local btn = CreateFrame("Button", "HC_DashboardButton", initiativesFrame)
    btn:SetSize(70, 32)
    btn:SetFrameStrata("HIGH")
    -- Position to the right of Activity title
    local activityFrame = initiativesFrame.InitiativeSetFrame and initiativesFrame.InitiativeSetFrame.InitiativeActivity
    if activityFrame then
        btn:SetPoint("TOPRIGHT", activityFrame, "TOPRIGHT", -20, 0)
    else
        btn:SetPoint("TOPRIGHT", initiativesFrame, "TOPRIGHT", -10, -10)
    end

    -- Wood sign background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("housing-woodsign")
    btn.bg = bg

    -- Button text
    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText("Endeavor\nTracker")
    text:SetJustifyH("CENTER")
    btn.text = text
    btn:SetScript("OnClick", function()
        HC:ToggleWindow()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Housing Companion", 1, 1, 1)
        GameTooltip:AddLine("Click to toggle the HC tracker window", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.dashboardButton = btn
    self.dashboardHooked = true

    -- Apply initial visibility based on config
    self:UpdateDashboardButtonVisibility()
end

-- Update dashboard button visibility based on config
function HC:UpdateDashboardButtonVisibility()
    if not self.dashboardButton then return end
    local showButton = true
    if HC.Store and HC.Store.state and HC.Store.state.config then
        showButton = HC.Store.state.config.showDashboardButton ~= false
    end
    self.dashboardButton:SetShown(showButton)
end

-- Toggle main window (alias for minimap/compartment)
function HC:Toggle()
    self:ToggleWindow()
end

-- Toggle main window
function HC:ToggleWindow()
    if not self.MainFrame then
        self:CreateMainWindow()
    end
    if self.MainFrame:IsShown() then
        self.MainFrame:Hide()
    else
        self.MainFrame:Show()
        self:RefreshUI()
    end
end

-- Refresh UI
function HC:RefreshUI()
    local frame = self.MainFrame
    if not frame or not frame:IsShown() then return end

    -- Refresh housing display (coupons + house level)
    if frame.UpdateHousingDisplay then
        frame:UpdateHousingDisplay()
    end

    -- Refresh header (always visible)
    if frame.UpdateHeader then
        frame:UpdateHeader()
    end

    -- Refresh the endeavors view (task list only)
    if frame.endeavorsTab and frame.endeavorsTab.Update then
        frame.endeavorsTab:Update()
    end
end

-- Rebuild UI after theme change
function HC:RebuildUI()
    local wasShown = self.MainFrame and self.MainFrame:IsShown()

    -- Destroy existing frame
    if self.MainFrame then
        self.MainFrame:Hide()
        self.MainFrame:SetParent(nil)
        self.MainFrame = nil
    end

    -- Recreate the window with new theme colors
    self:CreateMainWindow()

    -- Show if it was visible
    if wasShown then
        self.MainFrame:Show()
        self:RefreshUI()
    end
end

-- Get current character key
function HC:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

SLASH_HC1 = "/hc"
SLASH_HC2 = "/housingcompanion"
SlashCmdList["HC"] = function(msg)
    local command = msg:lower():match("^(%S*)")

    if command == "" or command == "show" then
        HC:ToggleWindow()
    elseif command == "debug" then
        local state = HC.Store:GetState()
        HC.Store:Dispatch("SET_CONFIG", { key = "debug", value = not state.config.debug })
        print("|cFF2aa198[HC]|r Debug mode:", state.config.debug and "OFF" or "ON")
    elseif command == "refresh" then
        if HC.EndeavorTracker then
            HC.EndeavorTracker:FetchEndeavorData()
        end
        print("|cFF2aa198[HC]|r Refreshing endeavor data...")
    elseif command == "dump" then
        -- Debug: dump current state
        local state = HC.Store:GetState()
        print("|cFF2aa198[HC]|r Current state:")
        print("  Season:", state.endeavor.seasonName)
        print("  Tasks:", #state.tasks)
        print("  Characters:", 0)
        for k, _ in pairs(state.characters) do
            print("    -", k)
        end
    elseif command == "xpdump" then
        -- Debug: dump task XP data for DR analysis
        if HC.EndeavorTracker then
            HC.EndeavorTracker:DumpTaskXPData()
        end
    elseif command == "testxp" then
        -- Debug: test house XP cache refresh
        if HC.EndeavorTracker then
            HC.EndeavorTracker:TestHouseXPRefresh()
        end
    elseif command == "coupons" then
        -- Debug: dump coupon reward data from API
        print("|cFF2aa198[HC]|r === Coupon Reward Debug ===")
        if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
            local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
            if info and info.tasks then
                for _, task in ipairs(info.tasks) do
                    if task.rewardQuestID and task.rewardQuestID > 0 then
                        local rewards = C_QuestLog.GetQuestRewardCurrencies(task.rewardQuestID)
                        local couponData = nil
                        if rewards then
                            for _, r in ipairs(rewards) do
                                if r.currencyID == 3363 then
                                    couponData = r
                                    break
                                end
                            end
                        end
                        if couponData then
                            local rep = task.taskType and task.taskType > 0 and "REP" or "ONE"
                            print(string.format("[%s] %s", rep, task.taskName or "?"))
                            print(string.format("  rewardQuestID=%d, timesCompleted=%d, completed=%s",
                                task.rewardQuestID, task.timesCompleted or 0, tostring(task.completed)))
                            print(string.format("  API coupon data: baseAmount=%s, totalAmount=%s, bonusAmount=%s",
                                tostring(couponData.baseRewardAmount), tostring(couponData.totalRewardAmount), tostring(couponData.bonusRewardAmount)))
                            -- Show all fields in couponData
                            print("  All coupon fields:")
                            for k, v in pairs(couponData) do
                                print(string.format("    %s = %s", tostring(k), tostring(v)))
                            end
                        end
                    end
                end
            else
                print("No initiative info available")
            end
        end
    elseif command == "couponstore" then
        -- Debug: dump tracked coupon gains from SavedVariables
        print("|cFF2aa198[HC]|r === Coupon Store Debug ===")
        HC_DB = HC_DB or {}
        local gains = HC_DB.couponGains or {}
        print(string.format("Total entries: %d", #gains))
        for i, gain in ipairs(gains) do
            local ts = gain.timestamp and date("%m/%d %H:%M", gain.timestamp) or "?"
            print(string.format("[%d] %s | %s | %s | +%s | src=%s | taskID=%s",
                i,
                ts,
                gain.character or "?",
                gain.taskName or "NIL",
                tostring(gain.amount),
                tostring(gain.source),
                tostring(gain.taskID)
            ))
        end
        -- Also dump taskActualCoupons
        local actual = HC_DB.taskActualCoupons or {}
        local taskCount = 0
        for _ in pairs(actual) do taskCount = taskCount + 1 end
        print(string.format("taskActualCoupons: %d tasks tracked", taskCount))
        for taskName, history in pairs(actual) do
            print(string.format("  %s: %d entries, latest=%s",
                taskName, #history,
                history[#history] and tostring(history[#history].amount) or "?"
            ))
        end
    elseif command == "tasks" then
        -- Debug: dump task structure - search for specific tasks
        print("|cFF2aa198[HC]|r Searching for debug tasks...")
        if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
            local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
            if info and info.tasks then
                local found = false
                for _, task in ipairs(info.tasks) do
                    local taskName = task.taskName or ""
                    local nameLower = taskName:lower()
                    if nameLower:find("hoard") or nameLower:find("forbidden") or
                       nameLower:find("lumber") or nameLower:find("harvest") or
                       nameLower:find("rare") or nameLower:find("neighbor") then
                        found = true
                        print(string.format("Task: %s", taskName))
                        print(string.format("  taskType = %s (0=Single, 1=RepeatableFinite, 2=Infinite)", tostring(task.taskType)))
                        print(string.format("  timesCompleted = %s", tostring(task.timesCompleted)))
                        print(string.format("  completed = %s", tostring(task.completed)))
                        print(string.format("  rewardQuestID = %s", tostring(task.rewardQuestID)))
                        print(string.format("  progressContributionAmount = %s", tostring(task.progressContributionAmount)))
                        -- Get ALL currency rewards from quest (not just coupons)
                        if task.rewardQuestID and task.rewardQuestID > 0 then
                            local rewards = C_QuestLog.GetQuestRewardCurrencies(task.rewardQuestID)
                            if rewards then
                                print("  Quest currency rewards:")
                                for _, reward in ipairs(rewards) do
                                    print(string.format("    ID %d: %s x%d", reward.currencyID or 0, reward.name or "?", reward.totalRewardAmount or 0))
                                end
                            end
                        end
                        -- Show all other fields
                        for k, v in pairs(task) do
                            if type(v) ~= "table" and k ~= "taskName" and k ~= "taskType" and
                               k ~= "timesCompleted" and k ~= "completed" and k ~= "rewardQuestID" and
                               k ~= "progressContributionAmount" then
                                print(string.format("  %s = %s", k, tostring(v)))
                            end
                        end
                        print("---")
                    end
                end
                if not found then
                    print("  No matching tasks found in current initiative")
                end
            else
                print("  No initiative info or tasks")
            end
        else
            print("  C_NeighborhoodInitiative not available")
        end
    elseif command == "questreward" then
        -- Debug: check quest reward for rewardQuestID 91024
        local questID = 91024
        print("|cFF2aa198[HC]|r Checking quest reward for ID:", questID)

        -- Try C_QuestLog methods
        if C_QuestLog then
            local rewards = C_QuestLog.GetQuestRewardCurrencies(questID)
            if rewards and #rewards > 0 then
                print("  Currency rewards:")
                for _, reward in ipairs(rewards) do
                    print(string.format("    %s x%d (ID: %d)", reward.name or "?", reward.totalRewardAmount or 0, reward.currencyID or 0))
                end
            else
                print("  No currency rewards from C_QuestLog")
            end
        end

        -- Try GetQuestCurrencyInfo
        if GetNumQuestLogRewardCurrencies then
            local numCurrencies = GetNumQuestLogRewardCurrencies(questID)
            if numCurrencies and numCurrencies > 0 then
                print("  GetNumQuestLogRewardCurrencies:", numCurrencies)
            end
        end
    elseif command == "currencies" then
        -- Debug: scan currencies looking for Community Coupons or housing-related
        print("|cFF2aa198[HC]|r Scanning currencies for housing/community/coupon...")
        local found = 0
        for i = 1, 3000 do
            local info = C_CurrencyInfo.GetCurrencyInfo(i)
            if info and info.name and info.name ~= "" then
                local nameLower = info.name:lower()
                if nameLower:find("community") or nameLower:find("coupon") or
                   nameLower:find("housing") or nameLower:find("endeavor") or
                   nameLower:find("neighborhood") or nameLower:find("initiative") then
                    print(string.format("  ID %d: %s (qty: %d)", i, info.name, info.quantity or 0))
                    found = found + 1
                end
            end
        end
        if found == 0 then
            print("  No matching currencies found. Try /hc allcurrencies for full list.")
        end
    elseif command == "allcurrencies" then
        -- Debug: list all currencies with non-zero quantity
        print("|cFF2aa198[HC]|r Currencies with quantity > 0:")
        for i = 1, 3000 do
            local info = C_CurrencyInfo.GetCurrencyInfo(i)
            if info and info.name and info.name ~= "" and info.quantity and info.quantity > 0 then
                print(string.format("  ID %d: %s (qty: %d)", i, info.name, info.quantity))
            end
        end
    elseif command == "activity" then
        -- Debug: dump activity log data
        -- API Reference: https://warcraft.wiki.gg/wiki/Category:API_systems/NeighborhoodInitiative
        print("|cFF2aa198[HC]|r Checking activity log APIs...")
        if C_NeighborhoodInitiative then
            -- List all available functions
            print("  Available C_NeighborhoodInitiative functions:")
            for k, v in pairs(C_NeighborhoodInitiative) do
                if type(v) == "function" then
                    print(string.format("    %s()", k))
                end
            end
            -- First request the activity log data
            if C_NeighborhoodInitiative.RequestInitiativeActivityLog then
                print("  Calling RequestInitiativeActivityLog()...")
                C_NeighborhoodInitiative.RequestInitiativeActivityLog()
            end
            -- Then get the activity log info
            if C_NeighborhoodInitiative.GetInitiativeActivityLogInfo then
                print("  Calling GetInitiativeActivityLogInfo()...")
                local log = C_NeighborhoodInitiative.GetInitiativeActivityLogInfo()
                if log then
                    print("  Activity log type:", type(log))
                    if type(log) == "table" then
                        -- Check if it's a single object or array
                        if log[1] then
                            print("  Activity log entries:", #log)
                            for i, entry in ipairs(log) do
                                if i <= 10 then -- Limit to first 10
                                    print(string.format("    [%d]", i))
                                    if type(entry) == "table" then
                                        for k, v in pairs(entry) do
                                            print(string.format("      %s = %s", k, tostring(v)))
                                        end
                                    else
                                        print(string.format("      %s", tostring(entry)))
                                    end
                                end
                            end
                        else
                            -- Single object, dump all fields
                            print("  Activity log info fields:")
                            for k, v in pairs(log) do
                                if type(v) == "table" then
                                    print(string.format("    %s = (table with %d entries)", k, #v))
                                    for i, entry in ipairs(v) do
                                        if i <= 5 then
                                            print(string.format("      [%d]", i))
                                            if type(entry) == "table" then
                                                for ek, ev in pairs(entry) do
                                                    print(string.format("        %s = %s", ek, tostring(ev)))
                                                end
                                            else
                                                print(string.format("        %s", tostring(entry)))
                                            end
                                        end
                                    end
                                else
                                    print(string.format("    %s = %s", k, tostring(v)))
                                end
                            end
                        end
                    end
                else
                    print("  GetInitiativeActivityLogInfo returned nil (data may not be loaded yet)")
                    print("  Try: /hc activity again after a moment")
                end
            else
                print("  GetInitiativeActivityLogInfo not found")
            end
        else
            print("  C_NeighborhoodInitiative not available")
        end
    elseif command == "broadcast" then
        -- Force an immediate alt sharing broadcast
        print("|cFF2aa198[HC]|r Forcing AltSharing broadcast...")
        if HC.AltSharing then
            -- Temporarily bypass rate limit
            HC.Store:Dispatch("SET_LAST_BROADCAST", { timestamp = 0 })
            HC.AltSharing:BroadcastIfEnabled()
        else
            print("  AltSharing module not available")
        end
    elseif command == "roster" then
        -- Debug: request roster and show in a scrollable window
        print("|cFF2aa198[HC]|r Requesting neighborhood roster...")
        if C_HousingNeighborhood and C_HousingNeighborhood.RequestNeighborhoodRoster then
            C_HousingNeighborhood.RequestNeighborhoodRoster()
            print("  Request sent - waiting for event callback...")
        else
            print("  C_HousingNeighborhood.RequestNeighborhoodRoster not available")
        end
    elseif command == "apis" then
        -- Debug: search ALL globals for housing/neighborhood related APIs
        HC:ShowDebugWindow("Housing APIs", function()
            local lines = {}
            for k, v in pairs(_G) do
                local kLower = tostring(k):lower()
                if kLower:find("housing") or kLower:find("neighborhood") or kLower:find("bulletin") then
                    if type(v) == "table" then
                        table.insert(lines, "|cFFFFFF00" .. k .. "|r (table):")
                        for funcName, funcVal in pairs(v) do
                            if type(funcVal) == "function" then
                                table.insert(lines, "  ." .. funcName .. "()")
                            end
                        end
                    elseif type(v) == "function" then
                        table.insert(lines, k .. "()")
                    end
                end
            end
            return table.concat(lines, "\n")
        end)
    elseif command == "house" then
        -- Debug: dump C_Housing API data
        print("|cFF2aa198[HC]|r Housing API Debug:")
        if not C_Housing then
            print("  C_Housing API not available")
        else
            -- List available functions
            print("  Available C_Housing functions:")
            for k, v in pairs(C_Housing) do
                if type(v) == "function" then
                    print("    " .. k)
                end
            end

            -- Get player houses
            print("\n  Requesting player houses...")
            local success, result = pcall(C_Housing.GetPlayerOwnedHouses)
            if success then
                print("  GetPlayerOwnedHouses called (async - check PLAYER_HOUSE_LIST_UPDATED event)")
            else
                print("  GetPlayerOwnedHouses error: " .. tostring(result))
            end

            -- Try to get max level
            if C_Housing.GetMaxHouseLevel then
                local success2, maxLevel = pcall(C_Housing.GetMaxHouseLevel)
                if success2 then
                    print("  Max House Level: " .. tostring(maxLevel))
                end
            end

            -- Try to get favor thresholds for levels 1-10
            if C_Housing.GetHouseLevelFavorForLevel then
                print("  House Level XP Thresholds:")
                for level = 1, 10 do
                    local success3, xp = pcall(C_Housing.GetHouseLevelFavorForLevel, level)
                    if success3 and xp then
                        print(string.format("    Level %d: %d XP", level, xp))
                    end
                end
            end
        end
    elseif command == "initiatives" then
        -- Debug: list all known initiative types collected over time
        local known = HC.Store:GetState().knownInitiatives
        local count = 0
        for _ in pairs(known) do count = count + 1 end
        print("|cFF2aa198[HC]|r Known Initiatives (" .. count .. " discovered):")
        if count == 0 then
            print("  No initiatives discovered yet. Play the game to collect them!")
        else
            for id, data in pairs(known) do
                local firstSeen = data.firstSeen and date("%Y-%m-%d", data.firstSeen) or "?"
                print(string.format("  [%d] %s (first seen: %s)", id, data.title, firstSeen))
                if data.description and data.description ~= "" then
                    print(string.format("      %s", data.description))
                end
            end
        end
    elseif command == "scale" then
        -- Show current scale factor and how it was derived
        if HC.EndeavorTracker then
            HC.EndeavorTracker:ShowScaleDebug()
        else
            print("|cFFdc322f[HC]|r EndeavorTracker not loaded")
        end
    elseif command == "validate" then
        -- Show learned XP formula values vs config defaults
        if HC.EndeavorTracker then
            HC.EndeavorTracker:ValidateFormulaConfig()
        else
            print("|cFFdc322f[HC]|r EndeavorTracker not loaded")
        end
    elseif command == "rules" then
        -- Show per-task learned decay rules (new simplified system)
        if HC.EndeavorTracker then
            HC.EndeavorTracker:ShowTaskRules(msg:match("^%S+%s+(.+)"))
        else
            print("|cFFdc322f[HC]|r EndeavorTracker not loaded")
        end
    elseif command == "relearn" then
        -- Rebuild task rules from activity log
        if HC.EndeavorTracker then
            print("|cFF2aa198[HC]|r Rebuilding task rules from activity log...")
            HC.EndeavorTracker:ResetTaskRules()
            HC.EndeavorTracker:BuildTaskRulesFromLog()
            -- Show summary
            local tracker = HC.EndeavorTracker
            local ruleCount = 0
            local atFloorCount = 0
            if tracker.taskRules then
                for _, rules in pairs(tracker.taskRules) do
                    ruleCount = ruleCount + 1
                    if rules.atFloor then atFloorCount = atFloorCount + 1 end
                end
            end
            print(string.format("|cFF2aa198[HC]|r Learned %d task rules (%d at floor)", ruleCount, atFloorCount))
            print("|cFF2aa198[HC]|r Use '/hc rules' to see details")
        else
            print("|cFFdc322f[HC]|r EndeavorTracker not loaded")
        end
    elseif command == "dumplog" then
        -- Dump all activity log fields to discover API structure
        if HC.EndeavorTracker then
            HC.EndeavorTracker:DumpActivityLogFields()
        else
            print("|cFFdc322f[HC]|r EndeavorTracker not loaded")
        end
    elseif command == "coffer" then
        -- Debug: check endeavor coffer/chest reward status
        print("|cFF2aa198[HC]|r === Endeavor Coffer Status ===")
        if not C_NeighborhoodInitiative then
            print("  C_NeighborhoodInitiative API not available")
        else
            local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
            if not info or not info.isLoaded then
                print("  Initiative data not loaded yet")
            elseif info.initiativeID == 0 then
                print("  No active initiative (choosing phase)")
            else
                print(string.format("  Initiative: %s (ID: %d)", info.title or "Unknown", info.initiativeID or 0))
                print(string.format("  Progress: %d / %d", info.currentProgress or 0, info.milestones and info.milestones[#info.milestones] and info.milestones[#info.milestones].requiredContributionAmount or 0))

                if info.milestones and #info.milestones > 0 then
                    print(string.format("  Milestones: %d total", #info.milestones))
                    for i, milestone in ipairs(info.milestones) do
                        local threshold = milestone.requiredContributionAmount or 0
                        local isReached = (info.currentProgress or 0) >= threshold
                        local isFinal = i == #info.milestones

                        -- Check reward quest status
                        local rewardInfo = milestone.rewards and milestone.rewards[1]
                        local questID = rewardInfo and rewardInfo.rewardQuestID or 0
                        local questCompleted = questID > 0 and C_QuestLog.IsQuestFlaggedCompleted(questID)

                        -- Determine coffer status
                        local statusText
                        if not isReached then
                            statusText = "|cFF888888Not reached|r"
                        elseif questCompleted then
                            statusText = "|cFF00FF00Claimed|r"
                        else
                            statusText = "|cFFFFD700AVAILABLE - Click chest!|r"
                        end

                        local milestoneLabel = isFinal and "[FINAL]" or string.format("[%d]", i)
                        print(string.format("    %s %d XP - %s", milestoneLabel, threshold, statusText))

                        -- Show reward details
                        if rewardInfo then
                            print(string.format("      Reward: %s", rewardInfo.title or "Unknown"))
                            print(string.format("      QuestID: %d | IsQuestFlaggedCompleted: %s", questID, tostring(questCompleted)))

                            -- Show currency rewards from quest
                            if questID > 0 then
                                local currencyRewards = C_QuestLog.GetQuestRewardCurrencies(questID)
                                if currencyRewards and #currencyRewards > 0 then
                                    for _, currency in ipairs(currencyRewards) do
                                        print(string.format("      -> %s x%d (ID: %d)",
                                            currency.name or "?",
                                            currency.totalRewardAmount or 0,
                                            currency.currencyID or 0))
                                    end
                                end
                                -- Try other quest completion APIs
                                print(string.format("      |cFF859900Quest API checks:|r"))
                                print(string.format("        IsQuestFlaggedCompleted: %s", tostring(C_QuestLog.IsQuestFlaggedCompleted(questID))))
                                print(string.format("        IsOnQuest: %s", tostring(C_QuestLog.IsOnQuest(questID))))
                                local questState = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID)
                                print(string.format("        GetQuestObjectives: %s", questState and #questState or "nil"))
                                -- Check if it's a world quest or special type
                                local isWorldQuest = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID)
                                print(string.format("        IsWorldQuest: %s", tostring(isWorldQuest)))
                                -- Try the old API
                                local oldComplete = IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID)
                                print(string.format("        IsQuestFlaggedCompleted (old): %s", tostring(oldComplete)))
                            end
                        end

                        -- Dump ALL milestone fields to discover what's available
                        print("      |cFF6c71c4Milestone fields:|r")
                        for k, v in pairs(milestone) do
                            if k ~= "rewards" then
                                print(string.format("        %s = %s", k, tostring(v)))
                            end
                        end
                        -- Dump reward fields
                        if rewardInfo then
                            print("      |cFF6c71c4Reward fields:|r")
                            for k, v in pairs(rewardInfo) do
                                print(string.format("        %s = %s", k, tostring(v)))
                            end
                        end
                    end

                    -- Summary
                    local finalMilestone = info.milestones[#info.milestones]
                    local finalThreshold = finalMilestone.requiredContributionAmount or 0
                    local finalReached = (info.currentProgress or 0) >= finalThreshold
                    local finalQuestID = finalMilestone.rewards and finalMilestone.rewards[1] and finalMilestone.rewards[1].rewardQuestID or 0
                    local finalClaimed = finalQuestID > 0 and C_QuestLog.IsQuestFlaggedCompleted(finalQuestID)

                    print("")
                    if finalReached and not finalClaimed then
                        print("|cFFFFD700  >> FINAL CHEST AVAILABLE! Go to your neighborhood to claim it! <<|r")
                    elseif finalClaimed then
                        print("|cFF00FF00  >> Final chest already claimed for this endeavor <<|r")
                    else
                        local remaining = finalThreshold - (info.currentProgress or 0)
                        print(string.format("  >> %d more XP needed for final chest <<", remaining))
                    end
                else
                    print("  No milestones found in initiative data")
                end
            end
        end
        print("|cFF2aa198[HC]|r === End ===")
    elseif command == "quote" then
        -- Test squirrel quote display
        if HC.Vamoose and HC.Vamoose.TestQuote then
            HC.Vamoose.TestQuote()
        else
            print("|cFFdc322f[HC]|r Vamoose quotes module not loaded")
        end
    elseif command == "memory" or command == "mem" then
        HC.ToggleMemoryMonitor()
    else
        print("|cFF2aa198[HC]|r Commands:")
        print("  /hc - Toggle window")
        print("  /hc refresh - Refresh endeavor data")
        print("|cFF2aa198[HC]|r Debug commands:")
        print("  /hc debug - Toggle debug mode")
        print("  /hc dump - Dump current state")
        print("  /hc xpdump - Dump task XP data (DR analysis)")
        print("  /hc coupons - Dump coupon reward data")
        print("  /hc tasks - Search task structure")
        print("  /hc questreward - Check quest reward data")
        print("  /hc currencies - Scan housing currencies")
        print("  /hc allcurrencies - List currencies with qty > 0")
        print("  /hc activity - Dump activity log APIs")
        print("  /hc house - Debug housing API")
        print("  /hc initiatives - List discovered initiative types")
        print("  /hc roster - Request roster data (shows in window)")
        print("  /hc apis - List all housing APIs (shows in window)")
        print("  /hc scale - Show current scale factor")
        print("  /hc validate - Show learned XP formula values")
        print("  /hc rules - Show per-task decay rules (new system)")
        print("  /hc rules [taskname] - Show rules for specific task")
        print("  /hc relearn - Rebuild task rules from activity log")
        print("  /hc dumplog - Dump activity log API fields")
        print("  /hc coffer - Check endeavor chest reward status")
        print("  /hc quote - Test squirrel quote display")
        print("  /hc memory - Toggle memory monitor chart")
    end
end

-- ============================================================================
-- MEMORY CHART WINDOW
-- ============================================================================

local MEM_MAX_SAMPLES = 300
local MEM_CHART_WIDTH = 340
local MEM_CHART_HEIGHT = 140

local memData = {}
local memDataHead = 0
local memDataCount = 0
local memPeak = 0

local memChartFrame, memBars, memGridLines, memGridLabels, memXLabels, memHeaderText
local memoryTicker = nil

local function NiceScale(maxVal)
    if maxVal <= 0 then return 1 end
    local exp = math.floor(math.log10(maxVal))
    local base = 10 ^ exp
    local frac = maxVal / base
    if frac <= 1 then return base
    elseif frac <= 2 then return 2 * base
    elseif frac <= 5 then return 5 * base
    else return 10 * base end
end

local function FormatKB(kb)
    if kb >= 1024 then
        return string.format("%.1f MB", kb / 1024)
    else
        return string.format("%.0f KB", kb)
    end
end

local function CreateMemoryChart()
    if memChartFrame then return memChartFrame end

    memChartFrame = CreateFrame("Frame", "VEMemoryChart", UIParent, "BackdropTemplate")
    memChartFrame:SetSize(400, 200)
    memChartFrame:SetPoint("TOPRIGHT", -200, -200)
    memChartFrame:SetMovable(true)
    memChartFrame:SetClampedToScreen(true)
    memChartFrame:EnableMouse(true)
    memChartFrame:SetFrameStrata("DIALOG")

    memChartFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    local colors = HC.Constants:GetThemeColors()
    if colors then
        memChartFrame:SetBackdropColor(colors.bg.r, colors.bg.g, colors.bg.b, 0.95)
        memChartFrame:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, colors.border.a or 1)
    else
        memChartFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        memChartFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end

    memChartFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then self:StartMoving() end
    end)
    memChartFrame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    -- Header
    memHeaderText = memChartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    memHeaderText:SetPoint("TOP", 0, -8)
    memHeaderText:SetText("|cFF00FFFF[HC Memory]|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, memChartFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() HC.ToggleMemoryMonitor() end)

    -- Chart area
    local chartArea = CreateFrame("Frame", nil, memChartFrame)
    chartArea:SetPoint("TOPLEFT", 45, -28)
    chartArea:SetPoint("BOTTOMRIGHT", -15, 25)

    -- Bar textures
    memBars = {}
    local barWidth = MEM_CHART_WIDTH / MEM_MAX_SAMPLES
    for i = 1, MEM_MAX_SAMPLES do
        local bar = chartArea:CreateTexture(nil, "ARTWORK")
        bar:SetColorTexture(0.0, 0.8, 0.8, 0.7)
        bar:SetWidth(barWidth)
        bar:SetHeight(0.001)
        bar:SetPoint("BOTTOMLEFT", (i - 1) * barWidth, 0)
        bar:Hide()
        memBars[i] = bar
    end

    -- Grid lines + Y-axis labels
    memGridLines = {}
    memGridLabels = {}
    for i = 1, 4 do
        local line = chartArea:CreateTexture(nil, "BACKGROUND")
        line:SetColorTexture(0.4, 0.4, 0.4, 0.3)
        line:SetHeight(1)
        line:SetPoint("LEFT", 0, 0)
        line:SetPoint("RIGHT", 0, 0)
        memGridLines[i] = line

        local label = memChartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("RIGHT", chartArea, "LEFT", -3, 0)
        label:SetJustifyH("RIGHT")
        label:SetTextColor(0.6, 0.6, 0.6)
        memGridLabels[i] = label
    end

    -- X-axis labels
    memXLabels = {}
    local xTexts = {"5m", "4m", "3m", "2m", "1m", "now"}
    for i = 1, 6 do
        local label = memChartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", chartArea, "BOTTOMLEFT", ((i - 1) / 5) * MEM_CHART_WIDTH, -3)
        label:SetTextColor(0.6, 0.6, 0.6)
        label:SetText(xTexts[i])
        memXLabels[i] = label
    end

    memChartFrame:Hide()
    return memChartFrame
end

local function UpdateMemoryChart()
    UpdateAddOnMemoryUsage()
    local kb = GetAddOnMemoryUsage("HousingCompanion")

    -- Write to circular buffer
    memDataHead = (memDataHead % MEM_MAX_SAMPLES) + 1
    memData[memDataHead] = kb
    if memDataCount < MEM_MAX_SAMPLES then memDataCount = memDataCount + 1 end
    if kb > memPeak then memPeak = kb end

    -- Find max in current buffer for auto-scale
    local maxVal = 0
    for i = 1, memDataCount do
        local idx = ((memDataHead - memDataCount + i - 1) % MEM_MAX_SAMPLES) + 1
        if memData[idx] > maxVal then maxVal = memData[idx] end
    end

    local ceiling = NiceScale(maxVal * 1.1)
    if ceiling <= 0 then ceiling = 1 end

    -- Update header
    memHeaderText:SetText(string.format("|cFF00FFFF[HC Memory]|r %s  |  Peak: %s", FormatKB(kb), FormatKB(memPeak)))

    -- Update bars — oldest on left, newest on right
    local chartHeight = MEM_CHART_HEIGHT
    local startSlot = MEM_MAX_SAMPLES - memDataCount + 1

    for i = 1, MEM_MAX_SAMPLES do
        if i < startSlot then
            memBars[i]:Hide()
        else
            local dataIdx = i - startSlot + 1
            local bufIdx = ((memDataHead - memDataCount + dataIdx - 1) % MEM_MAX_SAMPLES) + 1
            local val = memData[bufIdx] or 0
            local h = math.max((val / ceiling) * chartHeight, 0.001)
            memBars[i]:SetHeight(h)
            memBars[i]:Show()
        end
    end

    -- Update grid lines and labels
    for i = 1, 4 do
        local frac = i / 4
        local yOff = frac * chartHeight
        memGridLines[i]:ClearAllPoints()
        local parent = memBars[1]:GetParent()
        memGridLines[i]:SetPoint("LEFT", parent, "BOTTOMLEFT", 0, yOff)
        memGridLines[i]:SetPoint("RIGHT", parent, "BOTTOMRIGHT", 0, yOff)
        memGridLabels[i]:ClearAllPoints()
        memGridLabels[i]:SetPoint("RIGHT", parent, "BOTTOMLEFT", -3, yOff)
        memGridLabels[i]:SetText(FormatKB(ceiling * frac))
    end
end

function HC.ToggleMemoryMonitor()
    CreateMemoryChart()

    if memoryTicker then
        memoryTicker:Cancel()
        memoryTicker = nil
        memChartFrame:Hide()
        print("|cFF2aa198[HC]|r Memory chart |cFFFF0000STOPPED|r")
        return
    end

    -- Fresh start
    memData = {}
    memDataHead = 0
    memDataCount = 0
    memPeak = 0

    UpdateMemoryChart()
    memChartFrame:Show()

    print("|cFF2aa198[HC]|r Memory chart |cFF00FF00STARTED|r (/hc mem to stop)")
    memoryTicker = C_Timer.NewTicker(1, UpdateMemoryChart)
end
