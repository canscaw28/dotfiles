-- ws_notify.lua
-- Animated workspace toast triggered on keypress from ws_grid.
-- Single toast: rises into place, holds, then falls + fades with border graying out.

local M = {}

local overlay = nil
local riseTimer = nil
local fallTimer = nil
local displayTimer = nil

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local FONT_SIZE = 28
local FONT_NAME = "Helvetica Neue Medium"
local MIN_SIZE = 56
local PADDING = 24
local CORNER_RADIUS = 14
local BORDER_WIDTH = 3
local DISPLAY_TIME = 0.7

local RISE_DIST = 16
local RISE_STEPS = 3
local RISE_INTERVAL = 0.016

local FALL_DIST = 20
local FALL_STEPS = 10
local FALL_INTERVAL = 0.02

local GRAY = {0.4, 0.4, 0.4}

local MONITOR_COLORS = {
    [1] = {red = 0.2, green = 0.5, blue = 1, alpha = 1},
    [2] = {red = 1, green = 0.45, blue = 0.15, alpha = 1},
    [3] = {red = 0.2, green = 0.75, blue = 0.4, alpha = 1},
    [4] = {red = 0.6, green = 0.3, blue = 0.85, alpha = 1},
}
local DEFAULT_BORDER = {red = 0.5, green = 0.5, blue = 0.5, alpha = 0.6}

local DISPLAY_NAMES = {comma = ","}

-- Border element is always index 2 in the canvas (bg=1, border=2, text=3)
local BORDER_IDX = 2

local function displayName(ws)
    return DISPLAY_NAMES[ws] or ws
end

local function screenForMonitor(monitorId)
    if not monitorId or monitorId < 1 then return hs.screen.mainScreen() end
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens[monitorId] or hs.screen.mainScreen()
end

local function measureText(text)
    local st = hs.styledtext.new(text, {font = {name = FONT_NAME, size = FONT_SIZE}})
    return hs.drawing.getTextDrawingSize(st).w
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function cleanup()
    if riseTimer then riseTimer:stop(); riseTimer = nil end
    if fallTimer then fallTimer:stop(); fallTimer = nil end
    if displayTimer then displayTimer:stop(); displayTimer = nil end
    if overlay then overlay:delete(); overlay = nil end
end

function M.show(wsKey, monitorId)
    -- Cancel any existing toast immediately — new keypress wins
    cleanup()

    local displayText = displayName(wsKey)

    local textW = measureText(displayText)
    local canvasW = math.max(MIN_SIZE, textW + PADDING)
    local canvasH = MIN_SIZE

    local screen = screenForMonitor(monitorId)
    local sf = screen:frame()
    local targetX = sf.x + (sf.w - canvasW) / 2
    local targetY = sf.y + (sf.h - canvasH) / 2

    -- Position above grid overlay if visible
    local ok, ws_grid = pcall(require, "ws_grid")
    if ok and ws_grid.getFrame then
        local gf = ws_grid.getFrame()
        if gf then
            local GAP = 12
            targetY = gf.y - canvasH - GAP
        end
    end

    local borderColor = MONITOR_COLORS[monitorId] or DEFAULT_BORDER
    local borderR = borderColor.red
    local borderG = borderColor.green
    local borderB = borderColor.blue

    -- Start below final position
    local startY = targetY + RISE_DIST

    overlay = hs.canvas.new({x = targetX, y = startY, w = canvasW, h = canvasH})
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

    -- Rise phase: move upward toward targetY
    local riseStep = 0
    riseTimer = hs.timer.doEvery(RISE_INTERVAL, function()
        riseStep = riseStep + 1
        if not overlay then
            if riseTimer then riseTimer:stop(); riseTimer = nil end
            return
        end
        if riseStep >= RISE_STEPS then
            -- Snap to final position
            overlay:topLeft({x = targetX, y = targetY})
            riseTimer:stop()
            riseTimer = nil

            -- Mouse nudge after rise completes
            hs.timer.doAfter(0.05, function()
                if not overlay then return end
                local mp = hs.mouse.absolutePosition()
                if mp.x >= targetX and mp.x <= targetX + canvasW and mp.y >= targetY and mp.y <= targetY + canvasH then
                    hs.mouse.absolutePosition({x = mp.x, y = targetY + canvasH + 10})
                end
            end)

            -- Hold phase
            displayTimer = hs.timer.doAfter(DISPLAY_TIME, function()
                displayTimer = nil
                if not overlay then return end

                -- Fall + fade + gray border phase
                local fallStep = 0
                fallTimer = hs.timer.doEvery(FALL_INTERVAL, function()
                    fallStep = fallStep + 1
                    if not overlay then
                        if fallTimer then fallTimer:stop(); fallTimer = nil end
                        return
                    end
                    if fallStep >= FALL_STEPS then
                        cleanup()
                    else
                        local t = fallStep / FALL_STEPS
                        -- Move down
                        local curY = targetY + (FALL_DIST * t)
                        overlay:topLeft({x = targetX, y = curY})
                        -- Fade alpha
                        overlay:alpha(1 - t)
                        -- Interpolate border toward gray
                        overlay:elementAttribute(BORDER_IDX, "strokeColor", {
                            red = lerp(borderR, GRAY[1], t),
                            green = lerp(borderG, GRAY[2], t),
                            blue = lerp(borderB, GRAY[3], t),
                            alpha = 1,
                        })
                    end
                end)
            end)
        else
            -- Intermediate rise step
            local t = riseStep / RISE_STEPS
            local curY = startY + (targetY - startY) * t
            overlay:topLeft({x = targetX, y = curY})
        end
    end)
end

return M
