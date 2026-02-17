-- focus_border.lua
-- Blue border flash around the focused window.
-- Called explicitly from ws.sh, smart-focus.sh, and smart-move.sh.
-- Never fires on mouse clicks — only keyboard-driven operations.

local M = {}

local border = nil
local fadeTimer = nil

local STROKE_WIDTH = 6
local STROKE_COLOR = {red = 0.2, green = 0.5, blue = 1, alpha = 0.8}
local CORNER_RADIUS = 6
local DISPLAY_TIME = 0.5
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02
local FLASH_DELAY = 0.1

local function showBorder(win)
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if border then
        border:delete()
        border = nil
    end

    local frame = win:frame()

    border = hs.canvas.new(frame)
    border:level(hs.canvas.windowLevels.overlay)
    border:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    border:clickActivating(false)
    border:canvasMouseEvents(false)
    border:appendElements({
        type = "rectangle",
        action = "stroke",
        strokeWidth = STROKE_WIDTH,
        strokeColor = STROKE_COLOR,
        roundedRectRadii = {xRadius = CORNER_RADIUS, yRadius = CORNER_RADIUS},
    })

    border:alpha(1)
    border:show()

    fadeTimer = hs.timer.doAfter(DISPLAY_TIME, function()
        local step = 0
        fadeTimer = hs.timer.doEvery(FADE_INTERVAL, function()
            step = step + 1
            if step >= FADE_STEPS then
                fadeTimer:stop()
                fadeTimer = nil
                if border then border:hide() end
            else
                if border then
                    border:alpha(1 - step / FADE_STEPS)
                end
            end
        end)
    end)
end

-- Explicit flash from ws.sh (always fires).
-- Brief delay lets AeroSpace focus settle before querying the focused window.
function M.flash()
    hs.timer.doAfter(FLASH_DELAY, function()
        local win = hs.window.focusedWindow()
        if win then
            showBorder(win)
        end
    end)
end

return M
