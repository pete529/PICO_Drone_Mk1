try:
    import utime as time
except ImportError:
    import time

import math

# Try ICM-20948 first (prefer local drivers.icm20948)
try:
    from drivers import icm20948 as icm20948_mod
except Exception:
    try:
        icm20948_mod = __import__('icm20948')
    except Exception:
        icm20948_mod = None

# Then fall back to MPU9250 (prefer drivers package, then plain module)
try:
    from drivers import mpu9250 as mpu9250_mod
except Exception:
    try:
        mpu9250_mod = __import__('mpu9250')
    except Exception:
        mpu9250_mod = None

class ImuSensor:
    def __init__(self, i2c):
        self._i2c = i2c
        self._drv = None
        self._lib = None
        # Try ICM-20948 drivers with common signatures
        if icm20948_mod is not None:
            for ctor_name in ('ICM20948', 'ICM20948_I2C', 'ICM20948i2c'):
                try:
                    ctor = getattr(icm20948_mod, ctor_name)
                except Exception:
                    ctor = None
                if ctor:
                    try:
                        self._drv = ctor(i2c)
                        self._lib = 'icm20948'
                        break
                    except Exception:
                        pass
        # Try MPU9250
        if self._drv is None and mpu9250_mod is not None:
            for ctor_name in ('MPU9250', 'Mpu9250'):
                try:
                    ctor = getattr(mpu9250_mod, ctor_name)
                except Exception:
                    ctor = None
                if ctor:
                    try:
                        self._drv = ctor(i2c)
                        self._lib = 'mpu9250'
                        break
                    except Exception:
                        pass

    def read(self):
        # Returns dict: accel_g(x,y,z), gyro_dps(x,y,z), mag_uT(x,y,z), temp_c
        if self._drv is not None:
            try:
                if self._lib == 'icm20948':
                    # Try common attribute names
                    ax, ay, az = self._get_tuple(self._drv, ['accel', 'acceleration'])
                    gx, gy, gz = self._get_tuple(self._drv, ['gyro', 'gyroscope'])
                    mx, my, mz = self._get_tuple(self._drv, ['mag', 'magnetic'])
                    temp = self._get_scalar(self._drv, ['temperature', 'temp'])
                elif self._lib == 'mpu9250':
                    ax, ay, az = getattr(self._drv, 'acceleration', (None, None, None))
                    gx, gy, gz = getattr(self._drv, 'gyro', (None, None, None))
                    mx, my, mz = getattr(self._drv, 'mag', (None, None, None))
                    temp = getattr(self._drv, 'temperature', None)
                else:
                    ax=ay=az=gx=gy=gz=mx=my=mz=temp=None
                return {
                    'accel_g': (ax, ay, az),
                    'gyro_dps': (gx, gy, gz),
                    'mag_uT': (mx, my, mz),
                    'temp_c': temp,
                }
            except Exception:
                pass
        # Simulated fallback
        ms = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
        phase = (ms % 2000) / 2000.0
        ax = 0.0 + 0.02 * math.sin(2 * math.pi * phase)
        ay = 0.0 + 0.02 * math.cos(2 * math.pi * phase)
        az = 1.0  # ~1g
        gx = 0.5 * math.sin(2 * math.pi * phase)
        gy = 0.5 * math.cos(2 * math.pi * phase)
        gz = 0.0
        mx = 30.0 * math.sin(2 * math.pi * phase)
        my = 0.0
        mz = 15.0 * math.cos(2 * math.pi * phase)
        temp = 30.0
        return {
            'accel_g': (ax, ay, az),
            'gyro_dps': (gx, gy, gz),
            'mag_uT': (mx, my, mz),
            'temp_c': temp,
        }

    def _get_tuple(self, drv, names):
        for n in names:
            v = getattr(drv, n, None)
            if v is None:
                continue
            if callable(v):
                try:
                    v = v()
                except Exception:
                    continue
            if isinstance(v, (list, tuple)) and len(v) >= 3:
                return v[0], v[1], v[2]
        return (None, None, None)

    def _get_scalar(self, drv, names):
        for n in names:
            v = getattr(drv, n, None)
            if v is None:
                continue
            if callable(v):
                try:
                    v = v()
                except Exception:
                    continue
            return v
        return None
