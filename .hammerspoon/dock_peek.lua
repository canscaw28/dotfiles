local M = {}

local active = false
local savedPos = nil
local hideTimer = nil
local DOCK_TOGGLE = os.getenv("HOME") .. "/.local/bin/dock-toggle"
local AEROSPACE = os.getenv("HOME") .. "/.local/bin/aerospace"

function M.show()
    -- Cancel any pending hide sequence
    if hideTimer then
        hideTimer:stop()
        hideTimer = nil
    end

    if active then return end
    active = true

    -- Freeze tiling so AeroSpace never calls setFrame while dock is visible
    hs.task.new(AEROSPACE, function()
        -- Determine focused monitor
        local screen = nil
        local win = hs.window.focusedWindow()
        if win then screen = win:screen() end
        if not screen then
            screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
        end
        local frame = screen:fullFrame()
        local bottomCenter = hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h - 1)

        -- Warp cursor to dock edge so macOS targets this monitor
        savedPos = hs.mouse.absolutePosition()
        hs.mouse.absolutePosition(bottomCenter)
        hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.mouseMoved, bottomCenter):post()

        -- Brief pause for dock to register this monitor, then show and restore cursor
        hs.timer.doAfter(0.05, function()
            hs.task.new(DOCK_TOGGLE, function()
                if savedPos then
                    hs.mouse.absolutePosition(savedPos)
                    savedPos = nil
                end
            end, {"show"}):start()
        end)
    end, {"freeze-tiling", "on"}):start()
end

function M.hide()
    if not active then return end
    active = false

    -- Restore cursor if still warped
    if savedPos then
        hs.mouse.absolutePosition(savedPos)
        savedPos = nil
    end

    -- Hide dock, then unfreeze tiling after dock finishes hiding
    hs.task.new(DOCK_TOGGLE, nil, {"hide"}):start()
    hideTimer = hs.timer.doAfter(0.3, function()
        hideTimer = nil
        hs.task.new(AEROSPACE, nil, {"freeze-tiling", "off"}):start()
    end)
end

function M.toggle()
    if active then
        M.hide()
    else
        M.show()
    end
end

function M.isActive()
    return active
end

return M
