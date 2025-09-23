# PICO Drone Mk1 – Quadcopter Flight Controller PCB

**Status:** ✅ Hardware design complete with successful atopile builds. Ready for component sourcing and PCB manufacturing.

> **New:** Complete user stories and GitHub issue management system available. See [GitHub Issues Creation](#github-issues-creation) below.

## Overview
This project is a complete Raspberry Pi Pico 2W based quadcopter flight controller featuring:
- **Raspberry Pi Pico 2W** module (Wi-Fi enabled RP2040 with wireless connectivity)
- **Dual DRV8833** motor driver ICs (4 independent brushed motor outputs)  
- **GY-91 9-DOF IMU** (ICM-20948 + BMP280 for orientation, acceleration, and altitude)
- **Power management** with LiPo Amigo Pro (boost converter + charging circuit)
- **Status LEDs** (power indicator and user-controllable status)
- **User controls** (power button and mode switching)
- **Robust design** with proper power filtering and protection circuits

## Project Structure
```
├── hardware/                    # Main atopile project directory
│   ├── main.ato                # Top-level quadcopter module with complete wiring
│   ├── ato.yaml                # Build configuration with multiple targets
│   ├── atopile/components/     # Custom component definitions
│   ├── layouts/                # KiCad PCB layouts (default + test targets)
│   ├── build/                  # Generated build artifacts
│   └── PART_PICKING_GUIDE.md   # Troubleshooting and part selection guide
├── user_stories.md             # Complete user stories (6 epics, 25+ features)
├── create_github_issues.ps1    # Script to create GitHub issues from user stories
├── create_issues.bat           # Windows batch file for easy execution
├── GITHUB_ISSUES_README.md     # Documentation for issue management system
└── .github/workflows/          # CI/CD automation
```

## Current Status

### ✅ **Hardware Design Complete**
- **PCB Design**: Complete atopile design with comprehensive component wiring
- **Build System**: Successfully builds with `ato build` - all stages complete
- **Component Integration**: Pico 2W, dual DRV8833s, GY-91 IMU, power management
- **Signal Routing**: All motor control, I2C, power, and user interface connections
- **Build Artifacts**: KiCad files, BOMs, netlists, and manufacturing files generated

### ✅ **Development Infrastructure**  
- **CI/CD**: Automated builds on every commit with artifact publishing
- **Version Management**: Semantic versioning with automated version bumping
- **Issue Management**: Complete user story system with GitHub issue creation
- **Documentation**: Comprehensive guides for building, troubleshooting, and development

### 🔄 **Next Steps**
- **Component Sourcing**: Automated part selection from LCSC (BOM currently empty - needs library parts)
- **PCB Manufacturing**: Generate Gerber files and prepare for fabrication
- **Software Development**: Flight control algorithms and wireless interface
- **Testing & Validation**: Hardware testing and flight control validation

## Build System

### Local Development
Requirements: Python 3.11+, Atopile 0.12.4

```powershell
# Install atopile
pip install atopile==0.12.4

# Navigate to hardware directory  
cd hardware

# Build the project (generates KiCad files, BOM, netlist)
ato build

# Build specific target
ato build --target test_pickable
```

**Build Output:**
- `build/builds/default/` - Main quadcopter design files
- `build/builds/test_pickable/` - Component testing files
- KiCad PCB files (.kicad_pcb)
- Bill of Materials (.bom.csv) 
- Netlists and component reports

### Automated CI/CD
✅ **GitHub Actions** runs on every push:
- Validates atopile syntax and builds
- Generates all build artifacts
- Publishes downloadable artifacts
- Automated version bumping based on commit messages

**Download artifacts:** Go to any workflow run → Artifacts section

## GitHub Issues Creation

This project includes a comprehensive user story system organized into 6 major epics:

1. **Hardware Design & PCB Development** - Complete hardware platform
2. **Flight Control Software** - Stable and responsive flight control  
3. **Wireless Communication & Control** - Remote piloting capabilities
4. **Development Tools & CI/CD** - Automated build and test systems
5. **Testing & Validation** - Safety and reliability verification
6. **Documentation & User Guide** - Complete instructions and guides

### Creating Issues from User Stories

**Prerequisites:**
- GitHub CLI installed: https://cli.github.com/
- GitHub Personal Access Token: https://github.com/settings/tokens (with `repo` scope)

**Quick Start:**
```powershell
# Windows - Double-click the batch file
create_issues.bat

# Or run PowerShell directly
.\create_github_issues.ps1 -GitHubToken "your_token_here"
```

This will create 25+ GitHub issues organized with labels:
- `epic` - High-level business objectives
- `feature` - Major functional areas  
- `story` - Individual user requirements
- `hardware`, `software`, `testing`, `documentation` - Work categories

**See:** `GITHUB_ISSUES_README.md` for complete documentation

### Issue Automation (Advanced Usage)

The script `create_github_issues.ps1` is **idempotent**: it will not recreate issues that already exist (it checks both open and closed issues by exact title match).

Key features:
- Automatic authentication reuse (you only need `-GitHubToken` if not already logged in with `gh auth login`)
- Full backlog coverage (all epics, features, and stories from `user_stories.md`)
- Label synchronization (missing labels are created on-the-fly)
- Duplicate avoidance (skips existing titles, counts skipped vs created)
- Optional JSON summary output via `-SummaryPath`
- Safe to re-run any time to add only new backlog items

#### Parameters
| Parameter | Required | Description |
|-----------|----------|-------------|
| `-GitHubToken` | No | Personal access token (PAT) with `repo` scope. Optional if already authenticated. |
| `-Owner` | No | Repository owner (default: preset in script) |
| `-Repo` | No | Repository name (default: preset in script) |
| `-SummaryPath` | No | Path to write JSON summary of run (created, skipped, totals) |

#### Examples
```powershell
# 1. First time (no existing gh auth session)
./create_github_issues.ps1 -GitHubToken $env:GITHUB_TOKEN

# 2. Already authenticated via gh
./create_github_issues.ps1

# 3. Capture a summary JSON
./create_github_issues.ps1 -SummaryPath .\issue_summary.json

# 4. Different fork or repo
./create_github_issues.ps1 -Owner YourUser -Repo ForkedRepo -SummaryPath out\summary.json
```

#### Sample Output
```
Checking GitHub authentication...
Verifying repository access (owner/repo)...
Fetching existing issue titles...
Synchronizing labels...
Creating GitHub issues (idempotent)...
↷ Skipping (exists): Epic 1: Hardware Design & PCB Development
✓ Created: Story 2.2.1: Individual Motor Speed Control
...
🚀 Issue creation complete
Created: 57  Skipped: 42  Total Defined: 99  Elapsed: 12.4s
```

#### Summary JSON Schema
```json
{
	"repository": "owner/repo",
	"created": 57,
	"skipped": 42,
	"totalDefined": 99,
	"elapsedSeconds": 12.4,
	"timestamp": "2025-09-23T14:52:31.210Z"
}
```

#### Adding New Stories Later
1. Append new stories to `user_stories.md` using the naming pattern (e.g. `Story 2.4.1:`).
2. Add corresponding hash entry to the `$issues` array in `create_github_issues.ps1`.
3. Re-run the script – only new titles are created; existing ones are skipped.

#### Troubleshooting
| Issue | Cause | Resolution |
|-------|-------|------------|
| Auth error | Not logged in & no token | Run `gh auth login` or pass `-GitHubToken` |
| Label create warnings | Label exists / insufficient perms | Safe to ignore if labels appear in repo |
| Duplicate creation | Title manually changed on GitHub | Align local script title with existing issue |
| >500 existing issues | Pagination limit | (Future) add paging; currently first 500 open + 500 closed |

#### Potential Future Enhancements
- `-DryRun` preview mode
- Filtering (e.g. `-OnlyEpic 3` or `-Match "Motor"`)
- Auto-generated backlog index file
- Changelog-style diff when new stories are added

Open an issue if you need one of these prioritized.

## Roadmap & Development Status

| Phase | Goal | Status | Issues |
|-------|------|--------|---------|
| ✅ **Phase 1** | Repository + CI/CD infrastructure | **Complete** | Epic 4 |
| ✅ **Phase 2** | Hardware design + component integration | **Complete** | Epic 1 |
| ✅ **Phase 3** | Atopile build system + PCB generation | **Complete** | Epic 1 |
| 🔄 **Phase 4** | Component sourcing + BOM population | **In Progress** | Feature 1.2 |
| 📋 **Phase 5** | Flight control software development | **Planned** | Epic 2 |
| 📋 **Phase 6** | Wireless communication + web interface | **Planned** | Epic 3 |
| 📋 **Phase 7** | Testing + validation + safety systems | **Planned** | Epic 5 |
| 📋 **Phase 8** | Documentation + user guides | **Planned** | Epic 6 |
| 📋 **Phase 9** | PCB manufacturing + assembly | **Future** | Feature 1.3 |
| 📋 **Phase 10** | Flight testing + tuning | **Future** | Epic 2 |

**Current Focus:** Component sourcing and part selection for automated BOM generation

## Technical Specifications

### Hardware
- **Microcontroller:** Raspberry Pi Pico 2W (RP2040 + WiFi)
- **Motor Drivers:** 2x DRV8833 (4 independent brushed DC motor outputs)
- **IMU:** GY-91 (ICM-20948 9-DOF + BMP280 barometer)
- **Power:** LiPo Amigo Pro (boost converter + charging)
- **Connectivity:** WiFi 802.11n, I2C sensors, GPIO controls
- **Indicators:** Status LEDs, user button, power management

### Software (Planned)
- **Flight Control:** PID stabilization loops, sensor fusion
- **Communication:** WiFi AP/STA modes, real-time telemetry
- **Interface:** Web-based control panel, mobile-friendly
- **Safety:** Fail-safe landing, emergency stop, range limiting

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
