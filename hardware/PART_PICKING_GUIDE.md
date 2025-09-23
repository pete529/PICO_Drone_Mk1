## Part Picking Guide (Work in Progress)

This project currently uses abstract `component` definitions (e.g. `Pico2W`, `Drv8833`, `Led0603`) that do NOT resolve to physical parts yet. The BOM is empty because the picker has nothing to bind. This guide explains how to move from abstract components to picked parts.

### 1. Enable the `ato` CLI
Verify:
```
ato --version
```
If missing, install (choose one):
```
pip install --upgrade atopile
# or
pipx install atopile
```

### 2. Use Library Passives
Instead of `Resistor0603`, prefer the library `Resistor` module:
```ato
r_led = new Resistor
r_led.resistance = 1kohm +/- 5%
r_led.package = "0603"
```
Picker uses the toleranced parameter and package to choose a part. If multiple matches exist, narrow tolerance or specify `lcsc = "<LCSC_PARTNUMBER>"`.

### 3. Installing or Creating Device Packages
Check if a package exists:
```
ato add <vendor-part-package>
```
If not, create a local package (example DRV8833):
1. Make directory: `packages/ti-drv8833/`
2. Add `ato.yaml` with a `default` build entry.
3. Run part creation tool (if available) or manually write a driver module mapping pins to interfaces (e.g. `AIN1` as `ElectricLogic`).

### 4. Modeling Power & Buses
Use standard interfaces to improve part matching:
```ato
power_5v = new ElectricPower
power_5v.hv ~ power.V5
power_5v.lv ~ GND

i2c0 = new I2C
i2c0.scl.line ~ pico.SCL
i2c0.sda.line ~ pico.SDA
i2c0 ~ imu.i2c   # if imu exposes i2c interface
```

### 5. Transition Plan in This Repo
| Step | Action | Result |
| ---- | ------ | ------ |
| 1 | Remove ignored metadata (done) | Cleaner warnings |
| 2 | Replace custom resistors with library `Resistor` | Passives picked |
| 3 | Add packages for Pico & DRV8833 or create local ones | ICs pickable |
| 4 | Add correct footprints via created parts | KiCad board populated |
| 5 | Document design in README | Easier maintenance |

### 6. BOM Validation in CI
CI currently fails if BOM is empty. After introducing first picked passive, BOM will have at least one data row; refine progressively.

### 7. Troubleshooting Picker
Common causes of empty BOM:
- No parameters with tolerance (e.g. `10kohm` vs `10kohm +/- 5%`).
- Missing `package` constraint for passives.
- Using plain `component` with only `pin` declarations (no driver / part reference).
- Traits or metadata fields that are not supported in current grammar.

### 8. Next Candidate Changes
- Replace all `Resistor0603` instances.
- Introduce a `Capacitor` array for decoupling on Pico power rails (if adding regulators). Example:
```ato
decaps = new Capacitor[2]
for c in decaps:
    c.capacitance = 100nF +/- 20%
    c.package = "0402"
    power_3v3.hv ~> c ~> power_3v3.lv
```

### 9. Footprints & Explicit Parts
If a specific part is required, set one authoritative identifier (e.g. `lcsc`) rather than hardcoding footprint and value in abstract components. Let the part definition carry the footprint mapping.

### 10. Open Tasks
- Implement library resistor migration.
- Create/Install packages for Pico and DRV8833.
- Re-run build & validate BOM.
- Update root README with summary (this file can be referenced).

---
Maintainer Notes: After first successful pick, capture the picker logs and prune any obsolete abstractions.
