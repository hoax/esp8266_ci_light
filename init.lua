uart.setup(0, 115200, 8, 0, 1, 1)
gpio.mode(2, gpio.INT, gpio.PULLUP)

print()
print("esp8266 Continuous Integration Light")

LEDS = {}
LEDS.red = 7
LEDS.yellow = 6
LEDS.green = 5

BUTTONPIN = 3

for index,led in pairs(LEDS) do
    gpio.mode(led, gpio.OUTPUT)
    pwm.setup(led, 200, 0)
end

function leds (red, yellow, green)
    if red >= 0 then
        pwm.setduty(LEDS.red, red)
    end
    if yellow >= 0 then
        pwm.setduty(LEDS.yellow, yellow)
    end
    if green >= 0 then
        pwm.setduty(LEDS.green, green)
    end
end

function blinkYellow (redOn, yellowOn, greenOn, redOff, yellowOff, greenOff)
    local function blinkOn ()
        pwm.setduty(LEDS.red, redOn)
        pwm.setduty(LEDS.yellow, yellowOn)
        pwm.setduty(LEDS.green, greenOn)
        tmr.alarm(2, 500, tmr.ALARM_SINGLE, blinkOff)
    end
    local function blinkOff ()
        pwm.setduty(LEDS.red, redOff)
        pwm.setduty(LEDS.yellow, yellowOff)
        pwm.setduty(LEDS.green, greenOff)
        tmr.alarm(2, 500, tmr.ALARM_SINGLE, blinkOn)
    end
    yellowOn()
end

leds(128,128,128)
tmr.alarm(1, 3000, tmr.ALARM_SINGLE, function () 
    leds(0,0,0)
    local fileTable = file.list()
    if fileTable['cilight.lc'] then
        print("calling cilight.lc ...")
        pcall(dofile('cilight.lc'))
    else
        print("cilight.lc not found!")
    end
end)
print("press button to abort startup within the next 3 seconds ...")
gpio.mode(BUTTONPIN, gpio.INT, gpio.PULLUP)
gpio.trig(BUTTONPIN, "down", function () 
    tmr.stop(1)
    tmr.alarm(1, 3000, tmr.ALARM_SINGLE, function() 
        gpio.mode(BUTTONPIN, gpio.INPUT, gpio.FLOAT)
        leds(512,0,512)
        blink(0,1023,0,0,0,0)
        pcall(dofile('setup.lc'))
    end)
    gpio.trig(BUTTONPIN, "up", function () 
    if tmr.stop(1) then
        leds(0,0,0)
        blink(1023,0,0,0,0,0)
    end
    tmr.unregister(1)
    gpio.mode(BUTTONPIN, gpio.INPUT, gpio.PULLUP)
    end)
    print("startup aborted")
end)

