-- Warm Chrome's JXA ScriptingBridge off the main thread.
-- Chrome's Apple Events handler has a multi-second cold start; this
-- ensures it's ready before the user's first G-layer tab switch.

local function warmBridge()
    if hs.application.get("Google Chrome") then
        hs.task.new("/usr/bin/osascript", nil,
            {"-l", "JavaScript", "-e", "Application('Google Chrome').name()"}):start()
    end
end

-- Warm after startup settles
hs.timer.doAfter(2, warmBridge)

-- Warm when Chrome launches
chromeWatcher = hs.application.watcher.new(function(name, event)
    if name == "Google Chrome" and event == hs.application.watcher.launched then
        hs.timer.doAfter(2, warmBridge)
    end
end)
chromeWatcher:start()
