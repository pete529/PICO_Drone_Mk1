# Feature: IMU (GY-91/MPU9250) Integration

## Description
Integrate the GY-91 (MPU9250) IMU sensor with the flight computer using MicroPython and I2C. This feature enables the drone to read accelerometer, gyroscope, and temperature data for flight stabilization and navigation.

## Requirements
- Initialize and communicate with the GY-91 sensor via I2C
- Read and process accelerometer, gyroscope, and temperature data
- Provide sensor data to flight control algorithms

## Scope
- Hardware: Raspberry Pi Pico 2W, GY-91 (MPU9250)
- Software: MicroPython
- Communication: I2C

## Related Test
See `tests/test_imu_gy91.py` for validation of sensor data acquisition.
