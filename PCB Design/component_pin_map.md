# Component Pin Map (Draft)

> Update as components are instantiated in `main.ato`.

## Raspberry Pi Pico 2W (U1)
| Function | Pico GPIO | Planned Net | Notes |
|----------|-----------|-------------|-------|
| I2C SDA  | GP0       | SDA         | IMU + BMP280 bus |
| I2C SCL  | GP1       | SCL         | IMU + BMP280 bus |
| IMU INT  | GP2       | IMU_INT     | Optional interrupt |
| Spare / SPI | GP3    | SPI / Spare | Reserved |
| Motor L A | GP4      | L_M1        | DRV8833 Left AIN1 |
| Motor L B | GP5      | L_M2        | DRV8833 Left AIN2 |
| Motor L C | GP6      | L_M3        | DRV8833 Left BIN1 |
| Motor L D | GP7      | L_M4        | DRV8833 Left BIN2 |
| Motor R A | GP8      | R_M1        | DRV8833 Right AIN1 |
| Motor R B | GP9      | R_M2        | DRV8833 Right AIN2 |
| Motor R C | GP10     | R_M3        | DRV8833 Right BIN1 |
| Motor R D | GP11     | R_M4        | DRV8833 Right BIN2 |
| Red LED   | GP12     | LED_RED     | Activity blink |
| Green LED | GP13     | LED_GREEN   | Power on indicator |
| Power Btn | GP14     | BTN_PWR     | Input w/ pull-up |
| (Reserve) | GP15     | DEBUG_RX    | UART debug RX |
| UART TX   | GP16     | DEBUG_TX    | UART debug to external header |
| (Reserve) | GP17     | SPI / Spare | Expansion |
| (Reserve) | GP18     | SPI / Spare | Expansion |
| (Reserve) | GP19     | SPI / Spare | Expansion |
| (Reserve) | GP20     | SPI / Spare | Expansion |
| (Reserve) | GP21     | SPI / Spare | Expansion |
| (Reserve) | GP22     | SPI / Spare | Expansion |
| RUN       | RUN      | RUN_EN      | Can be tied to button for reset |
| 3V3       | 3V3      | +3V3        | Regulated output |
| VSYS      | VSYS     | VBAT / +5V  | From Amigo Pro |
| GND Pins  | GND*     | GND         | Multiple pins tied plane |

## DRV8833 (U2/U3) Dual H-Bridge (Typical)
| Pin | Signal | Net | Notes |
|-----|--------|-----|-------|
| 1   | nSLEEP | +3V3 (pull-up) | Enable tied high (or GPIO for control) |
| 2   | AIN1   | L_M1 / R_M1 | Left/Right mapping |
| 3   | AIN2   | L_M2 / R_M2 |  |
| 4   | BIN1   | L_M3 / R_M3 |  |
| 5   | BIN2   | L_M4 / R_M4 |  |
| 6   | nFAULT | (test pad) | Optional status |
| 7   | VREF   | (NC or tuned) | If current limiting used |
| 8   | GND    | GND | Ground |
| 9   | GND    | GND | Thermal pad (if exposed) |
| 10  | VM     | +MOTOR | Motor supply |
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
