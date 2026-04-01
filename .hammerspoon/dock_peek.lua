local M = {}
local cursor = require("cursor_hide")

local savedPos = nil
local active = false

function M.show()
    if active then return end
    active = true

    -- Save current cursor position
    savedPos = hs.mouse.absolutePosition()

    -- Find the bottom edge of the focused monitor
    local screen = hs.mouse.getCurrentScreen()
    if not screen then
        active = false
        return
    end
    local frame = screen:fullFrame()
    local target = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h - 1)

    -- Hide cursor, then warp to dock edge
    cursor.hide()
    hs.mouse.absolutePosition(target)
    -- Post a mouse-moved event so the Dock sees the cursor at the edge
    hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, target):post()
end

function M.hide()
    if not active then return end
    active = false

    -- Restore cursor position and show cursor
    if savedPos then
        hs.mouse.absolutePosition(savedPos)
        savedPos = nil
    end
    cursor.show()
end

function M.isActive()
    return active
end

return M
