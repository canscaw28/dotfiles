local M = {}

-- Track cursor grid position (col, row) — 0-indexed
local gridCol = nil
local gridRow = nil
local lastGridSize = nil

-- Convert current mouse position to nearest grid cell
local function snapToGrid(gridSize)
    local win = hs.window.focusedWindow()
    if not win then return false end
    local f = win:frame()
    local pos = hs.mouse.absolutePosition()

    local cellW = f.w / gridSize
    local cellH = f.h / gridSize

    -- Clamp mouse to window bounds
    local relX = math.max(0, math.min(pos.x - f.x, f.w - 1))
    local relY = math.max(0, math.min(pos.y - f.y, f.h - 1))

    gridCol = math.floor(relX / cellW)
    gridRow = math.floor(relY / cellH)

    -- Clamp to valid range
    gridCol = math.max(0, math.min(gridCol, gridSize - 1))
    gridRow = math.max(0, math.min(gridRow, gridSize - 1))
    lastGridSize = gridSize

    return true
end

-- Move mouse to center of current grid cell
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

--- Move the cursor on the grid.
--- @param direction string: "left", "right", "up", "down"
--- @param amount number: grid cells to move (negative for jump-to-edge)
--- @param gridSize number: 8 or 16
function M.move(direction, amount, gridSize)
    -- Re-snap if grid size changed or first use
    if gridCol == nil or gridRow == nil or lastGridSize ~= gridSize then
        if not snapToGrid(gridSize) then return end
    end

    if direction == "left" then
        if amount < 0 then
            gridCol = 0  -- jump to edge
        else
            gridCol = math.max(0, gridCol - amount)
        end
    elseif direction == "right" then
        if amount < 0 then
            gridCol = gridSize - 1  -- jump to edge
        else
            gridCol = math.min(gridSize - 1, gridCol + amount)
        end
    elseif direction == "up" then
        if amount < 0 then
            gridRow = 0  -- jump to edge
        else
            gridRow = math.max(0, gridRow - amount)
        end
    elseif direction == "down" then
        if amount < 0 then
            gridRow = gridSize - 1  -- jump to edge
        else
            gridRow = math.min(gridSize - 1, gridRow + amount)
        end
    end

    lastGridSize = gridSize
    moveToCellCenter(gridSize)
end

--- Reset tracked position (forces re-snap on next move)
function M.reset()
    gridCol = nil
    gridRow = nil
    lastGridSize = nil
end

return M
