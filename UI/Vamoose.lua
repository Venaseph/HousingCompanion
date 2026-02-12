-- ============================================================================
-- Vamoose's Endeavors - Vamoose Module
-- Squirrel talking head for endeavor task quotes
-- ============================================================================

-- Use global VE namespace (matches Init.lua pattern)
HC = HC or {}

HC.Vamoose = {}

-- ============================================================================
-- TALKING HEAD FRAME
-- Custom talking head display for endeavor quotes
-- ============================================================================

local VamooseHead = CreateFrame("Frame", "HC_VamooseTalkingHead", UIParent)
VamooseHead:SetSize(570, 155)
VamooseHead:SetPoint("TOP", UIParent, "TOP", 0, -200)
VamooseHead:Hide()
VamooseHead:SetFrameStrata("DIALOG")

-- Background texture
local vamooseBg = VamooseHead:CreateTexture(nil, "BACKGROUND")
vamooseBg:SetPoint("TOPLEFT", 0, 0)
vamooseBg:SetPoint("BOTTOMRIGHT", 0, 0)

-- Portrait frame overlay
local vamoosePortraitFrame = VamooseHead:CreateTexture(nil, "OVERLAY")
vamoosePortraitFrame:SetSize(143, 143)
vamoosePortraitFrame:SetPoint("TOPLEFT", 5, -6)

-- 3D Model frame
local vamooseModel = CreateFrame("PlayerModel", nil, VamooseHead)
vamooseModel:SetSize(115, 115)
vamooseModel:SetPoint("TOPLEFT", 19, -20)
vamooseModel:SetFrameStrata("DIALOG")
vamooseModel:SetFrameLevel(VamooseHead:GetFrameLevel() + 1)

-- Name text
local vamooseNameText = VamooseHead:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
vamooseNameText:SetPoint("TOPLEFT", 160, -28)
vamooseNameText:SetTextColor(1, 0.82, 0) -- Gold

-- Body text
local vamooseBodyText = VamooseHead:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
vamooseBodyText:SetPoint("TOPLEFT", 160, -55)
vamooseBodyText:SetWidth(380)
vamooseBodyText:SetJustifyH("LEFT")
vamooseBodyText:SetWordWrap(true)

-- Play a quote with the talking head
local function PlayTalkingHead(quote)
    if not HC.EndeavorQuotes or not HC.EndeavorQuotes.SPEAKER then return end

    local speaker = HC.EndeavorQuotes.SPEAKER
    -- Check for alternate mascot display (synced from MainFrame)
    local displayID = HC.MascotDisplayID or speaker.displayID
    local speakerName = (displayID == 64016) and "Nestor" or "Robo-Nestor"

    -- Set backdrop art (GarrFollower style - golden/bronze)
    vamooseBg:SetAtlas("TalkingHeads-GarrFollower-TextBackground")
    vamoosePortraitFrame:SetAtlas("TalkingHeads-GarrFollower-PortraitFrame")

    -- Setup 3D model
    vamooseModel:ClearModel()
    vamooseModel:SetDisplayInfo(displayID)
    vamooseModel:SetPortraitZoom(0.8)
    vamooseModel:SetCamDistanceScale(1.0)
    vamooseModel:SetPosition(0, 0, 0)

    -- Lighting for WoW 12.x
    local lightValues = {
        omnidirectional = false,
        point = CreateVector3D(-1, 0, -1),
        ambientIntensity = 0.7,
        ambientColor = CreateColor(0.7, 0.7, 0.7),
        diffuseIntensity = 1.0,
        diffuseColor = CreateColor(0.8, 0.8, 0.8),
    }
    vamooseModel:SetLight(true, lightValues)
    vamooseModel:SetAnimation(60) -- Talking animation

    -- Set text with speaker name
    vamooseNameText:SetText(speakerName)
    vamooseBodyText:SetText(quote)

    -- Show with fade in
    VamooseHead:Show()
    VamooseHead:SetAlpha(0)
    UIFrameFadeIn(VamooseHead, 0.3, 0, 1)

    -- Auto-hide after 5 seconds
    if VamooseHead.timer then VamooseHead.timer:Cancel() end
    VamooseHead.timer = C_Timer.NewTimer(5, function()
        UIFrameFadeOut(VamooseHead, 0.5, 1, 0)
        C_Timer.After(0.5, function() VamooseHead:Hide() end)
    end)
end

-- ============================================================================
-- QUOTE TRACKING
-- Track which tasks have shown quotes to avoid spam
-- ============================================================================

local shownCompletionQuotes = {} -- taskID -> true
local shownProgressQuotes = {}   -- taskID -> true

local PROGRESS_QUOTE_CHANCE = 0.15 -- 15% chance per progress update

-- Reset tracking (on house switch or new endeavor)
function HC.Vamoose.ResetTracking()
    shownCompletionQuotes = {}
    shownProgressQuotes = {}
end

-- Get a random quote from a category
local function GetRandomQuote(category)
    if not HC.EndeavorQuotes or not HC.EndeavorQuotes[category] then
        return nil
    end
    local quotes = HC.EndeavorQuotes[category]
    if #quotes == 0 then return nil end
    return quotes[math.random(#quotes)]
end

-- Check if quotes are enabled
local function QuotesEnabled()
    local state = HC.Store and HC.Store:GetState()
    if not state then return true end -- Default to enabled
    return state.config.quotesEnabled ~= false
end

-- Check if chat-only mode
local function ChatOnlyMode()
    local state = HC.Store and HC.Store:GetState()
    if not state then return false end
    return state.config.quotesOnlyChat == true
end

-- Display a quote (talking head or chat)
local function DisplayQuote(quote)
    if not quote then return end

    if ChatOnlyMode() then
        -- Brown color for squirrel in chat
        local displayID = HC.MascotDisplayID or 64016
        local name = (displayID == 64016) and "Nestor" or "Robo-Nestor"
        print("|cFFA0522D[" .. name .. "]|r " .. quote)
    else
        PlayTalkingHead(quote)
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- Called from EndeavorTracker when task events occur
-- ============================================================================

-- Called when a task is completed
function HC.Vamoose.OnTaskCompleted(taskID, taskName)
    if not QuotesEnabled() then return end
    if not taskID then return end

    -- Only show once per task
    if shownCompletionQuotes[taskID] then return end

    local quote = GetRandomQuote("COMPLETION")
    if quote then
        shownCompletionQuotes[taskID] = true
        DisplayQuote(quote)
    end
end

-- Called when task progress is updated
function HC.Vamoose.OnTaskProgress(taskID, taskName, current, max)
    if not QuotesEnabled() then return end
    if not taskID then return end

    -- Only show once per task, with random chance
    if shownProgressQuotes[taskID] then return end

    -- Skip if task is already complete or no progress
    if not current or not max or current >= max then return end

    -- Random chance to show quote
    if math.random() < PROGRESS_QUOTE_CHANCE then
        local quote = GetRandomQuote("PROGRESS")
        if quote then
            shownProgressQuotes[taskID] = true
            DisplayQuote(quote)
        end
    end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

-- Get completion quote count
function HC.Vamoose.GetCompletionQuoteCount()
    if not HC.EndeavorQuotes or not HC.EndeavorQuotes.COMPLETION then return 0 end
    return #HC.EndeavorQuotes.COMPLETION
end

-- Get progress quote count
function HC.Vamoose.GetProgressQuoteCount()
    if not HC.EndeavorQuotes or not HC.EndeavorQuotes.PROGRESS then return 0 end
    return #HC.EndeavorQuotes.PROGRESS
end

-- Get total quote count
function HC.Vamoose.GetTotalQuoteCount()
    return HC.Vamoose.GetCompletionQuoteCount() + HC.Vamoose.GetProgressQuoteCount()
end

-- Manual quote trigger (for testing via /hc quote)
function HC.Vamoose.TestQuote(category)
    category = category or "COMPLETION"
    local quote = GetRandomQuote(category:upper())
    if quote then
        DisplayQuote(quote)
        return true
    end
    return false
end
