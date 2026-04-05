require("hs.ipc")
require("line_nav")
require("ws_notify")
require("focus_border")
require("ws_grid")
require("key_suppress")
require("hs_server")
require("chrome_tabs")
require("chrome_warmup")
require("cursor_grid")
require("dock_peek")

screenWatcher = hs.screen.watcher.new(function()
    hs.timer.doAfter(2.0, function()
        hs.task.new("/Users/craig/.local/bin/cleanup-ws.sh", nil):start()
    end)
end)
screenWatcher:start()

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



scrollHandler = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
    function(event)
        local modifiers = event:getFlags()
        local keyCode = event:getKeyCode()
        local isDown = event:getType() == hs.eventtap.event.types.keyDown

        if isDown then
            keyStates[keyCode] = true
            if modifiers.ctrl and modifiers.shift then
                if keyCode == hs.keycodes.map["k"] then
                    startScrolling(10, false, keyCode)
                elseif keyCode == hs.keycodes.map["j"] then
                    startScrolling(-10, false, keyCode)
                elseif keyCode == hs.keycodes.map["h"] then
                    startScrolling(10, true, keyCode)
                elseif keyCode == hs.keycodes.map["l"] then
                    startScrolling(-10, true, keyCode)
                elseif keyCode == hs.keycodes.map["u"] then
                    if not lastKeyPressed then
                        smoothScroll(-getVisibleContentHeight() * 0.55, false, 0.15)
                    end
                    startScrolling(-25, false, keyCode)
                elseif keyCode == hs.keycodes.map["i"] then
                    if not lastKeyPressed then
                        smoothScroll(getVisibleContentHeight() * 0.55, false, 0.15)
                    end
                    startScrolling(25, false, keyCode)
                elseif keyCode == hs.keycodes.map["y"] then
                    scrollToTop()
                elseif keyCode == hs.keycodes.map["o"] then
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
