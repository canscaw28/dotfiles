-- ws_notify.lua
-- Flash workspace name centered on screen after workspace operations.

local M = {}

local canvas = nil
local fadeTimer = nil

local BG_COLOR = {red = 0.13, green = 0.13, blue = 0.13, alpha = 0.85}
local TEXT_COLOR = {red = 0.95, green = 0.95, blue = 0.95, alpha = 1}
local FONT_SIZE = 48
local PADDING_H = 40
local PADDING_V = 20
local CORNER_RADIUS = 12
local DISPLAY_TIME = 2
local FADE_STEPS = 10
local FADE_INTERVAL = 0.03 -- ~0.3s total fade

function M.show(workspaceName)
    -- Cancel any existing fade
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if canvas then
        canvas:delete()
        canvas = nil
    end

    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()

    -- Measure text to size the canvas
    local textStyle = {
        font = {name = ".AppleSystemUIFontBold", size = FONT_SIZE},
        color = TEXT_COLOR,
        paragraphStyle = {alignment = "center"},
    }
    local textSize = hs.drawing.getTextDrawingSize(workspaceName, textStyle)
    local w = textSize.w + PADDING_H * 2
    local h = textSize.h + PADDING_V * 2
    local x = screenFrame.x + (screenFrame.w - w) / 2
    local y = screenFrame.y + (screenFrame.h - h) / 2

    canvas = hs.canvas.new({x = x, y = y, w = w, h = h})
    canvas:level(hs.canvas.windowLevels.overlay)
    canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    canvas:clickActivating(false)
    canvas:canvasMouseEvents(false)

    canvas:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = BG_COLOR,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    }, {
        type = "text",
        text = workspaceName,
        textFont = ".AppleSystemUIFontBold",
        textSize = FONT_SIZE,
        textColor = TEXT_COLOR,
        textAlignment = "center",
        frame = {x = 0, y = PADDING_V / h, w = 1, h = 1 - (2 * PADDING_V / h)},
    })

    canvas:alpha(1)
    canvas:show()

    -- Fade out after display time
    fadeTimer = hs.timer.doAfter(DISPLAY_TIME, function()
        local step = 0
        fadeTimer = hs.timer.doEvery(FADE_INTERVAL, function()
            step = step + 1
            if step >= FADE_STEPS then
                fadeTimer:stop()
                fadeTimer = nil
                if canvas then
                    canvas:delete()
                    canvas = nil
                end
            else
                if canvas then
                    canvas:alpha(1 - step / FADE_STEPS)
                end
            end
        end)
    end)
end

return M
