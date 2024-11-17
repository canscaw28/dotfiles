-- Smooth scrolling configuration
local scrollSpeed = 1 -- Adjust for smoothness (lines per step)
local scrollInterval = 0.01 -- Interval between scroll steps in seconds
local scrollDirection = 0 -- Tracks the current scroll direction
local scrollTimer = nil
local keyStates = {} -- Tracks the state of keys (pressed or released)
local activeTimers = {} -- To track smoothScroll timers

-- Function to get the visible content height
local function getVisibleContentHeight()
    local win = hs.window.focusedWindow()
    if win then
        local frame = win:frame()
        return frame.h
    else
        local screen = hs.screen.mainScreen()
        local frame = screen:frame()
        return frame.h
    end
end

-- Function to start smooth scrolling with an optional delay
local function startScrolling(direction, horizontal, delay)
    if scrollDirection ~= direction then
        scrollDirection = direction
        if scrollTimer then
            scrollTimer:stop()
        end
        scrollTimer = hs.timer.doAfter(delay or 0, function()
            scrollTimer = hs.timer.doEvery(scrollInterval, function()
                if horizontal then
                    hs.eventtap.scrollWheel({direction * scrollSpeed, 0}, {}, "pixel")
                else
                    hs.eventtap.scrollWheel({0, direction * scrollSpeed}, {}, "pixel")
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

local function smoothScroll(pixels, horizontal, duration)
    local steps = math.max(1, math.floor(duration / scrollInterval)) -- Total number of steps
    local easingFunction = function(t)
        return t * t -- Quadratic easing
    end

    local totalDistance = 0 -- Tracks total distance to ensure accuracy
    local distances = {} -- Precompute distances for each step

    -- Precompute step distances using the easing function
    for step = 1, steps do
        local t = step / steps -- Normalize step to range [0, 1]
        local easedStep = easingFunction(t) - easingFunction((step - 1) / steps) -- Delta easing
        local stepDistance = math.floor(easedStep * pixels) -- Convert to integer
        totalDistance = totalDistance + stepDistance -- Accumulate total distance
        table.insert(distances, stepDistance)
    end

    -- Adjust for rounding errors
    local adjustment = pixels - totalDistance -- Remainder from rounding
    distances[#distances] = distances[#distances] + adjustment -- Apply adjustment to the last step

    -- Start scrolling
    local currentStep = 0
    local smoothTimer = hs.timer.doEvery(scrollInterval, function()
        currentStep = currentStep + 1
        if currentStep <= #distances then
            local distance = distances[currentStep]
            if horizontal then
                hs.eventtap.scrollWheel({distance}, {}, "pixel")
            else
                hs.eventtap.scrollWheel({0, distance}, {}, "pixel")
            end
        else
            smoothTimer:stop() -- Stop the timer after all steps are completed
        end
    end)
end


-- Eventtap to handle various Ctrl + [2-9] key scrolls
local scrollHandler = hs.eventtap.new(
    { hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        -- Handle key press/release state
        if isDown then
            if not keyStates[keyCode] then -- Only trigger smoothScroll on first press
                keyStates[keyCode] = true

                -- Ctrl + 4 for half-page scroll up
                if modifiers.ctrl and keyCode == hs.keycodes.map["4"] then
                    local halfPage = math.floor(getVisibleContentHeight() * 0.5) or 400 -- Default fallback to 400 pixels
                    smoothScroll(-halfPage, false, 0.175) -- Smoothly scroll up over 0.5 seconds
                    startScrolling(-20, false, 0.15) -- Optional continuous scrolling after delay
                elseif modifiers.ctrl and keyCode == hs.keycodes.map["4"] and not isDown then
                    stopScrolling()
                end

                -- Ctrl + 5 for half-page scroll down
                if modifiers.ctrl and keyCode == hs.keycodes.map["5"] then
                    local halfPage = math.floor(getVisibleContentHeight() * 0.5) or 400 -- Default fallback to 400 pixels
                    smoothScroll(halfPage, false, 0.175) -- Smoothly scroll down over 0.5 seconds
                    startScrolling(20, false, 0.15) -- Optional continuous scrolling after delay
                elseif modifiers.ctrl and keyCode == hs.keycodes.map["5"] and not isDown then
                    stopScrolling()
                end

                -- Ctrl + 6 for full-page scroll up
                if modifiers.ctrl and keyCode == hs.keycodes.map["6"] then
                    local fullPage = math.floor(getVisibleContentHeight()) or 800 -- Default fallback to 800 pixels
                    smoothScroll(-fullPage, false, 0.8) -- Smoothly scroll up over 0.8 seconds
                end

                -- Ctrl + 7 for full-page scroll down
                if modifiers.ctrl and keyCode == hs.keycodes.map["7"] then
                    local fullPage = math.floor(getVisibleContentHeight()) or 800 -- Default fallback to 800 pixels
                    smoothScroll(fullPage, false, 0.8) -- Smoothly scroll down over 0.8 seconds
                end

                -- Ctrl + 8 for scroll to top
                if modifiers.ctrl and keyCode == hs.keycodes.map["8"] then
                    hs.eventtap.keyStroke({}, "home")
                end

                -- Ctrl + 9 for scroll to bottom
                if modifiers.ctrl and keyCode == hs.keycodes.map["9"] then
                    hs.eventtap.keyStroke({}, "end")
                end
            end
        else
            keyStates[keyCode] = nil -- Reset key state on release
            if modifiers.ctrl and (keyCode == hs.keycodes.map["4"] or keyCode == hs.keycodes.map["5"]) then
                stopScrolling()
            end
        end

        -- Ctrl + ` for continuous scroll up
        if modifiers.ctrl and keyCode == hs.keycodes.map["`"] and isDown then
            startScrolling(-10) -- Scroll up
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["`"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 1 for continuous scroll down
        if modifiers.ctrl and keyCode == hs.keycodes.map["1"] and isDown then
            startScrolling(10) -- Scroll down
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["1"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 2 for scroll right
        if modifiers.ctrl and keyCode == hs.keycodes.map["2"] and isDown then
            startScrolling(10, true) -- Scroll right
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["2"] and not isDown then
            stopScrolling()
        end

        -- Ctrl + 3 for scroll left
        if modifiers.ctrl and keyCode == hs.keycodes.map["3"] and isDown then
            startScrolling(-10, true) -- Scroll left
        elseif modifiers.ctrl and keyCode == hs.keycodes.map["3"] and not isDown then
            stopScrolling()
        end

        return false -- Allow other apps to process these keys normally
    end
)

-- Start the event handler
scrollHandler:start()
