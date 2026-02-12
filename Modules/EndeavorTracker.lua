-- ============================================================================
-- Vamoose's Endeavors - EndeavorTracker
-- Fetches and tracks housing endeavor data using C_NeighborhoodInitiative API
-- API Reference: https://warcraft.wiki.gg/wiki/Category:API_systems/NeighborhoodInitiative
-- ============================================================================

HC = HC or {}
HC.EndeavorTracker = {}

local Tracker = HC.EndeavorTracker

-- ============================================================================
-- ONLY HARDCODED CONFIG VALUE
-- ============================================================================
local COMPLETIONS_TO_FLOOR = 5  -- Standard tasks reach floor at run 5

-- Frame for event handling
Tracker.frame = CreateFrame("Frame")

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function Tracker:Initialize()
    -- Register for neighborhood initiative events
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("NEIGHBORHOOD_INITIATIHC_UPDATED")
    self.frame:RegisterEvent("INITIATIHC_TASKS_TRACKED_UPDATED")
    self.frame:RegisterEvent("INITIATIHC_TASKS_TRACKED_LIST_CHANGED")
    self.frame:RegisterEvent("INITIATIHC_ACTIVITY_LOG_UPDATED")
    self.frame:RegisterEvent("INITIATIHC_TASK_COMPLETED")
    self.frame:RegisterEvent("INITIATIHC_COMPLETED")
    self.frame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")

    -- Track activity log loading state
    self.activityLogLoaded = false

    -- Cached activity log data (performance: avoid API calls on every UI update)
    self.cachedActivityLog = nil
    self.cachedActivityLogTime = 0
    self.activityLogStale = false

    -- Pre-calculated values from activity log (avoids iterating 23K+ entries per UI update)
    self.cachedPlayerContribution = 0
    self.cachedHouseXP = 0
    self.cachedHouseXPBreakdown = nil

    -- XP cap (2250) and contribution are per-house, not account-wide.
    -- HC_DB.houseData[guid] persists XP/contribution so house switches show correct values.
    self.currentHouseGUID = nil

    -- Task XP cache (from activity log) - maps taskID -> { amount, completionTime }
    self.taskXPCache = {}

    -- Track fetch status for UI display
    self.fetchStatus = {
        state = "pending",  -- "pending", "fetching", "loaded", "retrying"
        attempt = 0,
        lastAttempt = nil,
        nextRetry = nil,
    }

    -- Track pending retry timer (to cancel on new fetch)
    self.pendingRetryTimer = nil

    -- Track house list for house selector
    self.houseList = {}
    self.selectedHouseIndex = 1 -- Will be set properly on PLAYER_HOUSE_LIST_UPDATED via GUID match
    self.houseListLoaded = false -- Flag to track if we've received house list

    -- Per-task learned decay rules (simplified decay system)
    self.taskRules = {}

    self.frame:SetScript("OnEvent", function(frame, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Listen for state changes to save character progress (debounced)
    HC.EventBus:Register("HC_STATE_CHANGED", function(payload)
        if payload.action == "SET_TASKS" or payload.action == "SET_ENDEAVOR_INFO" then
            -- Debounce character saves - only save once per second max
            if self.saveCharProgressTimer then
                self.saveCharProgressTimer:Cancel()
            end
            self.saveCharProgressTimer = C_Timer.NewTimer(0.5, function()
                self.saveCharProgressTimer = nil
                self:SaveCurrentCharacterProgress()
            end)
        end
    end)

    -- Listen for coupon gains to refresh task display with actual values
    HC.EventBus:Register("HC_COUPON_GAINED", function(payload)
        -- Use centralized refresh with proper debouncing (0.3s)
        HC.EndeavorTracker:QueueDataRefresh()
    end)

    -- Load previously learned formula values from SavedVariables
    self:LoadLearnedValues()

    if HC.Store:GetState().config.debug then
        print("|cFF2aa198[VE Tracker]|r Initialized with C_NeighborhoodInitiative API")
    end
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

function Tracker:OnEvent(event, ...)
    local debug = HC.Store:GetState().config.debug

    if event == "PLAYER_ENTERING_WORLD" then
        -- Register current character for account-wide tracking (used by GetAccountCompletionCount)
        HC_DB = HC_DB or {}
        HC_DB.myCharacters = HC_DB.myCharacters or {}
        local charName = UnitName("player")
        if charName then HC_DB.myCharacters[charName] = true end

        -- Initialize housing system first (like Blizzard's dashboard does)
        -- This triggers PLAYER_HOUSE_LIST_UPDATED which handles the actual data fetch
        -- DON'T call FetchEndeavorData here - wait for PLAYER_HOUSE_LIST_UPDATED to set neighborhood context first
        C_Timer.After(2, function()
            if C_Housing and C_Housing.GetPlayerOwnedHouses then
                if debug then
                    print("|cFF2aa198[VE Tracker]|r Requesting player house list to initialize housing system...")
                end
                -- This will trigger PLAYER_HOUSE_LIST_UPDATED which does the proper API sequence
                C_Housing.GetPlayerOwnedHouses()
            end
        end)

    elseif event == "NEIGHBORHOOD_INITIATIHC_UPDATED" then
        -- Debug print moved to QueueDataRefresh to reduce noise (Blizzard fires this event multiple times)
        self:QueueDataRefresh()

    elseif event == "INITIATIHC_TASKS_TRACKED_UPDATED" then
        -- Debug print moved to QueueDataRefresh to reduce noise (Blizzard fires this event multiple times)
        self:QueueDataRefresh()
        -- RefreshTrackedTasks removed - FetchEndeavorData already updates task state

    elseif event == "INITIATIHC_TASKS_TRACKED_LIST_CHANGED" then
        if debug then
            print("|cFF2aa198[VE Tracker]|r Task tracking list changed")
        end
        self:RefreshTrackedTasks()

    elseif event == "INITIATIHC_ACTIVITY_LOG_UPDATED" then
        -- Debounce — this event fires frequently in busy areas, but the refresh
        -- itself is cheap (read cache + pre-calculate). Debounce keeps UI rebuilds sane.
        if self.activityLogRefreshTimer then
            self.activityLogRefreshTimer:Cancel()
        end
        self.activityLogRefreshTimer = C_Timer.NewTimer(0.5, function()
            self.activityLogRefreshTimer = nil
            self:RefreshActivityLogCache()
        end)

    elseif event == "INITIATIHC_TASK_COMPLETED" then
        local taskName = ...
        if debug then
            print("|cFF2aa198[VE Tracker]|r Task completed: |cFFFFD100" .. tostring(taskName) .. "|r")
        end
        -- Look up task info from current state
        local taskID, isRepeatable = nil, false
        local state = HC.Store:GetState()
        if state and state.tasks then
            for _, task in ipairs(state.tasks) do
                if task.name == taskName then
                    taskID = task.id
                    isRepeatable = task.isRepeatable or false
                    break
                end
            end
        end
        -- Store pending task for coupon correlation (CURRENCY_DISPLAY_UPDATE fires after this)
        HC._pendingTaskCompletion = {
            taskName = taskName,
            taskID = taskID,
            isRepeatable = isRepeatable,
            timestamp = time(),
        }
        -- Trigger squirrel quote for task completion
        if HC.Vamoose and HC.Vamoose.OnTaskCompleted then
            HC.Vamoose.OnTaskCompleted(taskID, taskName)
        end
        -- Data refresh happens via INITIATIHC_ACTIVITY_LOG_UPDATED (debounced),
        -- which fires ~1s after this event when server has processed the completion.
        -- Request house level update for XP delta display.
        if HC.HousingTracker then
            HC.HousingTracker:RequestHouseInfo(true)
        end

    elseif event == "INITIATIHC_COMPLETED" then
        local initiativeTitle = ...
        if debug then
            print("|cFF2aa198[VE Tracker]|r Initiative completed: " .. tostring(initiativeTitle))
        end
        self:FetchEndeavorData(true)

    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        -- House list loaded - extract neighborhood and set viewing context (CRITICAL for API to work)
        local houseInfoList = ...
        if debug then
            print("|cFF2aa198[VE Tracker]|r House list updated with " .. (houseInfoList and #houseInfoList or 0) .. " houses")
        end

        -- Store house list for UI dropdown
        self.houseList = houseInfoList or {}
        self.houseListLoaded = true

        -- Preserve user's dropdown selection if still valid
        local selectedIndex = nil
        local neighborhoodGUID = nil

        -- If user manually changed selection in last 2 seconds, respect their choice
        local recentManualSelection = self.lastManualSelectionTime and (GetTime() - self.lastManualSelectionTime) < 2
        if recentManualSelection and self.selectedHouseIndex then
            if debug then
                print("|cFF2aa198[VE Tracker]|r Preserving recent manual selection despite house list update")
            end
            return
        end

        -- Always auto-detect on login — old selectedHouseIndex was account-wide so
        -- switching factions kept showing the wrong house's XP data (bug: Feb 2026)
        -- Active neighborhood is what matters — XP goes to the active house regardless
        -- of which neighborhood the player is physically standing in.
        -- Priority 1: Active neighborhood (the one earning XP)
        local activeNeighborhood = C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetActiveNeighborhood and C_NeighborhoodInitiative.GetActiveNeighborhood()
        if activeNeighborhood and houseInfoList then
            for i, houseInfo in ipairs(houseInfoList) do
                if houseInfo.neighborhoodGUID == activeNeighborhood then
                    neighborhoodGUID = activeNeighborhood
                    selectedIndex = i
                    break
                end
            end
        end

        -- Priority 2: Saved houseGUID from last session
        if not selectedIndex then
            HC_DB = HC_DB or {}
            local savedGUID = HC_DB.selectedHouseGUID
            if savedGUID and houseInfoList then
                for i, houseInfo in ipairs(houseInfoList) do
                    if houseInfo.houseGUID == savedGUID then
                        neighborhoodGUID = houseInfo.neighborhoodGUID
                        selectedIndex = i
                        break
                    end
                end
            end
        end

        -- Priority 3: First house in the list (fallback)
        if not selectedIndex and houseInfoList and #houseInfoList > 0 then
            neighborhoodGUID = houseInfoList[1].neighborhoodGUID
            selectedIndex = 1
        end

        if selectedIndex then
            self.selectedHouseIndex = selectedIndex
            self.currentHouseGUID = houseInfoList[selectedIndex].houseGUID
            HC_DB = HC_DB or {}
            HC_DB.selectedHouseGUID = self.currentHouseGUID

            -- Load persisted per-house XP data for immediate display
            local savedHouseData = HC_DB.houseData and HC_DB.houseData[self.currentHouseGUID]
            if savedHouseData then
                self.cachedPlayerContribution = savedHouseData.playerContribution or 0
                self.cachedHouseXP = savedHouseData.houseXP or 0
            end
        end

        -- Update house GUID and request fresh level data for the selected house
        local selectedHouseInfo = houseInfoList and houseInfoList[selectedIndex]
        if selectedHouseInfo and selectedHouseInfo.houseGUID then
            HC.Store:Dispatch("SET_HOUSE_GUID", { houseGUID = selectedHouseInfo.houseGUID })
            if C_Housing and C_Housing.GetCurrentHouseLevelFavor then
                pcall(C_Housing.GetCurrentHouseLevelFavor, selectedHouseInfo.houseGUID)
            end
        end

        -- Notify UI about house list update
        HC.EventBus:Trigger("HC_HOUSE_LIST_UPDATED", { houseList = self.houseList, selectedIndex = selectedIndex })

        -- Set viewing neighborhood and request data (must set context first like Blizzard dashboard)
        if C_NeighborhoodInitiative and neighborhoodGUID then
            C_NeighborhoodInitiative.SetViewingNeighborhood(neighborhoodGUID)
            C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
            self:RequestActivityLog()
        end

    end
end

-- ============================================================================
-- DATA FETCHING
-- ============================================================================

function Tracker:UpdateFetchStatus(state, attempt, nextRetryTime)
    local prevState = self.fetchStatus.state
    self.fetchStatus.state = state
    self.fetchStatus.attempt = attempt or self.fetchStatus.attempt
    self.fetchStatus.lastAttempt = time()
    self.fetchStatus.nextRetry = nextRetryTime
    -- Only fire event if state actually changed (prevents spam on repeated "loaded" calls)
    if prevState ~= state then
        HC.EventBus:Trigger("HC_FETCH_STATUS_CHANGED", self.fetchStatus)
    end
end

-- ============================================================================
-- HELPER FUNCTIONS (Architecture: extracted for clarity per AI guidelines)
-- ============================================================================

function Tracker:GetViewingNeighborhoodGUID()
    if self.houseList and self.selectedHouseIndex and self.houseList[self.selectedHouseIndex] then
        return self.houseList[self.selectedHouseIndex].neighborhoodGUID
    end
    return nil
end

function Tracker:IsViewingActiveNeighborhood()
    if not C_NeighborhoodInitiative then return false end
    local activeGUID = C_NeighborhoodInitiative.GetActiveNeighborhood and C_NeighborhoodInitiative.GetActiveNeighborhood()
    local viewingGUID = self:GetViewingNeighborhoodGUID()
    -- If we can't determine, assume NOT active (shows Set as Active button, which is safer)
    if not activeGUID or not viewingGUID then return false end
    return activeGUID == viewingGUID
end

-- Consolidated data refresh - debounces multiple event triggers into single fetch
-- Only refreshes when VE window is visible (reduces Blizzard event spam in cities)
function Tracker:QueueDataRefresh()
    -- Skip background fetching when window is closed - OnShow will fetch when opened
    if not HC.MainFrame or not HC.MainFrame:IsShown() then
        return
    end

    if self.pendingRefreshTimer then
        self.pendingRefreshTimer:Cancel()
    end
    self.pendingRefreshTimer = C_Timer.NewTimer(0.3, function()
        self.pendingRefreshTimer = nil
        -- FetchEndeavorData internally decides whether to request fresh data or use cache
        self:FetchEndeavorData()
        if HC.RefreshUI then
            HC:RefreshUI()
        end
    end)
end

function Tracker:ClearEndeavorData()
    self:UpdateFetchStatus("loaded", 0, nil)
    HC.Store:Dispatch("SET_ENDEAVOR_INFO", {
        seasonName = "Not Active Endeavor",
        daysRemaining = 0,
        currentProgress = 0,
        maxProgress = 0,
        milestones = {},
    })
    HC.Store:Dispatch("SET_TASKS", { tasks = {} })
    self.activityLogLoaded = false
    HC.EventBus:Trigger("HC_ACTIVITY_LOG_UPDATED", { timestamp = nil })
end

function Tracker:ValidateRequirements()
    if not C_NeighborhoodInitiative then return "api_unavailable" end
    if not C_NeighborhoodInitiative.IsInitiativeEnabled() then return "disabled" end
    if not C_NeighborhoodInitiative.PlayerMeetsRequiredLevel() then return "low_level" end
    if not C_NeighborhoodInitiative.PlayerHasInitiativeAccess() then return "no_access" end
    return "ok"
end

-- ============================================================================
-- DATA FETCHING (Main)
-- ============================================================================

function Tracker:FetchEndeavorData(_, attempt)
    local debug = HC.Store:GetState().config.debug
    attempt = attempt or 0 -- 0 = manual/event-triggered, 1+ = auto-retry attempts

    -- Debounce: skip entirely if fetched within last 1 second (unless retry attempt)
    local now = GetTime()
    if attempt == 0 and self.lastFetchTime and (now - self.lastFetchTime) < 1 then
        return
    end
    self.lastFetchTime = now

    -- Determine if we should request fresh data (prevents infinite loop)
    -- Skip request if we requested within last 2 seconds
    local skipRequest = self.lastRequestTime and (now - self.lastRequestTime) < 2

    -- Cancel any pending retry timer (prevents stale retries from interfering)
    if self.pendingRetryTimer then
        self.pendingRetryTimer:Cancel()
        self.pendingRetryTimer = nil
    end

    -- Suppress frequent fetch messages (only show retries)
    if debug and attempt > 0 then
        print("|cFF2aa198[VE Tracker]|r Fetching endeavor data (attempt " .. attempt .. ")")
    end

    -- Update fetch status
    self:UpdateFetchStatus(attempt > 0 and "retrying" or "fetching", attempt, nil)

    -- Check if the API exists
    if not C_NeighborhoodInitiative then
        if debug then
            print("|cFFdc322f[VE Tracker]|r C_NeighborhoodInitiative API not available")
        end
        self:LoadPlaceholderData()
        return
    end

    -- Check if initiatives are enabled
    if not C_NeighborhoodInitiative.IsInitiativeEnabled() then
        if debug then
            print("|cFFdc322f[VE Tracker]|r Initiatives not enabled")
        end
        self:LoadPlaceholderData()
        return
    end

    -- Check player level requirement
    if not C_NeighborhoodInitiative.PlayerMeetsRequiredLevel() then
        local reqLevel = C_NeighborhoodInitiative.GetRequiredLevel()
        if debug then
            print("|cFFdc322f[VE Tracker]|r Player does not meet required level:", reqLevel)
        end
        self:LoadPlaceholderData()
        return
    end

    -- Check if player has initiative access
    if not C_NeighborhoodInitiative.PlayerHasInitiativeAccess() then
        if debug then
            print("|cFFdc322f[VE Tracker]|r Player does not have initiative access")
        end
        self:LoadPlaceholderData()
        return
    end

    -- Request fresh data if we haven't recently (prevents infinite loop from event chain)
    -- Don't change viewing neighborhood here - only SelectHouse should do that (respects Blizzard dashboard)
    if not skipRequest then
        self.lastRequestTime = now
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    end

    -- Get the initiative info
    local initiativeInfo = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()

    if not initiativeInfo or not initiativeInfo.isLoaded then
        if debug then
            print("|cFF2aa198[VE Tracker]|r Initiative data not loaded yet, waiting...")
        end
        -- Retry up to 3 times at 10s intervals, then rely on 60s auto-refresh
        -- Only retry if we have house list loaded (ensures SetViewingNeighborhood was called)
        if self.houseListLoaded and attempt >= 0 and attempt < 3 then
            local nextRetry = time() + 10
            self:UpdateFetchStatus("retrying", attempt + 1, nextRetry)
            if debug then
                print("|cFF2aa198[VE Tracker]|r Scheduling retry " .. (attempt + 1) .. "/3 in 10s...")
            end
            -- Cancel any existing retry timer before creating new one
            if self.pendingRetryTimer then
                self.pendingRetryTimer:Cancel()
            end
            self.pendingRetryTimer = C_Timer.NewTimer(10, function()
                self.pendingRetryTimer = nil
                -- Just re-request data, don't change viewing neighborhood (respects Blizzard dashboard)
                C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
                self:RequestActivityLog()
            end)
        end
        return
    end

    -- Data loaded successfully
    self:UpdateFetchStatus("loaded", attempt, nil)

    -- Get the active endeavor neighborhood
    local activeGUID = C_NeighborhoodInitiative.GetActiveNeighborhood and C_NeighborhoodInitiative.GetActiveNeighborhood()
    local dataGUID = initiativeInfo.neighborhoodGUID

    -- Detect if active neighborhood changed (e.g., from Blizzard's dashboard)
    if activeGUID and activeGUID ~= self.lastKnownActiveGUID then
        self.lastKnownActiveGUID = activeGUID
        HC.EventBus:Trigger("HC_ACTIHC_NEIGHBORHOOD_CHANGED")
    end

    -- Sync dropdown if Blizzard's dashboard changed the viewing neighborhood
    if dataGUID and self.houseList then
        local selectedGUID = self.selectedHouseIndex and self.houseList[self.selectedHouseIndex]
                             and self.houseList[self.selectedHouseIndex].neighborhoodGUID
        if dataGUID ~= selectedGUID then
            -- Find which house matches the data we received and sync dropdown
            for i, houseInfo in ipairs(self.houseList) do
                if houseInfo.neighborhoodGUID == dataGUID then
                    if debug then
                        print("|cFF2aa198[VE Tracker]|r Syncing dropdown to match Blizzard's selection: house " .. i)
                    end
                    self.selectedHouseIndex = i
                    self.currentHouseGUID = houseInfo.houseGUID
                    HC_DB = HC_DB or {}
                    HC_DB.selectedHouseGUID = houseInfo.houseGUID
                    HC.EventBus:Trigger("HC_HOUSE_LIST_UPDATED", { houseList = self.houseList, selectedIndex = i })
                    break
                end
            end
        end
    end

    -- ALWAYS check: If viewing a non-active neighborhood, clear data and return
    if dataGUID and activeGUID and dataGUID ~= activeGUID then
        if debug then
            print("|cFF2aa198[VE Tracker]|r Viewing non-active neighborhood (" .. tostring(dataGUID) .. " != " .. tostring(activeGUID) .. "), clearing data")
        end
        self:UpdateFetchStatus("loaded", 0, nil)  -- Mark as loaded so UI shows button, not "fetching"
        HC.Store:Dispatch("SET_ENDEAVOR_INFO", {
            seasonName = "Not Active Endeavor",
            daysRemaining = 0,
            currentProgress = 0,
            maxProgress = 0,
            milestones = {},
        })
        HC.Store:Dispatch("SET_TASKS", { tasks = {} })
        self.activityLogLoaded = false
        HC.EventBus:Trigger("HC_ACTIVITY_LOG_UPDATED", { timestamp = nil })
        return
    end

    if initiativeInfo.initiativeID == 0 then
        if debug then
            print("|cFF2aa198[VE Tracker]|r No active initiative (choosing phase)")
        end
        HC.Store:Dispatch("SET_ENDEAVOR_INFO", {
            seasonName = "No Active Endeavor",
            daysRemaining = 0,
            currentProgress = 0,
            maxProgress = 0,
            milestones = {},
        })
        HC.Store:Dispatch("SET_TASKS", { tasks = {} })
        return
    end

    -- Process initiative info
    self:ProcessInitiativeInfo(initiativeInfo)
end

-- ============================================================================
-- DATA PROCESSING
-- ============================================================================

function Tracker:ProcessInitiativeInfo(info)
    -- Calculate days remaining from duration (seconds)
    local daysRemaining = 0
    if info.duration and info.duration > 0 then
        daysRemaining = math.ceil(info.duration / 86400)  -- 86400 seconds per day
    end

    -- Process milestones
    local milestones = {}
    local maxProgress = 0
    if info.milestones then
        for _, milestone in ipairs(info.milestones) do
            local threshold = milestone.requiredContributionAmount or 0
            -- Use highest milestone threshold as max
            maxProgress = math.max(maxProgress, threshold)
            table.insert(milestones, {
                threshold = threshold,
                reached = (info.currentProgress or 0) >= threshold,
                rewards = milestone.rewards,
            })
        end
    end
    -- Fallback to progressRequired if no milestones
    if maxProgress == 0 then
        maxProgress = info.progressRequired or 100
    end

    -- Dispatch endeavor info
    HC.Store:Dispatch("SET_ENDEAVOR_INFO", {
        seasonName = info.title or "Unknown Endeavor",
        seasonEndTime = info.duration and (time() + info.duration) or 0,
        daysRemaining = daysRemaining,
        currentProgress = info.currentProgress or 0,
        maxProgress = maxProgress,
        milestones = milestones,
        description = info.description,
        initiativeID = info.initiativeID,
    })

    -- Record initiative for collection (builds database over time)
    if info.initiativeID and info.initiativeID > 0 and info.title then
        HC.Store:Dispatch("RECORD_INITIATIVE", {
            initiativeID = info.initiativeID,
            title = info.title,
            description = info.description,
        })
    end

    -- Process tasks
    local tasks = {}
    local hasMissingCoupons = false
    if info.tasks then
        for _, task in ipairs(info.tasks) do
            -- Skip subtasks (superseded tasks) - they're children of other tasks
            if not task.supersedes or task.supersedes == 0 then
                -- taskType: 0=Single, 1=RepeatableFinite, 2=RepeatableInfinite
                local isRepeatable = task.taskType and task.taskType > 0
                local couponReward, couponBase = self:GetTaskCouponReward(task)
                if couponReward == nil then
                    hasMissingCoupons = true
                    couponReward = 0  -- Default to 0 for display
                    couponBase = 0
                end
                table.insert(tasks, {
                    id = task.ID,
                    name = task.taskName,
                    description = task.description or "",
                    points = task.progressContributionAmount or 0,
                    progressContributionAmount = task.progressContributionAmount or 0,  -- API value (decayed)
                    completed = task.completed or false,
                    current = self:GetTaskProgress(task),
                    max = self:GetTaskMax(task),
                    taskType = task.taskType,
                    tracked = task.tracked or false,
                    sortOrder = task.sortOrder or 999,
                    requirementsList = task.requirementsList,
                    timesCompleted = task.timesCompleted,
                    isRepeatable = isRepeatable,
                    rewardQuestID = task.rewardQuestID,
                    couponReward = couponReward,  -- Actual (tracked) or base if no tracking
                    couponBase = couponBase or couponReward,  -- Base reward for tooltip
                })
            end
        end

        -- Sort tasks: incomplete first, then by sortOrder
        table.sort(tasks, function(a, b)
            if a.completed ~= b.completed then
                return not a.completed
            end
            return (a.sortOrder or 999) < (b.sortOrder or 999)
        end)
    end

    -- Check for task progress changes (for squirrel quotes)
    if HC.Vamoose and HC.Vamoose.OnTaskProgress then
        local oldTasks = HC.Store:GetState().tasks or {}
        local oldProgress = {}
        for _, task in ipairs(oldTasks) do
            if task.id and task.current and task.max then
                oldProgress[task.id] = task.current
            end
        end
        -- Check new tasks for progress changes
        for _, task in ipairs(tasks) do
            if task.id and task.current and task.max and not task.completed then
                local oldCurrent = oldProgress[task.id]
                if oldCurrent and task.current > oldCurrent then
                    -- Progress increased - trigger quote
                    HC.Vamoose.OnTaskProgress(task.id, task.name, task.current, task.max)
                end
            end
        end
    end

    HC.Store:Dispatch("SET_TASKS", { tasks = tasks })

    -- If coupon data wasn't ready, schedule a retry
    if hasMissingCoupons and not self._couponRetryScheduled then
        self._couponRetryScheduled = true
        C_Timer.After(2, function()
            self._couponRetryScheduled = false
            HC.EndeavorTracker:FetchEndeavorData()  -- Re-process to get coupon data
        end)
    end
    -- SaveCurrentCharacterProgress removed - handled by HC_STATE_CHANGED listener with 0.5s debounce
end

-- Extract current progress from task requirements
function Tracker:GetTaskProgress(task)
    if task.requirementsList and #task.requirementsList > 0 then
        local req = task.requirementsList[1]
        -- Try to parse "X / Y" format from requirementText
        if req.requirementText then
            local current = req.requirementText:match("(%d+)%s*/%s*%d+")
            if current then
                return tonumber(current) or 0
            end
        end
    end
    return task.completed and 1 or 0
end

-- Extract max value from task requirements
function Tracker:GetTaskMax(task)
    if task.requirementsList and #task.requirementsList > 0 then
        local req = task.requirementsList[1]
        if req.requirementText then
            local max = req.requirementText:match("%d+%s*/%s*(%d+)")
            if max then
                return tonumber(max) or 1
            end
        end
    end
    return 1
end

-- Get coupon reward amount from task's rewardQuestID
-- Returns: actual (or base if no tracking), base (for tooltip)
-- actual comes from tracked CURRENCY_DISPLAY_UPDATE data
-- base comes from quest reward API
function Tracker:GetTaskCouponReward(task)
    local taskName = task.taskName or task.name
    local base = 0

    if not task.rewardQuestID or task.rewardQuestID == 0 then
        return 0, 0
    end

    -- Get base reward from API
    if C_QuestLog and C_QuestLog.GetQuestRewardCurrencies then
        local rewards = C_QuestLog.GetQuestRewardCurrencies(task.rewardQuestID)
        if rewards then
            for _, reward in ipairs(rewards) do
                local couponID = HC.Constants and HC.Constants.CURRENCY_IDS and HC.Constants.CURRENCY_IDS.COMMUNITY_COUPONS or 3363
                if reward.currencyID == couponID then
                    base = reward.totalRewardAmount or 0
                    break
                end
            end
        else
            -- rewards is nil - API not ready yet
            return nil, nil
        end
    end

    -- Check for tracked actual reward (from CURRENCY_DISPLAY_UPDATE correlation)
    -- History is stored as array: { {amount, timestamp, character}, ... }
    -- Clear old format (single number) if found
    HC_DB = HC_DB or {}
    local history = HC_DB.taskActualCoupons and HC_DB.taskActualCoupons[taskName]
    if history and type(history) ~= "table" then
        HC_DB.taskActualCoupons[taskName] = nil  -- Clear old format
        history = nil
    end
    local actual = history and #history > 0 and history[#history].amount

    -- Return actual (or base if no tracking), and base for tooltip
    return actual or base, base
end

-- Debug dump of task XP data for analysis
function Tracker:DumpTaskXPData()
    local state = HC.Store:GetState()
    if not state or not state.tasks then
        print("|cFFdc322f[VE XP Dump]|r No tasks loaded")
        return
    end
    print("|cFF2aa198[VE XP Dump]|r === Task XP Data (from activity log) ===")
    local totalEarned = 0
    local seenTasks = {}
    for _, task in ipairs(state.tasks) do
        local earned = self:GetTaskTotalHouseXPEarned(task)
        local repLabel = task.isRepeatable and "REP" or "ONE"
        print(string.format("  [%s] %s: apiContrib=%d, earned=%.1f",
            repLabel,
            task.name or "?",
            task.progressContributionAmount or 0,
            earned))
        totalEarned = totalEarned + earned
        seenTasks[task.name] = true
    end
    -- Include "Be a Good Neighbor" if not already in task list (meta-task from activity log)
    local beGoodNeighbor = "Home: Be a Good Neighbor"
    if not seenTasks[beGoodNeighbor] then
        local fakeTask = { name = beGoodNeighbor, isRepeatable = true }
        local earned = self:GetTaskTotalHouseXPEarned(fakeTask)
        if earned > 0 then
            print(string.format("  [%s] %s: apiContrib=?, earned=%.1f",
                "REP", beGoodNeighbor, earned))
            totalEarned = totalEarned + earned
        end
    end
    print("|cFF2aa198[VE XP Dump]|r Total earned: " .. string.format("%.1f", totalEarned))
    print("|cFF2aa198[VE XP Dump]|r === End ===")
end

-- Scale constants for House XP calculation
-- Blizzard changed the scale on Jan 29, 2026 (hotfix to address community feedback)
-- Scale = baseScale / rosterSize, where baseScale changed from ~1.0 to ~2.325
local SCALE_CHANGE_CUTOFF = 1769620000  -- ~Jan 28, 2026 17:00 UTC (hotfix deployed between 11:23 and 21:07 UTC)
local OLD_SCALE = 0.04   -- Pre-Jan 29 scale (historical, won't change)
local PRE_JAN29_CAP = 1000  -- Endeavor XP cap before Jan 29 hotfix
local POST_JAN29_CAP = 2250  -- Endeavor XP cap after Jan 29 hotfix

-- Non-repeatable tasks have fixed XP values (don't use scale calculation)
-- ACCOUNT-WIDE: only one completion per task per initiative counts for house XP
-- Multiple alts completing the same task do NOT earn additional XP
local NON_REPEATABLE_XP = {
    ["Kill a Profession Rare"] = 150,
    ["Home: Complete Weekly Neighborhood Quests"] = 50,
    ["Champion a Faction Envoy"] = 10,
}

-- Get scale that was active at a given time
-- Pre-cutoff: hardcoded 0.04 (historical)
-- Post-cutoff: dynamic from API via GetAbsoluteScale()
function Tracker:GetScaleAtTime(_, targetTime)
    if targetTime < SCALE_CHANGE_CUTOFF then
        return OLD_SCALE
    else
        return self:GetAbsoluteScale()  -- Live from API
    end
end

-- Calculate total house XP earned from activity log for a specific task
-- Uses last known contribution as fallback when contribution = 0 (endeavor cap reached)
function Tracker:GetTaskTotalHouseXPEarned(task)
    local logInfo = self:GetActivityLogData()
    if not logInfo or not logInfo.taskActivity then return 0 end

    HC_DB = HC_DB or {}
    local myChars = HC_DB.myCharacters or {}

    local total = 0
    local lastKnown = nil  -- {contribution, timestamp} for this task

    -- Iterate in reverse (oldest first) so lastKnown builds up chronologically
    for i = #logInfo.taskActivity, 1, -1 do
        local entry = logInfo.taskActivity[i]
        if entry.taskName == task.name and myChars[entry.playerName] then
            -- Check for non-repeatable tasks with fixed XP
            local fixedXP = NON_REPEATABLE_XP[entry.taskName]
            local xp
            if fixedXP then
                xp = fixedXP
            else
                local rawContribution = entry.amount or 0
                local contribution = rawContribution
                local entryTime = entry.completionTime or 0

                -- FIX: Only apply fallback for post-Jan29 entries
                -- FIX: Use stored timestamp's scale for fallback
                local fallbackTime = nil
                if contribution == 0 and lastKnown and entryTime >= SCALE_CHANGE_CUTOFF then
                    contribution = lastKnown.contribution
                    fallbackTime = lastKnown.timestamp
                elseif contribution > 0 then
                    lastKnown = { contribution = contribution, timestamp = entryTime }
                end

                local scaleTime = fallbackTime or entryTime
                local scale = self:GetScaleAtTime(nil, scaleTime)
                xp = (scale > 0) and (contribution / scale) or 0
            end
            total = total + xp
        end
    end

    return total
end

-- Calculate TOTAL house XP earned from activity log (account-wide, all tasks)
-- Applies pre-Jan 29 cap (1000 XP) to combined pre-hotfix earnings
-- Uses last known contribution as fallback when contribution = 0 (endeavor cap reached)
-- Returns: total, breakdown table {preRaw, preCapped, post, preCap, postCap}
function Tracker:GetTotalHouseXPEarned()
    local debug = HC.Store:GetState().config.debug
    local logInfo = self:GetActivityLogData()
    if not logInfo or not logInfo.taskActivity then
        if debug then print("|cFFdc322f[VE HouseXP]|r No activity log data") end
        return 0, { preRaw = 0, preCapped = 0, post = 0, preCap = PRE_JAN29_CAP, postCap = POST_JAN29_CAP }
    end

    HC_DB = HC_DB or {}
    local myChars = HC_DB.myCharacters or {}

    -- Debug: show what we're working with
    if debug then
        local charList = {}
        for name, _ in pairs(myChars) do table.insert(charList, name) end
        print(string.format("|cFF2aa198[VE HouseXP]|r Activity entries: %d, myChars: %s",
            #logInfo.taskActivity, table.concat(charList, ", ")))
    end

    local preJan29Total = 0
    local postJan29Total = 0
    local matchCount = 0
    local fallbackCount = 0
    local lastKnown = {}  -- taskName -> {contribution, timestamp}

    -- Iterate in reverse (oldest first) so lastKnown builds up chronologically
    for i = #logInfo.taskActivity, 1, -1 do
        local entry = logInfo.taskActivity[i]
        if myChars[entry.playerName] then
            matchCount = matchCount + 1
            local rawContribution = entry.amount or 0
            local contribution = rawContribution
            local entryTime = entry.completionTime or 0

            -- Use last known contribution as fallback when capped (contribution = 0)
            -- FIX: Only apply fallback for post-Jan29 entries (pre-Jan29, amount=0 meant actual 0)
            -- FIX: Store timestamp with contribution to use correct scale for fallback
            local fallbackTime = nil
            if contribution == 0 and lastKnown[entry.taskName] and entryTime >= SCALE_CHANGE_CUTOFF then
                contribution = lastKnown[entry.taskName].contribution
                fallbackTime = lastKnown[entry.taskName].timestamp
                fallbackCount = fallbackCount + 1
            elseif contribution > 0 then
                lastKnown[entry.taskName] = { contribution = contribution, timestamp = entryTime }
            end

            -- Check for non-repeatable tasks with fixed XP
            local fixedXP = NON_REPEATABLE_XP[entry.taskName]
            local xp
            if fixedXP then
                xp = fixedXP
            else
                -- FIX: Use fallback timestamp's scale if applicable
                local scaleTime = fallbackTime or entryTime
                local scale = self:GetScaleAtTime(nil, scaleTime)
                if scale > 0 then
                    xp = contribution / scale
                else
                    xp = 0
                end
            end

            if entryTime < SCALE_CHANGE_CUTOFF then
                preJan29Total = preJan29Total + xp
            else
                postJan29Total = postJan29Total + xp
            end
        end
    end

    -- Apply caps:
    -- Pre-Jan29: capped at 1000 (old cap, historical)
    -- Post-Jan29: cumulative total (pre + post) capped at 2250
    local cappedPreJan29 = math.min(preJan29Total, PRE_JAN29_CAP)
    local remainingCap = POST_JAN29_CAP - cappedPreJan29  -- How much more can be earned
    local cappedPostJan29 = math.min(postJan29Total, remainingCap)

    local breakdown = {
        preRaw = preJan29Total,
        preCapped = cappedPreJan29,
        post = cappedPostJan29,  -- Post earnings (cumulative shown in tooltip)
        preCap = PRE_JAN29_CAP,
        postCap = POST_JAN29_CAP,
    }

    if debug then
        if fallbackCount > 0 then
            print(string.format("|cFFffd700[VE HouseXP]|r |cFF00ff00%d fallbacks used!|r Matches: %d, preXP: %.1f, postXP: %.1f, |cFFffd700total: %.1f|r",
                fallbackCount, matchCount, preJan29Total, postJan29Total, cappedPreJan29 + cappedPostJan29))
        else
            print(string.format("|cFF2aa198[VE HouseXP]|r Matches: %d, preXP: %.1f, postXP: %.1f, total: %.1f",
                matchCount, preJan29Total, postJan29Total, cappedPreJan29 + cappedPostJan29))
        end
    end

    return cappedPreJan29 + cappedPostJan29, breakdown
end

-- Clear cached scale timeline (call on house switch or relearn)
function Tracker:ClearScaleTimelineCache()
    self._scaleTimeline = nil
end

-- Refresh tracked tasks status
function Tracker:RefreshTrackedTasks()
    if not C_NeighborhoodInitiative then return end

    local trackedInfo = C_NeighborhoodInitiative.GetTrackedInitiativeTasks()
    if not trackedInfo or not trackedInfo.trackedIDs then return end

    local state = HC.Store:GetState()
    local tasks = state.tasks

    -- Update tracked status
    for _, task in ipairs(tasks) do
        task.tracked = tContains(trackedInfo.trackedIDs, task.id)
    end

    HC.Store:Dispatch("SET_TASKS", { tasks = tasks })
end

-- ============================================================================
-- PLACEHOLDER DATA (Fallback when API unavailable)
-- ============================================================================

function Tracker:LoadPlaceholderData()
    -- Placeholder endeavor info based on screenshot
    HC.Store:Dispatch("SET_ENDEAVOR_INFO", {
        seasonName = "Reaching Beyond the Possible",
        daysRemaining = 40,
        currentProgress = 185,
        maxProgress = 500,
        milestones = {
            { threshold = 100, reached = true },
            { threshold = 200, reached = false },
            { threshold = 350, reached = false },
            { threshold = 500, reached = false },
        },
    })

    -- Placeholder tasks based on screenshot
    -- taskType: 0=Single, 1=RepeatableFinite, 2=RepeatableInfinite
    local placeholderTasks = {
        {
            id = 1,
            name = "Home: Complete Weekly Neighborhood Quests",
            description = "Complete weekly quests in your neighborhood",
            points = 50,
            completed = false,
            current = 0,
            max = 1,
            isRepeatable = false,
        },
        {
            id = 2,
            name = "Home: Be a Good Neighbor",
            description = "Help your neighbors with various tasks",
            points = 50,
            completed = false,
            current = 0,
            max = 1,
            isRepeatable = false,
        },
        {
            id = 3,
            name = "Daily Quests",
            description = "Complete daily quests",
            points = 50,
            completed = true,
            current = 1,
            max = 1,
            isRepeatable = true,  -- Repeatable task
        },
        {
            id = 4,
            name = "Skyriding Races",
            description = "Complete skyriding races",
            points = 10,
            completed = false,
            current = 2,
            max = 5,
            isRepeatable = true,  -- Repeatable task
        },
        {
            id = 5,
            name = "Complete a Pet Battle World Quest",
            description = "Win a pet battle world quest",
            points = 25,
            completed = false,
            current = 0,
            max = 1,
            isRepeatable = true,  -- Repeatable task
        },
        {
            id = 6,
            name = "Kill Creatures",
            description = "Defeat creatures in the world",
            points = 10,
            completed = false,
            current = 47,
            max = 100,
            isRepeatable = true,  -- Repeatable task
        },
        {
            id = 7,
            name = "Kill a Profession Rare",
            description = "Defeat a rare creature related to professions",
            points = 25,
            completed = true,
            current = 1,
            max = 1,
            isRepeatable = true,  -- Repeatable task
        },
        {
            id = 8,
            name = "Kill Rares",
            description = "Defeat rare creatures",
            points = 15,
            completed = false,
            current = 3,
            max = 5,
            isRepeatable = true,  -- Repeatable task
        },
    }

    HC.Store:Dispatch("SET_TASKS", { tasks = placeholderTasks })
end

-- ============================================================================
-- CHARACTER PROGRESS
-- ============================================================================

function Tracker:SaveCurrentCharacterProgress()
    local charKey = HC:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    local _, class = UnitClass("player")

    local state = HC.Store:GetState()
    local taskProgress = {}

    -- Build progress map from current tasks
    for _, task in ipairs(state.tasks) do
        taskProgress[task.id] = {
            completed = task.completed,
            current = task.current,
            max = task.max,
        }
    end

    HC.Store:Dispatch("UPDATE_CHARACTER_PROGRESS", {
        charKey = charKey,
        name = name,
        realm = realm,
        class = class,
        tasks = taskProgress,
        endeavorInfo = {
            seasonName = state.endeavor.seasonName,
            currentProgress = state.endeavor.currentProgress,
            maxProgress = state.endeavor.maxProgress,
        },
    })
end

-- Get list of all tracked characters
function Tracker:GetTrackedCharacters()
    local state = HC.Store:GetState()
    local characters = {}
    if not state.characters then return characters end

    for charKey, charData in pairs(state.characters) do
        table.insert(characters, {
            key = charKey,
            name = charData.name,
            realm = charData.realm,
            class = charData.class,
            lastUpdated = charData.lastUpdated,
        })
    end

    -- Sort by name
    table.sort(characters, function(a, b)
        return a.name < b.name
    end)

    return characters
end

-- Get progress for a specific character
function Tracker:GetCharacterProgress(charKey)
    local state = HC.Store:GetState()
    return state.characters[charKey]
end

-- ============================================================================
-- TASK TRACKING API WRAPPERS
-- ============================================================================

function Tracker:TrackTask(taskID)
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.AddTrackedInitiativeTask then
        C_NeighborhoodInitiative.AddTrackedInitiativeTask(taskID)
    end
end

function Tracker:UntrackTask(taskID)
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RemoveTrackedInitiativeTask then
        C_NeighborhoodInitiative.RemoveTrackedInitiativeTask(taskID)
    end
end

function Tracker:GetTaskLink(taskID)
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetInitiativeTaskChatLink then
        return C_NeighborhoodInitiative.GetInitiativeTaskChatLink(taskID)
    end
    return nil
end

-- ============================================================================
-- ACTIVITY LOG DATA
-- ============================================================================

-- Returns cached activity log data (never calls API directly - use RefreshActivityLogCache)
function Tracker:GetActivityLogData()
    return self.cachedActivityLog
end

-- Refresh activity log cache - called only from controlled trigger points:
-- 1. OnShow (when window opens)
-- 2. INITIATIHC_TASK_COMPLETED (when player completes a task)
-- 3. Manual refresh button
function Tracker:RefreshActivityLogCache()
    if not C_NeighborhoodInitiative then return end
    if not C_NeighborhoodInitiative.GetInitiativeActivityLogInfo then return end

    local debug = HC.Store:GetState().config.debug
    if debug then
        print("|cFF2aa198[VE Tracker]|r Refreshing activity log cache...")
    end

    self.cachedActivityLog = C_NeighborhoodInitiative.GetInitiativeActivityLogInfo()
    self.cachedActivityLogTime = time()
    self.activityLogLoaded = true
    self.activityLogLastUpdated = time()
    self.activityLogStale = false

    -- Rebuild derived caches
    self:BuildTaskXPCache()
    self:BuildTaskRulesFromLog()

    -- Pre-calculate expensive values ONCE (avoids 23K+ iterations per UI update)
    self:PreCalculateActivityValues()

    HC.EventBus:Trigger("HC_ACTIVITY_LOG_UPDATED", { timestamp = self.activityLogLastUpdated })
end

-- Pre-calculate player contribution and house XP from cached activity log
function Tracker:PreCalculateActivityValues()
    local logInfo = self.cachedActivityLog
    if not logInfo or not logInfo.taskActivity then
        self.cachedPlayerContribution = 0
        self.cachedHouseXP = 0
        self.cachedHouseXPBreakdown = nil
        return
    end

    -- Calculate player contribution (was in UpdateHeader line 567-576)
    local currentPlayer = UnitName("player")
    local playerContrib = 0
    for _, entry in ipairs(logInfo.taskActivity) do
        if entry.playerName == currentPlayer then
            playerContrib = playerContrib + (entry.amount or 0)
        end
    end
    self.cachedPlayerContribution = playerContrib

    -- Calculate house XP using existing GetTotalHouseXPEarned logic (uses cached log)
    local houseXP, breakdown = self:GetTotalHouseXPEarned()
    local oldXP = self.cachedHouseXP or 0
    self.cachedHouseXP = houseXP
    self.cachedHouseXPBreakdown = breakdown

    -- Debug: show when cache changes
    local debug = HC.Store:GetState().config.debug
    if debug and math.abs(houseXP - oldXP) > 0.01 then
        print(string.format("|cFFffd700[VE HouseXP]|r Cache updated: %.1f → %.1f", oldXP, houseXP))
    end

    -- Persist per-house XP data so switching houses shows correct values immediately
    local guid = self.currentHouseGUID
    if guid then
        HC_DB = HC_DB or {}
        HC_DB.houseData = HC_DB.houseData or {}
        HC_DB.houseData[guid] = {
            houseXP = houseXP,
            playerContribution = playerContrib,
            lastUpdated = time(),
        }
    end
end

-- Fast getters for UI (instant lookup, no iteration)
function Tracker:GetCachedPlayerContribution()
    return self.cachedPlayerContribution or 0
end

function Tracker:GetCachedHouseXP()
    return self.cachedHouseXP or 0, self.cachedHouseXPBreakdown
end

-- Debug: Force cache refresh test (use /hc testxp)
function Tracker:TestHouseXPRefresh()
    print("|cFFffd700[VE Test]|r Simulating INITIATIHC_TASK_COMPLETED flow...")

    -- Capture state before
    local oldXP = self.cachedHouseXP or 0
    local mainFrame = HC.MainFrame
    local oldDisplayText = mainFrame and mainFrame.houseXpText and mainFrame.houseXpText:GetText() or "?"
    print(string.format("|cFFffd700[VE Test]|r BEFORE - Cache: %.1f, UI Display: %s", oldXP, oldDisplayText))

    -- Simulate exact INITIATIHC_TASK_COMPLETED flow (lines 176-183)
    print("|cFFffd700[VE Test]|r Step 1: RefreshActivityLogCache()...")
    self:RefreshActivityLogCache()

    print("|cFFffd700[VE Test]|r Step 2: QueueDataRefresh()...")
    self:QueueDataRefresh()

    print("|cFFffd700[VE Test]|r Step 3: HousingTracker:RequestHouseInfo(true)...")
    if HC.HousingTracker then
        HC.HousingTracker:RequestHouseInfo(true)
    end

    -- Check state after
    local newXP = self.cachedHouseXP or 0
    local newDisplayText = mainFrame and mainFrame.houseXpText and mainFrame.houseXpText:GetText() or "?"
    print(string.format("|cFFffd700[VE Test]|r AFTER - Cache: %.1f, UI Display: %s", newXP, newDisplayText))

    -- Summary
    local cacheChanged = math.abs(newXP - oldXP) > 0.01
    local uiChanged = oldDisplayText ~= newDisplayText
    print(string.format("|cFFffd700[VE Test]|r Cache changed: %s, UI changed: %s",
        cacheChanged and "|cFF00ff00YES|r" or "|cFFff0000NO|r",
        uiChanged and "|cFF00ff00YES|r" or "|cFFff0000NO|r"))
end

-- Build task XP cache from activity log (entry.amount = actual XP earned)
-- Also builds per-player cache for current character lookup
function Tracker:BuildTaskXPCache()
    self.taskXPCache = {}
    self.taskXPByPlayer = {}  -- taskID -> playerName -> { amount, completionTime }
    local logInfo = self:GetActivityLogData()
    if logInfo and logInfo.taskActivity then
        for _, entry in ipairs(logInfo.taskActivity) do
            local taskId = entry.taskID
            local amount = entry.amount
            local playerName = entry.playerName
            local completionTime = entry.completionTime or 0
            if taskId and amount then
                -- Global cache: most recent completion's XP value
                if not self.taskXPCache[taskId] or completionTime > (self.taskXPCache[taskId].completionTime or 0) then
                    self.taskXPCache[taskId] = {
                        amount = amount,
                        completionTime = completionTime,
                    }
                end
                -- Per-player cache: most recent completion per player
                if playerName then
                    self.taskXPByPlayer[taskId] = self.taskXPByPlayer[taskId] or {}
                    if not self.taskXPByPlayer[taskId][playerName] or completionTime > (self.taskXPByPlayer[taskId][playerName].completionTime or 0) then
                        self.taskXPByPlayer[taskId][playerName] = {
                            amount = amount,
                            completionTime = completionTime,
                        }
                    end
                end
            end
        end
    end
    return self.taskXPCache
end

-- Get actual earned XP from activity log cache (nil if never completed)
function Tracker:GetTaskXP(taskID)
    if not self.taskXPCache then
        self:BuildTaskXPCache()
    end
    local cached = self.taskXPCache[taskID]
    return cached and cached.amount or nil
end

-- Get actual earned XP for current player only (nil if current char hasn't completed)
function Tracker:GetTaskXPForCurrentPlayer(taskID)
    if not self.taskXPByPlayer then
        self:BuildTaskXPCache()
    end
    local playerName = UnitName("player")
    local taskData = self.taskXPByPlayer[taskID]
    if taskData and taskData[playerName] then
        return taskData[playerName].amount
    end
    return nil
end

-- Count completions for current player from activity log
function Tracker:GetPlayerCompletionCount(taskID)
    local logInfo = self:GetActivityLogData()
    if not logInfo or not logInfo.taskActivity then return 0 end
    local playerName = UnitName("player")
    local count = 0
    for _, entry in ipairs(logInfo.taskActivity) do
        if entry.taskID == taskID and entry.playerName == playerName then
            count = count + 1
        end
    end
    return count
end

-- Count completions across ALL of the user's characters (account-wide)
-- DR is account-based, so we sum completions from all alts in HC_DB.myCharacters
function Tracker:GetAccountCompletionCount(taskID)
    local logInfo = self:GetActivityLogData()
    if not logInfo or not logInfo.taskActivity then return 0 end

    -- Get list of user's characters (populated on login from Leaderboard/Activity tabs)
    HC_DB = HC_DB or {}
    local myChars = HC_DB.myCharacters or {}

    local count = 0
    for _, entry in ipairs(logInfo.taskActivity) do
        if entry.taskID == taskID and myChars[entry.playerName] then
            count = count + 1
        end
    end
    return count
end

-- ============================================================================
-- SELF-LEARNING XP FORMULA SYSTEM
-- Learns scale from observed floor task data (most accurate method)
-- Rebuilds fresh from activity log each session (no persistence needed)
-- ============================================================================

-- Count roster size from activity log
function Tracker:GetRosterSize()
    local logInfo = self:GetActivityLogData()
    local rosterSize = 0
    if logInfo and logInfo.taskActivity then
        local chars = {}
        for _, entry in ipairs(logInfo.taskActivity) do
            if entry.playerName then
                chars[entry.playerName] = true
            end
        end
        for _ in pairs(chars) do rosterSize = rosterSize + 1 end
    end
    return rosterSize
end

-- Reset learned task rules (triggers re-learning from activity log)
function Tracker:ResetTaskRules()
    self.taskRules = {}
    -- Clean up legacy SavedVariables data
    if HC_DB then
        HC_DB.taskRules = nil
        HC_DB.learnedFormula = nil
        HC_DB.formulaCheckpoint = nil
    end
end

-- Load learned values on init
function Tracker:LoadLearnedValues()
    -- taskRules rebuilt from activity log on INITIATIHC_ACTIVITY_LOG_UPDATED - no persistence needed
    self.taskRules = {}
    -- Clean up legacy SavedVariables data
    if HC_DB then
        HC_DB.learnedFormula = nil
        HC_DB.taskRules = nil
        HC_DB.formulaCheckpoint = nil
    end
end

-- Save/Load per-task rules removed - rebuilt fresh from activity log each time

-- ============================================================================
-- PER-TASK DECAY LEARNING (Simplified System)
-- Each task learns its own decay rate and floor from observed completions
-- ============================================================================

-- Build task rules from activity log
-- Simplified approach: for floor tasks (timesCompleted >= 5), use most recent entry as floor XP
function Tracker:BuildTaskRulesFromLog()
    local logInfo = self:GetActivityLogData()
    if not logInfo or not logInfo.taskActivity then return end

    -- Start fresh
    self.taskRules = {}

    -- Group by taskName, keeping only the most recent entry
    local recentByTask = {}
    for _, entry in ipairs(logInfo.taskActivity) do
        local task = entry.taskName
        local amount = entry.amount
        local completionTime = entry.completionTime or 0
        if task and amount and amount > 0 then
            if not recentByTask[task] or completionTime > recentByTask[task].time then
                recentByTask[task] = { amount = amount, time = completionTime }
            end
        end
    end

    -- For floor tasks (per API), use most recent entry as floor XP
    local tasks = HC.Store:GetState().tasks or {}
    local floorCount = 0
    for _, task in ipairs(tasks) do
        if (task.timesCompleted or 0) >= COMPLETIONS_TO_FLOOR then
            local recent = recentByTask[task.name]
            if recent then
                self.taskRules[task.name] = {
                    atFloor = true,
                    floorXP = recent.amount,
                    floorXPTime = recent.time,
                }
                floorCount = floorCount + 1
            end
        end
    end
end

-- Show per-task learned rules (/hc rules command)
function Tracker:ShowTaskRules(filterTask)
    print("|cFF2aa198[VE TaskRules]|r === Per-Task Rules ===")

    local scale = self:GetAbsoluteScale()
    local rosterSize = self:GetRosterSize()
    print(string.format("  Scale: |cFF268bd2%.5f|r | Roster: %d chars", scale, rosterSize))

    if not self.taskRules or not next(self.taskRules) then
        print("  No rules learned yet. Complete some tasks to learn rules.")
        return
    end

    local count = 0
    for taskName, rules in pairs(self.taskRules) do
        if not filterTask or taskName:lower():find(filterTask:lower()) then
            count = count + 1
            local pattern = rules.pattern and string.format(" |cFF6c71c4[%s]|r", rules.pattern) or ""

            -- Get calculated values from API
            local task = self:GetTaskByName(taskName)
            local currentContrib = task and task.progressContributionAmount or 0
            local timesCompleted = task and task.timesCompleted or 0
            -- Determine floor status from API, not historical activity log
            local isAtFloor = timesCompleted >= COMPLETIONS_TO_FLOOR
            local status = isAtFloor and "|cFF859900(at floor)|r" or "|cFFcb4b16(decaying)|r"
            local baseContrib = self:GetBaseTaskContribution(taskName)
            local calcFloorXP = self:CalculateFloorXP(taskName)
            local nextXP = self:CalculateNextContribution(taskName)

            print(string.format("  |cFFb58900%s|r%s %s", taskName, pattern, status))
            print(string.format("    API: current=|cFF93a1a1%d|r timesCompleted=|cFF93a1a1%d|r",
                currentContrib, timesCompleted))
            print(string.format("    Calc: base=|cFF859900%d|r floorXP=|cFF859900%.3f|r nextXP=|cFF859900%.3f|r",
                baseContrib, calcFloorXP, nextXP))
            if rules.floorXP and rules.floorXP > 0 then
                print(string.format("    Observed: floorXP=|cFF268bd2%.3f|r", rules.floorXP))
            end
        end
    end

    if count == 0 then
        print("  No matching tasks found for filter: " .. (filterTask or ""))
    else
        print(string.format("|cFF2aa198[VE TaskRules]|r %d task(s) shown", count))
    end
end

-- Refresh learned values (call on activity log update)
function Tracker:RefreshLearnedValues()
    self:BuildTaskRulesFromLog()
    -- Clear cached scale so it re-derives from fresh floor data
    self.cachedAbsoluteScale = nil
end

-- Derive scale from floor task observations
-- Formula: scale = floorXP / progressContributionAmount
-- Both values are at floor decay level, so they align perfectly
function Tracker:GetAbsoluteScale()
    if self.cachedAbsoluteScale then
        return self.cachedAbsoluteScale
    end

    local tasks = HC.Store:GetState().tasks or {}

    -- Primary: floor task with observed floorXP (most accurate)
    for _, task in ipairs(tasks) do
        if (task.timesCompleted or 0) >= COMPLETIONS_TO_FLOOR then
            local rules = self.taskRules and self.taskRules[task.name]
            if rules and rules.floorXP and rules.floorXP > 0 then
                local apiContrib = task.progressContributionAmount or 0
                if apiContrib > 0 then
                    self.cachedAbsoluteScale = rules.floorXP / apiContrib
                    self:SaveNeighborhoodScale(self.cachedAbsoluteScale)
                    return self.cachedAbsoluteScale
                end
            end
        end
    end

    -- Secondary: previously saved scale for this neighborhood (survives house switches)
    local saved = self:GetSavedNeighborhoodScale()
    if saved then
        self.cachedAbsoluteScale = saved
        return saved
    end

    -- Cold start fallback: tier 1 baseline (~0.04), will self-correct once floor data exists
    return 0.04
end

-- Persist derived scale for current neighborhood in SavedVariables
function Tracker:SaveNeighborhoodScale(scale)
    local guid = self:GetViewingNeighborhoodGUID()
    if not guid then return end
    HC_DB = HC_DB or {}
    HC_DB.neighborhoodScales = HC_DB.neighborhoodScales or {}
    HC_DB.neighborhoodScales[guid] = { scale = scale, timestamp = time() }
end

-- Retrieve previously saved scale for current neighborhood
function Tracker:GetSavedNeighborhoodScale()
    local guid = self:GetViewingNeighborhoodGUID()
    if not guid then return nil end
    HC_DB = HC_DB or {}
    local saved = HC_DB.neighborhoodScales and HC_DB.neighborhoodScales[guid]
    if saved then return saved.scale end
    return nil
end


-- Debug command: show learned values (/hc validate)
function Tracker:ValidateFormulaConfig()
    print("|cFF2aa198[VE Validate]|r === XP Formula & Scales ===")

    -- Scale info — track source by checking what data is available
    self.cachedAbsoluteScale = nil  -- Force re-derive to check source
    local postScale = self:GetAbsoluteScale()
    local postSource
    if not self.cachedAbsoluteScale then
        postSource = "|cFFcb4b16(fallback)|r"
    else
        -- Check if floor data exists (primary) vs saved neighborhood scale (secondary)
        local hasFloor = false
        for _, task in ipairs(HC.Store:GetState().tasks or {}) do
            local rules = self.taskRules and self.taskRules[task.name]
            if (task.timesCompleted or 0) >= COMPLETIONS_TO_FLOOR and rules and rules.floorXP and rules.floorXP > 0 then
                hasFloor = true
                break
            end
        end
        postSource = hasFloor and "|cFF859900(from floor task)|r" or "|cFF268bd2(saved for neighborhood)|r"
    end

    print("|cFF268bd2Scales:|r")
    print(string.format("  Pre-Jan29 (hardcoded):  |cFF268bd2%.5f|r", OLD_SCALE))
    print(string.format("  Post-Jan29 (dynamic):   |cFF268bd2%.5f|r %s", postScale, postSource))
    print(string.format("  Scale cutoff: %d (~Jan 28, 2026 17:00 UTC)", SCALE_CHANGE_CUTOFF))

    -- Per-task rules summary
    local ruleCount = 0
    local atFloorCount = 0
    if self.taskRules then
        for _, rules in pairs(self.taskRules) do
            ruleCount = ruleCount + 1
            if rules.atFloor then atFloorCount = atFloorCount + 1 end
        end
    end
    print(string.format("  Tasks learned: %d (%d at floor)", ruleCount, atFloorCount))

    -- Calculate and show house XP breakdown
    print("|cFF268bd2House XP Calculation:|r")
    local total, breakdown = self:GetTotalHouseXPEarned()
    if breakdown then
        print(string.format("  Pre-Jan29:  |cFF859900%.1f|r raw -> |cFF268bd2%.1f|r (cap: %d)",
            breakdown.preRaw or 0, breakdown.preCapped or 0, PRE_JAN29_CAP))
        print(string.format("  Post-Jan29: |cFF859900%.1f|r raw -> |cFF268bd2%.1f|r (remaining: %.1f)",
            breakdown.post or 0, breakdown.post or 0, POST_JAN29_CAP - (breakdown.preCapped or 0)))
        print(string.format("  |cFFffd700TOTAL: %.1f / %d|r%s",
            total, POST_JAN29_CAP, total >= POST_JAN29_CAP and " |cFFdc322f(CAPPED)|r" or ""))
    else
        print("  No activity log data available")
    end

    -- Formula explanation
    print("|cFF268bd2Formula:|r")
    print("  XP = contribution / scale")
    print("  Fallback: post-Jan29 zeros use last known (with original scale)")
    print("  Use '/hc rules' for per-task details, '/hc scale' for scale derivation")

    print("|cFF2aa198[VE Validate]|r === End ===")
end

-- Debug: Show current scale factor and derivation (/hc scale)
function Tracker:ShowScaleDebug()
    print("|cFF2aa198[VE Scale]|r === Scale Debug ===")

    -- Get roster size
    local rosterSize = self:GetRosterSize()
    print(string.format("  Roster size: |cFF268bd2%d|r characters", rosterSize))

    -- Check if we have a cached scale
    local hadCached = self.cachedAbsoluteScale ~= nil
    local scale = self:GetAbsoluteScale()
    local source = hadCached and "(cached)" or (self.cachedAbsoluteScale and "(derived from floor task)" or "(fallback)")
    print(string.format("  Scale factor: |cFF268bd2%.6f|r %s", scale, source))

    -- Find which floor task we derived scale from (exclude zero-floor tasks)
    local tasks = HC.Store:GetState().tasks or {}
    local floorTasks = {}
    for _, task in ipairs(tasks) do
        if (task.timesCompleted or 0) >= COMPLETIONS_TO_FLOOR then
            local rules = self.taskRules and self.taskRules[task.name]
            local apiContrib = task.progressContributionAmount or 0
            if rules and rules.floorXP and rules.floorXP > 0 and apiContrib > 0 then
                table.insert(floorTasks, {
                    name = task.name,
                    floorXP = rules.floorXP,
                    apiContrib = apiContrib,
                    derivedScale = rules.floorXP / apiContrib
                })
            end
        end
    end

    if #floorTasks > 0 then
        print("  |cFF859900Floor tasks used for scale derivation:|r")
        for _, ft in ipairs(floorTasks) do
            print(string.format("    %s: floorXP=%.2f / apiContrib=%d = %.6f",
                ft.name, ft.floorXP, ft.apiContrib, ft.derivedScale))
        end
    else
        print("  |cFFcb4b16No floor tasks available - using fallback scale|r")
    end

    print("|cFF2aa198[VE Scale]|r === End ===")
end

-- Debug: Dump all fields from activity log entries (/hc dumplog)
function Tracker:DumpActivityLogFields()
    local logInfo = self:GetActivityLogData()
    if not logInfo then
        print("|cFF2aa198[VE DumpLog]|r No activity log data available")
        return
    end

    print("|cFF2aa198[VE DumpLog]|r === Activity Log Structure ===")

    -- Dump top-level logInfo fields
    print("  |cFF268bd2Top-level logInfo fields:|r")
    for key, value in pairs(logInfo) do
        local valType = type(value)
        if valType == "table" then
            print(string.format("    %s = [table with %d entries]", key, #value > 0 and #value or 0))
        else
            print(string.format("    %s = %s (%s)", key, tostring(value), valType))
        end
    end

    -- Dump first entry's fields
    if logInfo.taskActivity and #logInfo.taskActivity > 0 then
        local entry = logInfo.taskActivity[1]
        print("  |cFF268bd2Entry fields (from first entry):|r")
        local fields = {}
        for key in pairs(entry) do
            table.insert(fields, key)
        end
        table.sort(fields)
        for _, key in ipairs(fields) do
            local value = entry[key]
            local valType = type(value)
            if valType == "table" then
                print(string.format("    %s = [table]", key))
            else
                print(string.format("    %s = %s (%s)", key, tostring(value), valType))
            end
        end
        print(string.format("  |cFF859900Total entries: %d|r", #logInfo.taskActivity))
    else
        print("  No taskActivity entries found")
    end

    print("|cFF2aa198[VE DumpLog]|r === End ===")
end

-- Look up task object from current initiative by name
function Tracker:GetTaskByName(taskName)
    if not taskName then return nil end
    local state = HC.Store:GetState()
    if state and state.tasks then
        for _, task in ipairs(state.tasks) do
            if task.name == taskName then
                return task
            end
        end
    end
    return nil
end

-- Get current contribution (decayed value from API progressContributionAmount)
-- This is what you'd earn on NEXT completion, pre-scale
function Tracker:GetCurrentContribution(task)
    if type(task) == "string" then
        task = self:GetTaskByName(task)
    end
    if not task then return 0 end
    return task.progressContributionAmount or 0
end

-- Get times completed for a task
function Tracker:GetTimesCompleted(task)
    if type(task) == "string" then
        task = self:GetTaskByName(task)
    end
    if not task then return 0 end
    return task.timesCompleted or 0
end

-- Calculate BaseTaskContribution by working backwards from current decayed value
-- BaseTaskContribution = progressContributionAmount / currentDecayMultiplier
function Tracker:GetBaseTaskContribution(task)
    if type(task) == "string" then
        task = self:GetTaskByName(task)
    end
    if not task then return 0 end

    local currentContribution = task.progressContributionAmount or 0
    if currentContribution == 0 then return 0 end

    local timesCompleted = task.timesCompleted or 0
    local nextRun = math.min(timesCompleted + 1, COMPLETIONS_TO_FLOOR)
    local currentDecay = self:GetDecayMultiplier(nextRun)

    return currentContribution / currentDecay
end

-- LEGACY: GetTaskInfo returns currentContribution as 'base' for backwards compatibility
-- TODO: Update callers to use GetCurrentContribution directly
function Tracker:GetTaskInfo(task)
    local currentContribution = self:GetCurrentContribution(task)
    return { base = currentContribution }
end

-- ============================================================================
-- CONTRIBUTION-BASED FORMULA (for Best Next Endeavor ranking)
-- Uses COMPLETIONS_TO_FLOOR as only hardcoded config value
-- ============================================================================

-- Calculate decay multiplier using formula derived from COMPLETIONS_TO_FLOOR
-- @param run: Which run this is (1 = first, 2 = second, etc.)
-- @return multiplier (0.0 to 1.0)
function Tracker:GetDecayMultiplier(run)
    if run < 1 then run = 1 end
    local floorPct = 1 / COMPLETIONS_TO_FLOOR  -- 0.20 for standard
    local decayRate = (1 - floorPct) / (COMPLETIONS_TO_FLOOR - 1)  -- 0.20 for standard
    return math.max(floorPct, 1 - decayRate * (run - 1))
end

-- Calculate next contribution using absolute scale (for rankings/tooltips)
-- Formula: NextContribution = progressContributionAmount × AbsoluteScale
-- progressContributionAmount is ALREADY DECAYED (changes with completions: 25→20→etc)
function Tracker:CalculateNextContribution(taskName, _completions)
    local task = self:GetTaskByName(taskName)
    if not task then return 0 end

    local timesCompleted = task.timesCompleted or 0
    local isAtFloor = timesCompleted >= COMPLETIONS_TO_FLOOR

    -- At floor: use observed floor XP directly (already has scale baked in)
    if isAtFloor then
        local rules = self.taskRules and self.taskRules[taskName]
        if rules and rules.floorXP and rules.floorXP > 0 then
            return rules.floorXP
        end
    end

    -- progressContributionAmount already has decay - just apply scale
    local apiContrib = task.progressContributionAmount or 0
    local absoluteScale = self:GetAbsoluteScale()
    return apiContrib * absoluteScale
end

-- Calculate floor XP for a task (what you'd earn at floor)
function Tracker:CalculateFloorXP(taskName)
    -- If we have observed floor XP, use it directly (from activity log)
    local rules = self.taskRules and self.taskRules[taskName]
    if rules and rules.floorXP and rules.floorXP > 0 then
        return rules.floorXP
    end

    -- No observed floor XP - can't calculate without reference point
    return 0
end

-- Calculate first run XP for a task (what you'd earn on first completion)
function Tracker:CalculateFirstRunXP(taskName)
    -- Derive from observed floor: firstRun = floor / floorPct = floor * 5
    local floorXP = self:CalculateFloorXP(taskName)
    if floorXP > 0 then
        return floorXP * COMPLETIONS_TO_FLOOR  -- floorXP / 0.20 = floorXP * 5
    end

    -- No observed data - can't calculate
    return 0
end

-- Get task rankings by next contribution value for current player
-- Returns: { [taskID] = { rank=1-3, nextXP=amount } } for top 3 only
function Tracker:GetTaskRankings()
    local tasks = HC.Store:GetState().tasks or {}
    local rankings = {}

    -- Build list of { taskID, nextXP, taskName } for incomplete repeatable tasks
    local taskList = {}
    for _, task in ipairs(tasks) do
        if task.isRepeatable and task.id and not task.completed then
            -- Use ACCOUNT-WIDE completions since DR is account-based
            local completions = self:GetAccountCompletionCount(task.id)
            -- Use contribution formula (with roster scale) for ranking
            local nextXP = self:CalculateNextContribution(task.name, completions)
            if nextXP > 0 then
                table.insert(taskList, {
                    id = task.id,
                    nextXP = nextXP,
                    name = task.name,
                    completions = completions,
                })
            end
        end
    end

    -- Sort by nextXP descending
    table.sort(taskList, function(a, b) return a.nextXP > b.nextXP end)

    -- Assign ranks with tie handling (tasks with same XP share rank)
    local currentRank = 0
    local lastXP = nil
    for _, task in ipairs(taskList) do
        -- New rank only if XP is different (using small epsilon for float comparison)
        if not lastXP or math.abs(task.nextXP - lastXP) > 0.0001 then
            currentRank = currentRank + 1
            lastXP = task.nextXP
        end
        -- Only include ranks 1-3 (gold/silver/bronze)
        if currentRank <= 3 then
            rankings[task.id] = {
                rank = currentRank,
                nextXP = task.nextXP,
                completions = task.completions,
            }
        else
            break  -- Stop once we've passed bronze
        end
    end

    return rankings
end

function Tracker:RequestActivityLog()
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.RequestInitiativeActivityLog then
        C_NeighborhoodInitiative.RequestInitiativeActivityLog()
    end
end

function Tracker:IsActivityLogLoaded()
    return self.activityLogLoaded
end

-- Manual refresh - ensures correct API call order for all data
function Tracker:RefreshAll()
    local debug = HC.Store:GetState().config.debug

    -- Cancel any pending retry timer
    if self.pendingRetryTimer then
        self.pendingRetryTimer:Cancel()
        self.pendingRetryTimer = nil
    end

    -- Update status
    self:UpdateFetchStatus("fetching", 0, nil)

    if not C_NeighborhoodInitiative then
        if debug then
            print("|cFFdc322f[VE Tracker]|r RefreshAll: C_NeighborhoodInitiative not available")
        end
        return
    end

    -- Request fresh data for current viewing neighborhood (don't change viewing context - respects Blizzard dashboard)
    if debug then
        print("|cFF2aa198[VE Tracker]|r RefreshAll: Requesting data for current viewing neighborhood")
    end
    C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
    self:RequestActivityLog()
end

-- ============================================================================
-- HOUSE SELECTION
-- ============================================================================

function Tracker:SelectHouse(index)
    if not self.houseList or #self.houseList == 0 then return end
    if index < 1 or index > #self.houseList then return end

    local houseInfo = self.houseList[index]
    if not houseInfo or not houseInfo.neighborhoodGUID then return end

    -- Cancel any pending retry from previous selection
    if self.pendingRetryTimer then
        self.pendingRetryTimer:Cancel()
        self.pendingRetryTimer = nil
    end

    self.selectedHouseIndex = index
    self.lastManualSelectionTime = GetTime()  -- Track when user manually changed selection
    -- Persist selection by houseGUID (stable across sessions, not fragile index)
    HC_DB = HC_DB or {}
    HC_DB.selectedHouseGUID = houseInfo.houseGUID
    self.currentHouseGUID = houseInfo.houseGUID
    local debug = HC.Store:GetState().config.debug

    if debug then
        print("|cFF2aa198[VE Tracker]|r Selecting house: " .. (houseInfo.houseName or "Unknown") .. " in neighborhood " .. tostring(houseInfo.neighborhoodGUID))
    end

    -- Update status to show we're fetching
    self:UpdateFetchStatus("fetching", 0, nil)

    -- Clear old data immediately when switching houses
    HC.Store:Dispatch("SET_TASKS", { tasks = {} })
    self.activityLogLoaded = false
    self.cachedAbsoluteScale = nil  -- Clear scale cache - each house has different roster size
    self.taskRules = {}             -- Clear task rules - will rebuild from new house's activity log

    -- Load persisted per-house XP data for immediate display while API refreshes
    HC_DB = HC_DB or {}
    local savedHouseData = HC_DB.houseData and HC_DB.houseData[houseInfo.houseGUID]
    if savedHouseData then
        self.cachedPlayerContribution = savedHouseData.playerContribution or 0
        self.cachedHouseXP = savedHouseData.houseXP or 0
    else
        self.cachedPlayerContribution = 0
        self.cachedHouseXP = 0
    end
    self.cachedHouseXPBreakdown = nil
    if HC.Vamoose and HC.Vamoose.ResetTracking then
        HC.Vamoose.ResetTracking()  -- Reset quote tracking for new house
    end
    HC.EventBus:Trigger("HC_ACTIVITY_LOG_UPDATED", { timestamp = nil })

    -- Update house GUID and request fresh level data for the selected house
    if houseInfo.houseGUID then
        HC.Store:Dispatch("SET_HOUSE_GUID", { houseGUID = houseInfo.houseGUID })
        if C_Housing and C_Housing.GetCurrentHouseLevelFavor then
            pcall(C_Housing.GetCurrentHouseLevelFavor, houseInfo.houseGUID)
        end
    end

    -- Only set viewing context (not active) - user must click "Set as Active" button
    if C_NeighborhoodInitiative then
        C_NeighborhoodInitiative.SetViewingNeighborhood(houseInfo.neighborhoodGUID)
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
        self:RequestActivityLog()

        -- INITIATIHC_ACTIVITY_LOG_UPDATED only marks stale (line ~147), never caches.
        -- Without this timer, switching houses left cachedActivityLog with old house's data.
        C_Timer.After(1.5, function()
            self:RefreshActivityLogCache()
            self:QueueDataRefresh()
        end)

        if debug then
            print("|cFF2aa198[VE Tracker]|r Called SetViewingNeighborhood and RequestNeighborhoodInitiativeInfo (not active yet)")
        end
    end
end

-- Set the currently selected house as the active endeavor
function Tracker:SetAsActiveEndeavor()
    if not self.selectedHouseIndex or not self.houseList then return end
    local houseInfo = self.houseList[self.selectedHouseIndex]
    if not houseInfo or not houseInfo.neighborhoodGUID then return end

    local debug = HC.Store:GetState().config.debug

    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.SetActiveNeighborhood then
        C_NeighborhoodInitiative.SetActiveNeighborhood(houseInfo.neighborhoodGUID)

        if debug then
            print("|cFF2aa198[VE Tracker]|r Set active neighborhood: " .. tostring(houseInfo.neighborhoodGUID))
        end

        -- Load persisted per-house XP, will recalculate from activity log after API responds
        self.currentHouseGUID = houseInfo.houseGUID
        HC_DB = HC_DB or {}
        local savedHouseData = HC_DB.houseData and HC_DB.houseData[houseInfo.houseGUID]
        if savedHouseData then
            self.cachedPlayerContribution = savedHouseData.playerContribution or 0
            self.cachedHouseXP = savedHouseData.houseXP or 0
        else
            self.cachedPlayerContribution = 0
            self.cachedHouseXP = 0
        end
        self.cachedHouseXPBreakdown = nil
        self.activityLogLoaded = false

        -- Notify user in chat
        print("|cFF2aa198[VE]|r Active Endeavor switched to |cFFffd700" .. (houseInfo.houseName or "Unknown") .. "|r. |cFFcb4b16All task progress/XP now applies to this house.|r")

        -- Set fetch status BEFORE firing event so UI shows "Loading..." state
        self:UpdateFetchStatus("fetching", 0, nil)

        -- Notify UI that active neighborhood changed
        HC.EventBus:Trigger("HC_ACTIHC_NEIGHBORHOOD_CHANGED")

        -- Request fresh data now that it's active
        C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
        self:RequestActivityLog()

        -- After API responds, refresh activity log cache and update UI (similar to task completion flow)
        C_Timer.After(1.5, function()
            self:RefreshActivityLogCache()
            self:QueueDataRefresh()
        end)
    end
end

function Tracker:GetHouseList()
    return self.houseList or {}
end

function Tracker:GetSelectedHouseIndex()
    return self.selectedHouseIndex or 1
end
