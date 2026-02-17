-- ws_grid.lua
-- Workspace grid overlay shown while caps+T+W is held.
-- Hides when a sub-mode key (E/R/3/4) is also held.
-- Displays 4x5 grid of workspace keys with colored text and underlines
-- for workspaces visible on each monitor. Focused workspace gets a * prefix.

local M = {}

local grid = nil
local pendingTask = nil
local keys = {t = false, w = false, e = false, r = false, ["3"] = false, ["4"] = false}

-- Grid layout: 4 rows of 5 keys with keyboard stagger
local ROWS = {
    {keys = {"6", "7", "8", "9", "0"}, stagger = 0},
    {keys = {"y", "u", "i", "o", "p"}, stagger = 0.25},
    {keys = {"h", "j", "k", "l", ";"}, stagger = 0.5},
    {keys = {"n", "m", ",", ".", "/"}, stagger = 0.75},
}

-- Monitor colors
local MONITOR_COLORS = {
    [1] = {red = 0.2, green = 0.5, blue = 1, alpha = 1},      -- blue
    [2] = {red = 1, green = 0.4, blue = 0.2, alpha = 1},      -- orange
    [3] = {red = 0.2, green = 0.8, blue = 0.4, alpha = 1},    -- green
    [4] = {red = 0.6, green = 0.3, blue = 0.9, alpha = 1},    -- purple
}

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.8}
local CELL_BG = {red = 0.2, green = 0.2, blue = 0.2, alpha = 0.9}
local TEXT_COLOR_DIM = {red = 0.5, green = 0.5, blue = 0.5, alpha = 1}
local CELL_SIZE = 40
local CELL_GAP = 6
local CELL_RADIUS = 6
local FONT_SIZE = 18
local UNDERLINE_HEIGHT = 3
local PADDING = 14

-- Map AeroSpace workspace names to grid display keys
local AERO_TO_KEY = {
    [";"] = ";", ["comma"] = ",",
}

local function shouldShowGrid()
    return keys.t and keys.w and not (keys.e or keys.r or keys["3"] or keys["4"])
end

local function drawGrid(visibleWs, focusedKey)
    if grid then
        grid:delete()
        grid = nil
    end

    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()

    local numCols = 5
    local numRows = #ROWS
    local maxStagger = ROWS[numRows].stagger * CELL_SIZE
    local gridW = numCols * (CELL_SIZE + CELL_GAP) - CELL_GAP + maxStagger
    local gridH = numRows * (CELL_SIZE + CELL_GAP) - CELL_GAP
    local totalW = gridW + PADDING * 2
    local totalH = gridH + PADDING * 2

    local x = screenFrame.x + (screenFrame.w - totalW) / 2
    local y = screenFrame.y + (screenFrame.h - totalH) / 2

    grid = hs.canvas.new({x = x, y = y, w = totalW, h = totalH})
    grid:level(hs.canvas.windowLevels.overlay)
    grid:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    grid:clickActivating(false)
    grid:canvasMouseEvents(false)

    -- Background
    grid:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = BG_COLOR,
        roundedRectRadii = {xRadius = 12, yRadius = 12},
    })

    -- Draw cells
    for rowIdx, row in ipairs(ROWS) do
        for colIdx, key in ipairs(row.keys) do
            local cellX = PADDING + (colIdx - 1) * (CELL_SIZE + CELL_GAP) + row.stagger * CELL_SIZE
            local cellY = PADDING + (rowIdx - 1) * (CELL_SIZE + CELL_GAP)

            -- Fractional coords for rectangles
            local fx = cellX / totalW
            local fy = cellY / totalH
            local fw = CELL_SIZE / totalW
            local fh = CELL_SIZE / totalH

            local monId = visibleWs[key]
            local isFocused = (key == focusedKey)

            -- Cell background
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = CELL_BG,
                roundedRectRadii = {xRadius = CELL_RADIUS, yRadius = CELL_RADIUS},
                frame = {x = fx, y = fy, w = fw, h = fh},
            })

            -- Key label — monitor color for visible workspaces, dim for others
            -- Focused workspace (on focused monitor) gets a star prefix
            local labelColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
            local displayText = isFocused and ("*" .. key) or key
            grid:appendElements({
                type = "text",
                text = displayText,
                textColor = labelColor,
                textSize = FONT_SIZE,
                textAlignment = "center",
                frame = {x = cellX, y = cellY, w = CELL_SIZE, h = CELL_SIZE},
            })

            -- Colored underline for visible workspaces
            if monId and MONITOR_COLORS[monId] then
                local barInset = 6
                local barX = (cellX + barInset) / totalW
                local barY = (cellY + CELL_SIZE - UNDERLINE_HEIGHT - 4) / totalH
                local barW = (CELL_SIZE - barInset * 2) / totalW
                local barH = UNDERLINE_HEIGHT / totalH

                grid:appendElements({
                    type = "rectangle",
                    action = "fill",
                    fillColor = MONITOR_COLORS[monId],
                    roundedRectRadii = {xRadius = 1, yRadius = 1},
                    frame = {x = barX, y = barY, w = barW, h = barH},
                })
            end
        end
    end

    grid:alpha(1)
    grid:show()
end

function M.showGrid()
    -- Cancel any in-flight workspace query
    if pendingTask and pendingTask:isRunning() then
        pendingTask:terminate()
        pendingTask = nil
    end

    -- Query workspace state asynchronously to avoid blocking Hammerspoon IPC
    pendingTask = hs.task.new("/bin/bash", function(exitCode, stdout, stderr)
        pendingTask = nil
        if exitCode ~= 0 then return end
        -- Re-check key state — user may have released keys during async query
        if not shouldShowGrid() then return end

        local visibleWs = {}
        local focusedKey = nil
        for line in stdout:gmatch("[^\n]+") do
            local focused = line:match("^F:(.+)")
            if focused then
                focused = focused:match("^%s*(.-)%s*$")
                if focused ~= "" then
                    focusedKey = AERO_TO_KEY[focused] or focused
                end
            end
            local monId, ws = line:match("^M:(%d+):(.+)")
            if monId and ws then
                ws = ws:match("^%s*(.-)%s*$")
                if ws ~= "" then
                    local displayKey = AERO_TO_KEY[ws] or ws
                    visibleWs[displayKey] = tonumber(monId)
                end
            end
        end

        drawGrid(visibleWs, focusedKey)
    end, {"-c", [[
        focused=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
        echo "F:$focused"
        for m in $(/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}'); do
            ws=$(/opt/homebrew/bin/aerospace list-workspaces --monitor "$m" --visible)
            echo "M:$m:$ws"
        done
    ]]})
    pendingTask:start()
end

function M.hideGrid()
    if pendingTask and pendingTask:isRunning() then
        pendingTask:terminate()
        pendingTask = nil
    end
    if grid then
        grid:delete()
        grid = nil
    end
end

local function refresh()
    if shouldShowGrid() then
        M.showGrid()
    else
        M.hideGrid()
    end
end

function M.keyDown(k)
    keys[k] = true
    refresh()
end

function M.keyUp(k)
    keys[k] = false
    refresh()
end

return M
