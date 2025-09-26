try:
    import utime as time
except ImportError:
    import time

import math

class ComplementaryAHRS:
    """Simple complementary filter for roll/pitch using accel + gyro.
    yaw uses integrated gyro (no mag fusion here).
    """
    def __init__(self, alpha=0.98):
        self.alpha = alpha
        self.roll = 0.0
        self.pitch = 0.0
        self.yaw = 0.0

    def update(self, accel_g, gyro_dps, dt):
        ax, ay, az = accel_g or (0.0, 0.0, 1.0)
        gx, gy, gz = gyro_dps or (0.0, 0.0, 0.0)
        # Integrate gyro
        roll_g = self.roll + gx * dt
        pitch_g = self.pitch + gy * dt
        yaw_g = self.yaw + gz * dt
        # Compute accel angles (guard atan2 domain)
        try:
            roll_a = math.degrees(math.atan2(ay, az))
            pitch_a = math.degrees(math.atan2(-ax, math.sqrt(ay*ay + az*az)))
        except Exception:
            roll_a = self.roll
            pitch_a = self.pitch
        a = self.alpha
        self.roll = a * roll_g + (1 - a) * roll_a
        self.pitch = a * pitch_g + (1 - a) * pitch_a
        self.yaw = yaw_g
        return self.roll, self.pitch, self.yaw
