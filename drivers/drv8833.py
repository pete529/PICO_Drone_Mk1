try:
    from machine import Pin, PWM
except ImportError:
    Pin = None
    PWM = None

try:
    from config import pins as PINS
except ImportError:
    class _Pins:
        DRV_LEFT_AIN1 = 0
        DRV_LEFT_AIN2 = 1
        DRV_LEFT_BIN1 = 2
        DRV_LEFT_BIN2 = 3
        DRV_LEFT_SLEEP = 8
        DRV_RIGHT_AIN1 = 4
        DRV_RIGHT_AIN2 = 5
        DRV_RIGHT_BIN1 = 6
        DRV_RIGHT_BIN2 = 7
        DRV_RIGHT_SLEEP = 9
        MOTOR_PWM_FREQ_HZ = 20000
    PINS = _Pins()

_DUTY_MAX = 65535

class HBridge:
    def __init__(self, ain1_pin, ain2_pin, pwm_freq_hz):
        if Pin is None or PWM is None:
            raise RuntimeError('machine.PWM not available (not MicroPython)')
        self._ain1 = PWM(Pin(ain1_pin))
        self._ain2 = PWM(Pin(ain2_pin))
        self._ain1.freq(pwm_freq_hz)
        self._ain2.freq(pwm_freq_hz)
        self.stop()

    def set(self, value):
        # value in [-1.0, 1.0]
        if value is None:
            value = 0.0
        v = max(-1.0, min(1.0, float(value)))
        if v > 0:
            d = int(v * _DUTY_MAX)
            self._ain1.duty_u16(d)
            self._ain2.duty_u16(0)
        elif v < 0:
            d = int((-v) * _DUTY_MAX)
            self._ain1.duty_u16(0)
            self._ain2.duty_u16(d)
        else:
            self.stop()

    def stop(self):
        self._ain1.duty_u16(0)
        self._ain2.duty_u16(0)

class Drv8833Dual:
    def __init__(self, ain1, ain2, bin1, bin2, sleep_pin, pwm_freq_hz):
        if Pin is None or PWM is None:
            raise RuntimeError('machine.PWM not available (not MicroPython)')
        self._sleep = Pin(sleep_pin, Pin.OUT)
        self._a = HBridge(ain1, ain2, pwm_freq_hz)
        self._b = HBridge(bin1, bin2, pwm_freq_hz)
        self.disable()

    def enable(self):
        self._sleep.value(1)

    def disable(self):
        self._sleep.value(0)
        self._a.stop()
        self._b.stop()

    def set_a(self, value):
        self._a.set(value)

    def set_b(self, value):
        self._b.set(value)

class MotorQuad:
    """Four-motor controller using two DRV8833 chips.

    Motors are mapped as:
      - left A channel -> motor L1
      - left B channel -> motor L2
      - right A channel -> motor R1
      - right B channel -> motor R2
    """
    def __init__(self, pwm_freq_hz=None):
        if pwm_freq_hz is None:
            pwm_freq_hz = getattr(PINS, 'MOTOR_PWM_FREQ_HZ', 20000)
        self.left = Drv8833Dual(
            PINS.DRV_LEFT_AIN1, PINS.DRV_LEFT_AIN2,
            PINS.DRV_LEFT_BIN1, PINS.DRV_LEFT_BIN2,
            PINS.DRV_LEFT_SLEEP, pwm_freq_hz,
        )
        self.right = Drv8833Dual(
            PINS.DRV_RIGHT_AIN1, PINS.DRV_RIGHT_AIN2,
            PINS.DRV_RIGHT_BIN1, PINS.DRV_RIGHT_BIN2,
            PINS.DRV_RIGHT_SLEEP, pwm_freq_hz,
        )
        self.disarmed = True

    def arm(self):
        self.left.enable()
        self.right.enable()
        self.disarmed = False

    def disarm(self):
        self.left.disable()
        self.right.disable()
        self.disarmed = True

    def stop_all(self):
        self.left._a.stop(); self.left._b.stop()
        self.right._a.stop(); self.right._b.stop()

    def set_quadsigned(self, l1, l2, r1, r2):
        if self.disarmed:
            self.stop_all()
            return
        self.left.set_a(l1)
        self.left.set_b(l2)
        self.right.set_a(r1)
        self.right.set_b(r2)

    def set_all(self, value):
        self.set_quadsigned(value, value, value, value)
