local M = {}

M.server = hs.httpserver.new(false, false)
M.server:setPort(27183)
M.server:setCallback(function(method, path)
    if path == "/focus-border-flash" then
        require("focus_border").flash()
        return "", 200, {}
    end
    local direction = path:match("^/chrome%-tab%-new%-window%?direction=(%a+)")
    if direction then
        require("chrome_tab_move").positionNewWindow(direction)
        return "", 200, {}
    end
    return "", 404, {}
end)
M.server:start()

return M
