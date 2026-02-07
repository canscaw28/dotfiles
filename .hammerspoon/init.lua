require("hs.ipc")

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

function chromeTabMove(direction)
    local sourceWin = hs.window.focusedWindow()
    if not sourceWin then return end
    local app = sourceWin:application()
    if not app or app:bundleID() ~= "com.google.Chrome" then return end

    local ok, result = hs.osascript.applescript(
        'tell application "Google Chrome" to return {active tab index of front window, count tabs of front window}'
    )
    if not ok then return end
    local tabIndex = result[1]
    local tabCount = result[2]
    local sourceFrame = sourceWin:frame()

    -- Find nearest Chrome window in the given direction (pure geometry, no focus dance)
    local targetWin = nil
    local bestDist = math.huge
    for _, w in ipairs(app:allWindows()) do
        if w:id() ~= sourceWin:id() and w:isVisible() then
            local f = w:frame()
            local inDir, dist = false, 0
            if direction == "right" then
                inDir = f.x >= sourceFrame.x + sourceFrame.w * 0.5
                dist = f.x - (sourceFrame.x + sourceFrame.w)
            elseif direction == "left" then
                inDir = f.x + f.w <= sourceFrame.x + sourceFrame.w * 0.5
                dist = sourceFrame.x - (f.x + f.w)
            elseif direction == "down" then
                inDir = f.y >= sourceFrame.y + sourceFrame.h * 0.5
                dist = f.y - (sourceFrame.y + sourceFrame.h)
            elseif direction == "up" then
                inDir = f.y + f.h <= sourceFrame.y + sourceFrame.h * 0.5
                dist = sourceFrame.y - (f.y + f.h)
            end
            if inDir and dist < bestDist then
                bestDist = dist
                targetWin = w
            end
        end
    end
    if not targetWin then return end

    local targetFrame = targetWin:frame()
    local origMouse = hs.mouse.absolutePosition()

    -- Calculate source tab center position
    -- Chrome tab bar: starts ~70px from left edge, tabs near window top
    local tabBarLeft = sourceFrame.x + 70
    local tabBarWidth = sourceFrame.w - 150
    local tabWidth = math.min(tabBarWidth / tabCount, 240)
    local tabX = tabBarLeft + (tabIndex - 0.5) * tabWidth
    local tabY = sourceFrame.y + 25

    -- Target: center of target tab bar
    local dropX = targetFrame.x + targetFrame.w / 2
    local dropY = targetFrame.y + 25

    -- Detach height: drag below tab bar to initiate Chrome tab detach
    local detachY = math.max(tabY, dropY) + 60

    -- Build waypoints: grab → detach → traverse → drop
    local waypoints = {
        {x = tabX,  y = tabY},
        {x = tabX,  y = detachY},
        {x = dropX, y = detachY},
        {x = dropX, y = dropY},
    }

    -- Helper: post mouse event with modifier flags cleared
    local function mouseEvent(type, pt)
        local e = hs.eventtap.event.newMouseEvent(type, pt)
        e:setFlags({})
        e:post()
    end

    -- Simulate drag: move actual cursor and post matching events
    local stepsPerSegment = 20
    local stepDelay = 6000 -- 6ms per step

    -- Temporarily float source window so AeroSpace doesn't interfere with the drag
    hs.execute("aerospace layout floating", true)
    hs.timer.usleep(50000)

    local success, err = pcall(function()
        -- Move cursor to tab and press down
        hs.mouse.absolutePosition(waypoints[1])
        hs.timer.usleep(80000)
        mouseEvent(hs.eventtap.event.types.leftMouseDown, waypoints[1])
        hs.timer.usleep(150000)

        -- Drag through waypoints
        for seg = 1, #waypoints - 1 do
            local from = waypoints[seg]
            local to = waypoints[seg + 1]
            for i = 1, stepsPerSegment do
                local t = i / stepsPerSegment
                local pt = {x = from.x + (to.x - from.x) * t, y = from.y + (to.y - from.y) * t}
                hs.mouse.absolutePosition(pt)
                mouseEvent(hs.eventtap.event.types.leftMouseDragged, pt)
                hs.timer.usleep(stepDelay)
            end
        end

        -- Release
        mouseEvent(hs.eventtap.event.types.leftMouseUp, waypoints[#waypoints])
        hs.timer.usleep(200000)
    end)

    -- Restore: tile the window back and reset mouse position
    hs.execute("aerospace layout tiling", true)
    hs.mouse.absolutePosition(origMouse)

    if not success then
        print("chromeTabMove error: " .. tostring(err))
    end

    -- Focus back to source window (if it still exists -- last tab case closes it)
    if sourceWin:isVisible() then
        sourceWin:focus()
    end
end
