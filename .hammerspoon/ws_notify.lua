-- ws_notify.lua
-- Flash workspace name centered on screen after workspace operations.
-- Styled as a macOS-like HUD overlay.

local M = {}

local overlay = nil
local fadeTimer = nil

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.75}
local TEXT_COLOR = {red = 1, green = 1, blue = 1, alpha = 1}
local FONT_SIZE = 28
local FONT_NAME = "Helvetica Neue Medium"
local SIZE = 56
local CORNER_RADIUS = 14
local DISPLAY_TIME = 0.7
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02

function M.show(workspaceName)
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if overlay then
        overlay:delete()
        overlay = nil
    end

    local screen = hs.screen.mainScreen()
    local sf = screen:frame()
    local x = sf.x + (sf.w - SIZE) / 2
    local y = sf.y + (sf.h - SIZE) / 2

    overlay = hs.canvas.new({x = x, y = y, w = SIZE, h = SIZE})
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
        text = workspaceName,
        textColor = TEXT_COLOR,
        textSize = FONT_SIZE,
        textFont = FONT_NAME,
        textAlignment = "center",
        textLineBreak = "clip",
        frame = {x = 0, y = (SIZE - FONT_SIZE * 1.3) / 2, w = SIZE, h = FONT_SIZE * 1.5},
    })

    overlay:alpha(1)
    overlay:show()

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
