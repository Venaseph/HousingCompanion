-- ============================================================================
-- Vamoose's Endeavors - Constants
-- Imports color schemes from SchemeConstants.lua and adds VE-specific colors
-- ============================================================================

HC = HC or {}
HC.Constants = {}
HC.Colors = {}

-- ============================================================================
-- 1. IMPORT COLOR SCHEMES FROM SHARED SCHEMECONSTANTS
-- ============================================================================

-- Import schemes from shared global (loaded via SchemeConstants.lua)
HC.Colors.Schemes = HC_SchemeConstants or {}

-- VE-specific colors to add to each scheme
local HC_COLORS = {
    endeavor = {r=0.85, g=0.65, b=0.13, a=1.00}, -- Gold for endeavor points
    favor    = {r=0.40, g=0.75, b=0.40, a=1.00}, -- Green for favor/XP
    -- Medal colors for leaderboards
    gold     = {r=1.00, g=0.84, b=0.00, a=1.00}, -- Gold medal (#FFD700)
    silver   = {r=0.75, g=0.75, b=0.75, a=1.00}, -- Silver medal (#C0C0C0)
    bronze   = {r=0.80, g=0.50, b=0.20, a=1.00}, -- Bronze medal (#CD7F32)
}

-- Add VE-specific colors to each scheme
for _, scheme in pairs(HC.Colors.Schemes) do
    scheme.endeavor = HC_COLORS.endeavor
    scheme.favor = HC_COLORS.favor
    scheme.gold = HC_COLORS.gold
    scheme.silver = HC_COLORS.silver
    scheme.bronze = HC_COLORS.bronze
end

-- ============================================================================
-- 2. THEME MANAGEMENT
-- ============================================================================

-- Current active colors (defaults to SolarizedDark)
HC.Constants.Colors = HC.Colors.Schemes.SolarizedDark
HC.Constants.ColorsDark = HC.Colors.Schemes.SolarizedDark
HC.Constants.ColorsLight = HC.Colors.Schemes.SolarizedLight

-- Theme cycle order (11 themes)
HC.Constants.ThemeOrder = {
    "solarizeddark",
    "solarizedlight",
    "gruvboxdark",
    "gruvboxlight",
    "everforestdark",
    "everforestlight",
    "everforestaccess",
    "kanagawadark",
    "kanagawalight",
    "accessibilityhc",
    "housingtheme"
}

-- Maps config key to scheme name (for HC.Colors.Schemes lookup)
HC.Constants.ThemeNames = {
    solarizeddark = "SolarizedDark",
    solarizedlight = "SolarizedLight",
    gruvboxdark = "GruvboxDark",
    gruvboxlight = "GruvboxLight",
    everforestdark = "EverforestDark",
    everforestlight = "EverforestLight",
    everforestaccess = "EverforestAccess",
    kanagawadark = "KanagawaDark",
    kanagawalight = "KanagawaLight",
    accessibilityhc = "AccessibilityHC",
    housingtheme = "HousingTheme",
    -- Legacy mappings for backwards compatibility
    dark = "SolarizedDark",
    light = "SolarizedLight",
    everforest = "EverforestDark",
    kanagawa = "KanagawaDark",
}

-- User-friendly display names for tooltips
HC.Constants.ThemeDisplayNames = {
    solarizeddark = "Solarized Dark",
    solarizedlight = "Solarized Light",
    gruvboxdark = "Gruvbox Dark",
    gruvboxlight = "Gruvbox Light",
    everforestdark = "Everforest Dark",
    everforestlight = "Everforest Light",
    everforestaccess = "Everforest Access",
    kanagawadark = "Kanagawa Dark",
    kanagawalight = "Kanagawa Light",
    accessibilityhc = "Accessibility HC",
    housingtheme = "Housing Theme",
    -- Legacy mappings
    dark = "Solarized Dark",
    light = "Solarized Light",
    everforest = "Everforest Dark",
    kanagawa = "Kanagawa Dark",
}

-- Font families available
HC.Constants.FontOrder = { "ARIALN", "FRIZQT__", "skurri", "MORPHEUS", "Expressway" }
HC.Constants.FontDisplayNames = {
    ARIALN = "Arial Narrow",
    FRIZQT__ = "Friz Quadrata",
    skurri = "Skurri",
    MORPHEUS = "Morpheus",
    Expressway = "Expressway",
}
HC.Constants.FontFiles = {
    ARIALN = "Fonts\\ARIALN.TTF",
    FRIZQT__ = "Fonts\\FRIZQT__.TTF",
    skurri = "Fonts\\skurri.TTF",
    MORPHEUS = "Fonts\\MORPHEUS.TTF",
    Expressway = "Interface\\AddOns\\VamoosesEndeavors\\Fonts\\expressway.ttf",
}

-- Get current font family file path
function HC.Constants:GetFontFile()
    local family = "ARIALN"
    if HC.Store and HC.Store.state and HC.Store.state.config then
        family = HC.Store.state.config.fontFamily or "ARIALN"
    elseif HC_DB and HC_DB.config and HC_DB.config.fontFamily then
        family = HC_DB.config.fontFamily
    end
    return self.FontFiles[family] or self.FontFiles.ARIALN
end

-- Get colors for current theme
function HC.Constants:GetThemeColors()
    local theme = "housingtheme"
    -- Read from Store state (immediate) rather than HC_DB (delayed save)
    if HC.Store and HC.Store.state and HC.Store.state.config then
        theme = HC.Store.state.config.theme or "housingtheme"
    elseif HC_DB and HC_DB.config and HC_DB.config.theme then
        theme = HC_DB.config.theme
    end

    local themeName = self.ThemeNames and self.ThemeNames[theme] or "HousingTheme"
    return HC.Colors.Schemes[themeName] or HC.Colors.Schemes.HousingTheme
end

-- Apply current theme to HC.Constants.Colors
function HC.Constants:ApplyTheme()
    self.Colors = self:GetThemeColors()
end

-- Toggle theme (cycles through all themes)
function HC.Constants:ToggleTheme()
    local currentTheme = self:GetCurrentTheme()

    -- Find current index and get next theme
    local currentIndex = 1
    for i, theme in ipairs(self.ThemeOrder) do
        if theme == currentTheme then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #self.ThemeOrder) + 1
    local newTheme = self.ThemeOrder[nextIndex]

    HC.Store:Dispatch("SET_CONFIG", { key = "theme", value = newTheme })
    self:ApplyTheme()

    return newTheme
end

-- Get current theme name
function HC.Constants:GetCurrentTheme()
    -- Read from Store state (immediate) rather than HC_DB (delayed save)
    if HC.Store and HC.Store.state and HC.Store.state.config then
        return HC.Store.state.config.theme or "housingtheme"
    elseif HC_DB and HC_DB.config and HC_DB.config.theme then
        return HC_DB.config.theme
    end
    return "housingtheme"
end

-- ============================================================================
-- 3. UI SIZING CONSTANTS
-- ============================================================================

HC.Constants.UI = {
    -- Main window
    mainWidth = 338,
    mainHeight = 480,
    titleBarHeight = 27,      -- Title bar height (increased 50% for Housing Theme)
    tabHeight = 24,           -- Tab button height
    headerSectionHeight = 73, -- Header section with season info, progress bar, house dropdown
    headerContentOffset = 132, -- titleBarHeight + tabHeight + headerSectionHeight + 8px spacing = 132

    -- Row sizing
    rowHeight = 22,
    taskRowHeight = 22,
    headerHeight = 24,

    -- Progress bar
    progressBarHeight = 16,
    milestoneSize = 12,

    -- Padding
    panelPadding = 5,
    sectionSpacing = 8,
    rowSpacing = 2,
    sectionHeaderYOffset = 0, -- Y offset for section headers from top of container (0 = flush with top)

    -- Character selector
    charSelectorHeight = 24,

    -- Tab sizing
    tabWidth = 75,

    -- Transparency (0.6 = 60% opacity)
    windowAlpha = 0.6,

    -- Set as Active button
    setActiveButtonWidth = 120,
    setActiveButtonHeight = 24,
    setActiveButtonOffset = -12,
}

-- ============================================================================
-- 4. CURRENCY IDS
-- ============================================================================

HC.Constants.CURRENCY_IDS = {
    COMMUNITY_COUPONS = 3363,
}

-- ============================================================================
-- 5. XP FORMULA (self-learning - no hardcoded values needed)
-- ============================================================================

-- All XP values are learned from activity log observations
-- Scale is derived from floor tasks: scale = observed_floorXP / progressContributionAmount
-- No hardcoded ROSTER_TIERS - scale CAPS at ~92.5% of baseline after 7+ characters

-- ============================================================================
-- 5. HELPER FUNCTIONS
-- ============================================================================

-- Helper to get color code string for text (uses hex if available, generates if not)
function HC.Constants:GetColorCode(colorName)
    local color = self.Colors[colorName]
    if color then
        if color.hex then
            return string.format("|cFF%s", color.hex)
        else
            -- Generate hex from RGB
            local hex = string.format("%02x%02x%02x",
                math.floor(color.r * 255),
                math.floor(color.g * 255),
                math.floor(color.b * 255))
            return string.format("|cFF%s", hex)
        end
    end
    return "|cFFFFFFFF"
end
