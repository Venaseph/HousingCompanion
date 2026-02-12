-- ============================================================================
-- Vamoose's Endeavors - AltSharing
-- Inter-addon communication for grouping neighborhood contributions by player
-- Uses custom CHANNEL for cross-faction neighborhood messaging
-- ============================================================================

HC = HC or {}
HC.AltSharing = {}

local AltSharing = HC.AltSharing
local PREFIX = "HC_ALTS"
local PROTOCOL_VERSION = 2  -- v2: BattleTag-based grouping
local BROADCAST_INTERVAL = 300  -- 5 minutes between broadcasts
local MAX_MESSAGE_LENGTH = 255
local CHANNEL_PREFIX = "VEN"  -- Neighborhood-specific channel prefix

AltSharing.frame = CreateFrame("Frame")
AltSharing.altToMainLookup = {}  -- Reverse lookup: { [charName] = "Main-Realm" }
AltSharing.knownAddonUsers = {}  -- Track characters from players with addon: { [charName] = true }
AltSharing.currentChannel = nil  -- Current neighborhood channel name
AltSharing.currentChannelNum = nil  -- Current channel number
AltSharing.battleTagLookup = {}  -- { [charName] = battleTag }
AltSharing.battleTagMains = {}   -- { [battleTag] = { main1, main2, ... } } - configured mains per BattleTag

-- ============================================================================
-- HASH FUNCTION - One-way hash for neighborhood GUID → channel name
-- ============================================================================

-- Simple djb2 hash function (deterministic, one-way)
local function HashString(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 0x7FFFFFFF
    end
    return hash
end

-- Convert hash to alphanumeric string (base36-ish)
local function HashToChannelSuffix(guid)
    if not guid or guid == "" then return nil end
    local hash = HashString(guid)
    -- Convert to 6-char alphanumeric (a-z, 0-9)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, 6 do
        local idx = (hash % 36) + 1
        result = result .. chars:sub(idx, idx)
        hash = math.floor(hash / 36)
    end
    return result
end

-- Get channel name for a neighborhood GUID
function AltSharing:GetChannelNameForNeighborhood(neighborhoodGUID)
    if not neighborhoodGUID then return nil end
    local suffix = HashToChannelSuffix(neighborhoodGUID)
    if not suffix then return nil end
    return CHANNEL_PREFIX .. suffix  -- e.g., "VENa7b3f2"
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function AltSharing:Initialize()
    local registered = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    if not registered then
        if HC.Store:GetState().config.debug then
            print("|cFFdc322f[VE AltSharing]|r Failed to register addon message prefix")
        end
    end

    -- Load persisted BattleTag data from SavedVariables
    self:LoadPersistedBattleTagData()

    self.frame:RegisterEvent("CHAT_MSG_ADDON")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("CHANNEL_UI_UPDATE")

    self.frame:SetScript("OnEvent", function(frame, event, ...)
        self:OnEvent(event, ...)
    end)

    -- Listen for state changes to trigger broadcasts
    HC.EventBus:Register("HC_STATE_CHANGED", function(payload)
        if payload.action == "SET_ALT_SHARING_ENABLED" or
           payload.action == "SET_MAIN_CHARACTER" then
            self:OnConfigChanged()
        end
    end)

    -- Build initial lookup for local grouping
    self:BuildAltToMainLookup()

    -- Join neighborhood-specific channel for cross-faction sync (only if alt sharing enabled)
    -- Delay 12s so all system channels (General, Trade, Services, etc.) register first
    -- and our temporary channel naturally gets the last slot
    C_Timer.After(12, function()
        if HC.Store:GetState().altSharing.enabled then
            self:JoinNeighborhoodChannel()
        end
    end)

    -- Listen for neighborhood changes to switch channels
    HC.EventBus:Register("HC_NEIGHBORHOOD_CHANGED", function()
        if HC.Store:GetState().altSharing.enabled then
            self:JoinNeighborhoodChannel()
        end
    end)

    if HC.Store:GetState().config.debug then
        print("|cFF2aa198[VE AltSharing]|r Initialized (neighborhood-scoped channels)")
    end
end

-- Load BattleTag mappings from SavedVariables (enables cross-faction grouping)
function AltSharing:LoadPersistedBattleTagData()
    if not HC_DB then HC_DB = {} end

    -- Load persisted battleTagLookup: { [charName] = battleTag }
    if HC_DB.battleTagLookup then
        for charName, battleTag in pairs(HC_DB.battleTagLookup) do
            self.battleTagLookup[charName] = battleTag
        end
    end

    -- Load persisted battleTagMains: { [battleTag] = { main1, main2, ... } }
    if HC_DB.battleTagMains then
        for battleTag, mains in pairs(HC_DB.battleTagMains) do
            self.battleTagMains[battleTag] = mains
        end
    end

    if HC.Store and HC.Store:GetState().config.debug then
        local btCount = 0
        for _ in pairs(self.battleTagLookup) do btCount = btCount + 1 end
        print("|cFF2aa198[VE AltSharing]|r Loaded", btCount, "persisted BattleTag mappings")
    end
end

-- Save BattleTag mappings to SavedVariables
function AltSharing:SaveBattleTagData()
    if not HC_DB then HC_DB = {} end
    HC_DB.battleTagLookup = self.battleTagLookup
    HC_DB.battleTagMains = self.battleTagMains
end

-- Get current neighborhood GUID
function AltSharing:GetCurrentNeighborhoodGUID()
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetActiveNeighborhood then
        return C_NeighborhoodInitiative.GetActiveNeighborhood()
    end
    return nil
end

-- Join neighborhood-specific channel (leaves old channel if switching)
function AltSharing:JoinNeighborhoodChannel()
    local debug = HC.Store:GetState().config.debug
    local neighborhoodGUID = self:GetCurrentNeighborhoodGUID()

    if not neighborhoodGUID then
        if debug then
            print("|cFF2aa198[VE AltSharing]|r No active neighborhood, skipping channel join")
        end
        return
    end

    local channelName = self:GetChannelNameForNeighborhood(neighborhoodGUID)
    if not channelName then
        if debug then
            print("|cFFdc322f[VE AltSharing]|r Failed to generate channel name for neighborhood")
        end
        return
    end

    -- If we're already in the correct channel, just broadcast and return
    local existingNum = GetChannelName(channelName)
    if existingNum and existingNum > 0 then
        self.currentChannel = channelName
        self.currentChannelNum = existingNum
        if debug then
            print("|cFF2aa198[VE AltSharing]|r Already in channel " .. channelName .. " (#" .. existingNum .. ")")
        end
        -- Hide from chat frames and broadcast
        for i = 1, NUM_CHAT_WINDOWS do
            local cf = _G["ChatFrame" .. i]
            if cf then ChatFrame_RemoveChannel(cf, channelName) end
        end
        self:BroadcastIfEnabled()
        return
    end

    -- Leave any OTHER VEN channels (switching neighborhoods or cleaning up old permanent channels)
    local leftCount = 0
    for i = 1, 20 do
        local _, name = GetChannelName(i)
        if name and name:sub(1, #CHANNEL_PREFIX) == CHANNEL_PREFIX then
            LeaveChannelByName(name)
            leftCount = leftCount + 1
            if debug then
                print("|cFF2aa198[VE AltSharing]|r Left channel " .. name .. " (cleanup)")
            end
        end
    end
    self.currentChannel = nil
    self.currentChannelNum = nil

    -- Join after confirmed leave (event-driven) or fallback timer
    local joined = false
    local function doJoin()
        if joined then return end
        joined = true
        JoinTemporaryChannel(channelName)
    end

    if leftCount > 0 then
        -- Listen for YOU_LEFT confirmation before re-joining
        local leaveConfirmed = 0
        local noticeFrame = CreateFrame("Frame")
        noticeFrame:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
        noticeFrame:SetScript("OnEvent", function(f, _, noticeType, _, _, _, _, _, _, _, channelBaseName)
            if noticeType == "YOU_LEFT" and channelBaseName and channelBaseName:sub(1, #CHANNEL_PREFIX) == CHANNEL_PREFIX then
                leaveConfirmed = leaveConfirmed + 1
                if debug then
                    print("|cFF2aa198[VE AltSharing]|r Confirmed left: " .. channelBaseName .. " (" .. leaveConfirmed .. "/" .. leftCount .. ")")
                end
                if leaveConfirmed >= leftCount then
                    f:UnregisterEvent("CHAT_MSG_CHANNEL_NOTICE")
                    f:SetScript("OnEvent", nil)
                    doJoin()
                end
            end
        end)
        -- Fallback timer in case event doesn't fire
        C_Timer.After(2, function()
            noticeFrame:UnregisterEvent("CHAT_MSG_CHANNEL_NOTICE")
            noticeFrame:SetScript("OnEvent", nil)
            doJoin()
        end)
    else
        doJoin()
    end

    -- Verify join after everything settles
    C_Timer.After(leftCount > 0 and 3 or 1, function()
        local num = GetChannelName(channelName)
        if num and num > 0 then
            self.currentChannel = channelName
            self.currentChannelNum = num
            -- Hide channel from all chat frames so it doesn't clutter user's channel list
            for i = 1, NUM_CHAT_WINDOWS do
                local cf = _G["ChatFrame" .. i]
                if cf then ChatFrame_RemoveChannel(cf, channelName) end
            end
            if debug then
                print("|cFF2aa198[VE AltSharing]|r Joined neighborhood channel " .. channelName .. " (#" .. num .. ")")
            end
            -- Broadcast immediately after joining
            self:BroadcastIfEnabled()
            -- Best-effort push channel to last position (bubble swap down)
            local function pushToLastSlot()
                local curNum = GetChannelName(channelName)
                if not curNum or curNum <= 0 then return end
                -- Find highest occupied channel index
                local maxIdx = curNum
                for ci = curNum + 1, 20 do
                    local cName = GetChannelName(ci)
                    if cName and cName ~= "" then maxIdx = ci end
                end
                if curNum >= maxIdx then return end -- already at or past last
                if debug then
                    print("|cFF2aa198[VE AltSharing]|r Bubbling channel from #" .. curNum .. " toward #" .. maxIdx)
                end
                for ci = curNum, maxIdx - 1 do
                    C_ChatInfo.SwapChatChannelsByChannelIndex(ci, ci + 1)
                end
            end
            C_Timer.After(3, pushToLastSlot)  -- first attempt
            C_Timer.After(12, pushToLastSlot) -- second attempt after things settle
        else
            if debug then
                print("|cFFdc322f[VE AltSharing]|r Failed to join channel " .. channelName)
            end
        end
    end)
end

-- ============================================================================
-- EVENT HANDLING
-- ============================================================================

function AltSharing:OnEvent(event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == PREFIX then
            self:OnAddonMessage(message, channel, sender)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, function()
            self:OnEnterWorld()
        end)
    end
end

function AltSharing:OnEnterWorld()
    if HC.Store:GetState().config.debug then
        print("|cFF2aa198[VE AltSharing]|r OnEnterWorld called")
    end

    -- Clean up stale mappings from ended initiatives
    local currentInitiativeId = self:GetCurrentInitiativeId()
    if currentInitiativeId then
        HC.Store:Dispatch("CLEAR_STALE_MAPPINGS", { activeInitiativeId = currentInitiativeId })
    end

    -- Broadcast to guild if enabled
    self:BroadcastIfEnabled()
end

function AltSharing:OnConfigChanged()
    local state = HC.Store:GetState()
    if state.altSharing.enabled then
        -- Reset rate limit to allow immediate broadcast on config change
        HC.Store:Dispatch("SET_LAST_BROADCAST", { timestamp = 0 })
        self:JoinNeighborhoodChannel()
        self:BroadcastIfEnabled()
    else
        -- Leave channel when alt sharing is disabled
        if self.currentChannel then
            LeaveChannelByName(self.currentChannel)
            self.currentChannel = nil
            self.currentChannelNum = nil
        end
    end
end

-- ============================================================================
-- MESSAGE SENDING
-- ============================================================================

function AltSharing:BroadcastIfEnabled()
    local state = HC.Store:GetState()
    local debug = state.config.debug

    if not state.altSharing.enabled then
        if debug then print("|cFF2aa198[VE AltSharing]|r Broadcast skipped: sharing not enabled") end
        return
    end

    -- Rate limit broadcasts
    local now = time()
    if (now - state.altSharing.lastBroadcast) < BROADCAST_INTERVAL then
        if debug then print("|cFF2aa198[VE AltSharing]|r Broadcast skipped: rate limited") end
        return
    end

    -- Ensure we're in a neighborhood channel
    if not self.currentChannel or not self.currentChannelNum then
        self:JoinNeighborhoodChannel()
        if debug then print("|cFF2aa198[VE AltSharing]|r Broadcast skipped: joining neighborhood channel...") end
        return
    end

    -- Verify we're still in the channel
    local channelNum = GetChannelName(self.currentChannel)
    if not channelNum or channelNum == 0 then
        if debug then print("|cFF2aa198[VE AltSharing]|r Broadcast skipped: not in channel") end
        self:JoinNeighborhoodChannel()
        return
    end

    local initiativeId = self:GetCurrentInitiativeId() or 0
    local battleTagHash = self:GetBattleTagHash()  -- Privacy-safe hash, not raw BattleTag
    local mainName = self:GetMainName()
    local charName = UnitName("player")

    -- Format v2: VERSION^INITIATIHC_ID^BATTLETAGHASH^MAIN^CHARNAME
    local message = string.format("%d^%d^%s^%s^%s",
        PROTOCOL_VERSION, initiativeId, battleTagHash or "UNKNOWN", mainName, charName)

    -- Truncate if too long
    if #message > MAX_MESSAGE_LENGTH then
        message = message:sub(1, MAX_MESSAGE_LENGTH)
    end

    -- Send to neighborhood-specific channel (same-faction only, but persisted data bridges factions)
    local success = C_ChatInfo.SendAddonMessage(PREFIX, message, "CHANNEL", channelNum)
    local method = "CHANNEL " .. self.currentChannel .. " (#" .. channelNum .. ")"

    HC.Store:Dispatch("SET_LAST_BROADCAST", { timestamp = now })

    if debug then
        print("|cFF2aa198[VE AltSharing]|r Broadcast sent via " .. method .. " (success=" .. tostring(success) .. ")")
        print("|cFF2aa198[VE AltSharing]|r Message:", message:sub(1, 100))
    end
end

function AltSharing:GetBattleTag()
    local _, battleTag = BNGetInfo()
    return battleTag  -- Format: "Name#1234" or nil if not available
end

-- Get a privacy-safe hash of the BattleTag (one-way, can't be reversed)
-- Same BattleTag always produces the same hash for grouping purposes
function AltSharing:GetBattleTagHash()
    local battleTag = self:GetBattleTag()
    if not battleTag then return nil end
    -- Use the same hash function as neighborhood channels, produce 8-char hash
    local hash = HashString(battleTag)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, 8 do
        local idx = (hash % 36) + 1
        result = result .. chars:sub(idx, idx)
        hash = math.floor(hash / 36)
    end
    return result  -- e.g., "a7f3b2c9" instead of "Vamoose#1321"
end

function AltSharing:GetBattleTagName()
    local battleTag = self:GetBattleTag()
    if battleTag then
        return battleTag:match("^([^#]+)")  -- Strip the #1234 part
    end
    return nil
end

function AltSharing:GetMainName()
    local state = HC.Store:GetState()
    if state.altSharing.mainCharacter then
        -- Extract just the name part (no realm)
        return state.altSharing.mainCharacter:match("^([^-]+)") or state.altSharing.mainCharacter
    end
    -- Use current character name as default
    return UnitName("player")
end

function AltSharing:GetMainCharacterKey()
    local state = HC.Store:GetState()
    if state.altSharing.mainCharacter then
        return state.altSharing.mainCharacter
    end
    -- Use current character as pseudo-main
    local name = UnitName("player")
    local realm = GetNormalizedRealmName() or GetRealmName():gsub("%s", "")
    return name .. "-" .. realm
end

function AltSharing:BuildAltsString()
    local alts = {}
    local state = HC.Store:GetState()

    -- Build set of characters with contributions > 0 from activity log
    local hasContribution = {}
    local activityData = HC.EndeavorTracker and HC.EndeavorTracker:GetActivityLogData()
    if activityData and activityData.taskActivity then
        for _, entry in ipairs(activityData.taskActivity) do
            if entry.playerName and (entry.amount or 0) > 0 then
                hasContribution[entry.playerName] = true
            end
        end
    end

    -- Only include characters that have contributed
    for _, charData in pairs(state.characters) do
        if charData.name and charData.realm and hasContribution[charData.name] then
            local realmNormalized = charData.realm:gsub("%s", "")
            table.insert(alts, charData.name .. "-" .. realmNormalized)
        end
    end

    -- Sort alphabetically for consistency
    table.sort(alts)

    return table.concat(alts, ",")
end

-- ============================================================================
-- MESSAGE RECEIVING
-- ============================================================================

function AltSharing:OnAddonMessage(message, channel, sender)
    -- Don't process our own messages
    local myName = UnitName("player")
    local senderName = sender:match("^([^-]+)")
    if senderName == myName then return end

    local debug = HC.Store:GetState().config.debug
    if debug then
        print("|cFF2aa198[VE AltSharing]|r Received from:", sender, "channel:", channel)
    end

    -- Try v2 format first: VERSION^INITIATIHC_ID^BATTLETAG^MAIN^CHARNAME
    local version, initiativeId, battleTag, mainName, charName = message:match("^(%d+)%^(%d+)%^([^^]+)%^([^^]+)%^(.+)$")

    if version and tonumber(version) >= 2 then
        -- v2 BattleTag-based message
        initiativeId = tonumber(initiativeId)

        -- Store BattleTag mapping for this character AND the main
        if battleTag and battleTag ~= "UNKNOWN" then
            self.battleTagLookup[charName] = battleTag
            -- Also map the main character name to this BattleTag (main is likely a contributor too)
            if mainName and mainName ~= "" then
                self.battleTagLookup[mainName] = battleTag
            end

            -- Store configured main for this BattleTag (replace, not accumulate)
            self.battleTagMains[battleTag] = { mainName }
        end

        -- Track addon user (both char and main)
        self.knownAddonUsers[charName] = true
        if mainName and mainName ~= "" then
            self.knownAddonUsers[mainName] = true
        end

        -- Persist BattleTag data to SavedVariables (enables cross-faction grouping)
        self:SaveBattleTagData()

        -- Rebuild lookups
        self:BuildAltToMainLookup()

        -- Notify leaderboard to update
        HC.EventBus:Trigger("HC_ALT_MAPPING_UPDATED")

        if debug then
            print("|cFF2aa198[VE AltSharing]|r v2 BattleTag:", battleTag, "main:", mainName, "char:", charName)
        end
        return
    end

    -- Fall back to v1 format: VERSION^INITIATIHC_ID^MAIN-REALM^ALT1-REALM,ALT2-REALM,...
    local v1version, v1initiativeId, mainChar, altsStr = message:match("^(%d+)%^(%d+)%^([^^]+)%^(.*)$")
    if not v1version then return end

    v1version = tonumber(v1version)
    v1initiativeId = tonumber(v1initiativeId)

    -- Parse alts
    local alts = {}
    if altsStr and #altsStr > 0 then
        for alt in altsStr:gmatch("[^,]+") do
            table.insert(alts, alt)
        end
    end

    -- Store mapping (legacy v1 format)
    HC.Store:Dispatch("UPDATE_RECEIVED_MAPPING", {
        mainCharacter = mainChar,
        alts = alts,
        initiativeId = v1initiativeId,
    })

    -- Track addon users (main + all alts have the addon)
    local mainNameV1 = mainChar:match("^([^-]+)")
    if mainNameV1 then
        self.knownAddonUsers[mainNameV1] = true
    end
    for _, altKey in ipairs(alts) do
        local altName = altKey:match("^([^-]+)")
        if altName then
            self.knownAddonUsers[altName] = true
        end
    end

    -- Rebuild reverse lookup
    self:BuildAltToMainLookup()

    -- Notify leaderboard to update
    HC.EventBus:Trigger("HC_ALT_MAPPING_UPDATED")

    if debug then
        print("|cFF2aa198[VE AltSharing]|r v1 mapping from", mainChar, "with", #alts, "alts")
    end
end

-- ============================================================================
-- GROUPING UTILITIES
-- ============================================================================

function AltSharing:BuildAltToMainLookup()
    self.altToMainLookup = {}
    local state = HC.Store:GetState()

    -- Add received mappings (name-only keys for activity log matching)
    -- Also mark these players as having the addon (restore from persisted data)
    for mainChar, data in pairs(state.altSharing.receivedMappings) do
        local mainName = mainChar:match("^([^-]+)")
        if mainName then
            self.altToMainLookup[mainName] = mainChar
            self.knownAddonUsers[mainName] = true
        end
        for _, altKey in ipairs(data.alts or {}) do
            local altName = altKey:match("^([^-]+)")
            if altName then
                self.altToMainLookup[altName] = mainChar
                self.knownAddonUsers[altName] = true
            end
        end
    end

    -- Always add our own alts for local grouping (independent of sharing)
    local ourMain = self:GetMainCharacterKey()
    local ourMainName = ourMain:match("^([^-]+)")
    local ourBattleTagHash = self:GetBattleTagHash()  -- Use hash for privacy

    if ourMainName then
        self.altToMainLookup[ourMainName] = ourMain
        self.knownAddonUsers[ourMainName] = true  -- We have the addon
    end

    -- Add BattleTag hash mapping for our own characters
    if ourBattleTagHash then
        local currentChar = UnitName("player")
        self.battleTagLookup[currentChar] = ourBattleTagHash
        -- Also map our configured main to BattleTag hash (main is likely a contributor)
        local ourConfiguredMain = self:GetMainName()
        if ourConfiguredMain then
            self.battleTagLookup[ourConfiguredMain] = ourBattleTagHash
        end
        -- Store our configured main for this BattleTag hash (replace, not accumulate)
        self.battleTagMains[ourBattleTagHash] = { ourConfiguredMain }
    end

    -- Add from HC_DB.myCharacters (all logged-in characters)
    local myChars = HC_DB and HC_DB.myCharacters or {}
    for charName, _ in pairs(myChars) do
        self.altToMainLookup[charName] = ourMain
        self.knownAddonUsers[charName] = true  -- Our alts have the addon
        if ourBattleTagHash then
            self.battleTagLookup[charName] = ourBattleTagHash
        end
    end
    -- Also add from state.characters (has more detail)
    for charKey, charData in pairs(state.characters) do
        if charData.name then
            self.altToMainLookup[charData.name] = ourMain
            self.knownAddonUsers[charData.name] = true  -- Our alts have the addon
            if ourBattleTagHash then
                self.battleTagLookup[charData.name] = ourBattleTagHash
            end
        end
    end

    -- Persist our BattleTag mappings (enables cross-faction grouping via shared SavedVariables)
    self:SaveBattleTagData()
end

-- Resolve a character name to their main (name-only lookup for activity log)
function AltSharing:ResolveToMain(charName)
    return self.altToMainLookup[charName] or charName
end

-- Check if a character is from a player with the addon installed
function AltSharing:HasAddon(charName)
    return self.knownAddonUsers[charName] == true
end

-- Apply grouping to contribution data
-- Returns: grouped contributions table, groupedNames table (maps displayKey -> list of char entries)
function AltSharing:GroupContributions(contributions)
    local state = HC.Store:GetState()
    if state.altSharing.groupingMode ~= "byMain" then
        return contributions, nil
    end

    -- Rebuild lookup to ensure it's current
    self:BuildAltToMainLookup()

    local debug = state.config.debug
    if debug then
        local btCount = 0
        for _ in pairs(self.battleTagLookup) do btCount = btCount + 1 end
        print("|cFF2aa198[VE AltSharing]|r GroupContributions: BattleTag lookup has", btCount, "entries")
    end

    local grouped = {}
    local groupedNames = {}  -- { [displayKey] = { {name="Char1", amount=X}, ... } }
    local groupKeyToBattleTag = {}  -- Track which groupKey maps to which BattleTag

    for charName, amount in pairs(contributions) do
        local groupKey
        local battleTag = self.battleTagLookup[charName]

        if not battleTag then
            -- Check if resolved main has a BattleTag (prevents split grouping)
            local mainKey = self:ResolveToMain(charName)
            local mainName = mainKey:match("^([^-]+)") or mainKey
            battleTag = self.battleTagLookup[mainName]
        end

        if battleTag then
            -- Use "BT:BattleTag" as group key to distinguish from character names
            groupKey = "BT:" .. battleTag
            groupKeyToBattleTag[groupKey] = battleTag
        else
            -- Fall back to old main-based grouping (no prefix = character name)
            local mainKey = self:ResolveToMain(charName)
            groupKey = mainKey:match("^([^-]+)") or mainKey
        end

        grouped[groupKey] = (grouped[groupKey] or 0) + amount

        -- Track which characters are in this group with their contributions
        if not groupedNames[groupKey] then
            groupedNames[groupKey] = {}
        end
        -- Add char if not already in list
        local found = false
        for _, entry in ipairs(groupedNames[groupKey]) do
            if entry.name == charName then found = true break end
        end
        if not found then
            table.insert(groupedNames[groupKey], { name = charName, amount = amount })
        end
    end

    -- Build display names for BattleTag groups (show multiple mains if different accounts)
    local displayNames = {}
    for groupKey, _ in pairs(groupedNames) do
        local battleTag = groupKeyToBattleTag[groupKey]
        if battleTag and self.battleTagMains[battleTag] and #self.battleTagMains[battleTag] > 0 then
            -- Use configured mains (e.g., "Vamoose, Gypsypip")
            local mains = self.battleTagMains[battleTag]
            if #mains > 1 then
                displayNames[groupKey] = table.concat(mains, ", ")
            else
                displayNames[groupKey] = mains[1]
            end
        elseif battleTag then
            -- BattleTag exists but no configured mains - use first character name in group
            if groupedNames[groupKey] and #groupedNames[groupKey] > 0 then
                displayNames[groupKey] = groupedNames[groupKey][1].name
            else
                displayNames[groupKey] = groupKey
            end
        else
            -- No BattleTag - use the group key itself (character/main name)
            displayNames[groupKey] = groupKey
        end
    end

    -- Attach display names to groupedNames for Leaderboard to use
    for groupKey, _ in pairs(groupedNames) do
        groupedNames[groupKey].displayName = displayNames[groupKey]
    end

    -- Sort each group by contribution (highest first)
    for _, entries in pairs(groupedNames) do
        table.sort(entries, function(a, b)
            return a.amount > b.amount
        end)
    end

    if HC.Store:GetState().config.debug then
        local groupCount = 0
        for displayName, entries in pairs(groupedNames) do
            groupCount = groupCount + 1
            if #entries > 1 then
                -- Extract names from {name, amount} entries for display
                local nameList = {}
                for _, entry in ipairs(entries) do
                    local name = type(entry) == "table" and entry.name or entry
                    table.insert(nameList, name)
                end
                print("|cFF2aa198[VE AltSharing]|r Group '" .. displayName .. "': " .. table.concat(nameList, ", "))
            end
        end
        print("|cFF2aa198[VE AltSharing]|r Grouped into", groupCount, "entries")
    end

    return grouped, groupedNames
end

-- ============================================================================
-- HELPERS
-- ============================================================================

function AltSharing:GetCurrentInitiativeId()
    if HC.EndeavorTracker and HC.EndeavorTracker.GetCurrentInitiativeId then
        return HC.EndeavorTracker:GetCurrentInitiativeId()
    end
    -- Fallback: try to get from API directly
    if C_NeighborhoodInitiative and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo then
        local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()
        if info and info.initiativeID and info.initiativeID > 0 then
            return info.initiativeID
        end
    end
    return nil
end
