-- ws_notify.lua
-- Animated workspace toast triggered on keypress from ws_grid.
-- New toast rises into place; previous toast grays out and falls behind.

local M = {}

local toasts = {}  -- array of toast entries, index 1 = newest
local MAX_TOASTS = 4

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local FONT_SIZE = 28
local FONT_NAME = "Helvetica Neue Medium"
local MIN_SIZE = 56
local PADDING = 24
local CORNER_RADIUS = 14
local BORDER_WIDTH = 3
local DISPLAY_TIME = 0.7

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

local function removeToast(entry)
    if entry.fallTimer then entry.fallTimer:stop(); entry.fallTimer = nil end
    if entry.displayTimer then entry.displayTimer:stop(); entry.displayTimer = nil end
    if entry.canvas then entry.canvas:delete(); entry.canvas = nil end
    for i, e in ipairs(toasts) do
        if e == entry then
            table.remove(toasts, i)
            break
        end
    end
end

-- Forward declare
local startFall

local function demoteToast(entry)
    -- Gray out border immediately
    if entry.canvas then
        entry.canvas:elementAttribute(BORDER_IDX, "strokeColor", {
            red = GRAY[1], green = GRAY[2], blue = GRAY[3], alpha = 1,
        })
    end
    -- Update stored colors so fall interpolation stays gray
    entry.borderR = GRAY[1]
    entry.borderG = GRAY[2]
    entry.borderB = GRAY[3]

    -- Cancel hold timer
    if entry.displayTimer then
        entry.displayTimer:stop()
        entry.displayTimer = nil
    end

    -- Start fall+fade if not already falling
    if not entry.fallTimer then
        startFall(entry)
    end
end

startFall = function(entry)
    local fallStep = 0
    entry.fallTimer = hs.timer.doEvery(FALL_INTERVAL, function()
        fallStep = fallStep + 1
        if not entry.canvas then
            if entry.fallTimer then entry.fallTimer:stop(); entry.fallTimer = nil end
            return
        end
        if fallStep >= FALL_STEPS then
            removeToast(entry)
        else
            local t = fallStep / FALL_STEPS
            entry.canvas:topLeft({x = entry.targetX, y = entry.targetY + FALL_DIST * t})
            entry.canvas:alpha(1 - t)
            entry.canvas:elementAttribute(BORDER_IDX, "strokeColor", {
                red = lerp(entry.borderR, GRAY[1], t),
                green = lerp(entry.borderG, GRAY[2], t),
                blue = lerp(entry.borderB, GRAY[3], t),
                alpha = 1,
            })
        end
    end)
end

function M.show(wsKey, monitorId, sourceKey, followFocus)
    -- Demote current newest toast
    if #toasts > 0 then
        demoteToast(toasts[1])
    end

    -- Trim oldest if at capacity
    while #toasts >= MAX_TOASTS do
        removeToast(toasts[#toasts])
    end

    local displayText
    if sourceKey then
        if followFocus then
            displayText = displayName(sourceKey) .. " \u{2192} *" .. displayName(wsKey)
        else
            displayText = "*" .. displayName(sourceKey) .. " \u{2192} " .. displayName(wsKey)
        end
    else
        displayText = displayName(wsKey)
    end

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

    local c = hs.canvas.new({x = targetX, y = targetY, w = canvasW, h = canvasH})
    c:level(hs.canvas.windowLevels.overlay + 1)
    c:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    c:clickActivating(false)
    c:canvasMouseEvents(false)

    c:appendElements({
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

    c:alpha(1)
    c:show()

    local entry = {
        canvas = c,
        fallTimer = nil,
        displayTimer = nil,
        targetX = targetX,
        targetY = targetY,
        canvasW = canvasW,
        canvasH = canvasH,
        borderR = borderColor.red,
        borderG = borderColor.green,
        borderB = borderColor.blue,
    }

    -- Insert as newest (index 1) — naturally z-on-top (created last)
    table.insert(toasts, 1, entry)

    -- Mouse nudge
    hs.timer.doAfter(0.05, function()
        if not entry.canvas or toasts[1] ~= entry then return end
        local mp = hs.mouse.absolutePosition()
        if mp.x >= targetX and mp.x <= targetX + canvasW
           and mp.y >= targetY and mp.y <= targetY + canvasH then
            hs.mouse.absolutePosition({x = mp.x, y = targetY + canvasH + 10})
        end
    end)

    -- Hold phase → fall+fade
    entry.displayTimer = hs.timer.doAfter(DISPLAY_TIME, function()
        entry.displayTimer = nil
        if not entry.canvas then return end
        startFall(entry)
    end)
end

return M
