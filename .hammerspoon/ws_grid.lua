-- ws_grid.lua
-- Workspace grid overlay shown while caps+T+W is held.
-- Hides when a sub-mode key (E/R/3/4) is also held.
-- Displays 4x5 grid of workspace keys styled as keyboard keycaps.
-- Visible workspaces colored by monitor. Focused workspace gets a * prefix.

local M = {}

local grid = nil
local pendingTask = nil
local keys = {t = false, w = false, e = false, r = false, ["3"] = false, ["4"] = false, q = false}

-- Grid layout: 4 rows of 5 keys with keyboard stagger
local ROWS = {
    {keys = {"6", "7", "8", "9", "0"}, stagger = 0},
    {keys = {"y", "u", "i", "o", "p"}, stagger = 0.25},
    {keys = {"h", "j", "k", "l", ";"}, stagger = 0.5},
    {keys = {"n", "m", ",", ".", "/"}, stagger = 0.75},
}

-- Monitor colors
local MONITOR_COLORS = {
    [1] = {red = 0.1, green = 0.3, blue = 0.7, alpha = 1},      -- blue
    [2] = {red = 0.7, green = 0.25, blue = 0.1, alpha = 1},     -- orange
    [3] = {red = 0.1, green = 0.5, blue = 0.25, alpha = 1},     -- green
    [4] = {red = 0.4, green = 0.15, blue = 0.6, alpha = 1},     -- purple
}

-- Keycap styling — high contrast so keys read as individual caps, not a blob
local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.85}
local KEY_FACE = {red = 0.38, green = 0.38, blue = 0.40, alpha = 0.95}
local KEY_FACE_ACTIVE = {red = 0.48, green = 0.48, blue = 0.50, alpha = 0.95}
local KEY_EDGE = {red = 0.28, green = 0.28, blue = 0.30, alpha = 0.95}  -- darker bottom/side for 3D
local KEY_BORDER = {red = 0.55, green = 0.55, blue = 0.58, alpha = 0.8}
local KEY_SHADOW = {red = 0, green = 0, blue = 0, alpha = 0.5}
local TEXT_COLOR_DIM = {red = 0.18, green = 0.18, blue = 0.20, alpha = 1}
local CELL_SIZE = 44
local CELL_GAP = 8
local KEY_RADIUS = 7
local FONT_SIZE = 17
local SHADOW_OFFSET = 3
local EDGE_HEIGHT = 4     -- visible "thickness" of keycap bottom edge
local PADDING = 14

-- Map AeroSpace workspace names to grid display keys
local AERO_TO_KEY = {
    [";"] = ";", ["comma"] = ",",
}

-- Map sub-mode keys to AeroSpace monitor IDs
local MODE_TO_MONITOR = {e = 1, r = 2, ["3"] = 3, ["4"] = 4}

-- Determine target monitor ID for grid display (nil = don't show)
local function targetMonitor()
    if not keys.t then return nil end
    if keys.q then return 0 end  -- 0 = current monitor
    if not keys.w then return nil end
    -- W held: check if a focus-on-monitor sub-mode is active
    for k, monId in pairs(MODE_TO_MONITOR) do
        if keys[k] then return monId end
    end
    return 0  -- W only = current monitor
end

-- Get screen for an AeroSpace monitor ID (sorted left-to-right to match AeroSpace ordering)
local function screenForMonitor(monitorId)
    if not monitorId or monitorId < 1 then return hs.mouse.getCurrentScreen() or hs.screen.mainScreen() end
    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)
    return screens[monitorId]  -- nil if monitor doesn't exist
end

local function shouldShowGrid()
    return targetMonitor() ~= nil
end

local function drawGrid(visibleWs, focusedKey, focusedMonId)
    if grid then
        grid:delete()
        grid = nil
    end

    local monId = targetMonitor()
    if monId == nil then return end
    -- For "current monitor" (0), use AeroSpace's focused monitor instead of mouse position
    local screen = screenForMonitor(monId == 0 and (focusedMonId or 0) or monId)
    if not screen then return end  -- target monitor doesn't exist
    local screenFrame = screen:frame()

    local numCols = 5
    local numRows = #ROWS
    local maxStagger = ROWS[numRows].stagger * CELL_SIZE
    local gridW = numCols * (CELL_SIZE + CELL_GAP) - CELL_GAP + maxStagger
    local gridH = numRows * (CELL_SIZE + CELL_GAP) - CELL_GAP + EDGE_HEIGHT
    local totalW = gridW + PADDING * 2
    local totalH = gridH + PADDING * 2

    local x = screenFrame.x + (screenFrame.w - totalW) / 2
    local y = screenFrame.y + (screenFrame.h - totalH) / 2

    grid = hs.canvas.new({x = x, y = y, w = totalW, h = totalH})
    grid:level(hs.canvas.windowLevels.overlay + 1)
    grid:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.transient)
    grid:clickActivating(false)
    grid:canvasMouseEvents(false)

    -- Plate: one opaque rounded rect per row, overlapping vertically.
    -- Even padding on all sides; smooth corner radius blends the row transitions.
    local PLATE_PAD = 12
    local PLATE_RADIUS = 10
    local PLATE_COLOR = {red = 0.1, green = 0.1, blue = 0.12, alpha = 1}
    local rowW = numCols * (CELL_SIZE + CELL_GAP) - CELL_GAP
    for rowIdx, row in ipairs(ROWS) do
        local rLeft = PADDING + row.stagger * CELL_SIZE - PLATE_PAD
        local rTop = PADDING + (rowIdx - 1) * (CELL_SIZE + CELL_GAP) - PLATE_PAD
        local rW = rowW + 2 * PLATE_PAD
        local rH = CELL_SIZE + 2 * PLATE_PAD
        if rowIdx < numRows then
            rH = rH + CELL_GAP  -- overlap into gap to merge with next row
        else
            rH = rH + EDGE_HEIGHT  -- cover key edge on last row
        end
        grid:appendElements({
            type = "rectangle",
            action = "fill",
            fillColor = PLATE_COLOR,
            roundedRectRadii = {xRadius = PLATE_RADIUS, yRadius = PLATE_RADIUS},
            frame = {x = rLeft, y = rTop, w = rW, h = rH},
        })
    end

    -- Draw keycaps
    -- All coordinates use absolute pixels (fractional 0-1 coords break rendering)
    for rowIdx, row in ipairs(ROWS) do
        for colIdx, key in ipairs(row.keys) do
            local cellX = PADDING + (colIdx - 1) * (CELL_SIZE + CELL_GAP) + row.stagger * CELL_SIZE
            local cellY = PADDING + (rowIdx - 1) * (CELL_SIZE + CELL_GAP)

            local monId = visibleWs[key]
            local isFocused = (key == focusedKey)
            local isActive = monId ~= nil

            -- Layer 1: Drop shadow (offset down for ground shadow)
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = KEY_SHADOW,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX + 1, y = cellY + SHADOW_OFFSET,
                         w = CELL_SIZE, h = CELL_SIZE},
            })

            -- Layer 2: Key edge/side (taller, darker — "thickness" peeks out at bottom)
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = KEY_EDGE,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE + EDGE_HEIGHT},
            })

            -- Layer 3: Key face (top surface, lighter, shorter to reveal edge at bottom)
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = isActive and KEY_FACE_ACTIVE or KEY_FACE,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE},
            })

            -- Layer 4: Border for definition
            grid:appendElements({
                type = "rectangle",
                action = "stroke",
                strokeWidth = 1.5,
                strokeColor = KEY_BORDER,
                roundedRectRadii = {xRadius = KEY_RADIUS, yRadius = KEY_RADIUS},
                frame = {x = cellX, y = cellY,
                         w = CELL_SIZE, h = CELL_SIZE},
            })

            -- Key label (vertically centered — hs.canvas text renders from top)
            local labelColor = (monId and MONITOR_COLORS[monId]) or TEXT_COLOR_DIM
            local displayText = isFocused and ("*" .. key) or key
            local fontName = isActive and "Helvetica-Bold" or "Helvetica"
            local styledText = hs.styledtext.new(displayText, {
                font = {name = fontName, size = FONT_SIZE},
                color = labelColor,
                paragraphStyle = {alignment = "center"},
            })
            local textOffsetY = (CELL_SIZE - FONT_SIZE * 1.25) / 2
            grid:appendElements({
                type = "text",
                text = styledText,
                frame = {x = cellX, y = cellY + textOffsetY, w = CELL_SIZE, h = FONT_SIZE * 1.5},
            })

        end
    end

    grid:alpha(0.9)
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
        local focusedMonId = nil
        for line in stdout:gmatch("[^\n]+") do
            local focused = line:match("^F:(.+)")
            if focused then
                focused = focused:match("^%s*(.-)%s*$")
                if focused ~= "" then
                    focusedKey = AERO_TO_KEY[focused] or focused
                end
            end
            local fm = line:match("^FM:(%d+)")
            if fm then
                focusedMonId = tonumber(fm)
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

        drawGrid(visibleWs, focusedKey, focusedMonId)
    end, {"-c", [[
        focused=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
        echo "F:$focused"
        focused_mon=$(/opt/homebrew/bin/aerospace list-monitors --focused --format '%{monitor-id}')
        echo "FM:$focused_mon"
        for m in $(/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}'); do
            ws=$(/opt/homebrew/bin/aerospace list-workspaces --monitor "$m" --visible)
            echo "M:$m:$ws"
        done
    ]]})
    pendingTask:start()
end

function M.getFrame()
    if grid then return grid:frame() end
    return nil
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
