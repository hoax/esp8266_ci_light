# esp8266_ci_light
simple 3-color light based on Espressif ESP8266 mcu to display the status of continuous integration systems like jenkins

It basicly provides an simple http interface to be used with curl/wget/... to toggle the the connected leds.

## Installation
These are the steps to use this software on an esp8266 module:

1. get nodemcu firmware (needed modules: node, gpio, net, wifi, pwm, enduser_setup)
1. flash nodemcu firmware on you esp8266 module
1. Compile *cilight.lua* to *cilight.lc*
1. Compile *setup.lua* to *setup.lc*
1. Upload *init.lua*, *setup.lc* and *cilight.lc* on your esp8266 module
1. reset your module (e.g. node.restart())

If you don't have a local lua installation you can simply upload cilight.lua and setup.lua and compile them on the module
itself by calling `node.compile(...)` for both files.
