local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"
local OPPOSITES = { left = "right", right = "left", up = "down", down = "up" }

local function refocusSource(direction)
    hs.task.new(AEROSPACE, function()
        require("focus_border").flash()
    end, { "focus", OPPOSITES[direction] }):start()
end

function M.positionNewWindow(direction)
    -- New Chrome window is currently focused (just created by extension).
    -- Karabiner already set aerospace split horizontal/vertical before creation,
    -- so the new window is in the correct orientation.
    -- For left/up: new window appeared to the right/below, swap it.
    -- For right/down: already in correct position.
    -- Then refocus the source window.
    if direction == "left" or direction == "up" then
        hs.task.new(AEROSPACE, function()
            refocusSource(direction)
        end, { "move", direction }):start()
    else
        refocusSource(direction)
    end
end

return M
