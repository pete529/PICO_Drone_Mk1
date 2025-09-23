# PICO Drone Mk1 – Quadcopter Flight Controller PCB

**Status:** Early electrical net scaffolding (components not yet fully instantiated in Atopile – BOM empty). This repository will evolve toward a complete Raspberry Pi Pico 2W based flight controller PCB.

> See `COMPONENT_TASKS.md` for the detailed hardware implementation checklist.

## Overview
This project aims to design and iterate a custom flight controller PCB using:
- Raspberry Pi Pico 2W module (Wi-Fi enabled RP2040)
- Dual DRV8833 motor driver ICs (4 brushed outputs)
- 9-axis IMU (ICM-20948/20946 family)
- Barometric sensor (BMP280)
- Power management based on Pimoroni Amigo Pro (boost + charge)
- Status LEDs (Green solid, Red flashing)
- Power button / enable circuitry
- Motor connectors (4x) with proper decoupling

## Current Repository Contents
- `PCB Design/quadcopter_pcb/main.ato` – Signal-level module definitions (needs real component models)
- `PCB Design/quadcopter_pcb/layouts/default` – Generated KiCad PCB (placeholder, no footprints yet)
- `.github/workflows/build.yml` – CI workflow to run `ato build` and publish artifacts
- `LICENSE` – MIT License
- `PROJECT_STATUS.md` – Narrative project status notes
- `pico2w.ato` – Early attempt at a Pico part module (incomplete)

## Build (Locally)
Requirements: Python 3.11+, Atopile 0.12.4

```powershell
pip install atopile==0.12.4
cd "PCB Design/quadcopter_pcb"
ato build
```
Artifacts appear in `build/builds/default/`.

## GitHub Actions CI
Every push to `main` runs the Atopile build and uploads:
- KiCad PCB file
- BOM (currently empty)
- Variable & I2C tree markdown
- 3D board model (if generated)

You can download them from the workflow run artifacts page.

## Roadmap
| Phase | Goal | Status |
|-------|------|--------|
| 1 | Repo + signal scaffolding | Done |
| 2 | Validate Pico 2W component definition | Pending |
| 3 | Add DRV8833 component (x2) + nets | Pending |
| 4 | Add IMU + BMP280 I2C device definitions | Pending |
| 5 | Power / protection / decoupling library parts | Pending |
| 6 | LED + resistor + button footprints | Pending |
| 7 | Mounting holes, board outline | Pending |
| 8 | Gerber generation & DFM review | Pending |
| 9 | Release v0.2.0 (first real PCB) | Future |

## Dual Push (GitHub + GitLab)
Configured by adding GitLab remote earlier. Optional combined push strategy (if desired) can be a script or additional push URL.

To add GitLab as additional push target on `origin` (alternative approach):
```powershell
git remote set-url --add origin https://gitlab.com/pete529/PICO_Drone_Mk1.git
```
(We kept a distinct `gitlab` remote instead to keep fetches clean.)

Push both manually:
```powershell
git push origin main
git push gitlab main
```

## Versioning
We'll start semantic versioning now.
Create a new tag after meaningful milestones:
```powershell
git tag -a v0.1.0 -m "Initial CI + scaffolding"
git push origin v0.1.0
```

An automated workflow (`.github/workflows/bump-version.yml`) inspects commit messages on `main` and will bump the version file (`VERSION`) using these rules:
- `feat:` → minor (unless major bump triggered)
- `BREAKING CHANGE` or `!: ` → major
- otherwise → patch

To disable auto bump for a commit, include `[skip bump]` in the commit message.

## Contributing
Currently private / personal R&D. Future contribution guidelines may include:
- Atopile component style guide
- Pin mapping validation steps
- CI footprint linting

## License
MIT – see `LICENSE`.

## Disclaimer
Electronics provided as-is; verify footprints, clearances, and power integrity before fabrication. Use at your own risk.
