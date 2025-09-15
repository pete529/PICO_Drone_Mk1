
# Pico 2W Quadcopter PCB — Starter Project
Generated: 2025-09-15

This package gives you a **ready-to-open KiCad project** plus an **Atopile project scaffold** that match the spec you provided.
I cannot run external tools from here, so please run `ato build` and generate Gerbers locally. Everything is wired for that workflow.

---
## Key electrical choices (aligned to your brief)
- **MCU:** Raspberry Pi Pico 2W (RP2350) — Wi‑Fi/BLE; powered from **VSYS = 5V** output of the Pimoroni LiPo Amigo Pro.
- **Motors:** 4x 720 brushed motors driven by **two DRV8833 dual H‑bridges**.
- **Motor supply (VMOTOR):** **3.7 V (battery rail)** by default to match 720 motor rating. A solder‑jumper lets you re‑select 5 V if you really need it.
- **Sensors:** GY‑91 combo (MPU‑9250 + BMP280). Connected over **I2C0** on GPIO **20 (SDA)** and **21 (SCL)**.
- **LEDs:** 
  - **Green (GPIO16):** “ARMED/ON” (software‑controlled).
  - **Red (GPIO17):** Flashes when the quadcopter is moving.
- **Power button:** Inline **latching SPST slide switch** on the battery positive before the Pimoroni board.
- **Grounding:** All grounds (Pico GND, Amigo GND, DRV8833 PGND/GND, GY‑91 GND, LED returns) tied to a **single ground plane**.
- **PCB rule:** **Minimum via drill = 0.50 mm** (as requested). Two M2.5 mounting holes included.
- **Do NOT modify IC pin‑maps**. Symbols/footprints note the real pin numbers; please double‑check when you swap packages.

---
## Pin map (Pico 2W)
- **DRV8833 #1 (Left motors):**
  - AIN1 → GPIO2
  - AIN2 → GPIO3
  - BIN1 → GPIO4
  - BIN2 → GPIO5
  - nSLEEP → GPIO10 (pull‑down adds 100 k to GND; drive high to enable)
- **DRV8833 #2 (Right motors):**
  - AIN1 → GPIO6
  - AIN2 → GPIO7
  - BIN1 → GPIO8
  - BIN2 → GPIO9
  - nSLEEP → GPIO11 (100 k pull‑down)
- **GY‑91 (I2C0):**
  - SDA → GPIO20
  - SCL → GPIO21
  - INT (optional) → GPIO22
- **LEDs:**
  - Green: anode → 3V3 via 1 k; cathode → GPIO16 (active‑LOW sink)
  - Red: anode → 3V3 via 1 k; cathode → GPIO17 (active‑LOW sink)
- **Power button (latching):** Battery+ → Slide SW → Amigo BAT+
- **Pico 3V3_EN:** 100 k to GND (keeps LDO enabled by default).

> PWM-capable GPIOs were chosen for clean motor control. You can remap in firmware if needed.

---
## Atopile workflow
Files under `./atopile/` show each component added **one‑by‑one** in `main.ato`. After each block you should run:
```
ato build
```
I cannot run that here; the scaffolding is ready for you to do so locally in VS Code.

---
## KiCad workflow
1. Open `kicad/pico2w_quadcopter.kicad_pro`.
2. Inspect schematic (`.kicad_sch`), then **Update PCB from Schematic**.
3. The PCB already has a 2‑layer stackup, 0.50 mm min via drill, and basic keep‑outs.
4. Plot Gerbers (`File → Plot`) and drill files into `kicad/gerbers`.
5. DRC: pay attention to **motor current widths** (recommend ≥ 40–60 mil to motors).

---
## Notes on the DRV8833 pinout
This project uses the TI **DRV8833** (HTSSOP‑16) dual H‑bridge. Double‑check your exact variant/package before fab.
Pins (typical HTSSOP‑16 ordering — confirm with your datasheet!):
- 1: AOUT1
- 2: AISEN (sense; left floating by default here)
- 3: AOUT2
- 4: BOUT2
- 5: BISEN (sense; left floating by default here)
- 6: BOUT1
- 7: nSLEEP
- 8: VREF (not used; tie to logic if your variant needs it—see DS)
- 9: GND/PGND
-10: VM (motor supply; **jumper: BAT (3.7 V)** or 5 V)
-11: BIN2
-12: BIN1
-13: AIN2
-14: AIN1
-15: nFAULT (optional test‑pad)
-16: VCC (logic 3.3 V)

Because there are several close variants (8833 / 8833C), keep the symbol/footprint pair consistent and **do not edit pin maps**. Swap footprints instead if your distributor sends a different package.

---
## What’s included
- KiCad 7/8 compatible project: schematic + board + rules + placeholders for Gerbers.
- Atopile project scaffold with `define` blocks adding each component in order.
- A TSV BOM starter you can adapt for your fab/assembly partner.

Good luck — and ping me if you want me to iterate the routing or widen any copper for higher motor currents.
