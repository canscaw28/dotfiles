-- focus_border.lua
-- Blue border flash around the focused window.
-- Called explicitly from ws.sh, smart-focus.sh, and smart-move.sh.
-- Never fires on mouse clicks — only keyboard-driven operations.

local M = {}

local border = nil
local fadeTimer = nil
local delayTimer = nil
local lastWid = nil
local lastActionFlashAt = 0

local STROKE_WIDTH = 6
local STROKE_COLOR = {red = 1, green = 0.6, blue = 0.1, alpha = 0.8}
local CORNER_RADIUS = 12
local DISPLAY_TIME = 0.25
local FADE_STEPS = 8
local FADE_INTERVAL = 0.02
local FLASH_DELAY = 0.05
local BLINK_GAP = 0.04
local LAYER_FLASH_DELAY = 0.08

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

local function scheduleFade()
    if fadeTimer then fadeTimer:stop() end
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

local function showBorder(frame, wid)
    clearBorder()
    lastWid = wid

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

    scheduleFade()
end

-- Brief alpha dip so a re-flash on the same window reads as input feedback.
local function blinkBorder()
    if fadeTimer then fadeTimer:stop(); fadeTimer = nil end
    border:alpha(0)
    hs.timer.doAfter(BLINK_GAP, function()
        if border then
            border:alpha(1)
            scheduleFade()
        end
    end)
end

-- Extend the current border's display time without clearing/redrawing.
-- If no border is showing, does a full flash instead.
function M.extend()
    if border then
        border:alpha(1)
        scheduleFade()
    elseif delayTimer then
        -- flash() is pending, let it proceed
    else
        M.flash()
    end
end

-- Explicit flash from ws.sh, smart-focus.sh, smart-move.sh.
-- Immediately clears any existing/fading border, then waits briefly
-- for AeroSpace focus to settle before drawing the new one.
-- monitorOnly: when true, always draw border around the monitor
-- (caller knows the workspace is empty — avoids unreliable hs.window.focusedWindow)
function M.flash(monitorOnly)
    lastActionFlashAt = hs.timer.secondsSinceEpoch()
    -- Kill any pending delay and any visible/fading border immediately
    if delayTimer then
        delayTimer:stop()
        delayTimer = nil
    end
    clearBorder()

    delayTimer = hs.timer.doAfter(FLASH_DELAY, function()
        delayTimer = nil
        if not monitorOnly then
            local win = hs.window.focusedWindow()
            if win then
                showBorder(win:frame())
                return
            end
        end
        local screen = hs.mouse.getCurrentScreen()
        if screen then
            showBorder(screen:frame())
        end
    end)
end

-- Flash border on a specific window by AeroSpace window ID.
-- No delay needed — the caller already knows which window to highlight.
-- If a border is already showing (e.g. boundary re-flash on the same
-- window), pulse via a brief alpha dip so the keypress is visible.
function M.flashWindowId(wid)
    lastActionFlashAt = hs.timer.secondsSinceEpoch()
    if delayTimer then
        delayTimer:stop()
        delayTimer = nil
    end

    local win = hs.window.get(wid)
    local frame
    if win then
        frame = win:frame()
    else
        local screen = hs.mouse.getCurrentScreen()
        if screen then frame = screen:frame() end
    end
    if not frame then return end

    if border and wid and wid == lastWid then
        blinkBorder()
    else
        showBorder(frame, wid)
    end
end

-- Called from layer-key setters (e.g. caps+T press) as input feedback.
-- Defers briefly; if any action flash lands in the interim, this one skips
-- so we never clobber an action's correct border or draw on a stale window.
function M.flashOnLayerActivate()
    local pressTime = hs.timer.secondsSinceEpoch()
    hs.timer.doAfter(LAYER_FLASH_DELAY, function()
        if lastActionFlashAt >= pressTime then return end
        local win = hs.window.focusedWindow()
        if win then
            showBorder(win:frame(), win:id())
        end
    end)
end

return M
