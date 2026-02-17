-- ws_grid.lua
-- Workspace grid overlay shown while caps+T+W+(E/R/3/4) is held.
-- Displays 4x5 grid of workspace keys with colored circles for visible workspaces.

local M = {}

local grid = nil
local keys = {w = false, e = false, r = false, ["3"] = false, ["4"] = false}

-- Grid layout: 4 rows of 5 keys with keyboard stagger
local ROWS = {
    {keys = {"6", "7", "8", "9", "0"}, stagger = 0},
    {keys = {"y", "u", "i", "o", "p"}, stagger = 0.25},
    {keys = {"h", "j", "k", "l", ";"}, stagger = 0.5},
    {keys = {"n", "m", ",", ".", "/"}, stagger = 0.75},
}

-- Monitor colors
local MONITOR_COLORS = {
    [1] = {red = 0.2, green = 0.5, blue = 1, alpha = 0.9},    -- blue
    [2] = {red = 1, green = 0.4, blue = 0.2, alpha = 0.9},    -- orange
    [3] = {red = 0.2, green = 0.8, blue = 0.4, alpha = 0.9},  -- green
    [4] = {red = 0.6, green = 0.3, blue = 0.9, alpha = 0.9},  -- purple
}

local BG_COLOR = {red = 0.1, green = 0.1, blue = 0.1, alpha = 0.8}
local CELL_BG = {red = 0.2, green = 0.2, blue = 0.2, alpha = 0.9}
local TEXT_COLOR = {red = 0.9, green = 0.9, blue = 0.9, alpha = 1}
local CELL_SIZE = 60
local CELL_GAP = 8
local CELL_RADIUS = 8
local FONT_SIZE = 24
local RING_WIDTH = 3
local PADDING = 20

-- Map AeroSpace workspace names to grid display keys
local AERO_TO_KEY = {
    [";"] = ";", ["comma"] = ",",
}

local function getVisibleWorkspaces()
    local mapping = {}
    local output, ok = hs.execute("/opt/homebrew/bin/aerospace list-monitors --format '%{monitor-id}'")
    if not ok then return mapping end

    for monId in output:gmatch("(%d+)") do
        local wsOutput, ok2 = hs.execute("/opt/homebrew/bin/aerospace list-workspaces --monitor " .. monId .. " --visible")
        if ok2 then
            local ws = wsOutput:match("^%s*(.-)%s*$")
            if ws and ws ~= "" then
                local displayKey = AERO_TO_KEY[ws] or ws
                mapping[displayKey] = tonumber(monId)
            end
        end
    end
    return mapping
end

function M.showGrid()
    if grid then
        grid:delete()
        grid = nil
    end

    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()

    local visibleWs = getVisibleWorkspaces()

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

            -- Fractional coords for rectangles (works fine)
            local fx = cellX / totalW
            local fy = cellY / totalH
            local fw = CELL_SIZE / totalW
            local fh = CELL_SIZE / totalH

            -- Cell background
            grid:appendElements({
                type = "rectangle",
                action = "fill",
                fillColor = CELL_BG,
                roundedRectRadii = {xRadius = CELL_RADIUS, yRadius = CELL_RADIUS},
                frame = {x = fx, y = fy, w = fw, h = fh},
            })

            -- Monitor indicator ring
            local monId = visibleWs[key]
            if monId and MONITOR_COLORS[monId] then
                grid:appendElements({
                    type = "rectangle",
                    action = "stroke",
                    strokeColor = MONITOR_COLORS[monId],
                    strokeWidth = RING_WIDTH,
                    roundedRectRadii = {xRadius = CELL_RADIUS, yRadius = CELL_RADIUS},
                    frame = {x = fx, y = fy, w = fw, h = fh},
                })
            end

            -- Key label (absolute pixel coords — fractional breaks text)
            grid:appendElements({
                type = "text",
                text = key,
                textColor = TEXT_COLOR,
                textSize = FONT_SIZE,
                textAlignment = "center",
                frame = {x = cellX, y = cellY, w = CELL_SIZE, h = CELL_SIZE},
            })
        end
    end

    grid:alpha(1)
    grid:show()
end

function M.hideGrid()
    if grid then
        grid:delete()
        grid = nil
    end
end

local function refresh()
    if keys.w and (keys.e or keys.r or keys["3"] or keys["4"]) then
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
