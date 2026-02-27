local M = {}
M.active = false

M.tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    if M.active
       and event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1 then
        return true
    end
    return false
end)
M.tap:start()

function M.start()
    M.active = true
end

function M.stop()
    M.active = false
end

return M
