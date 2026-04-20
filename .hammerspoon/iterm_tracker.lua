-- Track the TTY of the frontmost iTerm2 window so external scripts
-- (e.g. Karabiner-triggered g-focus-tmux.sh) can target the correct
-- tmux client without paying AppleScript latency on every keypress.
--
-- Design: maintain a {windowID -> tty} map refreshed on window
-- creation/destruction via one osascript call. Focus changes are a
-- synchronous O(1) lookup that writes /tmp/iterm-front-tty immediately,
-- avoiding the race between focus and async AppleScript completion.

local M = {}

local CACHE_PATH = "/tmp/iterm-front-tty"
local ITERM_BUNDLE = "com.googlecode.iterm2"

local windowTTYs = {}

local function writeFront(tty)
    local f = io.open(CACHE_PATH, "w")
    if not f then return end
    f:write(tty)
    f:close()
end

local function writeFromFocused()
    local w = hs.window.focusedWindow()
    if not w then return end
    local app = w:application()
    if not app or app:bundleID() ~= ITERM_BUNDLE then return end
    local tty = windowTTYs[w:id()]
    if tty then writeFront(tty) end
end

-- One AppleScript dump of all iTerm2 windows → their active session's TTY.
-- Called only on window creation/destruction/app launch, never on focus change.
local SCAN_SCRIPT = [[
set out to ""
tell application "iTerm2"
  repeat with w in windows
    try
      set out to out & (id of w as string) & " " & (tty of current session of w) & linefeed
    end try
  end repeat
end tell
return out
]]

local function rescan()
    hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, _)
        if exitCode ~= 0 then return end
        local next = {}
        for line in (stdOut or ""):gmatch("[^\n]+") do
            local wid, tty = line:match("^(%d+)%s+(/dev/%S+)")
            if wid and tty then next[tonumber(wid)] = tty end
        end
        windowTTYs = next
        writeFromFocused()
    end, {"-e", SCAN_SCRIPT}):start()
end

local function onFocus()
    local w = hs.window.focusedWindow()
    if not w then return end
    local app = w:application()
    if not app or app:bundleID() ~= ITERM_BUNDLE then return end
    local tty = windowTTYs[w:id()]
    if tty then
        writeFront(tty)
    else
        rescan()
    end
end

M.rescan = rescan
M.onFocus = onFocus

itermFilter = hs.window.filter.new("iTerm2")
itermFilter:subscribe({hs.window.filter.windowFocused}, onFocus)
itermFilter:subscribe({
    hs.window.filter.windowCreated,
    hs.window.filter.windowDestroyed,
}, rescan)

itermAppWatcher = hs.application.watcher.new(function(_, event, app)
    if app and app:bundleID() == ITERM_BUNDLE
       and (event == hs.application.watcher.launched
         or event == hs.application.watcher.activated) then
        rescan()
    end
end)
itermAppWatcher:start()

rescan()

return M
