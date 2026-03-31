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
local currentGridSize = nil

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
-- Grid overlay
-- ============================================================

local LINE_STYLES = {
    major = {color = {red = 0, green = 0.8, blue = 0.2, alpha = 0.45}, width = 1.5},
    mid   = {color = {red = 0.4, green = 0.7, blue = 1.0, alpha = 0.35}, width = 1.0},
    minor = {color = {red = 0.5, green = 0.6, blue = 0.8, alpha = 0.2}, width = 0.5,
             dash = {4, 4}},
}

local function classifyLine(pos, gridSize)
    if gridSize <= 8 then
        if pos == gridSize / 2 then return "major" end
        return "mid"
    else
        -- 32x32: hierarchical classification
        if pos == gridSize / 2 then return "major"          -- 16 → 2x2 midline
        elseif pos % (gridSize / 8) == 0 then return "mid"  -- 4,8,12,20,24,28 → 8x8
        elseif pos % (gridSize / 16) == 0 then return "minor" -- 2,6,10,... → 16x16
        else return nil
        end
    end
end

local function createGridCanvas(gridSize)
    local win = hs.window.focusedWindow()
    if not win then return end
    local f = win:frame()

    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end

    local elements = {}
    local cellW = f.w / gridSize
    local cellH = f.h / gridSize

    for i = 1, gridSize - 1 do
        local cat = classifyLine(i, gridSize)
        if cat then
            local style = LINE_STYLES[cat]
            local vx = math.floor(i * cellW)
            local hy = math.floor(i * cellH)

            if style.dash then
                table.insert(elements, {
                    type = "segments",
                    coordinates = {{x = vx, y = 0}, {x = vx, y = f.h}},
                    strokeColor = style.color,
                    strokeWidth = style.width,
                    strokeDashPattern = style.dash,
                    action = "stroke",
                })
                table.insert(elements, {
                    type = "segments",
                    coordinates = {{x = 0, y = hy}, {x = f.w, y = hy}},
                    strokeColor = style.color,
                    strokeWidth = style.width,
                    strokeDashPattern = style.dash,
                    action = "stroke",
                })
            else
                table.insert(elements, {
                    type = "rectangle",
                    frame = {x = vx, y = 0, w = style.width, h = f.h},
                    fillColor = style.color,
                    action = "fill",
                })
                table.insert(elements, {
                    type = "rectangle",
                    frame = {x = 0, y = hy, w = f.w, h = style.width},
                    fillColor = style.color,
                    action = "fill",
                })
            end
        end
    end

    gridCanvas = hs.canvas.new({x = f.x, y = f.y, w = f.w, h = f.h})
    gridCanvas:level(hs.canvas.windowLevels.overlay)
    gridCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces + hs.canvas.windowBehaviors.stationary)
    gridCanvas:mouseCallback(function() return true end)
    gridCanvas:canvasMouseEvents(false)

    for idx, elem in ipairs(elements) do
        gridCanvas[idx] = elem
    end

    gridCanvas:show()
    gridVisible = true
    currentGridSize = gridSize
end

function M.toggleGrid(gridSize)
    if gridVisible and currentGridSize == gridSize then
        M.hideGrid()
    else
        createGridCanvas(gridSize)
    end
end

function M.hideGrid()
    if gridCanvas then
        gridCanvas:delete()
        gridCanvas = nil
    end
    gridVisible = false
    currentGridSize = nil
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

function M.move(direction, amount, gridSize)
    if gridCol == nil or gridRow == nil or lastGridSize ~= gridSize then
        if not snapToGrid(gridSize) then return end
    end

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

    lastGridSize = gridSize
    moveToCellCenter(gridSize)
    showIndicator()
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

    -- Update grid tracking to match new position (snap to 8x8)
    gridCol = math.floor(pos[1] * 8)
    gridRow = math.floor(pos[2] * 8)
    gridCol = math.max(0, math.min(gridCol, 7))
    gridRow = math.max(0, math.min(gridRow, 7))
    lastGridSize = 8

    showIndicator()
end

-- ============================================================
-- Reset
-- ============================================================

function M.reset()
    gridCol = nil
    gridRow = nil
    lastGridSize = nil
end

return M
