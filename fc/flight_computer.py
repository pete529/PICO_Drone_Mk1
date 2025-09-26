try:
    import utime as time
except ImportError:
    import time

try:
    from machine import Pin
except ImportError:
    Pin = None

from drivers.i2c_bus import get_i2c
from sensors.sensor_hub import SensorHub
from control.pid import PID
from config import pins as PINS
from drivers.drv8833 import MotorQuad
from control.attitude import ComplementaryAHRS


class FlightComputer:
    def __init__(self, loop_hz=100):
        self.loop_hz = loop_hz
        self.dt = 1.0 / float(loop_hz)
        self.i2c = get_i2c()
        self.sensors = SensorHub(self.i2c)
        self.led = Pin(PINS.LED_RED_PIN, Pin.OUT) if Pin else None
        self.btn = Pin(PINS.BUTTON_ARM_PIN, Pin.IN, Pin.PULL_UP) if Pin else None
        self._btn_last = 1
        self._btn_last_change = 0
        self._btn_debounce_ms = 80
        self.motors = MotorQuad()
        self.motors.disarm()  # start safe
        self._throttle = 0.0  # keep at 0 until explicitly set and armed

        # Controllers
        self.pid_roll = PID(kp=0.8, ki=0.0, kd=0.02, out_limit=1.0)
        self.pid_pitch = PID(kp=0.8, ki=0.0, kd=0.02, out_limit=1.0)
        self.pid_yaw = PID(kp=0.4, ki=0.0, kd=0.01, out_limit=1.0)
        self._last_tick = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)

        # Attitude filter
        self.ahrs = ComplementaryAHRS(alpha=0.98)
        self.att_roll = 0.0
        self.att_pitch = 0.0
        self.att_yaw = 0.0
        self.att_yaw_rate = 0.0

    def step(self):
        # Timing
        now = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
        dt_ms = now - self._last_tick if not hasattr(time, 'ticks_diff') else time.ticks_diff(now, self._last_tick)
        self._last_tick = now
        dt = max(self.dt, dt_ms / 1000.0)

        # Read sensors
        s = self.sensors.read()
        ax, ay, az = s.get('accel_g') or (0.0, 0.0, 1.0)
        gx, gy, gz = s.get('gyro_dps') or (0.0, 0.0, 0.0)

        # Update arm button state (debounced)
        self._update_arm_button(now)

        # Attitude estimate: complementary filter
        self.att_roll, self.att_pitch, self.att_yaw = self.ahrs.update((ax, ay, az), (gx, gy, gz), dt)
        self.att_yaw_rate = gz

        # Target setpoints (hover placeholder)
        roll_sp = 0.0
        pitch_sp = 0.0
        yaw_rate_sp = 0.0

        # Errors
        err_roll = roll_sp - self.att_roll
        err_pitch = pitch_sp - self.att_pitch
        err_yaw = yaw_rate_sp - self.att_yaw_rate

        # Controllers -> normalized demands in [-1,1]
        u_roll = self.pid_roll.update(err_roll, dt)
        u_pitch = self.pid_pitch.update(err_pitch, dt)
        u_yaw = self.pid_yaw.update(err_yaw, dt)

        # Throttle (0..1). Default 0.0 unless set and armed.
        throttle = 0.0 if self.motors.disarmed else max(0.0, min(1.0, self._throttle))

        # Simple quad X mixer (brushed)
        l1 = throttle + (+u_roll) + (+u_pitch) + (-u_yaw)
        l2 = throttle + (+u_roll) + (-u_pitch) + (+u_yaw)
        r1 = throttle + (-u_roll) + (+u_pitch) + (+u_yaw)
        r2 = throttle + (-u_roll) + (-u_pitch) + (-u_yaw)

        # Normalize to [-1, 1]
        def clamp(x):
            if x is None:
                return 0.0
            if x > 1.0:
                return 1.0
            if x < -1.0:
                return -1.0
            return x

        l1 = clamp(l1); l2 = clamp(l2); r1 = clamp(r1); r2 = clamp(r2)

        # Apply to motors (will noop if disarmed)
        self.motors.set_quadsigned(l1, l2, r1, r2)

        # LED heartbeat
        if self.led:
            try:
                if hasattr(self.led, 'toggle'):
                    self.led.toggle()
                else:
                    self.led.value(0 if self.led.value() else 1)
            except Exception:
                pass

        return {
            'dt': dt,
            'roll_deg': self.att_roll,
            'pitch_deg': self.att_pitch,
            'yaw_deg': self.att_yaw,
            'yaw_rate_dps': self.att_yaw_rate,
            'u_roll': u_roll,
            'u_pitch': u_pitch,
            'u_yaw': u_yaw,
            'throttle': throttle,
            'mix': (l1, l2, r1, r2),
            'alt_m': s.get('altitude_m'),
            'temp_c': s.get('temperature_c') or s.get('imu_temp_c'),
        }

    # Basic API
    def arm(self):
        self.motors.arm()

    def disarm(self):
        self.motors.disarm()

    def set_throttle(self, t):
        try:
            self._throttle = float(t)
        except Exception:
            self._throttle = 0.0

    def _update_arm_button(self, now_ms):
        if not self.btn:
            return
        cur = self.btn.value()
        if cur != self._btn_last:
            self._btn_last_change = now_ms
            self._btn_last = cur
        # Debounce and act on falling edge (button press when pull-up)
        if cur == 0 and (now_ms - self._btn_last_change) >= self._btn_debounce_ms:
            if self.motors.disarmed:
                self.arm()
            else:
                self.disarm()
            # Prevent rapid toggles until release
            self._btn_last_change = now_ms + 500

    def run(self, seconds=None):
        next_ts = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
        period_ms = int(1000 / self.loop_hz)
        end_time = None
        if seconds is not None:
            now = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
            end_time = now + int(seconds * 1000)

        while True:
            out = self.step()
            try:
                print(out)
            except Exception:
                pass

            if seconds is not None:
                cur = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
                if end_time is not None and cur >= end_time:
                    break

            next_ts += period_ms
            cur = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
            delay = next_ts - cur
            if delay > 0:
                if hasattr(time, 'sleep_ms'):
                    time.sleep_ms(delay)
                else:
                    time.sleep(delay / 1000.0)
            else:
                # Overrun: skip sleep to catch up
                pass
