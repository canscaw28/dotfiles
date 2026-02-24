-- ws_notify.lua
-- Flash workspace name centered on screen after workspace operations.
-- Styled as a macOS-like HUD overlay with monitor-colored border.
-- Supports action text like "h → i" for move/swap ops.

local M = {}

local overlay = nil
local fadeTimer = nil

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local FONT_SIZE = 28
local FONT_NAME = "Helvetica Neue Medium"
local MIN_SIZE = 56
local PADDING = 24
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

local function displayName(ws)
    return DISPLAY_NAMES[ws] or ws
end

-- Get screen for an AeroSpace monitor ID (sorted left-to-right to match AeroSpace ordering)
local function screenForMonitor(monitorId)
    if not monitorId or monitorId < 1 then return hs.screen.mainScreen() end
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens[monitorId] or hs.screen.mainScreen()
end

-- Measure text width
local function measureText(text)
    local st = hs.styledtext.new(text, {font = {name = FONT_NAME, size = FONT_SIZE}})
    return hs.drawing.getTextDrawingSize(st).w
end

function M.show(text, monitorId)
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if overlay then
        overlay:delete()
        overlay = nil
    end

    -- Apply display name mapping to each workspace name in action text
    local displayText
    local from, arrow, to = text:match("^(.+) ([→↔]) (.+)$")
    if from then
        displayText = displayName(from) .. " " .. arrow .. " " .. displayName(to)
    else
        displayText = displayName(text)
    end

    -- Auto-size canvas: use min size for single chars, measure for longer text
    local textW = measureText(displayText)
    local canvasW = math.max(MIN_SIZE, textW + PADDING)
    local canvasH = MIN_SIZE

    local screen = screenForMonitor(monitorId)
    local sf = screen:frame()
    local x = sf.x + (sf.w - canvasW) / 2
    local y = sf.y + (sf.h - canvasH) / 2

    -- Position above grid overlay if it's visible on this screen
    local ok, ws_grid = pcall(require, "ws_grid")
    if ok and ws_grid.getFrame then
        local gf = ws_grid.getFrame()
        if gf then
            local GAP = 12
            y = gf.y - canvasH - GAP
        end
    end

    local borderColor = MONITOR_COLORS[monitorId] or DEFAULT_BORDER

    overlay = hs.canvas.new({x = x, y = y, w = canvasW, h = canvasH})
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
        text = displayText,
        textColor = TEXT_COLOR,
        textSize = FONT_SIZE,
        textFont = FONT_NAME,
        textAlignment = "center",
        textLineBreak = "clip",
        frame = {x = 0, y = (canvasH - FONT_SIZE * 1.3) / 2, w = canvasW, h = FONT_SIZE * 1.5},
    })

    overlay:alpha(1)
    overlay:show()

    -- Nudge cursor below toast if it overlaps (move-mouse may land on top)
    hs.timer.doAfter(0.15, function()
        if not overlay then return end
        local mp = hs.mouse.absolutePosition()
        if mp.x >= x and mp.x <= x + canvasW and mp.y >= y and mp.y <= y + canvasH then
            hs.mouse.absolutePosition({x = mp.x, y = y + canvasH + 10})
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
