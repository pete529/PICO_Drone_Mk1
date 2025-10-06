"""
DRV8833 test mixer stub for Pico W.

Provides a minimal interface to apply four motor outputs (0..1) to either:
- Test PWM pins (if configured), or
- Print/log the values for bring-up.

Use configure_test_pins() to map four PWM pins for motors M1..M4.
"""

try:
    from machine import Pin, PWM  # type: ignore
except Exception:
    Pin = None  # type: ignore
    PWM = None  # type: ignore


class DRV8833Mixer:
    def __init__(self):
        self._pwms = None  # type: ignore

    def configure_test_pins(self, pins):
        """Configure four PWM pins for test output.
        pins: iterable of 4 GPIO numbers (ints)
        """
        if PWM is None or Pin is None:
            raise RuntimeError("PWM not available on this platform")
        self._pwms = []
        for gpio in pins:
            p = PWM(Pin(gpio))
            p.freq(2000)
            self._pwms.append(p)

    def apply_motors(self, m1: float, m2: float, m3: float, m4: float):
        """Apply normalized motor values 0..1 to four outputs.
        For test pins, sets PWM duty; else prints condensed line.
        """
        m = [max(0.0, min(1.0, v)) for v in (m1, m2, m3, m4)]
        if self._pwms:
            # 16-bit duty on MicroPython PWM
            for pwm, v in zip(self._pwms, m):
                pwm.duty_u16(int(v * 65535))
        else:
            # Fallback print (throttled by caller)
            print("M:", *(round(v, 2) for v in m))


def quad_x_mixer(throttle: float, roll: float, pitch: float, yaw: float):
    """Simple quad-X mix producing four motor commands before limits.
    Returns tuple (m1, m2, m3, m4) in 0..1 after clamping.
    """
    t = max(0.0, min(1.0, throttle))
    r = roll
    p = pitch
    y = yaw
    m1 = t + p + r + y   # front-right
    m2 = t + p - r - y   # front-left
    m3 = t - p + r - y   # rear-right
    m4 = t - p - r + y   # rear-left
    # Clamp to signed range for directional control
    motors = [max(-1.0, min(1.0, v)) for v in (m1, m2, m3, m4)]
    return tuple(motors)
