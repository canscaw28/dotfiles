-- Smooth scrolling configuration
scrollSpeed = 1 -- Adjust for smoothness (lines per step)
scrollInterval = 0.01 -- Interval between scroll steps in seconds
scrollDirection = 0 -- Tracks the current scroll direction
scrollTimer = nil
smoothTimer = nil
keyStates = {} -- Tracks the state of keys (pressed or released)
activeTimers = {} -- To track smoothScroll timers
debounceTimers = {} -- To differentiate taps and holds
isContinuousScrolling = {} -- Tracks if continuous scrolling has started for a key

-- Function to get the visible content height
function getVisibleContentHeight()
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

-- Function to start smooth scrolling
function startScrolling(direction, horizontal, keyCode)
    isContinuousScrolling[keyCode] = true -- Mark as continuous scrolling
    if scrollDirection ~= direction then
        scrollDirection = direction
        if scrollTimer then
            scrollTimer:stop()
        end
        scrollTimer = hs.timer.doEvery(scrollInterval, function()
            if horizontal then
                hs.eventtap.scrollWheel({direction * scrollSpeed, 0}, {}, "pixel")
            else
                hs.eventtap.scrollWheel({0, direction * scrollSpeed}, {}, "pixel")
            end
        end)
    end
end

-- Function to stop smooth scrolling
function stopScrolling(keyCode)
    isContinuousScrolling[keyCode] = false -- Reset continuous scrolling flag
    scrollDirection = 0
    if scrollTimer then
        scrollTimer:stop()
        scrollTimer = nil
    end
end

-- Smooth scrolling function
function smoothScroll(pixels, horizontal, duration)
    local steps = math.max(1, math.floor(duration / scrollInterval)) -- Total number of steps
    local easingFunction = function(t)
        return t * t -- Quadratic easing
    end

    local totalDistance = 0 -- Tracks total distance to ensure accuracy
    local distances = {} -- Precompute distances for each step

    for step = 1, steps do
        local t = step / steps -- Normalize step to range [0, 1]
        local easedStep = easingFunction(t) - easingFunction((step - 1) / steps) -- Delta easing
        local stepDistance = math.floor(easedStep * pixels) -- Convert to integer
        totalDistance = totalDistance + stepDistance -- Accumulate total distance
        table.insert(distances, stepDistance)
    end

    -- Adjust for rounding errors
    local adjustment = pixels - totalDistance
    distances[#distances] = distances[#distances] + adjustment -- Apply adjustment to the last step

    -- Stop any existing smooth scrolling
    if smoothTimer then
        smoothTimer:stop()
        smoothTimer = nil
    end

    -- Start scrolling
    local currentStep = 0
    smoothTimer = hs.timer.doEvery(scrollInterval, function()
        currentStep = currentStep + 1
        if currentStep <= #distances then
            local distance = distances[currentStep]
            if horizontal then
                hs.eventtap.scrollWheel({distance}, {}, "pixel")
            else
                hs.eventtap.scrollWheel({0, distance}, {}, "pixel")
            end
        else
            smoothTimer:stop()
            smoothTimer = nil
        end
    end)
end

-- Eventtap handler
scrollHandler = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        if isDown then
            keyStates[keyCode] = true
            if modifiers.ctrl then
                if keyCode == hs.keycodes.map["`"] then
                    startScrolling(-10, false, keyCode) -- Scroll up
                elseif keyCode == hs.keycodes.map["1"] then
                    startScrolling(10, false, keyCode) -- Scroll down
                elseif keyCode == hs.keycodes.map["2"] then
                    startScrolling(10, true, keyCode) -- Scroll right
                elseif keyCode == hs.keycodes.map["3"] then
                    startScrolling(-10, true, keyCode) -- Scroll left
                elseif keyCode == hs.keycodes.map["4"] then
                    smoothScroll(-getVisibleContentHeight() * 0.55, false, 0.15) -- Half-page up
                    startScrolling(-10, false, keyCode) -- Start continuous scrolling
                elseif keyCode == hs.keycodes.map["5"] then
                    smoothScroll(getVisibleContentHeight() * 0.55, false, 0.15) -- Half-page down
                    startScrolling(10, false, keyCode) -- Start continuous scrolling
                end
            end
        else
            keyStates[keyCode] = nil
            stopScrolling(keyCode)
        end

        return false -- Allow other apps to process these keys normally
    end
)

-- Start the event handler
scrollHandler:start()
