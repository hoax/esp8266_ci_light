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

function handleLight (c, url)
    local _, _, color, value = url:find(".*/(.-)/(.-)$")
    if color and value then
        value = tonumber(value)
        if not value or value < 0 then
            value = 0
        elseif value > 1023 then
            value = 1023
        end
        local led = LEDS[color]
        if led then
            pwm.setduty(led, value)
        end
    end
    serveStatus(c)
end

function servePage (c, method, url)
    if method == "GET" and url then
        if url == "/" then
            serveIndex(c)
        elseif url == "/light/status" then
            serveStatus(c)
        elseif url:find('^/light/') then
            handleLight(c, url)
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

            --[[
            --]]
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
