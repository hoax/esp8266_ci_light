function sendNotFound (c) 
    c:send("HTTP/1.0 404 Not found\r\n"
        .. "Connection: close\r\n\r\n"
        .. "NOT FOUND!")
end

function closeConnection (c)
    c:close()
end

function sendParts (c, parts)
    local function sender (sck)
        if #parts>0 then 
            local part = table.remove(parts,1)
            part(sck)
        else 
            sck:close()
        end
    end
    c:on('sent', sender)
    sender(c)
end

function sendHeaders (c)
    c:send("HTTP/1.0 200 OK\r\n"
        --.. "Server: nodemcu-httpserver\r\n"
        .. "Access-Control-Allow-Origin: *\r\n"
        .. "Content-Type: text/html\r\n" 
        .. "Connection: close\r\n\r\n")
end

function sendHead (c)
    c:send("<html>"
        .. "<head><title>Continuous Integration Light v0.1</title></head>"
        .. "<body>")
end

function sendFooter (c)
    c:send("</body></html>")
end

function sendIndexBody (c)
    c:send("Verwenden Sie die URL <em>/light/$color/$brightness</em> um die einzelnen Farben zu steuern.<br>"
        .. "$color steht hierbei f&uuml;r <em>red</emd>,<em>yellow</em> oder <em>green</em> und $brightness ist eine "
        .. "Ganzzahl von 0 (= aus) bis 1023 (= 100% an).<br>"
        .. "Aktueller Zustand: <ul>"
        .. "<li>Rot: " .. pwm.getduty(LEDS.red)
        .. "<li>Gelb: " .. pwm.getduty(LEDS.yellow)
        .. "<li>Gr&uuml;n: " .. pwm.getduty(LEDS.green)
        .. "</ul>")
end

function sendStatus (c)
    c:send('{ "red":' .. pwm.getduty(LEDS.red)
        .. ', "yellow":' .. pwm.getduty(LEDS.yellow)
        .. ', "green":' .. pwm.getduty(LEDS.green)
        .. '}')
end

function serveIndex (c)
    local parts = { sendHeaders, sendHead, sendIndexBody, sendFooter, closeConnection } 
    sendParts(c, parts)
end

function serveStatus (c)
    local parts = { sendHeaders, sendStatus, closeConnection }
    sendParts(c, parts)
end

function serveNotFound (c)
    local parts = { sendNotFound, closeConnection }
    sendParts(c, parts)
end

function processFade (entry)
    local fade = entry.fade
    tmr.unregister(LEDS[fade.color]-1)
    local value = fade.from
    tmr.alarm(LEDS[fade.color]-1, fade.delay, tmr.ALARM_SEMI, function ()
        pwm.setduty(LEDS[fade.color], value)
        local nextValue = value + fade.step
        if (fade.step > 0 and nextValue > fade.to)
                or (fade.step < 0 and nextValue < fade.to) then
            nextValue = fade.to
        end
        if (value < fade.to and nextValue <= fade.to) 
            or (value > fade.to and nextValue >= fade.to) then
            value = nextValue
            tmr.start(LEDS[fade.color]-1)
        else
            tmr.unregister(LEDS[fade.color]-1)
            processBlinkQueue()
        end
    end)
end

_blinkQueue = {}
function processBlinkQueue ()
    while #_blinkQueue > 0 do
        local entry = table.remove(_blinkQueue, 1)
        if entry then
            if _blinkQueue.doRepeat == true then
                table.insert(_blinkQueue, entry)
            end
    
            if entry.setColor then
                local led = LEDS[entry.setColor.color]
                pwm.setduty(led, entry.setColor.value)
            end
            if entry.fade then
                processFade(entry)
                break
            end
            if entry.delay then
                tmr.alarm(3, entry.delay, tmr.ALARM_SINGLE, processBlinkQueue)
                break
            end
        end
    end
end

function matchDelay (url)
    return url:find("^/delay/(%d+)")
end

function matchRepeat (url)
    return url:find('^/repeat/')
end

function matchFade (url)
    return url:find('^/fade/(%a+)/(%d+)/(%d+)/(%d+)/(%d+)')
end

function setQueue (newQueue)
    for i=4,6 do
        tmr.unregister(i)
    end
    tmr.unregister(3)
    _blinkQueue = newQueue 
end

function handleLight (c, url)
    local blinkQueue = {}
    
    function enqueue (entry)
        table.insert(blinkQueue, entry)
    end

    url = url:sub(7)
    while #url > 0 do
        if matchDelay(url) then
            local _, endIndex, timeStr = matchDelay(url)
            local time = tonumber(timeStr)
            if time then
                url = url:sub(endIndex + 1)
                enqueue({ delay = tonumber(time) })
            else
                serveNotFound(c)
                return
            end
        elseif matchRepeat(url) then
            url = url:sub(8)
            blinkQueue.doRepeat = true
        elseif matchFade(url) then
            local _, endIndex, color, delayStr, fromStr, toStr, stepStr = matchFade(url)
            url = url:sub(endIndex+1)
            local delay = tonumber(delayStr)
            local from = tonumber(fromStr)
            local to = tonumber(toStr)
            local step = tonumber(stepStr)
            delay = math.min(1023, delay)
            from = math.min(1023, from)
            to = math.min(1023, to)
            step = math.min(1023, step)
            if to < from then
                step = step * -1
            end
            if LEDS[color] and delay and from and to and step then
                enqueue({fade={color=color, delay=delay, from=from, to=to, step=step}})
            end
        else
            local _, endIndex, color, value = url:find("^/(%a+)/(%d+)")
            if color and value and LEDS[color] then
                url = url:sub(endIndex + 1)
                value = tonumber(value)
                if not value or value < 0 then
                    value = 0
                elseif value > 1023 then
                    value = 1023
                end
                enqueue({setColor={color=color, value=value}})
            else
                serveNotFound(c)
                return
            end
        end
    end

    setQueue(blinkQueue)
    processBlinkQueue()
    serveStatus(c)
end

function handlePresetBuildFade (c)
    tmr.unregister(3)
    local queue = {
        doRepeat = true,
        { setColor = { color = "red", value = 0 } },
        { setColor = { color = "yellow", value = 0 } },
        { setColor = { color = "green", value = 0 } },
        { fade = { color = "red", delay = 10, from = 0, to = 1020, step = 10 } },
        { fade = { color = "red", delay = 10, from = 1020, to = 0, step = -10 } },
        { fade = { color = "yellow", delay = 10, from = 0, to = 1020, step = 10 } },
        { fade = { color = "yellow", delay = 10, from = 1020, to = 0, step = -10 } },
        { fade = { color = "green", delay = 10, from = 0, to = 1020, step = 10 } },
        { fade = { color = "green", delay = 10, from = 1020, to = 0, step = -10 } },
    }
    setQueue(queue)
    processBlinkQueue()
    serveStatus(c)
end

function servePage (c, method, url)
    if method == "GET" and url then
        if url == "/" then
            serveIndex(c)
        elseif url == "/light/status" then
            serveStatus(c)
        elseif url:find('^/light/') or url:find('^/repeat/') then
            handleLight(c, url)
        elseif url == "/preset/buildFade" then
            handlePresetBuildFade(c)
        else
            serveNotFound(c)
        end
    else
        serveNotFound(c)
    end
end

if srv then
    srv:close()
end
srv = net.createServer(net.TCP, 60)
srv:listen(80, function(c)
    local firstLine = ""
    local lastFewBytes = ""
    local getFirstLine = true
    c:on("receive", function (c,pl)
        if getFirstLine then
            local _, posEnd = pl:find("\n")
            if posEnd then
                firstLine = firstLine .. pl:sub(1, posEnd)
                getFirstLine = false
            else
                firstLine = firstLine .. pl
            end
        end

        if not getFirstLine then
            lastFewBytes = lastFewBytes .. pl
            local _, headerEnd = lastFewBytes:find("\r\n\r\n")
            if headerEnd then
                local _, _, method, url = firstLine:find("^([A-Z]+) (.-) HTTP/[1-9]+.[0-9]+\r\n$")
                servePage(c, method, url)
            else
                lastFewBytes = lastFewBytes:sub(-3, -1)
            end
        end
    end)
end)
