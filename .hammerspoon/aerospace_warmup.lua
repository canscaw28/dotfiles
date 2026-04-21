-- Warm the AeroSpace CLI off the main thread.
-- The first `aerospace` invocation after HS loads pays a noticeable cold
-- cost (binary dyld + first daemon IPC). ws_grid.showGrid fans out several
-- aerospace calls via bash on the first caps+T+W display; warming once
-- removes the visible lag before the grid appears.

local function warmAerospace()
    hs.task.new("/opt/homebrew/bin/aerospace", nil,
        {"list-workspaces", "--focused"}):start()
end

hs.timer.doAfter(2, warmAerospace)
