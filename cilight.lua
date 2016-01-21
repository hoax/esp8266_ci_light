function string.startsWith(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function sendParts (c, parts)
    local function sender (sck)
        if #parts>0 then 
            table.remove(parts,1)(sck)
        else 
            sck:close()
        end
    end
    sender(c)
end

function sendHeaders (c)
    c:send("HTTP/1.0 200 OK\r\n"
        .. "Server: nodemcu-httpserver\r\n"
        .. "Content-Type: text/html\r\n" 
        .. "Connection: close\r\n\r\n")
end

function sendRedirect (c) 
    c:send("HTTP/1.0 302 Found\r\n"
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
    c:send("Verwenden Sie die URL <em>/light/$color/$brightness</em> um die einzelnen Lampen zu steuern.<br>"
        .. "$color steht hierbei für <em>red</emd>,<em>yellow</em> oder <em>green</em> und $brightness ist eine "
        .. "Ganzzahl von 0 (= aus) bis 1023 (= 100% an).<br>"
        .. "Aktueller Zustand: <ul>"
        .. "<li>Rot: " .. pwm.getduty(LEDS.red)
        .. "<li>Gelb: " .. pwm.getduty(LEDS.yellow)
        .. "<li>Grün: " .. pwm.getduty(LEDS.green)
        .. "</ul>")
end

function serveIndex (c)
    local parts = { sendHeaders, sendHead, sendIndexBody, sendFooter } 
    sendParts(c, parts)
end

function handleLight (c, method)
    local _, _, color, value = method:find(".*/(.-)/(.-)$")
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
    
    sendRedirect(c, "/")
end

function servePage (c, method, url)
    if method == "GET" then
        if url == "/" then
            serveIndex(c)
        elseif url:startsWith('/light/') then
            handleLight(c, method)
        end
    end
end

srv = net.createServer(net.TCP, 30)
srv:listen(80, function(c)
    local data = ""
    c:on("receive", function (c,pl)
        if #data + #pl > 60 then
            c:close()
            return
        end

        data = data + pl
        if data:find("\n") then
            local _, _, method, url = data:find("^([A-Z]+) (.-) HTTP/[1-9]+.[0-9]+\r\n$")
            servePage(c, method, url)
        end
    end)
end)
