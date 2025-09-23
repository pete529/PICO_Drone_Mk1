# Feature: Safety - Bluetooth Connection Loss

## Description
Implement safety features to stop the drone and hover in place if the Bluetooth connection to the controller drops, and automatically reconnect when possible.

## Requirements
- Detect Bluetooth connection status
- Stop motors and maintain hover on connection loss
- Attempt automatic reconnection

## Scope
- Hardware: Raspberry Pi Pico 2W, Wii controller
- Software: MicroPython
- Communication: Bluetooth

## Related Test
See `tests/test_safety_bluetooth.py` for validation of safety logic.
