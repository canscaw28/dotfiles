-- line_nav.lua
-- Handles line-by-line navigation with end/beginning-of-line snapping.
--
-- Problem: Cmd+Right/Left in web apps (Notion, Google Docs) jumps to end of
-- the entire block/paragraph, not the visual line. So Karabiner can't simply
-- send "Down, Cmd+Right" in to_if_held_down — the events fire too fast for
-- apps to process sequentially, and Cmd+Right overshoots.
--
-- Solution: Karabiner sends F-keys via to_if_held_down (one-shot trigger).
-- This module intercepts the F-key keyDown, runs the compound action
-- (arrow + delay + snap-to-line-edge), and manages its own repeat timer.
-- On F-key keyUp (user releases), the timer stops.
--
-- This avoids the double-delay problem where both Karabiner's threshold
-- AND the OS key repeat delay stack up. Only one delay exists (Karabiner's
-- to_if_held_down threshold), then Hammerspoon repeats at the system rate.
--
-- F13 = Up,             then Cmd+Left         (caps+Y held)
-- F14 = Down,           then Cmd+Right        (caps+O held)
-- F17 = Shift+Up,       then Cmd+Shift+Left   (caps+S+Y held)
-- F20 = Shift+Down,     then Cmd+Shift+Right  (caps+S+O held)
-- F5  = Shift+Down,     then forwarddelete     (caps+D+O held)
-- F6  = Shift+Up,       then delete            (caps+D+Y held)

local lineNav = {}

local repeatTimers = {}
local snapTimers = {}

local SNAP_DELAY = 0.02     -- 20ms between arrow and snap-to-edge
local REPEAT_INTERVAL = 0.083 -- ~83ms, matches system KeyRepeatInterval

-- Post key events directly (safe to call from eventtap callbacks,
-- unlike hs.eventtap.keyStroke which can cause loops)
local function postKeyStroke(mods, key)
    local code = hs.keycodes.map[key]
    hs.eventtap.event.newKeyEvent(mods, code, true):post()
    hs.eventtap.event.newKeyEvent(mods, code, false):post()
end

local function stopAction(keyCode)
    if snapTimers[keyCode] then
        snapTimers[keyCode]:stop()
        snapTimers[keyCode] = nil
    end
    if repeatTimers[keyCode] then
        repeatTimers[keyCode]:stop()
        repeatTimers[keyCode] = nil
    end
end

local function doCompound(keyCode, cfg)
    postKeyStroke(cfg.arrowMods, cfg.arrowKey)
    if cfg.noDelay then
        -- Fire immediately (delete ops: no visible selection flash)
        postKeyStroke(cfg.snapMods, cfg.snapKey)
    else
        -- Fire after delay (nav ops: app needs time to reflow before snap)
        if snapTimers[keyCode] then snapTimers[keyCode]:stop() end
        snapTimers[keyCode] = hs.timer.doAfter(SNAP_DELAY, function()
            postKeyStroke(cfg.snapMods, cfg.snapKey)
            snapTimers[keyCode] = nil
        end)
    end
end

local function startAction(keyCode, cfg)
    stopAction(keyCode)
    -- Fire first compound action immediately
    doCompound(keyCode, cfg)
    -- Repeat at system key repeat rate
    repeatTimers[keyCode] = hs.timer.doEvery(REPEAT_INTERVAL, function()
        doCompound(keyCode, cfg)
    end)
end

local configs = {
    [105] = {arrowKey="up",   arrowMods={},        snapKey="left",  snapMods={"cmd"}},          -- F13
    [107] = {arrowKey="down", arrowMods={},        snapKey="right", snapMods={"cmd"}},          -- F14
    [64]  = {arrowKey="up",   arrowMods={"shift"}, snapKey="left",  snapMods={"cmd","shift"}},  -- F17
    [90]  = {arrowKey="down", arrowMods={"shift"}, snapKey="right", snapMods={"cmd","shift"}},  -- F20
    [96]  = {arrowKey="down", arrowMods={"shift"}, snapKey="forwarddelete", snapMods={}, noDelay=true}, -- F5
    [97]  = {arrowKey="up",   arrowMods={"shift"}, snapKey="delete",        snapMods={}, noDelay=true}, -- F6
}

lineNav.handler = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local keyCode = event:getKeyCode()
        local cfg = configs[keyCode]
        if not cfg then return false end

        if event:getType() == hs.eventtap.event.types.keyDown then
            -- Only start on initial keyDown, not OS auto-repeat
            if not repeatTimers[keyCode] then
                startAction(keyCode, cfg)
            end
        else
            stopAction(keyCode)
        end
        return true -- consume the F-key event
    end
)

lineNav.handler:start()

return lineNav
