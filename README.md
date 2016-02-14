# esp8266_ci_light
simple 3-color light based on Espressif ESP8266 mcu to display the status of continuous integration systems like jenkins

It provides a simple http interface to be used with curl/wget/... to toggle the the connected leds.

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

## Configuration

To configure the pins used to toogle the leds have a look at the LEDS-table at the beginning of *init.lua*.
By default pins 7, 6 and 5 are used for red, yellow and green light.

There is also a BUTTONPIN variable (default is 3) defining a pin which is connect to GND via a push button (internal pullup is used).

## Usage

### Setup wifi
To configure the wifi connection press the button (on pin 3) within the first 3 seconds after plugin in the power (or pressing reset) while all the colors are on at about 12%. This runs `setup.lc` where the enduser_setup module is used to create an access point. Join this AP and open 192.168.4.1 in your browser to provide SSID and password of the wifi network to use.
After that use the serial console to find out the IP of the esp8266 or ask your wifi router. (The esp8266 uses DHCP to obtain an IP address.)

(If you keep the button pressed for more than 3 seconds while the all the colors glow dimly the boot process is aborted so you can use a serial connection for debugging/testing/...)

### Spot on!
Now you can talk to the esp8266 using simple HTTP request to port 80.

A simple info page can be retrieved by opening path **/** (http://ipOfYourEsp/).

A JSON-document providing information about the status of the three colors is available on path **/light/status** (http://ipOfYourEsp/light/status). The retured document looks like `{ "red":0, "yellow":0, "green":0}`

A built in animation fading on and off red, yellow and green on after another is available through requesting path **/preset/buildFade**.

For custom animations or static lighting open path **/light** + what you want it to display. The subsequent path elements are parsed and put into a queue. Then the command from the queue are executed. The following path elements are available:

  * **/$color/$value** sets the value of the specified color. $color has to be **red**, **yellow** or **green**. $value is any integer value from 0 to 1023 where 0 is off and 1023 is completely on.
  * **/fade/$color/$delay/$from/$to/$step** starts to fade the $color by starting with value $from and then increasing the value by $step every $delay milliseconds until $to is reached (or exceeded). $step has to be a positive number even if $from > $to! Fade works asynchronous, that means that it runs independendly from the queue so multiple fade animantions (one for every color) can be run simultaneously and the delay command has no effect on fade.
  * **/delay/$duration** waits $duration milliseconds before executing the next element from the queue.
  * **/repeat** runs the queue in a loop, otherwise the queue will be run only once.

#### Example URLs

Lets assume that you request these URLs one after another:

  * **http://ipOfYourEsp/light/red/0/yellow/0/green/0** turns the light on.
  * **http://ipOfYourEsp/light/red/512** turns on red with 50% brightness (half of 1024)
  * **http://ipOfYourEsp/light/green/1023** also turns on green with 100% brightness. (Red is still on at 50%!)
  * **http://ipOfYourEsp/light/repeat/green/0/delay/500/green/1023/delay/500** lets blink green with 1 Hz. (turn off, wait 500ms, turn 100% on, wait 500ms, repeat)
  * **http://ipOfYourEsp/light/green/0** stops the fade and turns green off. (And red is still on at 50%)
  * **http://ipOfYourEsp/light/fade/red/10/0/1023/10** fades red from completely off to completely on within about 1s
  * **http://ipOfYourEsp/light/fade/red/10/0/1023/10/delay/1000/fade/red/10/1023/0/10** fade red from off to on for one second, then fade back to off
  
Too long URLs sometimes lead to a crash because there is no memory left!
