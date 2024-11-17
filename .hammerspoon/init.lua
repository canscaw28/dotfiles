-- Smooth scrolling configuration
local scrollSpeed = 1 -- Adjust for smoothness (lines per step)
local scrollInterval = 0.04 -- Interval between scroll steps in seconds
local scrollDirection = 0 -- Tracks the current scroll direction
local scrollTimer = nil

-- Function to start smooth scrolling
local function startScrolling(direction)
    if scrollDirection ~= direction then
        -- If direction changes, restart the timer
        scrollDirection = direction
        if scrollTimer then
            scrollTimer:stop()
        end
        scrollTimer = hs.timer.doEvery(scrollInterval, function()
            hs.eventtap.scrollWheel({0, direction * scrollSpeed}, {}, "line")
        end)
    end
end

-- Function to stop smooth scrolling
local function stopScrolling()
    scrollDirection = 0
    if scrollTimer then
        scrollTimer:stop()
        scrollTimer = nil
    end
end

-- Eventtap to handle Ctrl + ` (scroll up) and Ctrl + 1 (scroll down)
local scrollHandler = hs.eventtap.new(
    {hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        -- Ctrl + ` for scroll up
        if modifiers.ctrl and keyCode == hs.keycodes.map["`"] and isDown then
            startScrolling(-1) -- Scroll up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["`"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 1 for scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["1"] and isDown then
            startScrolling(1) -- Scroll down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["1"] and not isDown then
            stopScrolling()
        end

        return false -- Allow other apps to process these keys normally
    end
)

-- Start the event handler
scrollHandler:start()

