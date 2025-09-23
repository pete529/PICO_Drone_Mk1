# Component Implementation Task List

This document tracks the concrete steps required to move from a signal-only scaffold to a manufacturable flight controller PCB with full component definitions.

## Legend
- [ ] Not started
- [~] In progress / prototype
- [x] Done / validated in build (BOM lists part, footprint present)

## 1. Core MCU: Raspberry Pi Pico 2W Module
- [ ] Create `components/pico2w.ato` with proper pin map (USB, SWD, GPIO0-29, RUN, 3V3_EN, VSYS, VBUS, GND pins). 
- [ ] Associate correct KiCad footprint (module or castellated variant). 
- [ ] Expose key nets: I2C (SDA/SCL), SPI (if needed), UART (for debug), PWM outputs for motor drivers, status LED pins, power enable.
- [ ] Validate build: BOM contains Pico module; layout shows footprint.

## 2. Motor Drivers (2x DRV8833)
- [ ] Create `components/drv8833.ato` with 2 instances (Left/Right or Front/Back) or parameterizable module.
- [ ] Pins: AIN1, AIN2, BIN1, BIN2, nSLEEP, nFAULT, VM, OUT1..OUT4, GND.
- [ ] Decoupling caps (100nF close to VM, bulk cap 10µF–47µF). Add as part of submodule or board-level power cluster.
- [ ] Add nets: map Pico PWM pins → AIN/BIN signals; motor outputs to connector nets (M1/M2/M3/M4 or ± pairs).
- [ ] Validate: BOM lists 2 driver ICs + required capacitors.

## 3. IMU (ICM-20948 / ICM-20946 family)
- [ ] Create `components/imu_icm20948.ato`.
- [ ] Pins: VDD, VDDIO, GND, SDA, SCL, INT, AD0/ADDR, optional FSYNC, auxiliary I2C if used.
- [ ] Add 0.1µF + 10µF decoupling close to VDD.
- [ ] Optional: Pull-ups for SDA/SCL if not provided elsewhere (decide central vs distributed strategy).
- [ ] Validate orientation (axes arrow) footprint note.

## 4. Barometric Sensor (BMP280)
- [ ] Create `components/bmp280.ato`.
- [ ] Pins: VDDIO, VDD, GND, SDA, SCL, CSB (tie high for I2C), SDO (tie per address choice), optional INT (if variant supports).
- [ ] Add 0.1µF decoupling.

## 5. Power System (Amigo Pro Derived)
- [ ] Abstract pimoroni Amigo Pro functional blocks (LiPo charger, boost 5V, 3V3 regulator enable logic) OR integrate discrete equivalents.
- [ ] Battery connector footprint (JST-PH 2-pin).
- [ ] Protection: TVS diode (USB), reverse polarity MOSFET or rely on module design.
- [ ] Net naming: VBAT, 5V (if produced), 3V3, VSYS (Pico), VBUS (USB), GND.
- [ ] Verify Pico 3V3_EN / RUN wiring and safe power-up sequence.

## 6. LEDs and Resistors
- [ ] Add `components/status_led.ato` or inline LED + resistor pairs.
- [ ] Green LED (power or status) – anode to 3V3 via resistor, cathode to Pico pin (active low) OR anode to pin via resistor (active high) – decide scheme.
- [ ] Red LED (fault / armed) – map to PWM-capable pin if blinking intensity control desired.
- [ ] Confirm resistor values (e.g., 1k for indicator ~2mA from 3V3).

## 7. Button / Reset / Boot Select
- [ ] Add momentary pushbutton footprint for user input (soft power / mode) OR tie to RUN.
- [ ] Evaluate adding BOOTSEL accessible pad or test point.

## 8. Motor Connectors
- [ ] Decide connector: JST-SH / Micro JST / Through-hole pads.
- [ ] 4 connectors each with 2 terminals for brushed motor pairs OR 8 single outputs.
- [ ] Add mechanical keep-outs and strain relief considerations.

## 9. Mounting + Mechanical
- [ ] Add 4x mounting holes (e.g., M2 or M2.5) with keep-outs.
- [ ] Define board outline (square/plus shape) – ensure prop clearance for typical frame.
- [ ] Add reference silks (motor numbers, orientation arrow, center mark).

## 10. Test / Debug Access
- [ ] SWD pads: SWDIO, SWCLK, GND, 3V3, RUN.
- [ ] UART TX/RX test pads (optional for boot logs).
- [ ] Battery sense divider (optional) routed to ADC pin.

## 11. Net Clean-Up & Layer Strategy
- [ ] Replace generic signal placeholders with component-driven nets.
- [ ] Add ground pour strategy (top + bottom) with stitching vias near drivers & IMU.
- [ ] Controlled routing for IMU I2C and interrupt lines (short, low-noise path).

## 12. EMC / Power Integrity
- [ ] Bulk capacitor near motor driver supply rail.
- [ ] Add snubber or RC if motor noise observed (optional future iteration).
- [ ] Separate analog ground island if needed for IMU (may be overkill – evaluate after first bring-up).

## 13. Gerbers & Fabrication Prep
- [ ] Add fabrication notes layer (board name, revision, date).
- [ ] Run DRC after footprint placement.
- [ ] Export Gerbers & IPC-356 netlist.

## 14. Version Advancement to v0.2.0
- [ ] Criteria: All core components in BOM, footprints placed, at least draft routing complete.
- [ ] Tag: `v0.2.0` and update README roadmap statuses.

## Supporting Tasks
- [ ] Introduce `components/` directory structure.
- [ ] Add style guidelines for Atopile component pin naming (match datasheet order where feasible).
- [ ] Add pre-commit hook for `ato build` dry-run.

---

Feel free to check off items and incrementally commit as components become real objects in BOM output.
