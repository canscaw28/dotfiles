local M = {}
local repeatTimer = nil
local startTimer = nil

local function switchTabInner(step)
    local jsStep = type(step) == "string" and ('"' .. step .. '"') or tostring(step)
    local ok, result = hs.osascript.javascript(string.format([[
        (function() {
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
            return "boundary," + wrapDir;
        })()
    ]], jsStep))
    if not ok then return nil end
    return result
end

function M.switchTab(step, wrap)
    local result = switchTabInner(step)
    if not result or result == "switched" then return end
    if not wrap then return end
    local dir = result:match("boundary,(%w+)")
    if dir then
        require("chrome_focus").focus(dir)
        -- Land on the near edge: moving right → first tab, moving left → last tab
        local landTab = dir == "right" and 1 or -1
        hs.osascript.javascript(string.format([[
            (function() {
                var win = Application("Google Chrome").windows[0];
                win.activeTabIndex = %d < 0 ? win.tabs.length : %d;
            })()
        ]], landTab, landTab))
    end
end

function M.onKeyDown(step)
    M.switchTab(step, true)
    if startTimer then startTimer:stop() end
    startTimer = hs.timer.doAfter(0.2, function()
        startTimer = nil
        M.stopRepeat()
        repeatTimer = hs.timer.doEvery(0.07, function()
            switchTabInner(step)
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
