# Component Pin Map (Draft)

> Update as components are instantiated in `main.ato`.

## Raspberry Pi Pico 2W (U1)
| Function | Pico GPIO | Planned Net | Notes |
|----------|-----------|-------------|-------|
| GPS RX   | GP0       | GPS_RX      | UART0 RX - GPS module |
| GPS TX   | GP1       | GPS_TX      | UART0 TX - GPS module |
| Motor L A | GP2      | L_M1        | DRV8833 Left AIN1 (Motor A direction/PWM) |
| Motor L B | GP3      | L_M2        | DRV8833 Left AIN2 (Motor A direction/PWM) |
| Motor L C | GP4      | L_M3        | DRV8833 Left BIN1 (Motor A direction/PWM) |
| Motor L D | GP5      | L_M4        | DRV8833 Left BIN2 (Motor A direction/PWM) |
| Motor R A | GP6      | R_M1        | DRV8833 Right AIN1 (Motor B direction/PWM) |
| Motor R B | GP7      | R_M2        | DRV8833 Right AIN2 (Motor B direction/PWM) |
| Motor R C | GP8      | R_M3        | DRV8833 Right BIN1 (Motor B direction/PWM) |
| Motor R D | GP9      | R_M4        | DRV8833 Right BIN2 (Motor B direction/PWM) |
| (Reserve) | GP10     | Spare       | Reserved for expansion |
| (Reserve) | GP11     | Spare       | Reserved for expansion |
| (Reserve) | GP12     | Spare       | Reserved for expansion |
| Power Btn | GP13     | BTN_PWR     | Input (button) |
| Red LED   | GP14     | LED_RED     | Activity blink |
| DRV_L EN  | GP15     | DRV_L_SLEEP | DRV8833 Left enable/sleep |
| IMU INT   | GP16     | IMU_INT     | IMU interrupt input |
| DRV_R EN  | GP17     | DRV_R_SLEEP | DRV8833 Right enable/sleep |
| (Reserve) | GP18     | Spare       | Reserved for expansion |
| (Reserve) | GP19     | Spare       | Reserved for expansion |
| (Reserve) | GP20     | Spare       | Reserved for expansion |
| (Reserve) | GP21     | Spare       | Reserved for expansion |
| (Reserve) | GP22     | Spare       | Reserved for expansion |
| I2C SDA   | GP26     | SDA         | I2C data - IMU + BMP280 |
| I2C SCL   | GP27     | SCL         | I2C clock - IMU + BMP280 |
| RUN       | RUN      | RUN_EN      | Can be tied to button for reset |
| 3V3       | 3V3      | +3V3        | Regulated output |
| VSYS      | VSYS     | VBAT / +5V  | From Amigo Pro |
| GND Pins  | GND*     | GND         | Multiple pins tied plane |

## DRV8833 (U2/U3) Dual H-Bridge (Typical)
| Pin | Signal | Net | Notes |
|-----|--------|-----|-------|
| 1   | nSLEEP | +3V3 (or GPIO control) | Enable: tied to +3V3 to always enable, or GP15(L)/GP17(R) for power control |
| 2   | AIN1   | GP2(L) / GP6(R) | Left uses GP2, Right uses GP6 |
| 3   | AIN2   | GP3(L) / GP7(R) | Left uses GP3, Right uses GP7 |
| 4   | BIN1   | GP4(L) / GP8(R) | Left uses GP4, Right uses GP8 |
| 5   | BIN2   | GP5(L) / GP9(R) | Left uses GP5, Right uses GP9 |
| 6   | nFAULT | (test pad) | Optional status |
| 7   | VREF   | (NC or tuned) | If current limiting used |
| 8   | GND    | GND | Ground |
| 9   | GND    | GND | Thermal pad (if exposed) |
| 10  | VM     | +MOTOR | Motor supply (5V from Amigo Pro) |
| 11  | OUT1A  | MOTOR_L1 / MOTOR_R1 | Off-board to motor |
| 12  | OUT1B  | MOTOR_L2 / MOTOR_R2 |  |
| 13  | OUT2A  | MOTOR_L3 / MOTOR_R3 |  |
| 14  | OUT2B  | MOTOR_L4 / MOTOR_R4 |  |

## IMU (ICM-20948) (Adafruit Breakout)
| Breakout Pin | Net | Notes |
|--------------|-----|-------|
| VIN          | +3V3 | (Or +5 -> internal LDO) Prefer +3V3 |
| 3V3          | +3V3 | If powering from 3V3 only one is used |
| GND          | GND |  |
| SCL          | SCL |  |
| SDA          | SDA |  |
| INT          | IMU_INT | Optional interrupt |
| AD0          | GND | I2C address select |
| FSYNC        | (NC) | Not used |
| CS           | (NC) | SPI not used |

## BMP280 (GY-BMP280)
| Pin | Net | Notes |
|-----|-----|-------|
| VIN | +3V3 |  |
| GND | GND |  |
| SCL | SCL |  |
| SDA | SDA |  |
| CSB | +3V3 | Keep high for I2C |
| SDO | GND | Address select |

## Power (Pimoroni Amigo Pro Interface)
Expose pads / header:
- BAT (LiPo)
- 5V (USB / boost if available)
- GND
- CHG / PGOOD status (optional)

## LEDs
| Ref | Net | Driver GPIO | Resistor |
|-----|-----|-------------|----------|
| D1 (Green) | LED_GREEN | GP13 | R1 (1k) |
| D2 (Red)   | LED_RED   | GP12 | R2 (1k) |

## Power Button (S1)
- One side to GND
- Other side to BTN_PWR (GP14) with internal pull-up (enable in firmware) or external 10k to +3V3

## Motor Headers (Off-board)
Left: J1 -> MOTOR_L1..L4 to DRV8833 U2 OUT pins
Right: J2 -> MOTOR_R1..R4 to DRV8833 U3 OUT pins
Return path: shared GND

## Net Summary
| Net | Source | Loads |
|-----|--------|-------|
| VBAT | Battery (Amigo Pro) | Pico VSYS (if used), +MOTOR (if direct) |
| +5V | Amigo Pro USB/Boost | (Optional) |
| +3V3 | Pico regulator | IMU, BMP280, logic, LEDs, button pull-up |
| +MOTOR | VBAT or +5V | DRV8833 VM pins |
| GND | Common | All components |
| SCL/SDA | Pico I2C0 | IMU, BMP280 |
| IMU_INT | IMU | Pico GP2 |
| LED_RED / LED_GREEN | Pico GPIO | LEDs via resistors |
| BTN_PWR | Button | Pico GP14 |
| L_M*, R_M* | Pico GPIO | DRV8833 inputs |

---
This file is a living document. Update when you finalize actual routed nets in KiCad.
