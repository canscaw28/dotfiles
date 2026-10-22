local M = {}

M.server = hs.httpserver.new(false, false)
M.server:setPort(27183)
M.server:setCallback(function(method, path)
    if path == "/focus-border-flash" then
        require("focus_border").flash()
        return "", 200, {}
    end
    local direction, params = path:match("^/chrome%-tab%-new%-window%?direction=(%a+)(.*)")
    if direction then
        local follow = params and params:match("follow=true") ~= nil
        require("chrome_tab_move").positionNewWindow(direction, follow)
        return "", 200, {}
    end
    -- Pane numbers (tmux-pane-num.sh) of panes running an agent, so tab-mover
    -- can mark tab groups of ended sessions as unassigned. Synchronous, but
    -- tmux answers in milliseconds and this is polled only every 30s.
    if path == "/agent-panes" then
        local out, ok = hs.execute("/opt/homebrew/bin/tmux list-panes -a -F '#{pane_current_command} #{@num}'")
        if not ok then return "", 503, {} end
        local nums = {}
        for cmd, num in out:gmatch("(%S+) (%d+)") do
            if cmd:match("^claude") or cmd:match("^codex") then table.insert(nums, tonumber(num)) end
        end
        return hs.json.encode(nums), 200, { ["Content-Type"] = "application/json" }
    end
    return "", 404, {}
end)
M.server:start()

return M
