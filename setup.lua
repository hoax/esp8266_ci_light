print("starting AP for setup")
print(wifi.sta.getconfig())
wifi.setmode(wifi.SOFTAP)
wifi.sta.config("", "")
enduser_setup.start()
