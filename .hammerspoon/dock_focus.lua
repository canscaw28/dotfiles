-- Virtual focus for use while the dock is visible.
-- No AX focus/raise calls are made (they trigger macOS's window frame
-- constraint). Instead, a visual indicator shows the "selected" window.
-- The actual focus is applied when the dock hides.
local M = {}

local selectedWindow = nil

function M.focus(direction)
    local cur = selectedWindow or hs.window.focusedWindow()
    if not cur then return false end

    local target
    if direction == "left" then
        target = cur:windowsToWest(nil, true, true)
    elseif direction == "right" then
        target = cur:windowsToEast(nil, true, true)
    elseif direction == "up" then
        target = cur:windowsToNorth(nil, true, true)
    elseif direction == "down" then
        target = cur:windowsToSouth(nil, true, true)
    end

    if target and #target > 0 then
        selectedWindow = target[1]
        -- Visual indicator only — no actual focus change
        require('focus_border').flashWindowId(selectedWindow:id())
        return true
    end
    return false
end

-- Apply the virtual focus as a real focus (call when dock hides)
function M.apply()
    if selectedWindow then
        selectedWindow:focus()
        selectedWindow = nil
    end
end

-- Reset without applying (e.g., if dock hide is cancelled)
function M.reset()
    selectedWindow = nil
end

return M
