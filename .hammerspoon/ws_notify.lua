-- ws_notify.lua
-- Flash workspace name centered on screen after workspace operations.

local M = {}

local overlay = nil
local fadeTimer = nil

local BG_COLOR = {red = 0.13, green = 0.13, blue = 0.13, alpha = 0.85}
local TEXT_COLOR = {red = 0.95, green = 0.95, blue = 0.95, alpha = 1}
local FONT_SIZE = 48
local PADDING_H = 40
local PADDING_V = 20
local CORNER_RADIUS = 12
local DISPLAY_TIME = 0.7
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02

local FONT_NAME = "Helvetica Neue Bold"

function M.show(workspaceName)
    -- Cancel any existing fade
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if overlay then
        overlay:delete()
        overlay = nil
    end

    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()

    local styledText = hs.styledtext.new(workspaceName, {
        font = {name = FONT_NAME, size = FONT_SIZE},
        color = TEXT_COLOR,
        paragraphStyle = {alignment = "center"},
    })
    local textSize = hs.drawing.getTextDrawingSize(styledText)
    local w = textSize.w + PADDING_H * 2
    local h = textSize.h + PADDING_V * 2
    local x = screenFrame.x + (screenFrame.w - w) / 2
    local y = screenFrame.y + (screenFrame.h - h) / 2

    overlay = hs.canvas.new({x = x, y = y, w = w, h = h})
    overlay:level(hs.canvas.windowLevels.overlay)
    overlay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    overlay:clickActivating(false)
    overlay:canvasMouseEvents(false)

    overlay:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = BG_COLOR,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    }, {
        type = "text",
        text = styledText,
        frame = {x = 0, y = PADDING_V / h, w = 1, h = 1 - (2 * PADDING_V / h)},
    })

    overlay:alpha(1)
    overlay:show()

    -- Fade out after display time
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
