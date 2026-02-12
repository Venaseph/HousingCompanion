-- ============================================================================
-- VE_signatures.lua - API Reference
-- Function signatures for VamoosesEndeavors addon
-- ============================================================================

-- ============================================================================
-- Store.lua - Redux-lite state management
-- ============================================================================

HC.Store:GetState()                                  -- Returns current state table
HC.Store:RegisterReducer(action, reducerFn)          -- Register a reducer function for an action type
HC.Store:Dispatch(action, payload)                   -- Dispatch action to update state, triggers VE_STATE_CHANGED event
HC.Store:LoadFromSavedVariables()                    -- Load persisted state from VE_DB SavedVariables
HC.Store:SaveToSavedVariables()                      -- Save current state to VE_DB SavedVariables
HC.Store:QueueSave()                                 -- Queue a debounced save (1 second delay)
HC.Store:Flush()                                     -- Cancel pending save timer and save immediately

-- Built-in reducers (dispatch these actions):
-- "SET_CONFIG"                { key, value }        -- Update config setting
-- "SET_ENDEAVOR_INFO"         { seasonName, seasonEndTime, daysRemaining, currentProgress, maxProgress, milestones }
-- "SET_TASKS"                 { tasks }             -- Update endeavor tasks list
-- "UPDATE_CHARACTER_PROGRESS" { charKey, name, realm, class, tasks }
-- "SET_SELECTED_CHARACTER"    { charKey }           -- Change viewed character
-- "SET_HOUSE_GUID"            { houseGUID }         -- Cache current house GUID
-- "SET_HOUSE_LEVEL"           { level, xp, xpForNextLevel, maxLevel }
-- "SET_COUPONS"               { count, iconID }     -- Update community coupons

-- ============================================================================
-- EventBus.lua - Pub/Sub messaging
-- ============================================================================

HC.EventBus:Register(event, callback)                -- Register callback for event, returns nil
HC.EventBus:Trigger(event, payload)                  -- Fire event with optional payload to all listeners
HC.EventBus:Unregister(event, callback)              -- Remove specific callback, returns true/false

-- Internal events:
-- "VE_STATE_CHANGED"          { action, state }     -- Fired after Store:Dispatch
-- "VE_THEME_UPDATE"           { themeName }         -- Theme changed
-- "VE_ACTIVITY_LOG_UPDATED"                         -- Activity log data received

-- ============================================================================
-- Constants.lua - Theme and UI constants
-- ============================================================================

HC.Constants:GetThemeColors()                        -- Returns color scheme table for current theme
HC.Constants:ApplyTheme()                            -- Apply current theme to HC.Constants.Colors
HC.Constants:ToggleTheme()                           -- Cycle to next theme, returns new theme key
HC.Constants:GetCurrentTheme()                       -- Returns current theme key (e.g., "solarizeddark")
HC.Constants:GetColorCode(colorName)                 -- Returns WoW color code string "|cFFxxxxxx"

-- Tables:
-- HC.Constants.Colors         -- Current active color scheme
-- HC.Constants.UI             -- UI sizing constants (mainWidth, mainHeight, rowHeight, etc.)
-- HC.Constants.CURRENCY_IDS   -- Currency ID constants (COMMUNITY_COUPONS = 3363)
-- HC.Constants.ThemeOrder     -- Array of theme keys in cycle order
-- HC.Constants.ThemeNames     -- Map of theme key to scheme name
-- HC.Constants.ThemeDisplayNames -- Map of theme key to display name
-- HC.Colors.Schemes           -- All color scheme tables (SolarizedDark, SolarizedLight, etc.)

-- ============================================================================
-- Framework.lua - UI factory methods
-- ============================================================================

HC.UI:CreateMainFrame(name, title)                   -- Create main draggable window with title bar, returns frame
HC.UI:CreateButton(parent, text, width, height)      -- Create themed button, returns button frame
HC.UI:CreateTabButton(parent, text)                  -- Create tab button with active/inactive states, returns button
HC.UI:CreateProgressBar(parent, options)             -- Create progress bar with milestones, returns container
HC.UI:CreateTaskRow(parent, options)                 -- Create task row with status/points/progress, returns row
HC.UI:CreateDropdown(parent, options)                -- Create dropdown selector, returns container
HC.UI:CreateSectionHeader(parent, text)              -- Create section header with line, returns header frame
HC.UI:CreateScrollFrame(parent)                      -- Create scroll frame with styled scrollbar, returns scrollFrame, content
HC.UI:ColorCode(colorName)                           -- Returns WoW color code for named color "|cFFxxxxxx"

-- Widget methods:
-- progressBar:SetProgress(current, max)             -- Update progress bar fill and text
-- progressBar:SetMilestones(milestones, max)        -- Add milestone diamonds
-- taskRow:SetTask(task)                             -- Update row with task data
-- dropdown:SetItems(items)                          -- Set dropdown options [{key, label}]
-- dropdown:SetSelected(key, data)                   -- Set selected item
-- dropdown:GetSelected()                            -- Returns selected key
-- tabButton:SetActive(active)                       -- Set active state (boolean)

-- ============================================================================
-- ThemeEngine.lua - Live theme switching
-- ============================================================================

HC.Theme:Initialize()                                -- Initialize theme engine, listen for VE_THEME_UPDATE
HC.Theme:Register(widget, widgetType)                -- Register widget for theme updates
HC.Theme:UpdateAll()                                 -- Re-skin all registered widgets with current scheme
HC.Theme:GetScheme()                                 -- Returns current color scheme table
HC.Theme.ApplyTextShadow(fontString, scheme)         -- Apply/remove text shadow based on theme

-- Tables:
-- HC.Theme.registry           -- Weak table of registered widgets
-- HC.Theme.currentScheme      -- Current active color scheme
-- HC.Theme.Skinners           -- Skinner functions by widget type
-- HC.Theme.BACKDROP_FLAT      -- Standard backdrop with border
-- HC.Theme.BACKDROP_BORDERLESS -- Backdrop without border

-- Skinner types: Frame, Panel, Button, Text, SectionHeader, ProgressBar,
--                TaskRow, Dropdown, ScrollFrame, Checkbox, TitleBar, TabButton, HeaderText

-- ============================================================================
-- EndeavorTracker.lua - Endeavor data via C_NeighborhoodInitiative
-- ============================================================================

HC.EndeavorTracker:Initialize()                      -- Register events, setup listeners
HC.EndeavorTracker:FetchEndeavorData(skipRequest)    -- Fetch endeavor data, skipRequest=true skips API call
HC.EndeavorTracker:ProcessInitiativeInfo(info)       -- Process raw initiative info into Store
HC.EndeavorTracker:GetTaskProgress(task)             -- Extract current progress from task requirements
HC.EndeavorTracker:GetTaskMax(task)                  -- Extract max value from task requirements
HC.EndeavorTracker:GetTaskCouponReward(task)         -- Get coupon reward amount for task
HC.EndeavorTracker:RefreshTrackedTasks()             -- Update tracked status from API
HC.EndeavorTracker:LoadPlaceholderData()             -- Load fallback placeholder data
HC.EndeavorTracker:SaveCurrentCharacterProgress()    -- Save current character's task progress to Store
HC.EndeavorTracker:GetTrackedCharacters()            -- Returns array of tracked character info
HC.EndeavorTracker:GetCharacterProgress(charKey)     -- Returns character progress data or nil
HC.EndeavorTracker:TrackTask(taskID)                 -- Add task to objective tracker
HC.EndeavorTracker:UntrackTask(taskID)               -- Remove task from objective tracker
HC.EndeavorTracker:GetTaskLink(taskID)               -- Returns chat link for task or nil
HC.EndeavorTracker:GetActivityLogData()              -- Returns activity log info or nil
HC.EndeavorTracker:RequestActivityLog()              -- Request activity log from server
HC.EndeavorTracker:IsActivityLogLoaded()             -- Returns true if activity log has been loaded

-- ============================================================================
-- HousingTracker.lua - House level and currency via C_Housing
-- ============================================================================

HC.HousingTracker:Initialize()                       -- Register events for housing updates
HC.HousingTracker:RequestHouseInfo()                 -- Request house level/XP data from API
HC.HousingTracker:OnHouseListUpdated(houseInfoList)  -- Process PLAYER_HOUSE_LIST_UPDATED event
HC.HousingTracker:OnHouseLevelFavorUpdated(favor)    -- Process HOUSE_LEVEL_FAVOR_UPDATED event
HC.HousingTracker:UpdateCoupons()                    -- Fetch and dispatch community coupon count
HC.HousingTracker:GetHouseLevel()                    -- Returns level, xp, xpForNextLevel
HC.HousingTracker:GetCoupons()                       -- Returns coupons, couponsIcon
