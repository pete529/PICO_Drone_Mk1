# Feature: Nintendo Wii Controller Integration

## Description
Enable drone control using a Nintendo Wii controller. This feature provides a user-friendly interface for piloting the drone via Bluetooth.

## Requirements
- Connect and communicate with Wii controller via Bluetooth
- Map controller inputs to flight control commands
- Handle connection status and input events

## Scope
- Hardware: Raspberry Pi Pico 2W, Wii controller
- Software: MicroPython
- Communication: Bluetooth

## Related Test
See `tests/test_wii_controller.py` for validation of controller input handling.
