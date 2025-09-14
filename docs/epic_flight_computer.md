# Epic: Build the Flight Computer

## Overview
Build the flight computer for our micro python drone. It will use a Raspberry Pi Pico 2W for the flight computer and has the following sensors:

- IMU – GY-91 (MPU9250)
- GPS – NEO-6M compatible

For the ESC, the drone will use two DRV8833 motor drivers.

The drone will be controlled using a Nintendo Wii controller.

## Safety Features
- Stop the drone and hover in place if the Bluetooth connection drops
- Automatically reconnect when Bluetooth is restored
