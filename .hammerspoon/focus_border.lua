-- focus_border.lua
-- Blue border flash around the focused window.
-- Triggers on keyboard-driven focus changes and ws.sh operations.
-- Suppressed after mouse clicks to avoid flashing on normal clicking.

local M = {}

local border = nil
local fadeTimer = nil
local mouseSuppress = false
local suppressTimer = nil

local STROKE_WIDTH = 6
local STROKE_COLOR = {red = 0.2, green = 0.5, blue = 1, alpha = 0.8}
local CORNER_RADIUS = 6
local DISPLAY_TIME = 0.3
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02
local MOUSE_SUPPRESS_TIME = 0.5

local function showBorder(win)
    if fadeTimer then
        fadeTimer:stop()
        fadeTimer = nil
    end

    local frame = win:frame()

    if not border then
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
    else
        border:frame(frame)
    end

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

-- Explicit flash from ws.sh (always fires, ignores mouse suppress)
function M.flash()
    local win = hs.window.focusedWindow()
    if win then
        showBorder(win)
    end
end

-- Suppress border after mouse clicks
local clickWatcher = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function()
    mouseSuppress = true
    if suppressTimer then suppressTimer:stop() end
    suppressTimer = hs.timer.doAfter(MOUSE_SUPPRESS_TIME, function()
        mouseSuppress = false
        suppressTimer = nil
    end)
    return false
end)
clickWatcher:start()

-- Window focus filter (keyboard-driven focus changes)
local wf = hs.window.filter.default
wf:subscribe(hs.window.filter.windowFocused, function(win)
    if mouseSuppress then return end
    if win then
        showBorder(win)
    end
end)

return M
