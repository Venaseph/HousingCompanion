-- ============================================================================
-- Vamoose's Endeavors - Info Tab
-- How-to guide displaying addon features by tab
-- ============================================================================

HC = HC or {}
HC.UI = HC.UI or {}
HC.UI.Tabs = HC.UI.Tabs or {}

local function GetColors()
    return HC.Constants:GetThemeColors()
end

-- Guide content organized by what players want to do
local GUIDE_SECTIONS = {
    {
        title = "Getting Started",
        lines = {
            "Type /hc to open the window. Use the minimap button or Housing Dashboard button as alternatives.",
            "If you own multiple houses, use the dropdown at the top to view each one. Click 'Set as Active' to switch which house earns endeavor progress.",
            "Data refreshes automatically when you complete tasks or earn rewards.",
        },
    },
    {
        title = "Tracking Your Endeavor Tasks",
        lines = {
            "The Endeavors tab lists every task in your current neighborhood initiative.",
            "Completed tasks show a green checkmark. Repeatable tasks have a circular arrow icon.",
            "Each task shows its XP reward (gold badge) and coupon reward (cyan badge).",
            "Use the sort buttons to find the best tasks: sort by XP, Coupons, or Best Next Task.",
            "Best Next Task highlights tasks in gold/silver/bronze based on their XP value.",
            "Shift-click up to 5 tasks to favourite them - they stay visible in the minimized window.",
        },
    },
    {
        title = "Your Progress",
        lines = {
            "The progress bar at the top tracks your neighborhood's initiative progress toward milestone rewards.",
            "Your House Level and XP are shown in the header alongside Community Coupons.",
            "Your personal contribution is displayed on the right. It dims when the endeavor cap is reached.",
            "House XP from endeavors caps at 2250 per initiative, plus 250 from the completion chest.",
            "Minimize the window to show just the progress bar and your favourited tasks.",
        },
    },
    {
        title = "Neighborhood Rankings",
        lines = {
            "The Rankings tab shows everyone in your neighborhood ranked by contribution.",
            "Top 3 contributors are shown in gold, silver, and bronze. Your characters are highlighted.",
            "A green bar next to a name means that player also uses this addon.",
            "Toggle 'Group by Player' to combine all of a player's alts into one entry.",
            "Hover a grouped entry to see each character's individual contribution.",
            "Export to CSV if you want to analyse the data in a spreadsheet.",
        },
    },
    {
        title = "Activity Feed",
        lines = {
            "The Activity tab shows the most popular tasks and a live feed of recent completions.",
            "Filter to just your character with 'Me Only', or all your alts with 'My Chars'.",
            "Use the task dropdown to focus on a specific task type.",
            "Switch to Coupon Earnings view (coupon icon) to see how many coupons each task earnt.",
        },
    },
    {
        title = "Playing on Multiple Characters",
        lines = {
            "Your own alts are automatically grouped together on the Rankings and Activity tabs.",
            "Enable 'Share my alts' in Settings so guildmates can see your characters as one player.",
            "Sharing is private: BattleTags are hashed and communication uses a hidden addon channel.",
            "Set your Main Character in Settings to choose which name represents your warband.",
            "Cross-faction alts are linked automatically through your BattleTag.",
        },
    },
    {
        title = "Multiple Accounts & Cross-Faction Sync",
        lines = {
            "Alt sharing uses a hidden addon channel scoped to your neighborhood. No messages appear in chat.",
            "Enable 'Share my alts' in Settings. When you log into any character, the addon broadcasts after a few seconds.",
            "To sync Alliance and Horde alts, log into each character at least once with the addon installed and sharing enabled.",
            "Your BattleTag links characters across both factions automatically. Only a privacy hash is shared, never the raw tag.",
            "Guildmates who also run the addon will receive your broadcast and group your alts on their leaderboard.",
            "To force a refresh, toggle 'Share my alts' off and back on in Settings, or simply relog.",
            "Alt data persists between sessions. You only need to be online at the same time as a guildmate once to sync.",
        },
    },
    {
        title = "Customization",
        lines = {
            "Choose from 11 themes in Settings, or press the 'T' button in the title bar to cycle quickly.",
            "Adjust UI Scale (80-140%) and background Transparency (30-100%) to suit your setup.",
            "Pick from 5 font families including Expressway.",
            "Right-click the squirrel mascot to switch between variants.",
        },
    },
}

function HC.UI.Tabs:CreateInfo(parent)
    local UI = HC.Constants.UI

    local container = CreateFrame("Frame", nil, parent)
    container:SetAllPoints()

    -- ========================================================================
    -- HEADER
    -- ========================================================================

    local header = HC.UI:CreateSectionHeader(container, "How to Use")
    header:SetPoint("TOPLEFT", 0, UI.sectionHeaderYOffset)
    header:SetPoint("TOPRIGHT", 0, UI.sectionHeaderYOffset)

    -- ========================================================================
    -- SCROLLABLE CONTENT
    -- ========================================================================

    local scrollContainer = CreateFrame("Frame", nil, container, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = nil,
    })
    container.scrollContainer = scrollContainer

    local ApplyPanelColors = HC.UI:AddAtlasBackground(scrollContainer)
    ApplyPanelColors()

    local scrollFrame, scrollContent = HC.UI:CreateScrollFrame(scrollContainer)
    container.scrollFrame = scrollFrame
    container.scrollContent = scrollContent
    container.elements = {}

    -- ========================================================================
    -- BUILD GUIDE CONTENT
    -- ========================================================================

    function container:BuildGuide()
        local C = GetColors()

        -- Clear previous elements
        for _, el in ipairs(self.elements) do
            el:Hide()
            el:SetParent(nil)
        end
        wipe(self.elements)

        local yOffset = -10

        for sectionIdx, section in ipairs(GUIDE_SECTIONS) do
            -- Section title
            local title = scrollContent:CreateFontString(nil, "OVERLAY")
            title:SetPoint("TOPLEFT", 12, yOffset)
            title:SetPoint("TOPRIGHT", -12, yOffset)
            title:SetJustifyH("LEFT")
            HC.Theme.ApplyFont(title, C, "body")
            title:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
            title:SetText(section.title)
            title._colorType = "accent"
            HC.Theme:Register(title, "RowText")
            table.insert(self.elements, title)

            yOffset = yOffset - (title:GetStringHeight() or 14) - 6

            -- Bullet points
            for _, line in ipairs(section.lines) do
                local bullet = scrollContent:CreateFontString(nil, "OVERLAY")
                bullet:SetPoint("TOPLEFT", 22, yOffset)
                bullet:SetPoint("TOPRIGHT", -12, yOffset)
                bullet:SetJustifyH("LEFT")
                bullet:SetWordWrap(true)
                HC.Theme.ApplyFont(bullet, C, "small")
                bullet:SetTextColor(C.text.r, C.text.g, C.text.b)
                bullet:SetText("- " .. line)
                bullet._colorType = "text"
                HC.Theme:Register(bullet, "RowText")
                table.insert(self.elements, bullet)

                yOffset = yOffset - (bullet:GetStringHeight() or 12) - 3
            end

            -- Spacing between sections
            yOffset = yOffset - 8

            -- Divider line (except after last section)
            if sectionIdx < #GUIDE_SECTIONS then
                local divider = scrollContent:CreateTexture(nil, "ARTWORK")
                divider:SetPoint("TOPLEFT", 12, yOffset)
                divider:SetPoint("TOPRIGHT", -12, yOffset)
                divider:SetHeight(1)
                divider:SetColorTexture(C.border.r, C.border.g, C.border.b, 0.3)
                table.insert(self.elements, divider)
                yOffset = yOffset - 8
            end
        end

        scrollContent:SetHeight(math.abs(yOffset) + 10)
    end

    -- ========================================================================
    -- THEME UPDATE
    -- ========================================================================

    function container:ApplyTheme()
        ApplyPanelColors()
        self:BuildGuide()
    end

    HC.EventBus:Register("VE_STATE_CHANGED", function(payload)
        if payload.action == "SET_CONFIG" and payload.state.config.theme then
            container:ApplyTheme()
        end
    end)

    container:SetScript("OnShow", function()
        container:BuildGuide()
    end)

    return container
end
