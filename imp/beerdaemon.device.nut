// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT
class NeoPixels {
	// This class uses SPI to emulate the newpixels' one-wire protocol.
	// This requires one byte per bit to send data at 7.5 MHz via SPI.
	// These consts define the "waveform" to represent a zero or one

	static ZERO            = 0xC0;
	static ONE             = 0xF8;
	static BYTESPERPIXEL   = 24;

	// when instantiated, the neopixel class will fill this array with blobs to
	// represent the waveforms to send the numbers 0 to 255. This allows the blobs to be
	// copied in directly, instead of being built for each pixel - which makes the class faster.

	bits            = null;

	// Like bits, this blob holds the waveform to send the color [0,0,0], to clear pixels faster

	clearblob       = blob(12);

	// private variables passed into the constructor

	spi             = null; // imp SPI interface (pre-configured)
	frameSize       = null; // number of pixels per frame
	frame           = null; // a blob to hold the current frame

	// _spi - A configured spi (MSB_FIRST, 7.5MHz)
	// _frameSize - Number of Pixels per frame

	constructor(_spi, _frameSize) {
		this.spi = _spi;
		this.frameSize = _frameSize;
		this.frame = blob(frameSize*BYTESPERPIXEL + 1);
		this.frame[frameSize*BYTESPERPIXEL] = 0;

		// prepare the bits array and the clearblob blob

		initialize();

		clearFrame();
		writeFrame();
	}

	// fill the array of representative 1-wire waveforms.
	// done by the constructor at instantiation.

	function initialize() {
		// fill the bits array first

		bits = array(256);
		for (local i = 0; i < 256; i++) {
			local valblob = blob(BYTESPERPIXEL / 3);
			valblob.writen((i & 0x80) ? ONE:ZERO,'b');
			valblob.writen((i & 0x40) ? ONE:ZERO,'b');
			valblob.writen((i & 0x20) ? ONE:ZERO,'b');
			valblob.writen((i & 0x10) ? ONE:ZERO,'b');
			valblob.writen((i & 0x08) ? ONE:ZERO,'b');
			valblob.writen((i & 0x04) ? ONE:ZERO,'b');
			valblob.writen((i & 0x02) ? ONE:ZERO,'b');
			valblob.writen((i & 0x01) ? ONE:ZERO,'b');
			bits[i] = valblob;
		}

		// now fill the clearblob
		for(local j = 0; j < BYTESPERPIXEL; j++) {
			clearblob.writen(ZERO, 'b');
		}
	}

	// sets a pixel in the frame buffer
	// but does not write it to the pixel strip
	// color is an array of the form [r, g, b]

	function writePixel(p, color) {
		frame.seek(p*BYTESPERPIXEL);

		// red and green are swapped for some reason, so swizzle them back

		frame.writeblob(bits[color[1]]);
		frame.writeblob(bits[color[0]]);
		frame.writeblob(bits[color[2]]);
	}

	// Clears the frame buffer
	// but does not write it to the pixel strip

	function clearFrame() {
		frame.seek(0);
		for (local p = 0; p < frameSize; p++) frame.writeblob(clearblob);
	}

	// writes the frame buffer to the pixel strip
	// ie - this function changes the pixel strip

	function writeFrame() {
		spi.write(frame);
	}
}





// Ultrasonic Range Sensor HC-SR04
// https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE/edit
// Ultrasonic Range Sensor HC-SR04
// https://docs.google.com/document/d/1Y-yZnNhMYy7rwhAgyL_pfa39RsB-x2qR4vP8saG73rE/edit
class HCSR04 {
    // consts
    static TO = 500; // timeout in ms
    
    // pins
    _trig   = null;
    _echo   = null;

    // aliased methods
    _tw     = null;
    _er     = null;
    _hu     = null;
    _hm     = null;

    // vars
    _es     = null; // echo start time
    _ee     = null; // echo end time

    constructor(trig, echo) {
        _trig = trig;
        _echo = echo;

        _hu   = hardware.micros.bindenv(hardware);
        _hm   = hardware.millis.bindenv(hardware);
        _tw   = _trig.write.bindenv(_trig);
        _er   = _trig.read.bindenv(_echo);
    }

    function read_cm() {
        local st = _hm(); // start time for timeout
        // Quickly pulse the trig pin
        _tw(0); _tw(1); _tw(0);

        // Wait for the rising edge on echo
        while (_er() == 0 && (_hm() - st) < TO);
        _es = _hu();

        // Time to the falling edge on echo
        while (_er() == 1 && (_hm() - st) < TO);
        _ee = _hu();

        //if ((_hm() - st) >= TO) return -1;
        return (_ee - _es)/58.0;
    }
}












/*
Beer Daemon Device
John Reimers 2015
http://ohm.ninja
*/



wakeUpPin <- hardware.pin1
echoPin <- hardware.pin2
trigPin <- hardware.pin5
tempPin <- hardware.pin8
ledDataPin <- hardware.spi257

local statusLed
local pinger
local doorOpen = false;

function initializeHardware() {
    ledDataPin.configure(MSB_FIRST, 7500)
    wakeUpPin.configure(DIGITAL_IN_WAKEUP, wakeUpChange)
    tempPin.configure(ANALOG_IN)
    trigPin.configure(DIGITAL_OUT,0)
    echoPin.configure(DIGITAL_IN)
    
    statusLed = NeoPixels(ledDataPin, 1)
    pinger = HCSR04(trigPin, echoPin)
}

function wakeUpChange() {
    if(wakeUpPin.read()) {
        statusLed.writePixel(0, [0, 10, 0])
        statusLed.writeFrame()
        doorOpen = true;
        reportDist();
    } else {
        doorOpen = false;
    }
}

function reportTemp() {
    local tempVoltage = tempPin.read() * 3300 / 65535
    local temp = (tempVoltage - 500) / 10.0
    agent.send("update_temp", temp)
    
    imp.wakeup(1, reportTemp);
}

function reportDist() {
    if(doorOpen) {
        local dist = pinger.read_cm();
        agent.send("update_dist", dist)
        imp.wakeup(1, reportDist);
    }
}

initializeHardware()


server.log("Woke Up")
wakeUpChange()
 
reportTemp();


