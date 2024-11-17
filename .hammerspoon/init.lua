-- Smooth scrolling configuration
local scrollSpeed = 1 -- Adjust for smoothness (lines per step)
local scrollInterval = 0.04 -- Interval between scroll steps in seconds
local scrollDirection = 0 -- Tracks the current scroll direction
local scrollTimer = nil

-- Function to start smooth scrolling
local function startScrolling(direction, horizontal)
    if scrollDirection ~= direction then
        scrollDirection = direction
        if scrollTimer then
            scrollTimer:stop()
        end
        scrollTimer = hs.timer.doEvery(scrollInterval, function()
            if horizontal then
                hs.eventtap.scrollWheel({direction * scrollSpeed, 0}, {}, "line")
            else
                hs.eventtap.scrollWheel({0, direction * scrollSpeed}, {}, "line")
            end
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

-- Function for one-time actions (like half/full page or top/bottom)
local function singleScroll(lines, horizontal)
    if horizontal then
        hs.eventtap.scrollWheel({lines, 0}, {}, "line")
    else
        hs.eventtap.scrollWheel({0, lines}, {}, "line")
    end
end

-- Eventtap to handle various Ctrl + [2-0] key scrolls
local scrollHandler = hs.eventtap.new(
    {hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        -- Ctrl + ` for scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["`"] and isDown then
            startScrolling(1) -- Scroll up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["`"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 1 for scroll up
        if modifiers.ctrl and keyCode == hs.keycodes.map["1"] and isDown then
            startScrolling(-1) -- Scroll down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["1"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 2 for scroll right
        if modifiers.ctrl and keyCode == hs.keycodes.map["2"] and isDown then
            startScrolling(1, true) -- Scroll right
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["2"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 3 for scroll left
        if modifiers.ctrl and keyCode == hs.keycodes.map["3"] and isDown then
            startScrolling(-1, true) -- Scroll left
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["3"] and not isDown then
            stopScrolling()
        end

        if modifiers.ctrl and keyCode == hs.keycodes.map["4"] and isDown then
            startScrolling(-2) -- Scroll half a page down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["4"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 1 for scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["5"] and isDown then
            startScrolling(2) -- Scroll half a page up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["5"] and not isDown then
            stopScrolling()
        end

        if modifiers.ctrl and keyCode == hs.keycodes.map["6"] and isDown then
            startScrolling(-4) -- Scroll a full half page down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["6"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 1 for scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["7"] and isDown then
            startScrolling(4) -- Scroll a full half page up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["7"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 8 for scroll to top
        if modifiers.ctrl and keyCode == hs.keycodes.map["8"] and isDown then
            singleScroll(-math.huge) -- Scroll to top
        end

        -- Ctrl + 9 for scroll to bottom
        if modifiers.ctrl and keyCode == hs.keycodes.map["9"] and isDown then
            singleScroll(math.huge) -- Scroll to bottom
        end

        return false -- Allow other apps to process these keys normally
    end
)

-- Start the event handler
scrollHandler:start()

