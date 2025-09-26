try:
    import utime as time
except ImportError:
    import time

import math

try:
    from bmp280 import BMP280 as BMP280Driver
except ImportError:
    BMP280Driver = None

DEFAULT_ADDRS = (0x76, 0x77)

class Bmp280Sensor:
    def __init__(self, i2c, addr=None):
        self._i2c = i2c
        self._driver = None
        self._addr = addr
        if BMP280Driver is not None:
            # Pick address if not specified
            if self._addr is None:
                found = set(i2c.scan())
                pick = next((a for a in DEFAULT_ADDRS if a in found), None)
                self._addr = pick if pick is not None else DEFAULT_ADDRS[0]
            # Try common constructor signatures
            try:
                self._driver = BMP280Driver(i2c, addr=self._addr)
            except TypeError:
                try:
                    self._driver = BMP280Driver(i2c)
                except Exception:
                    self._driver = None

    def read(self):
        # Returns dict: temperature_c, pressure_pa, altitude_m
        if self._driver:
            t = None
            p = None
            try:
                t = getattr(self._driver, 'temperature', None)
                p = getattr(self._driver, 'pressure', None)
                if callable(t):
                    t = t()
                if callable(p):
                    p = p()
            except Exception:
                t = None
                p = None
            # Normalize units
            # Normalize type if it's a number
            if isinstance(p, (int, float)):
                p = float(p)
            else:
                p = None
            if p is not None:
                # If hPa, convert to Pa
                try:
                    if p < 2000.0:
                        p = p * 100.0
                except Exception:
                    pass
            alt = None
            if p is not None:
                # Barometric formula (ISA)
                try:
                    alt = 44330.0 * (1.0 - (p / 101325.0) ** 0.1903)
                except Exception:
                    alt = None
            return {
                'temperature_c': t,
                'pressure_pa': p,
                'altitude_m': alt,
            }
        # Simulated fallback
        ms = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
        phase = (ms % 10000) / 10000.0
        t = 25.0 + 2.0 * math.sin(2 * math.pi * phase)
        p = 101325.0 + 200.0 * math.sin(2 * math.pi * phase)
        alt = 44330.0 * (1.0 - (p / 101325.0) ** 0.1903)
        return {
            'temperature_c': t,
            'pressure_pa': p,
            'altitude_m': alt,
        }
