"""SensorHub smoke test (simulation path, no hardware required)."""

from sensors.sensor_hub import SensorHub


def is_tuple3(x):
    return isinstance(x, (list, tuple)) and len(x) == 3


def is_num(x):
    return isinstance(x, (int, float))


def test_sensor_hub_simulated():
    hub = SensorHub(i2c=None)
    out = hub.read()
    assert "accel_g" in out and is_tuple3(out["accel_g"]) and all(is_num(v) for v in out["accel_g"]) 
    assert "gyro_dps" in out and is_tuple3(out["gyro_dps"]) and all(is_num(v) for v in out["gyro_dps"]) 
    assert "mag_uT" in out and is_tuple3(out["mag_uT"]) and all(is_num(v) for v in out["mag_uT"]) 
    assert "temperature_c" in out and is_num(out["temperature_c"]) 
    assert "altitude_m" in out and is_num(out["altitude_m"]) 
