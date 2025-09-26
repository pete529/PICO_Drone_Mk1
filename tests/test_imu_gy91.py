"""CPython-friendly IMU wrapper test using simulated path.

Exercises sensors.imu_wrapper.ImuSensor which falls back to a simulator in the
absence of hardware/driver modules.
"""

from sensors.imu_wrapper import ImuSensor


def is_tuple3(x):
	return isinstance(x, (list, tuple)) and len(x) == 3


def is_num(x):
	return isinstance(x, (int, float))


def test_imu_wrapper_simulated_read():
	imu = ImuSensor(i2c=None)
	out = imu.read()
	assert set(out.keys()) == {"accel_g", "gyro_dps", "mag_uT", "temp_c"}
	assert is_tuple3(out["accel_g"]) and all(is_num(v) for v in out["accel_g"]) 
	assert is_tuple3(out["gyro_dps"]) and all(is_num(v) for v in out["gyro_dps"]) 
	assert is_tuple3(out["mag_uT"]) and all(is_num(v) for v in out["mag_uT"]) 
	assert is_num(out["temp_c"]) 
