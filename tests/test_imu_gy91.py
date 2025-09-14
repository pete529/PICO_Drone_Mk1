# Test script for IMU (GY-91/MPU9250)
# This script validates basic sensor communication and data acquisition
from mpu9250 import read_reg, ACCEL_XOUT_H, GYRO_XOUT_H, TEMP_OUT_H

# Read accelerometer data
accel = read_reg(0x68, ACCEL_XOUT_H, 6)
assert len(accel) == 6, "Accelerometer data length mismatch"

# Read gyroscope data
gyro = read_reg(0x68, GYRO_XOUT_H, 6)
assert len(gyro) == 6, "Gyroscope data length mismatch"

# Read temperature data
temp = read_reg(0x68, TEMP_OUT_H, 2)
assert len(temp) == 2, "Temperature data length mismatch"

print("IMU (GY-91) sensor test passed.")
