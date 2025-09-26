"""CPython-friendly BMP280 wrapper test (no hardware required).

Uses sensors.bmp280_wrapper which falls back to a simulator when drivers are
unavailable. This allows basic sanity checks on a desktop.
"""

from sensors.bmp280_wrapper import Bmp280Sensor


def is_num(x):
    return isinstance(x, (int, float))


def test_bmp280_wrapper_simulated_read():
    # Pass i2c=None to force wrapper to avoid driver path in CPython
    s = Bmp280Sensor(i2c=None)
    out = s.read()
    assert set(out.keys()) == {"temperature_c", "pressure_pa", "altitude_m"}
    assert is_num(out["temperature_c"]) and is_num(out["pressure_pa"]) and is_num(out["altitude_m"]) 