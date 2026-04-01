local M = {}

local active = false
local DOCK_TOGGLE = os.getenv("HOME") .. "/.local/bin/dock-toggle"
local AEROSPACE = "/opt/homebrew/bin/aerospace"

function M.show()
    if active then return end
    active = true

    -- Disable AeroSpace to prevent retiling
    hs.task.new(AEROSPACE, nil, {"enable", "off"}):start()

    -- Warp cursor to bottom of focused monitor so dock appears there
    local savedPos = hs.mouse.absolutePosition()
    local screen = hs.mouse.getCurrentScreen()
    if screen then
        local frame = screen:fullFrame()
        local bottomCenter = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h - 1)
        hs.mouse.absolutePosition(bottomCenter)
    end

    -- Show dock
    hs.task.new(DOCK_TOGGLE, function()
        -- Restore cursor after dock-toggle completes
        hs.mouse.absolutePosition(savedPos)
    end, {"show"}):start()
end

function M.hide()
    if not active then return end
    active = false

    -- Hide dock, then re-enable AeroSpace after dock starts hiding
    hs.task.new(DOCK_TOGGLE, function()
        hs.timer.doAfter(0.3, function()
            hs.task.new(AEROSPACE, nil, {"enable", "on"}):start()
        end)
    end, {"hide"}):start()
end

function M.isActive()
    return active
end

return M
