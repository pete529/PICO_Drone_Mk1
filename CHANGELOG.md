# Changelog

All notable changes to this project will be documented in this file.

## [0.8.0] - 2025-09-26

- Firmware
  - Fixed FlightComputer syntax/structure and improved loop timing
  - Added ComplementaryAHRS (control/attitude.py) and integrated into FC
  - Added arm button on GP13 with debounce and safe arming flow
  - Added DRV8833 driver integration and simple quad-X mixer
  - Added UART helper (drivers/uart_bus.py) with configurable pins
  - Refactored MPU9250 driver to class and enabled AK8963 magnetometer with calibration
  - I2C singleton (drivers/i2c_bus.py) wired to I2C1 GP26/GP27
- Sensors
  - Wrappers prefer drivers/ modules, fallback to simulation when missing
  - BMP280 wrapper normalizes pressure units and provides altitude estimation
  - IMU wrapper returns accel/gyro/mag/temp and supports MPU9250 or simulated
- Tests
  - Converted tests to be CPython-friendly (no machine module required)
  - Added SensorHub smoke test and UART helper smoke test
- Docs
  - Firmware README documents arming button, complementary filter, magnetometer support, and desktop testing

[0.8.0]: https://github.com/pete529/PICO_Drone_Mk1/releases/tag/v0.8.0