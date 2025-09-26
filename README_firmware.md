# Drone_mk1 Firmware (MicroPython)

This folder adds a modular firmware skeleton for the Raspberry Pi Pico 2W based flight controller. It wires up the I2C sensors using your hardware pin map from `hardware/main.ato` and provides a first-draft flight computer loop with pluggable PID.

- Bus: I2C1, SDA=GP26, SCL=GP27 (400 kHz)
- IMU INT: GP16
- Status LED: GP14 (red), GP15 (green)

Drivers are optional: if you copy in MicroPython drivers (e.g., `bmp280.py`, `icm20948.py`, or `mpu9250.py`) the wrappers will use them. If not, the code falls back to a lightweight simulator so you can test the flow without hardware.

## Layout

- `config/pins.py` — Central pin definitions for the board
- `drivers/i2c_bus.py` — Singleton I2C manager (I2C1 on GP26/GP27)
- `drivers/uart_bus.py` — Singleton UART helper (default UART1 on GP20/GP21)
- `sensors/imu_wrapper.py` — IMU detection and reads via available drivers, else simulated
- `sensors/bmp280_wrapper.py` — BMP280 read via driver, else simulated
- `sensors/sensor_hub.py` — Unified sensor interface (accel/gyro/mag/temp/press)
- `control/pid.py` — Minimal PID controller
- `fc/flight_computer.py` — First-draft loop reading sensors and applying PIDs
- `run_fc.py` — Entry-point to run the flight computer (MicroPython)
- `run_sensors_demo.py` — Quick sensor demo to print IMU/Baro values

Copy the folder(s) to your Pico’s filesystem (e.g., into `/lib` or root) and run `run_fc.py`.

## Adding real drivers (recommended)

- BMP280: place a MicroPython `bmp280.py` driver in `drivers/` (preferred) or root/`lib/`.
- IMU: for ICM-20948 or MPU-9250/9255, place the driver in `drivers/` (preferred) or root/`lib/`.

The wrappers will try drivers packages first (e.g., `drivers.mpu9250`, `drivers.bmp280`) and then plain modules.

## Notes

- I2C addresses auto-detected. Common ones:
  - IMU: 0x68 or 0x69
  - BMP280: 0x76 or 0x77
- UART default: UART1 @ 115200, TX=GP20, RX=GP21 (configurable in `config/pins.py`)
- If no sensor drivers are found, simulated readings are produced so the loop runs.
- Tune the PID gains in `flight_computer.py`.

## Arming button (GP13)

- The flight computer watches a momentary push-button on GP13 (`BUTTON_ARM_PIN` in `config/pins.py`).
- The input is configured with pull-up; a press pulls the line low (active-low).
- Debounce: 80 ms; a valid press toggles armed/disarmed. While armed, motors respond to throttle/mixer; when disarmed, outputs are forced to zero.

## Attitude filter (Complementary)

- `control/attitude.py` provides a simple complementary filter that fuses accelerometer (for roll/pitch long-term) and gyroscope (short-term dynamics). Yaw integrates gyro Z rate.
- Tuning: `alpha` (default 0.98). Higher alpha trusts gyro more (faster response, more drift), lower alpha trusts accel more (slower, less drift).

## Magnetometer support

- The `drivers/mpu9250.py` driver enables AK8963 magnetometer via I2C bypass and applies factory sensitivity adjustment.
- Sensor outputs are exposed in microtesla (uT) via `ImuSensor` wrapper at `out['mag_uT']`.
- Note: Hard/soft iron calibration is not implemented; heading accuracy may be limited without calibration.

## Running tests on desktop (no hardware)

- Tests under `tests/` are CPython-friendly and exercise simulation paths (no `machine` module required).
- Examples:
  - `test_bmp280.py` uses the BMP280 wrapper and checks numeric outputs.
  - `test_imu_gy91.py` validates accel/gyro/mag/temp fields from the IMU wrapper.
  - `test_sensor_hub.py` checks combined outputs from the `SensorHub`.

## Motor control (DRV8833 x2)

- Pins (from `hardware/main.ato`):
  - Left driver: GP0/GP1 (A), GP2/GP3 (B), sleep GP8
  - Right driver: GP4/GP5 (A), GP6/GP7 (B), sleep GP9
- PWM: 20 kHz default
- Safety: Motors start disarmed; outputs are zero until `arm()` is called on the flight computer.

Example (REPL):

```python
from fc.flight_computer import FlightComputer
fc = FlightComputer(loop_hz=100)
fc.arm()  # enable drivers
# Let it run for a few seconds, then:
fc.disarm()
```
