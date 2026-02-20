-- focus_border.lua
-- Blue border flash around the focused window.
-- Called explicitly from ws.sh, smart-focus.sh, and smart-move.sh.
-- Never fires on mouse clicks — only keyboard-driven operations.

local M = {}

local border = nil
local fadeTimer = nil
local delayTimer = nil

local STROKE_WIDTH = 6
local STROKE_COLOR = {red = 1, green = 0.6, blue = 0.1, alpha = 0.8}
local CORNER_RADIUS = 12
local DISPLAY_TIME = 0.5
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02
local FLASH_DELAY = 0.1

local function clearBorder()
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end
    if border then
        border:delete()
        border = nil
    end
end

local function showBorder(frame)
    clearBorder()

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
                if border then border:delete(); border = nil end
            else
                if border then
                    border:alpha(1 - step / FADE_STEPS)
                end
            end
        end)
    end)
end

-- Explicit flash from ws.sh, smart-focus.sh, smart-move.sh.
-- Immediately clears any existing/fading border, then waits briefly
-- for AeroSpace focus to settle before drawing the new one.
function M.flash()
    -- Kill any pending delay and any visible/fading border immediately
    if delayTimer then
        delayTimer:stop()
        delayTimer = nil
    end
    clearBorder()

    delayTimer = hs.timer.doAfter(FLASH_DELAY, function()
        delayTimer = nil
        local screen = hs.mouse.getCurrentScreen()
        local win = hs.window.focusedWindow()
        -- Check the window is on the current screen — macOS keeps reporting
        -- the old focused window even after AeroSpace switches to an empty workspace
        if win and screen and win:screen() == screen then
            showBorder(win:frame())
        elseif screen then
            -- Empty workspace — highlight the focused monitor
            local f = screen:frame()
            local pad = STROKE_WIDTH
            showBorder({x = f.x + pad, y = f.y + pad, w = f.w - 2 * pad, h = f.h - 2 * pad})
        end
    end)
end

return M
