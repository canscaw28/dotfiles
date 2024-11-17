-- Smooth scrolling configuration
local scrollSpeed = 1 -- Adjust for smoothness (lines per step)
local scrollInterval = 0.01 -- Interval between scroll steps in seconds
local scrollDirection = 0 -- Tracks the current scroll direction
local scrollTimer = nil
local keyStates = {} -- Tracks the state of keys (pressed or released)
local activeTimers = {} -- To track smoothScroll timers

-- Periodic failsafe to stop scrolling
local failsafeTimer = hs.timer.doEvery(0.5, function()
    local isAnyKeyActive = false
    for _, state in pairs(keyStates) do
        if state then
            isAnyKeyActive = true
            break
        end
    end

    if not isAnyKeyActive and scrollTimer then
        stopScrolling()
    end
end)

-- Reset key states periodically
hs.timer.doEvery(1, function()
    for key, _ in pairs(keyStates) do
        keyStates[key] = nil
    end
    stopScrolling()
end)



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

-- Improved smooth scrolling function
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

-- Improved eventtap handler
scrollHandler = hs.eventtap.new(
    {hs.eventtap.event.types.flagsChanged, hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        -- Track key states
        if isDown then
            keyStates[keyCode] = true
        else
            keyStates[keyCode] = nil
            stopScrolling() -- Stop scrolling on key release
        end

        -- Continuous scrolling
        if modifiers.ctrl then
            if keyCode == hs.keycodes.map["`"] and isDown then
                startScrolling(-10) -- Scroll up
            elseif keyCode == hs.keycodes.map["1"] and isDown then
                startScrolling(10) -- Scroll down
            elseif keyCode == hs.keycodes.map["2"] and isDown then
                startScrolling(10, true) -- Scroll right
            elseif keyCode == hs.keycodes.map["3"] and isDown then
                startScrolling(-10, true) -- Scroll left
            end
        end

        -- Half-page and full-page scrolls
        if modifiers.ctrl and isDown then
            if keyCode == hs.keycodes.map["4"] then
                smoothScroll(-getVisibleContentHeight() * 0.5, false, 0.175) -- Half-page up
            elseif keyCode == hs.keycodes.map["5"] then
                smoothScroll(getVisibleContentHeight() * 0.5, false, 0.175) -- Half-page down
            elseif keyCode == hs.keycodes.map["6"] then
                smoothScroll(-getVisibleContentHeight(), false, 0.8) -- Full-page up
            elseif keyCode == hs.keycodes.map["7"] then
                smoothScroll(getVisibleContentHeight(), false, 0.8) -- Full-page down
            elseif keyCode == hs.keycodes.map["8"] then
                hs.eventtap.keyStroke({}, "home") -- Scroll to top
            elseif keyCode == hs.keycodes.map["9"] then
                hs.eventtap.keyStroke({}, "end") -- Scroll to bottom
            end
        end

        return false -- Allow other apps to process these keys normally
    end
)

-- Start the event handler
scrollHandler:start()

-- Modifier-based forced stop
hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
    local modifiers = event:getFlags()
    if not modifiers.ctrl then
        stopScrolling()
    end
    return false
end):start()
