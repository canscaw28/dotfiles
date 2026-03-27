local M = {}

local AEROSPACE = "/opt/homebrew/bin/aerospace"
local OPPOSITES = { left = "right", right = "left", up = "down", down = "up" }

function M.positionNewWindow(direction)
    -- New Chrome window is currently focused (just created by extension).
    -- Move it in the desired direction, then refocus the source window.
    hs.task.new(AEROSPACE, function()
        hs.task.new(AEROSPACE, function()
            require("focus_border").flash()
        end, { "focus", OPPOSITES[direction] }):start()
    end, { "move", direction }):start()
end

return M
