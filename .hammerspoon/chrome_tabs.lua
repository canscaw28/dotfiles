local M = {}
local repeatTimer = nil
local startTimer = nil

local function raiseChrome()
    local win = hs.window.focusedWindow()
    if win then win:raise() end
end

-- Run a JXA script asynchronously via osascript subprocess (never blocks main thread).
-- Calls callback(result_string) on completion, or callback(nil) on failure.
local function asyncJxa(script, callback)
    hs.task.new("/usr/bin/osascript", function(exitCode, stdout)
        if callback then
            callback(exitCode == 0 and stdout:gsub("%s+$", "") or nil)
        end
    end, {"-l", "JavaScript", "-e", script}):start()
end

local function buildTabScript(step)
    local jsStep = type(step) == "string" and ('"' .. step .. '"') or tostring(step)
    return string.format([[(function() {
        var chrome = Application("Google Chrome");
        var win = chrome.windows[0];
        var ai = win.activeTabIndex();
        var tc = win.tabs.length;
        var step = %s;
        var target, wrapDir;
        if (step === "first") { target = 1; wrapDir = "left"; }
        else if (step === "last") { target = tc; wrapDir = "right"; }
        else { target = Math.max(1, Math.min(tc, ai + step)); wrapDir = step > 0 ? "right" : "left"; }
        if (target !== ai) { win.activeTabIndex = target; return "switched"; }
        else { return "boundary," + wrapDir; }
    })()]], jsStep)
end

function M.switchTab(step, wrap)
    raiseChrome()
    asyncJxa(buildTabScript(step), function(result)
        if not result or result == "switched" then return end
        if not wrap then return end
        local dir = result:match("boundary,(%w+)")
        if not dir then return end

        -- Move to next window (any app) via AeroSpace hotkey
        local curWin = hs.window.focusedWindow()
        local curWinId = curWin and curWin:id()
        local key = dir == "right" and "l" or "h"
        hs.eventtap.keyStroke({"cmd", "ctrl", "alt"}, key, 0)

        -- After focus settles, if window changed AND new window is Chrome, land on near edge tab
        if curWinId then
            hs.timer.doAfter(0.15, function()
                local newWin = hs.window.focusedWindow()
                if newWin and newWin:id() ~= curWinId and
                   newWin:application() and
                   newWin:application():bundleID() == "com.google.Chrome" then
                    newWin:raise()
                    local landTab = dir == "right" and "first" or "last"
                    asyncJxa(buildTabScript(landTab), nil)
                end
            end)
        end
    end)
end

function M.onKeyDown(step)
    M.switchTab(step, true)
    if startTimer then startTimer:stop() end
    startTimer = hs.timer.doAfter(0.2, function()
        startTimer = nil
        M.stopRepeat()
        repeatTimer = hs.timer.doEvery(0.07, function()
            asyncJxa(buildTabScript(step), nil)
        end)
    end)
end

function M.onKeyUp()
    if startTimer then
        startTimer:stop()
        startTimer = nil
    end
    M.stopRepeat()
end

function M.stopRepeat()
    if repeatTimer then
        repeatTimer:stop()
        repeatTimer = nil
    end
end

return M
