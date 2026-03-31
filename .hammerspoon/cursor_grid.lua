local M = {}

-- ============================================================
-- State
-- ============================================================
local gridCol = nil
local gridRow = nil
local lastGridSize = nil

-- Indicator
local indicatorCanvas = nil
local indicatorFadeTimer = nil
local INDICATOR_DIAMETER = 16
local INDICATOR_COLOR = {red = 1, green = 0.6, blue = 0.1, alpha = 0.7}

-- Grid overlay
local gridCanvas = nil
local gridVisible = false
local gridEnabled = false  -- toggled by P, persists until reset
local currentGridSize = nil
local currentGridMode = nil -- "move" or "jump"

-- Hold-to-repeat
local moveTimer = nil
local REPEAT_DELAY = 0.3   -- initial delay before repeat (like OS key repeat)
local REPEAT_INTERVAL = 0.065

-- Fixed positions for F+E mode {xFraction, yFraction}
local JUMP_POSITIONS = {
    h         = {0.0625, 0.5},     -- left center
    l         = {0.9375, 0.5},     -- right center
    j         = {0.5, 0.9375},     -- bottom center
    k         = {0.5, 0.0625},     -- top center
    semicolon = {0.5, 0.5},        -- window center
    y         = {0.0625, 0.0625},  -- top-left corner
    o         = {0.9375, 0.0625},  -- top-right corner
    n         = {0.0625, 0.9375},  -- bottom-left corner
    period    = {0.9375, 0.9375},  -- bottom-right corner
    u         = {0.25, 0.25},      -- top-left quadrant center
    i         = {0.75, 0.25},      -- top-right quadrant center
    m         = {0.25, 0.75},      -- bottom-left quadrant center
    comma     = {0.75, 0.75},      -- bottom-right quadrant center
}

-- ============================================================
-- Indicator (amber dot at cursor position)
-- ============================================================
local function showIndicator()
    if indicatorFadeTimer then
        indicatorFadeTimer:stop()
        indicatorFadeTimer = nil
    end

    local pos = hs.mouse.absolutePosition()
    local x = pos.x - INDICATOR_DIAMETER / 2
    local y = pos.y - INDICATOR_DIAMETER / 2

    if not indicatorCanvas then
        indicatorCanvas = hs.canvas.new({x = x, y = y, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER})
        indicatorCanvas:level(hs.canvas.windowLevels.overlay)
        indicatorCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
        indicatorCanvas[1] = {
            type = "oval",
            frame = {x = 0, y = 0, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER},
            fillColor = INDICATOR_COLOR,
            action = "fill",
        }
    else
        indicatorCanvas:frame({x = x, y = y, w = INDICATOR_DIAMETER, h = INDICATOR_DIAMETER})
    end

    indicatorCanvas:alpha(1)
    indicatorCanvas:show()

    local fadeSteps = 10
    local fadeInterval = 0.05
    local step = 0
    indicatorFadeTimer = hs.timer.doEvery(fadeInterval, function()
        step = step + 1
        if step >= fadeSteps then
            indicatorCanvas:hide()
            indicatorFadeTimer:stop()
            indicatorFadeTimer = nil
        else
            indicatorCanvas:alpha(1 - step / fadeSteps)
        end
    end)
end

-- ============================================================
-- Grid overlay — lines through cell CENTERS (intersections = landing positions)
-- ============================================================

local LINE_STYLES = {
    major = {color = {red = 0, green = 0.85, blue = 0.3, alpha = 0.6}, width = 2.0},
    mid   = {color = {red = 0.4, green = 0.75, blue = 1.0, alpha = 0.5}, width = 1.5},
    minor = {color = {red = 0.5, green = 0.6, blue = 0.8, alpha = 0.3}, width = 1.0,
             dash = {6, 4}},
}

local function classifyMoveLine(cellIdx, gridSize)
    if gridSize <= 8 then
        return "mid"
    else
        if cellIdx % 8 == 0 then return "major"
        elseif cellIdx % 4 == 0 then return "mid"
        elseif cellIdx % 2 == 0 then return "minor"
        else return nil
        end
    end
end

local function addLine(elements, x, y, w, h, style)
    if style.dash then
        if w < h then
            table.insert(elements, {
                type = "segments",
                coordinates = {{x = x, y = y}, {x = x, y = y + h}},
                strokeColor = style.color,
                strokeWidth = style.width,
                strokeDashPattern = style.dash,
                action = "stroke",
            })
        else
            table.insert(elements, {
                type = "segments",
                coordinates = {{x = x, y = y}, {x = x + w, y = y}},
                strokeColor = style.color,
                strokeWidth = style.width,
                strokeDashPattern = style.dash,
                action = "stroke",
            })
        end
    else
        table.insert(elements, {
            type = "rectangle",
            frame = {x = x, y = y, w = math.max(w, style.width), h = math.max(h, style.width)},
            fillColor = style.color,
            action = "fill",
        })
    end
end

local function createMoveGrid(gridSize, winFrame)
    local elements = {}
    local cellW = winFrame.w / gridSize
    local cellH = winFrame.h / gridSize

    for i = 0, gridSize - 1 do
        local cat = classifyMoveLine(i, gridSize)
        if cat then
            local style = LINE_STYLES[cat]
            local cx = math.floor((i + 0.5) * cellW)
            local cy = math.floor((i + 0.5) * cellH)
            addLine(elements, cx, 0, style.width, winFrame.h, style)
            addLine(elements, 0, cy, winFrame.w, style.width, style)
        end
    end

    return elements
end

local function createJumpGrid(winFrame)
    local elements = {}
    local DOT_SIZE = 10
    local DOT_COLOR = {red = 1, green = 0.6, blue = 0.1, alpha = 0.5}

    for _, pos in pairs(JUMP_POSITIONS) do
        local px = math.floor(pos[1] * winFrame.w)
        local py = math.floor(pos[2] * winFrame.h)
        local armLen = 12
        local armW = 1.5
        table.insert(elements, {
            type = "rectangle",
            frame = {x = px - armLen, y = py - armW / 2, w = armLen * 2, h = armW},
            fillColor = DOT_COLOR,
            action = "fill",
        })
        table.insert(elements, {
            type = "rectangle",
            frame = {x = px - armW / 2, y = py - armLen, w = armW, h = armLen * 2},
            fillColor = DOT_COLOR,
            action = "fill",
        })
        table.insert(elements, {
            type = "oval",
            frame = {x = px - DOT_SIZE / 2, y = py - DOT_SIZE / 2, w = DOT_SIZE, h = DOT_SIZE},
            fillColor = DOT_COLOR,
            action = "fill",
        })
    end

    return elements
end

local function showGrid(gridSize, mode)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end

    local elements
    if mode == "jump" then
        elements = createJumpGrid(f)
    else
        elements = createMoveGrid(gridSize, f)
    end

    gridCanvas = hs.canvas.new({x = f.x, y = f.y, w = f.w, h = f.h})
    gridCanvas:level(hs.canvas.windowLevels.overlay)
    gridCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    gridCanvas:canvasMouseEvents(false)

    for idx, elem in ipairs(elements) do
        gridCanvas[idx] = elem
    end

    gridCanvas:show()
    gridVisible = true
    currentGridSize = gridSize
    currentGridMode = mode
end

-- Re-show grid if enabled and mode/size changed
local function ensureGrid(gridSize, mode)
    if gridEnabled then
        if not gridVisible or currentGridSize ~= gridSize or currentGridMode ~= mode then
            showGrid(gridSize, mode)
        end
    end
end

function M.toggleGrid(gridSize, mode)
    mode = mode or "move"
    if gridEnabled then
        gridEnabled = false
        M.hideGrid()
    else
        gridEnabled = true
        showGrid(gridSize, mode)
    end
end

-- Hide the canvas but keep gridEnabled (grid re-shows when mode re-entered)
function M.hideGrid()
    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end
    gridVisible = false
    currentGridSize = nil
    currentGridMode = nil
end

-- ============================================================
-- Grid-based cursor movement (F+D, F+S)
-- ============================================================

local function snapToGrid(gridSize)
    local win = hs.window.focusedWindow()
    if not win then return false end
    local f = win:frame()
    local pos = hs.mouse.absolutePosition()

    local cellW = f.w / gridSize
    local cellH = f.h / gridSize

    local relX = math.max(0, math.min(pos.x - f.x, f.w - 1))
    local relY = math.max(0, math.min(pos.y - f.y, f.h - 1))

    gridCol = math.floor(relX / cellW)
    gridRow = math.floor(relY / cellH)
    gridCol = math.max(0, math.min(gridCol, gridSize - 1))
    gridRow = math.max(0, math.min(gridRow, gridSize - 1))
    lastGridSize = gridSize

    return true
end

local function moveToCellCenter(gridSize)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    local cellW = f.w / gridSize
    local cellH = f.h / gridSize

    local x = f.x + (gridCol + 0.5) * cellW
    local y = f.y + (gridRow + 0.5) * cellH

    hs.mouse.absolutePosition(hs.geometry.point(x, y))
end

local function doMove(direction, amount, gridSize)
    if direction == "left" then
        if amount < 0 then gridCol = 0
        else gridCol = math.max(0, gridCol - amount) end
    elseif direction == "right" then
        if amount < 0 then gridCol = gridSize - 1
        else gridCol = math.min(gridSize - 1, gridCol + amount) end
    elseif direction == "up" then
        if amount < 0 then gridRow = 0
        else gridRow = math.max(0, gridRow - amount) end
    elseif direction == "down" then
        if amount < 0 then gridRow = gridSize - 1
        else gridRow = math.min(gridSize - 1, gridRow + amount) end
    end
end

function M.move(direction, amount, gridSize)
    if gridCol == nil or gridRow == nil or lastGridSize ~= gridSize then
        if not snapToGrid(gridSize) then return end
    end

    doMove(direction, amount, gridSize)
    lastGridSize = gridSize
    moveToCellCenter(gridSize)
    showIndicator()
end

-- Hold-to-repeat: first move immediate, then OS-style delay before continuous repeat
function M.startMove(direction, amount, gridSize)
    M.stopMove()
    ensureGrid(gridSize, "move")
    M.move(direction, amount, gridSize)
    -- Initial delay (like holding a key on the keyboard)
    moveTimer = hs.timer.doAfter(REPEAT_DELAY, function()
        -- Delay expired — start continuous repeat
        M.move(direction, amount, gridSize)
        moveTimer = hs.timer.doEvery(REPEAT_INTERVAL, function()
            M.move(direction, amount, gridSize)
        end)
    end)
end

function M.stopMove()
    if moveTimer then
        moveTimer:stop()
        moveTimer = nil
    end
end

-- ============================================================
-- Fixed-position jumps (F+E)
-- ============================================================

function M.jump(position)
    local pos = JUMP_POSITIONS[position]
    if not pos then return end

    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    local x = f.x + pos[1] * f.w
    local y = f.y + pos[2] * f.h

    hs.mouse.absolutePosition(hs.geometry.point(x, y))

    gridCol = math.floor(pos[1] * 8)
    gridRow = math.floor(pos[2] * 8)
    gridCol = math.max(0, math.min(gridCol, 7))
    gridRow = math.max(0, math.min(gridRow, 7))
    lastGridSize = 8

    ensureGrid(8, "jump")
    showIndicator()
end

-- ============================================================
-- Reset — clears all state including gridEnabled
-- ============================================================

function M.reset()
    gridCol = nil
    gridRow = nil
    lastGridSize = nil
    gridEnabled = false
end

return M
