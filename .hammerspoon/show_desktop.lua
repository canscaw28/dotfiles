-- Lightweight state tracker for Show Desktop (caps+A+O).
-- Does NOT post key events — Karabiner sends fn+F11 directly.
local M = {}

local active = false

function M.toggle()
    active = not active
end

function M.isActive()
    return active
end

function M.dismiss()
    if not active then return end
    active = false
    hs.eventtap.event.newKeyEvent({}, 'f11', true):setFlags({fn=true}):post()
    hs.eventtap.event.newKeyEvent({}, 'f11', false):setFlags({fn=true}):post()
end

return M
