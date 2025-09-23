# Quadcopter PCB Project - Current Status

## Project Structure Created ✅

Successfully set up Atopile project in: `c:\Users\pete5\pico_code_projects\Drone_mk1\PCB Design\quadcopter_pcb\`

### Generated Files:
- `ato.yaml` - Project configuration
- `main.ato` - Main board definition (currently minimal)
- `layouts/default/default.kicad_pcb` - Auto-generated KiCad PCB file
- Build outputs in `build/builds/default/`

## Components Required

### Main Components:
1. **Raspberry Pi Pico 2W** - Main microcontroller
   - RP2040 with WiFi/Bluetooth
   - 40-pin DIP package with castellated holes
   - 3.3V logic level

2. **2x DRV8833 Motor Drivers**
   - Dual H-bridge motor driver ICs
   - Control 4 brushed DC motors (720 motors)
   - Each DRV8833 controls 2 motors

3. **ICM-20946 IMU** (Adafruit breakout)
   - 9-DOF sensor: magnetometer, gyroscope, accelerometer
   - I2C interface
   - Link: https://www.adafruit.com/product/4554

4. **BMP280 Pressure/Temperature Sensor**
   - I2C interface
   - Altitude measurement for flight control

5. **Pimoroni Amigo Pro LiPo Charger**
   - Battery management system
   - 5V output for motors
   - 3.7V LiPo battery support (800mAh)

6. **Status LEDs**
   - Green LED: Power indicator (solid)
   - Red LED: Activity/motion indicator (flashing)
   - Include current limiting resistors

7. **Power Button**
   - Tactile switch for system power control

8. **Motor Connectors**
   - Headers for 4x 720 brushed motors (external)

## Pin Assignments (Planned)

### Raspberry Pi Pico 2W Pin Usage:
```
Power:
- VSYS (pin 39) - System power from Amigo Pro
- 3V3_OUT (pin 36) - 3.3V for sensors
- Multiple GND pins - Ground connections

Motor Control:
- GP0-GP7 - DRV8833 control signals (4 pins per driver)

I2C Bus (sensors):
- GP26 (pin 31) - SDA
- GP27 (pin 32) - SCL

Status/Control:
- GP13 (pin 17) - Power button input
- GP14 (pin 19) - Red LED control  
- GP15 (pin 20) - Green LED control
```

## Power Distribution

```
LiPo Battery (3.7V) → Amigo Pro → VSYS (Pico 2W)
                                ↓
                              3V3_OUT → Sensors (ICM-20946, BMP280)
                                ↓
                              5V_OUT → Motors via DRV8833
```

## Communication Protocols

- **I2C**: IMU and pressure sensor communication
- **Bluetooth**: Android phone app for drone control
- **GPIO**: Motor driver control, LED status, button input

## Current Build Status

✅ **Working**: Basic Atopile project builds successfully
✅ **Generated**: KiCad PCB file structure
⏳ **Next**: Add component definitions with correct Atopile syntax

## Required Component Libraries

Need to either:
1. Find existing Atopile packages for components
2. Create custom component definitions
3. Import from KiCad library format

## Build Commands

```powershell
# Navigate to project
cd "c:\Users\pete5\pico_code_projects\Drone_mk1\PCB Design\quadcopter_pcb"

# Build project
ato build

# Generated files appear in:
# - build/builds/default/default.kicad_pcb
# - layouts/default/default.kicad_pcb
```

## Next Steps

1. **Learn correct Atopile component syntax**
2. **Add Raspberry Pi Pico 2W component**
3. **Add motor drivers (DRV8833)**
4. **Add sensors (ICM-20946, BMP280)**
5. **Add power management**
6. **Add LEDs and button**
7. **Connect all signals/nets**
8. **Generate final KiCad files**
9. **Create schematic**
10. **Layout PCB**
11. **Generate Gerbers**

## Design Requirements

- **Drill holes**: 0.5mm for mounting
- **KiCad version**: 9.0.4 compatibility
- **Output files**: Schematic, PCB, Gerbers, BOM
- **Component placement**: All components on PCB except motors
- **Motor voltage**: 3.7V (from battery)
- **Logic voltage**: 3.3V
- **Control interface**: Android app via Bluetooth