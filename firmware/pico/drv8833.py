"""
DRV8833 motor driver control for Pico W (MicroPython).

Controls up to 4 motors using two DRV8833 chips (each has 2 H-bridges).
Inputs per motor: IN1, IN2. Direction via which pin is PWM'd; the other held low.

Usage:
  drv = DRV8833Driver({
      1: (16, 17),  # M1 IN1, IN2
      2: (18, 19),  # M2 IN1, IN2
      3: (20, 21),  # M3 IN1, IN2
      4: (22, 26),  # M4 IN1, IN2
  })
  drv.apply_motors(-0.2, 0.5, 0.0, 1.0)
"""

try:
    from machine import Pin, PWM  # type: ignore
except Exception:
    Pin = None  # type: ignore
    PWM = None  # type: ignore


class DRV8833Motor:
    def __init__(self, in1_gpio: int, in2_gpio: int, freq_hz: int = 2000):
        if PWM is None or Pin is None:
            raise RuntimeError("PWM/Pin not available on this platform")
        self.in1 = PWM(Pin(in1_gpio, Pin.OUT))
        self.in2 = PWM(Pin(in2_gpio, Pin.OUT))
        self.in1.freq(freq_hz)
        self.in2.freq(freq_hz)
        self.brake()

    def brake(self):
        # Fast decay: both low
        self.in1.duty_u16(0)
        self.in2.duty_u16(0)

    def set(self, v: float):
        # v in [-1..1]
        v = max(-1.0, min(1.0, v))
        duty = int(abs(v) * 65535)
        if v >= 0:
            self.in1.duty_u16(duty)
            self.in2.duty_u16(0)
        else:
            self.in1.duty_u16(0)
            self.in2.duty_u16(duty)


class DRV8833Driver:
    def __init__(self, mapping: dict[int, tuple[int, int]]):
        """mapping: { motor_index(1..4): (IN1_gpio, IN2_gpio) }"""
        self.motors = {}
        for idx, (g1, g2) in mapping.items():
            self.motors[idx] = DRV8833Motor(g1, g2)

    def apply_motors(self, m1: float, m2: float, m3: float, m4: float):
        vals = {1: m1, 2: m2, 3: m3, 4: m4}
        for i, v in vals.items():
            if i in self.motors:
                self.motors[i].set(v)
