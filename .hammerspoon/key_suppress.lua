local M = {}
M.suppressedKeys = {}

M.tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    if event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1 then
        local code = event:getKeyCode()
        if M.suppressedKeys[code] then
            return true
        end
    end
    return false
end)
M.tap:start()

function M.start(keyName)
    if keyName then
        local code = hs.keycodes.map[keyName]
        if code then M.suppressedKeys[code] = true end
    end
end

function M.stop(keyName)
    if keyName then
        local code = hs.keycodes.map[keyName]
        if code then M.suppressedKeys[code] = nil end
    else
        M.suppressedKeys = {}
    end
end

return M
