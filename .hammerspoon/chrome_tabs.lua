local M = {}
local repeatTimer = nil
local startTimer = nil

local function getFocusedBounds()
    local win = hs.window.focusedWindow()
    if not win then return nil end
    local f = win:frame()
    return { x = f.x, y = f.y, w = f.w, h = f.h }
end

local function switchTabInner(step, bounds)
    local jsStep = type(step) == "string" and ('"' .. step .. '"') or tostring(step)
    -- Build window finder: match by bounds if available, fall back to windows[0]
    local findWin
    if bounds then
        findWin = string.format([[
            var wins = chrome.windows();
            for (var i = 0; i < wins.length; i++) {
                var b = wins[i].bounds();
                if (Math.abs(b.x - %d) < 5 && Math.abs(b.y - %d) < 5 &&
                    Math.abs(b.width - %d) < 5 && Math.abs(b.height - %d) < 5) {
                    win = wins[i]; break;
                }
            }
        ]], bounds.x, bounds.y, bounds.w, bounds.h)
    else
        findWin = ""
    end

    local ok, result = hs.osascript.javascript(string.format([[
        (function() {
            var chrome = Application("Google Chrome");
            var win = chrome.windows[0];
            %s
            var ai = win.activeTabIndex();
            var tc = win.tabs.length;
            var step = %s;
            var target, wrapDir;
            if (step === "first") { target = 1; wrapDir = "left"; }
            else if (step === "last") { target = tc; wrapDir = "right"; }
            else { target = Math.max(1, Math.min(tc, ai + step)); wrapDir = step > 0 ? "right" : "left"; }
            if (target !== ai) { win.activeTabIndex = target; return "switched"; }
            return "boundary," + wrapDir;
        })()
    ]], findWin, jsStep))
    if not ok then return nil end
    return result
end

function M.switchTab(step, wrap)
    local bounds = getFocusedBounds()
    local result = switchTabInner(step, bounds)
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
                local newBounds = getFocusedBounds()
                local landTab = dir == "right" and "first" or "last"
                switchTabInner(landTab, newBounds)
            end
        end)
    end
end

function M.onKeyDown(step)
    M.switchTab(step, true)
    if startTimer then startTimer:stop() end
    local bounds = getFocusedBounds()
    startTimer = hs.timer.doAfter(0.2, function()
        startTimer = nil
        M.stopRepeat()
        repeatTimer = hs.timer.doEvery(0.07, function()
            switchTabInner(step, bounds)
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

-- Land on the tab closest to where the user came from.
-- Called after focusing a Chrome window from another app (e.g. tmux).
-- going left/up → land on last tab (rightmost, closest to origin)
-- going right/down → land on first tab (leftmost, closest to origin)
function M.landNearEdge(direction)
    local bounds = getFocusedBounds()
    local step = (direction == "right" or direction == "down") and "first" or "last"
    switchTabInner(step, bounds)
end

return M
