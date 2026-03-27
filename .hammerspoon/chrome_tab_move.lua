local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"
local OPPOSITES = { left = "right", right = "left", up = "down", down = "up" }

local function refocusSource(direction)
    hs.task.new(AEROSPACE, function()
        require("focus_border").flash()
    end, { "focus", OPPOSITES[direction] }):start()
end

function M.positionNewWindow(direction, follow)
    -- New Chrome window is currently focused (just created by extension).
    -- Karabiner already set aerospace split horizontal/vertical before creation,
    -- so the new window is in the correct orientation.
    -- For left/up: new window appeared to the right/below, swap it.
    -- For right/down: already in correct position.
    -- If follow: stay on the new window. Otherwise refocus the source.
    if direction == "left" or direction == "up" then
        hs.task.new(AEROSPACE, function()
            if follow then
                require("focus_border").flash()
            else
                refocusSource(direction)
            end
        end, { "move", direction }):start()
    else
        if follow then
            require("focus_border").flash()
        else
            refocusSource(direction)
        end
    end
end

return M
