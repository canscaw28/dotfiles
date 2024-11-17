-- Smooth scrolling configuration
local scrollSpeed = 1 -- Adjust for smoothness (lines per step)
local scrollInterval = 0.04 -- Interval between scroll steps in seconds
local scrollDirection = 0 -- Tracks the current scroll direction
local scrollTimer = nil
local keyStates = {} -- Tracks the state of keys (pressed or released)

-- Function to start smooth scrolling with an optional delay
local function startScrolling(direction, horizontal, delay)
    if scrollDirection ~= direction then
        scrollDirection = direction
        if scrollTimer then
            scrollTimer:stop()
        end
        scrollTimer = hs.timer.doAfter(delay or 0, function() -- Optional delay
            scrollTimer = hs.timer.doEvery(scrollInterval, function()
                if horizontal then
                    hs.eventtap.scrollWheel({direction * scrollSpeed, 0}, {}, "line")
                else
                    hs.eventtap.scrollWheel({0, direction * scrollSpeed}, {}, "line")
                end
            end)
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

        -- Handle key press/release state
        if isDown then
            if not keyStates[keyCode] then -- Only trigger singleScroll on first press
                keyStates[keyCode] = true
                if modifiers.ctrl and keyCode == hs.keycodes.map["4"] then
                    singleScroll(-10) -- Instant half-page up
                    startScrolling(-2, false, 0.1) -- Continuous scrolling after a delay
                elseif modifiers.ctrl and keyCode == hs.keycodes.map["5"] then
                    singleScroll(10) -- Instant half-page down
                    startScrolling(2, false, 0.1) -- Continuous scrolling after a delay
                end
            end
        else
            keyStates[keyCode] = nil -- Reset key state on release
            if modifiers.ctrl and (keyCode == hs.keycodes.map["4"] or keyCode == hs.keycodes.map["5"]) then
                stopScrolling()
            end
        end

        -- Ctrl + 1 for continuous scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["1"] and isDown then
            startScrolling(1) -- Continuous scroll down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["1"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + ` for continuous scroll up
        if modifiers.ctrl and keyCode == hs.keycodes.map["`"] and isDown then
            startScrolling(-1) -- Continuous scroll up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["`"] and not isDown then
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

        -- Ctrl + 6 for full-page scroll up (instant only)
        if modifiers.ctrl and keyCode == hs.keycodes.map["6"] and isDown then
            singleScroll(-30) -- Full-page up
        end

        -- Ctrl + 7 for full-page scroll down (instant only)
        if modifiers.ctrl and keyCode == hs.keycodes.map["7"] and isDown then
            singleScroll(30) -- Full-page down
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
