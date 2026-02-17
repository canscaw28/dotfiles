-- ws_notify.lua
-- Flash workspace name centered on screen after workspace operations.
-- Styled as a macOS-like HUD overlay with monitor-colored border.

local M = {}

local overlay = nil
local fadeTimer = nil

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local FONT_SIZE = 28
local FONT_NAME = "Helvetica Neue Medium"
local SIZE = 56
local CORNER_RADIUS = 14
local BORDER_WIDTH = 3
local DISPLAY_TIME = 0.7
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02

local MONITOR_COLORS = {
    [1] = {red = 0.2, green = 0.5, blue = 1, alpha = 1},
    [2] = {red = 1, green = 0.45, blue = 0.15, alpha = 1},
    [3] = {red = 0.2, green = 0.75, blue = 0.4, alpha = 1},
    [4] = {red = 0.6, green = 0.3, blue = 0.85, alpha = 1},
}
local DEFAULT_BORDER = {red = 0.5, green = 0.5, blue = 0.5, alpha = 0.6}

-- Map AeroSpace workspace names to display characters
local DISPLAY_NAMES = {comma = ","}

-- Get screen for an AeroSpace monitor ID (sorted left-to-right to match AeroSpace ordering)
local function screenForMonitor(monitorId)
    if not monitorId or monitorId < 1 then return hs.screen.mainScreen() end
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens[monitorId] or hs.screen.mainScreen()
end

function M.show(workspaceName, monitorId)
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if overlay then
        overlay:delete()
        overlay = nil
    end

    local screen = screenForMonitor(monitorId)
    local sf = screen:frame()
    local x = sf.x + (sf.w - SIZE) / 2
    local y = sf.y + (sf.h - SIZE) / 2

    local borderColor = MONITOR_COLORS[monitorId] or DEFAULT_BORDER
    local displayName = DISPLAY_NAMES[workspaceName] or workspaceName

    overlay = hs.canvas.new({x = x, y = y, w = SIZE, h = SIZE})
    overlay:level(hs.canvas.windowLevels.overlay + 1)
    overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    overlay:clickActivating(false)
    overlay:canvasMouseEvents(false)

    overlay:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = BG_COLOR,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    }, {
        type = "rectangle",
        action = "stroke",
        strokeWidth = BORDER_WIDTH,
        strokeColor = borderColor,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    }, {
        type = "text",
        text = displayName,
        textColor = TEXT_COLOR,
        textSize = FONT_SIZE,
        textFont = FONT_NAME,
        textAlignment = "center",
        textLineBreak = "clip",
        frame = {x = 0, y = (SIZE - FONT_SIZE * 1.3) / 2, w = SIZE, h = FONT_SIZE * 1.5},
    })

    overlay:alpha(1)
    overlay:show()

    -- Nudge cursor below toast if it overlaps (move-mouse may land on top)
    hs.timer.doAfter(0.15, function()
        if not overlay then return end
        local mp = hs.mouse.absolutePosition()
        if mp.x >= x and mp.x <= x + SIZE and mp.y >= y and mp.y <= y + SIZE then
            hs.mouse.absolutePosition({x = mp.x, y = y + SIZE + 10})
        end
    end)

    fadeTimer = hs.timer.doAfter(DISPLAY_TIME, function()
        local step = 0
        fadeTimer = hs.timer.doEvery(FADE_INTERVAL, function()
            step = step + 1
            if step >= FADE_STEPS then
                fadeTimer:stop()
                fadeTimer = nil
                if overlay then
                    overlay:delete()
                    overlay = nil
                end
            else
                if overlay then
                    overlay:alpha(1 - step / FADE_STEPS)
                end
            end
        end)
    end)
end

return M
