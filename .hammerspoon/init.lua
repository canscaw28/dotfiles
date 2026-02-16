require("line_nav")
require("ws_notify")

scrollSpeed = 1
scrollInterval = 0.01
scrollDirection = 0
scrollTimer = nil
smoothTimer = nil
keyStates = {}
lastKeyPressed = nil
isContinuousScrolling = {}

function getVisibleContentHeight()
    local win = hs.window.focusedWindow()
    if win then
        return win:frame().h
    else
        return hs.screen.mainScreen():frame().h
    end
end

function startScrolling(direction, horizontal, keyCode)
    isContinuousScrolling[keyCode] = true
    if scrollDirection ~= direction or lastKeyPressed ~= keyCode then
        lastKeyPressed = keyCode
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

function stopScrolling(keyCode)
    isContinuousScrolling[keyCode] = false
    if keyCode == lastKeyPressed then
        scrollDirection = 0
        lastKeyPressed = nil
        if scrollTimer then
            scrollTimer:stop()
            scrollTimer = nil
        end
    end
end

function smoothScroll(pixels, horizontal, duration)
    if smoothTimer then
        smoothTimer:stop()
        smoothTimer = nil
    end

    local steps = math.max(1, math.floor(duration / scrollInterval))
    local easingFunction = function(t) return t * t end
    local totalDistance = 0
    local distances = {}

    for step = 1, steps do
        local t = step / steps
        local easedStep = easingFunction(t) - easingFunction((step - 1) / steps)
        local stepDistance = math.floor(easedStep * pixels)
        totalDistance = totalDistance + stepDistance
        table.insert(distances, stepDistance)
    end

    local adjustment = pixels - totalDistance
    distances[#distances] = distances[#distances] + adjustment

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

function scrollToTop()
    smoothScroll(-1000000, false, 0.3)
end

function scrollToBottom()
    smoothScroll(1000000, false, 0.3)
end

function moveToBottomLeftCornerOfFocusedWindow()
    local win = hs.window.focusedWindow()
    if win then
        local f = win:frame()
        local newPoint = hs.geometry.point(f.x + f.w - 50, f.y + f.h / 2)
        hs.mouse.absolutePosition(newPoint)
    else
        hs.alert.show("No active window found")
    end
end


hs.hotkey.bind({"ctrl"}, "0", moveToBottomLeftCornerOfFocusedWindow)

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
                    startScrolling(-10, false, keyCode)
                elseif keyCode == hs.keycodes.map["1"] then
                    startScrolling(10, false, keyCode)
                elseif keyCode == hs.keycodes.map["2"] then
                    startScrolling(10, true, keyCode)
                elseif keyCode == hs.keycodes.map["3"] then
                    startScrolling(-10, true, keyCode)
                elseif keyCode == hs.keycodes.map["4"] then
                    if not lastKeyPressed then
                        smoothScroll(-getVisibleContentHeight() * 0.55, false, 0.15)
                    end
                    startScrolling(-25, false, keyCode)
                elseif keyCode == hs.keycodes.map["5"] then
                    if not lastKeyPressed then
                        smoothScroll(getVisibleContentHeight() * 0.55, false, 0.15)
                    end
                    startScrolling(25, false, keyCode)
                elseif keyCode == hs.keycodes.map["6"] then
                    if not lastKeyPressed then
                        smoothScroll(-getVisibleContentHeight() * 0.9, false, 0.3)
                    end
                    startScrolling(-50, false, keyCode)
                elseif keyCode == hs.keycodes.map["7"] then
                    if not lastKeyPressed then
                        smoothScroll(getVisibleContentHeight() * 0.9, false, 0.3)
                    end
                    startScrolling(50, false, keyCode)
                elseif keyCode == hs.keycodes.map["8"] then
                    scrollToTop()
                elseif keyCode == hs.keycodes.map["9"] then
                    scrollToBottom()
                end
            end
        else
            keyStates[keyCode] = nil
            stopScrolling(keyCode)
        end
        return false
    end
)

scrollHandler:start()

hs.shutdownCallback = function()
    if scrollHandler then
        scrollHandler:stop()
    end
end
