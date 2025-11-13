# DRV8833 Motor Driver Wiring Guide

This guide documents the exact wiring between the Raspberry Pi Pico 2W and the Adafruit DRV8833 dual motor driver.

## Overview

The PICO Drone Mk1 uses **two DRV8833** motor drivers to control four brushed DC motors (720 motors). Each DRV8833 can control two motors independently.

- **Left DRV8833**: Controls Motor A (front-left) and Motor B (rear-left)
- **Right DRV8833**: Controls Motor C (front-right) and Motor D (rear-right)

## Wiring Table (Pico 2W → DRV8833 → Motors)

### Logic & Control Connections

#### Left DRV8833 (Motor Driver #1)

| DRV8833 Pin | Function | Connect To | Pico Pin # | Notes |
|-------------|----------|------------|------------|-------|
| AIN1 | Motor A direction | GP2 | Pin 4 | PWM capable for speed control |
| AIN2 | Motor A direction | GP3 | Pin 5 | PWM capable for speed control |
| BIN1 | Motor B direction | GP4 | Pin 6 | PWM capable for speed control |
| BIN2 | Motor B direction | GP5 | Pin 7 | PWM capable for speed control |
| nSLEEP | Enable driver | 3V3 or GP15 | Pin 36 or Pin 20 | Pull high to enable; can use GPIO for power management |
| VCC | Logic power | 3V3 | Pin 36 | 3.3V logic supply |
| GND | Ground | GND | Pin 38 or any GND | Must share ground with motor supply |

#### Right DRV8833 (Motor Driver #2)

| DRV8833 Pin | Function | Connect To | Pico Pin # | Notes |
|-------------|----------|------------|------------|-------|
| AIN1 | Motor C direction | GP6 | Pin 9 | PWM capable for speed control |
| AIN2 | Motor C direction | GP7 | Pin 10 | PWM capable for speed control |
| BIN1 | Motor D direction | GP8 | Pin 11 | PWM capable for speed control |
| BIN2 | Motor D direction | GP9 | Pin 12 | PWM capable for speed control |
| nSLEEP | Enable driver | 3V3 or GP17 | Pin 36 or Pin 22 | Pull high to enable; can use GPIO for power management |
| VCC | Logic power | 3V3 | Pin 36 | 3.3V logic supply |
| GND | Ground | GND | Pin 38 or any GND | Must share ground with motor supply |

### Motor Power Connections

| DRV8833 Pin | Connect To | Notes |
|-------------|------------|-------|
| VM | Motor battery + (4–9V) | **DO NOT** use Pico 5V output; use dedicated motor supply |
| GND | Motor battery – | Common ground is **mandatory** with Pico GND |

### Motor Output Connections

| DRV8833 Outputs | Motor | Notes |
|-----------------|-------|-------|
| Left AOUT1 / AOUT2 | Motor A (Front-Left) | If motor spins backwards, swap wires |
| Left BOUT1 / BOUT2 | Motor B (Rear-Left) | If motor spins backwards, swap wires |
| Right AOUT1 / AOUT2 | Motor C (Front-Right) | If motor spins backwards, swap wires |
| Right BOUT1 / BOUT2 | Motor D (Rear-Right) | If motor spins backwards, swap wires |

## Quick Wiring Diagram (Text Layout)

```
PICO 2W                    LEFT DRV8833                  MOTOR POWER
--------                   ------------                   -----------
       GP2  ------------>  AIN1
       GP3  ------------>  AIN2
       GP4  ------------>  BIN1
       GP5  ------------>  BIN2

      3V3  -------------+-- VCC
                        |
 GP15/3V3 -------------> nSLEEP

      GND  -------------+-- GND --- Motor Battery (-)
                        |
Motor Battery (+) ------> VM

Motor A (FL)  <-------->  AOUT1 / AOUT2
Motor B (RL)  <-------->  BOUT1 / BOUT2


PICO 2W                   RIGHT DRV8833                  MOTOR POWER
--------                  -------------                  -----------
       GP6  ------------>  AIN1
       GP7  ------------>  AIN2
       GP8  ------------>  BIN1
       GP9  ------------>  BIN2

      3V3  -------------+-- VCC
                        |
 GP17/3V3 -------------> nSLEEP

      GND  -------------+-- GND --- Motor Battery (-)
                        |
Motor Battery (+) ------> VM

Motor C (FR)  <-------->  AOUT1 / AOUT2
Motor D (RR)  <-------->  BOUT1 / BOUT2
```

## Motor Control Logic

Each motor is controlled using two GPIO pins in a standard H-bridge configuration:

| AINx/BINx State | Motor Behavior |
|-----------------|----------------|
| IN1=LOW, IN2=LOW | Coast (motor off) |
| IN1=LOW, IN2=HIGH | Rotate forward |
| IN1=HIGH, IN2=LOW | Rotate backward |
| IN1=HIGH, IN2=HIGH | Brake (short to ground) |

### PWM Speed Control

For variable speed control, use PWM on one or both of the input pins:
- **Forward with PWM**: IN1=PWM, IN2=LOW
- **Backward with PWM**: IN1=LOW, IN2=PWM

The duty cycle of the PWM signal determines the motor speed (0-100%).

## Power Management

### nSLEEP Pin Options

**Option 1: Always Enabled (Simplest)**
- Connect nSLEEP directly to 3V3
- Motor drivers are always powered and ready

**Option 2: GPIO Control (Recommended)**
- Connect nSLEEP to GPIO pin (GP15 for left, GP17 for right)
- Allows software control of motor driver power
- Pull HIGH to enable motors, LOW to put drivers to sleep
- Reduces power consumption when motors are not in use

## Safety Notes

1. **Shared Ground**: The Pico GND and motor battery GND **MUST** be connected together
2. **Separate Motor Supply**: Do NOT power motors from Pico's 5V or 3.3V rails
3. **Voltage Range**: DRV8833 supports 2.7V to 10.8V motor supply
4. **Current Limit**: Each DRV8833 channel can handle up to 1.2A continuous, 2A peak
5. **Thermal Protection**: The DRV8833 has built-in thermal shutdown protection
6. **nFAULT Pin**: Optionally monitor for fault conditions (overtemperature, overcurrent)

## GPIO Pin Summary

| GPIO Pin | Function | Description |
|----------|----------|-------------|
| GP2 | Left AIN1 | Motor A direction/PWM |
| GP3 | Left AIN2 | Motor A direction/PWM |
| GP4 | Left BIN1 | Motor B direction/PWM |
| GP5 | Left BIN2 | Motor B direction/PWM |
| GP6 | Right AIN1 | Motor C direction/PWM |
| GP7 | Right AIN2 | Motor C direction/PWM |
| GP8 | Right BIN1 | Motor D direction/PWM |
| GP9 | Right BIN2 | Motor D direction/PWM |
| GP15 | Left nSLEEP | Enable left motor driver (optional) |
| GP17 | Right nSLEEP | Enable right motor driver (optional) |

## Firmware Example (MicroPython)

```python
from machine import Pin, PWM

# Initialize motor control pins
motor_a_in1 = PWM(Pin(2))  # Left DRV8833 AIN1
motor_a_in2 = PWM(Pin(3))  # Left DRV8833 AIN2
motor_b_in1 = PWM(Pin(4))  # Left DRV8833 BIN1
motor_b_in2 = PWM(Pin(5))  # Left DRV8833 BIN2

# Set PWM frequency (1-20kHz typical for DC motors)
motor_a_in1.freq(1000)
motor_a_in2.freq(1000)
motor_b_in1.freq(1000)
motor_b_in2.freq(1000)

# Enable motor drivers (if using GPIO control)
drv_left_sleep = Pin(15, Pin.OUT)
drv_right_sleep = Pin(17, Pin.OUT)
drv_left_sleep.value(1)  # Enable left driver
drv_right_sleep.value(1)  # Enable right driver

def set_motor_speed(motor_in1, motor_in2, speed):
    """
    Set motor speed and direction
    speed: -100 to +100 (negative = reverse)
    """
    if speed > 0:
        # Forward
        motor_in1.duty_u16(int(speed * 655.35))  # 0-65535
        motor_in2.duty_u16(0)
    elif speed < 0:
        # Reverse
        motor_in1.duty_u16(0)
        motor_in2.duty_u16(int(-speed * 655.35))
    else:
        # Coast
        motor_in1.duty_u16(0)
        motor_in2.duty_u16(0)

# Example: Run motor A forward at 50% speed
set_motor_speed(motor_a_in1, motor_a_in2, 50)
```

## Testing Procedure

1. **Power Connection Test**
   - Connect only 3.3V and GND to DRV8833 VCC and GND
   - Verify 3.3V is present at VCC pin
   - Do NOT connect motor power yet

2. **GPIO Signal Test**
   - Set all control pins (GP2-GP9) to LOW
   - Individually toggle each pin HIGH and verify with multimeter
   - Verify signal levels are 0V (LOW) and 3.3V (HIGH)

3. **Motor Power Test**
   - Connect motor battery to VM and GND
   - Verify voltage at VM pin matches battery voltage
   - Enable nSLEEP (pull to 3.3V)

4. **Motor Movement Test**
   - Connect one motor to AOUT1/AOUT2
   - Set AIN1=HIGH, AIN2=LOW
   - Motor should rotate in one direction
   - Reverse signals: AIN1=LOW, AIN2=HIGH
   - Motor should rotate in opposite direction

5. **All Motors Test**
   - Connect all four motors
   - Test each motor independently
   - Verify correct direction for each motor
   - If direction is wrong, swap motor wires

## Troubleshooting

### Motor doesn't spin
- Check nSLEEP is HIGH (3.3V)
- Verify VM has motor battery voltage
- Check GND is shared between Pico and motor battery
- Verify GPIO pins are outputting signals

### Motor spins wrong direction
- Swap the two motor wires (AOUT1 ↔ AOUT2 or BOUT1 ↔ BOUT2)

### Motor runs slow or weak
- Check motor battery voltage (should be 4-9V)
- Verify PWM duty cycle is appropriate (50-100%)
- Check motor battery capacity (might be depleted)

### DRV8833 gets hot
- Reduce PWM frequency if too high (try 1-5kHz)
- Check for motor stall condition
- Verify current draw is within limits (1.2A continuous per channel)
- Add heatsink if running motors at high power continuously

## References

- [DRV8833 Datasheet](https://www.ti.com/lit/ds/symlink/drv8833.pdf)
- [Adafruit DRV8833 Guide](https://www.adafruit.com/product/3297)
- [Raspberry Pi Pico Datasheet](https://datasheets.raspberrypi.com/pico/pico-datasheet.pdf)

---

**Document Version**: 1.0  
**Last Updated**: 2025-11-13  
**Author**: PICO Drone Mk1 Project
