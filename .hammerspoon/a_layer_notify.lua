-- a_layer_notify.lua
-- Toast indicator for A layer actions, matching ws_notify fall+fade style.

local M = {}

local canvas = nil
local displayTimer = nil
local fallTimer = nil
local targetX = nil
local targetY = nil

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local BORDER_COLOR = {red = 0.6, green = 0.3, blue = 0.85, alpha = 1}
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

local function cleanup()
    if fallTimer then fallTimer:stop(); fallTimer = nil end
    if displayTimer then displayTimer:stop(); displayTimer = nil end
    if canvas then canvas:delete(); canvas = nil end
end

local function startFall()
    local step = 0
    fallTimer = hs.timer.doEvery(FALL_INTERVAL, function()
        step = step + 1
        if not canvas then
            if fallTimer then fallTimer:stop(); fallTimer = nil end
            return
        end
        if step >= FALL_STEPS then
            cleanup()
        else
            local t = step / FALL_STEPS
            canvas:topLeft({x = targetX, y = targetY + FALL_DIST * t})
            canvas:alpha(1 - t)
        end
    end)
end

function M.show(label)
    cleanup()

    local st = hs.styledtext.new(label, {font = {name = FONT_NAME, size = FONT_SIZE}})
    local textW = hs.drawing.getTextDrawingSize(st).w
    local canvasW = math.max(MIN_SIZE, textW + PADDING)
    local canvasH = MIN_SIZE

    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local sf = screen:fullFrame()
    targetX = sf.x + (sf.w - canvasW) / 2
    targetY = sf.y + (sf.h - canvasH) / 2

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
        strokeColor = BORDER_COLOR,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    }, {
        type = "text",
        text = label,
        textColor = TEXT_COLOR,
        textSize = FONT_SIZE,
        textFont = FONT_NAME,
        textAlignment = "center",
        textLineBreak = "clip",
        frame = {x = 0, y = (canvasH - FONT_SIZE * 1.3) / 2, w = canvasW, h = FONT_SIZE * 1.5},
    })

    c:alpha(1)
    c:show()
    canvas = c

    displayTimer = hs.timer.doAfter(DISPLAY_TIME, function()
        displayTimer = nil
        if not canvas then return end
        startFall()
    end)
end

return M
