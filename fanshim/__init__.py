import RPi.GPIO as GPIO
import time
import apa102
import atexit
from threading import Thread

__version__ = '0.0.5'


class FanShim():
    def __init__(self, pin_fancontrol=18, pin_button=17, button_poll_delay=0.05, disable_button=False, disable_led=False):
        """FAN Shim.

        :param pin_fancontrol: BCM pin for fan on/off
        :param pin_button: BCM pin for button

        """
        self._pin_fancontrol = pin_fancontrol
        self._pin_button = pin_button
        self._poll_delay = button_poll_delay
        self._button_press_handler = None
        self._button_release_handler = None
        self._button_hold_handler = None
        self._button_hold_time = 2.0
        self._t_poll = None

        self._disable_button = disable_button
        self._disable_led = disable_led

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self._pin_fancontrol, GPIO.OUT)

        if not self._disable_button:
            GPIO.setup(self._pin_button, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        if not self._disable_led:
            self._led = apa102.APA102(1, 15, 14, None, brightness=0.05)

        atexit.register(self._cleanup)

    def start_polling(self):
        """Start button polling."""
        if self._disable_button:
            return

        if self._t_poll is None:
            self._t_poll = Thread(target=self._run)
            self._t_poll.daemon = True
            self._t_poll.start()

    def stop_polling(self):
        """Stop button polling."""
        if self._disable_button:
            return

        if self._t_poll is not None:
            self._running = False
            self._t_poll.join()

    def on_press(self, handler=None):
        """Attach function to button press event."""
        def attach_handler(handler):
            self._button_press_handler = handler
            self.start_polling()

        if handler is not None:
            attach_handler(handler)
        else:
            return attach_handler

    def on_release(self, handler=None):
        """Attach function to button release event."""
        def attach_handler(handler):
            self._button_release_handler = handler
            self.start_polling()

        if handler is not None:
            attach_handler(handler)
        else:
            return attach_handler

    def on_hold(self, handler=None):
        """Attach function to button hold event."""
        def attach_handler(handler):
            self._button_hold_handler = handler
            self.start_polling()

        if handler is not None:
            attach_handler(handler)
        else:
            return attach_handler

    def set_hold_time(self, hold_time):
        """Set the button hold time in seconds.

        :param hold_time: Amount of time button must be held to trigger on_hold (in seconds)

        """
        self._button_hold_time = hold_time

    def get_fan(self):
        """Get current fan state."""
        return GPIO.input(self._pin_fancontrol)

    def toggle_fan(self):
        """Toggle fan state."""
        return self.set_fan(False if self.get_fan() else True)

    def set_fan(self, fan_state):
        """Set the fan on/off.

        :param fan_state: True/False for on/off

        """
        GPIO.output(self._pin_fancontrol, True if fan_state else False)
        return True if fan_state else False

    def set_light(self, r, g, b, brightness=None):
        """Set LED.

        :param r: Red (0-255)
        :param g: Green (0-255)
        :param b: Blue (0-255)

        """
        if self._disable_led:
            return

        self._led.set_pixel(0, r, g, b)
        if brightness is not None:
            self._led.set_brightness(0, brightness)
        self._led.show()

    def _cleanup(self):
        self.stop_polling()

        self.set_light(0, 0, 0)

    def _run(self):
        self._running = True
        last = 1

        while self._running:
            current = GPIO.input(self._pin_button)
            # Transition from 1 to 0
            if last > current:
                self._t_pressed = time.time()
                self._hold_fired = False

                if callable(self._button_press_handler):
                    self._t_repeat = time.time()
                    Thread(target=self._button_press_handler).start()

            if last < current:
                if callable(self._button_release_handler):
                    Thread(target=self._button_release_handler, args=(self._hold_fired,)).start()

            if current == 0:
                if not self._hold_fired and (time.time() - self._t_pressed) > self._button_hold_time:
                    if callable(self._button_hold_handler):
                        Thread(target=self._button_hold_handler).start()
                    self._hold_fired = True

            last = current

            time.sleep(self._poll_delay)
