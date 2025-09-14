# Feature: GPS (NEO-6M) Integration

## Description
Integrate the NEO-6M compatible GPS module with the flight computer. This feature enables the drone to acquire location and time data for navigation and telemetry.

## Requirements
- Communicate with the GPS module via UART
- Parse and provide location (latitude, longitude) and time data
- Integrate GPS data into flight control and logging

## Scope
- Hardware: Raspberry Pi Pico 2W, NEO-6M GPS
- Software: MicroPython
- Communication: UART

## Related Test
See `tests/test_gps_neo6m.py` for validation of GPS data acquisition.
