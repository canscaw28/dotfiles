local M = {}

function M.focus(direction)
    local chrome = hs.application.get("Google Chrome")
    if not chrome then return end

    local focused = chrome:focusedWindow()
    if not focused then return end

    local screenFrames = {}
    for _, s in ipairs(hs.screen.allScreens()) do
        table.insert(screenFrames, s:frame())
    end

    local function isOnScreen(f)
        local cx = f.x + f.w / 2
        local cy = f.y + f.h / 2
        for _, sf in ipairs(screenFrames) do
            if cx >= sf.x and cx < sf.x + sf.w and cy >= sf.y and cy < sf.y + sf.h then
                return true
            end
        end
        return false
    end

    local sf = focused:frame()
    local srcCX = sf.x + sf.w / 2
    local srcCY = sf.y + sf.h / 2

    local target = nil
    local bestDist = math.huge

    for _, w in ipairs(chrome:allWindows()) do
        if w:id() ~= focused:id() and w:isVisible() then
            local f = w:frame()
            if isOnScreen(f) then
                local cx = f.x + f.w / 2
                local cy = f.y + f.h / 2
                local dx = cx - srcCX
                local dy = cy - srcCY
                local valid = false
                local dist = 0

                if direction == "right" then valid = dx > 0; dist = dx
                elseif direction == "left" then valid = dx < 0; dist = -dx
                elseif direction == "down" then valid = dy > 0; dist = dy
                elseif direction == "up" then valid = dy < 0; dist = -dy
                end

                if valid and dist < bestDist then
                    bestDist = dist
                    target = w
                end
            end
        end
    end

    if target then
        target:focus()
        require("focus_border").flash()
    end
end

return M
