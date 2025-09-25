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

## GitHub Issues Creation (v2 Markdown Parser)

A newer v2 script parses a simple Markdown file and syncs GitHub issues idempotently.

- File format: `# Epic`, `## Feature`, `### Story`
- Optional labels inline: `[labels: a, b]` in the heading, or a `Labels:` line in the body
- Auto adds a type label: `Epic` | `Feature` | `Story`

Usage:

```powershell
# Basic: create missing issues only
./create_github_issues_v2.ps1 -StoriesPath user_stories.md

# Update existing issues (body + labels add). Use -ReplaceLabels to reconcile exactly
./create_github_issues_v2.ps1 -StoriesPath user_stories.md -UpdateExisting
./create_github_issues_v2.ps1 -StoriesPath user_stories.md -UpdateExisting -ReplaceLabels

# Dry run (no changes), plus write summary and markdown report
./create_github_issues_v2.ps1 -StoriesPath user_stories.md -DryRun -SummaryPath issues_summary_v2.json -MarkdownReportPath issues_report_v2.md

# Process a specific chunk (e.g. items 30-44) to avoid long-run hangs
./create_github_issues_v2.ps1 -StoriesPath user_stories.md -UpdateExisting -ReplaceLabels -FromIndex 30 -LimitItems 15 -SummaryPath chunk_30_44.json

# Run all chunks automatically (default size 15)
./run_issue_chunks.ps1 -ChunkSize 15 -UpdateExisting -ReplaceLabels
```

Tips:
- Auth via `gh auth login`, or set `GH_TOKEN` / `GITHUB_TOKEN` env var
- Repo resolution: uses the current repo if `-Owner/-Repo` are not provided
- Labels referenced in Markdown are ensured (created if missing)

### Chunked / Resumable Execution

If very large full runs occasionally stall (external `gh` CLI hang), you can process the backlog in deterministic chunks:

- `-FromIndex N` starts processing at the zero-based index of the parsed markdown items.
- `-LimitItems K` caps how many items are processed in this invocation.
- Together they form a window: `[FromIndex, FromIndex + LimitItems)`.

Helper script `run_issue_chunks.ps1` orchestrates sequential chunks:

```powershell
# Dry run all chunks (no changes)
./run_issue_chunks.ps1 -ChunkSize 20 -DryRun

# Live update with label reconciliation (body+labels) in 15-item windows
./run_issue_chunks.ps1 -ChunkSize 15 -UpdateExisting -ReplaceLabels

# Resume only remaining tail manually
./create_github_issues_v2.ps1 -UpdateExisting -ReplaceLabels -FromIndex 60 -LimitItems 20
```

Each chunk writes its own summary/report (`issues_summary_v2_chunk_#.json`). You can merge results later if desired. This strategy avoids losing progress to a mid-run stall.

### Additional Resilience & Performance Flags (Advanced)

The v2 script also supports advanced flags to make large synchronizations safer and faster:

| Flag | Purpose | Default | When to Use |
|------|---------|---------|-------------|
| `-GhTimeoutSeconds <n>` | Kills and retries any single `gh` CLI call exceeding `n` seconds. | 60 | Full runs that occasionally hang mid-call. |
| `-SkipUnchanged` | Skips body update when the existing GitHub issue body already matches the markdown (still reconciles labels). | Off | Re-running frequent syncs where most stories are unchanged. |

Examples:
```powershell
# Run chunked with a 45s per-call timeout
./run_issue_chunks.ps1 -ChunkSize 15 -UpdateExisting -ReplaceLabels; \
	Get-ChildItem issues_summary_v2_chunk_*.json | Select Name

# Direct window with timeout + skip unchanged bodies
./create_github_issues_v2.ps1 -FromIndex 30 -LimitItems 15 -UpdateExisting -ReplaceLabels -GhTimeoutSeconds 45 -SkipUnchanged

# Speedy dry run sanity check
./create_github_issues_v2.ps1 -DryRun -SkipUnchanged -StoriesPath user_stories.md
```

Effect of `-SkipUnchanged`:
- Performs a lightweight `gh issue view --json body` per issue on update.
- If trimmed body text matches, body update call is omitted, reducing API/process usage.
- Labels are still reconciled (added/removed) respecting `-ReplaceLabels`.

Timeout Behavior (`-GhTimeoutSeconds`):
- Each `gh` invocation is launched in a separate process.
- If it exceeds the timeout, the process is terminated and retried (subject to `-RetryCount` / backoff).
- Exit codes `-999` (timeout) and other non-zero values are treated as transient until retries exhausted.

See `user_stories.template.md` for a sample structure.

## GitHub Issues Creation (v2 REST Variant)

To eliminate occasional external `gh` CLI stalls, a REST-native script `create_github_issues_v2_rest.ps1` provides near feature parity plus extra optimization options.

### Why REST?
| Concern | CLI Variant | REST Variant |
|---------|-------------|--------------|
| External process hangs | Possible on long runs | None (direct HTTP) |
| Per-call timeout | Manual wrapper | Native via `Invoke-RestMethod` timeout |
| Label ensure | Yes | Yes |
| Skip unchanged bodies | String compare | String or hash compare (optional) |
| Hash-based change detection | No | Yes (`-UseBodyHash`) |
| Parse-only mode | Yes (`-ParseOnly` in CLI via earlier improvements) | Yes (`-ParseOnly`) |
| Chunk window | Yes | Yes |
| Replace labels exactly | `-ReplaceLabels` | `-ReplaceLabels` |

### Key Additional Flags
| Flag | Purpose |
|------|---------|
| `-ParseOnly` | Parse markdown and write summaries/reports without any API calls (no token required). |
| `-UseBodyHash` | Appends an HTML comment `<!-- sync-hash:SHA256 -->` to each issue body. Future runs compare only the hash for fast unchanged detection. |
| `-SkipUnchanged` | When used with `-UseBodyHash`, hash comparison avoids fetching or diffing large bodies; otherwise falls back to canonical text compare. |
| `-HttpTimeoutSeconds` | Timeout for each REST call (default 40s) with retries/backoff. |
| `-FilterTitle "regex"` | Process only items whose title matches the supplied case-insensitive regex (applied before chunk window). |

### Usage Examples
```powershell
# 1. Parse-only (no token required) with body hashing to preview generated issues
./create_github_issues_v2_rest.ps1 -ParseOnly -UseBodyHash -StoriesPath user_stories.md -SummaryPath rest_parse.json

# 2. First real creation pass (creates missing issues only)
./create_github_issues_v2_rest.ps1 -GitHubToken $env:GITHUB_TOKEN -UseBodyHash -SummaryPath rest_create.json

# 3. Update existing issues (body + label reconciliation) but skip unchanged using hashes
./create_github_issues_v2_rest.ps1 -UpdateExisting -SkipUnchanged -UseBodyHash -ReplaceLabels -GitHubToken $env:GITHUB_TOKEN -SummaryPath rest_update.json

# 4. Process a specific window (items 30-44) safely
./create_github_issues_v2_rest.ps1 -UpdateExisting -ReplaceLabels -FromIndex 30 -LimitItems 15 -SkipUnchanged -UseBodyHash -GitHubToken $env:GITHUB_TOKEN -SummaryPath rest_chunk_30_44.json

# 5. Pure dry run (no create/update) but still exercise label ensure logic
./create_github_issues_v2_rest.ps1 -DryRun -UpdateExisting -ReplaceLabels -UseBodyHash -SkipUnchanged -GitHubToken $env:GITHUB_TOKEN -SummaryPath rest_dryrun.json

# 6. Only sync WiFi or telemetry related items
./create_github_issues_v2_rest.ps1 -UpdateExisting -ReplaceLabels -FilterTitle "WiFi|Telemetry" -SkipUnchanged -UseBodyHash -GitHubToken $env:GITHUB_TOKEN -SummaryPath rest_wifi.json
```

### Hash Logic Details
- Canonical body removes any existing `<!-- sync-hash:... -->` marker before hashing.
- Hashing uses SHA-256 over UTF-8 bytes of canonical text.
- The hash marker is appended as a final line to persist change fingerprint.
- On `-SkipUnchanged -UseBodyHash`, if existing and new hashes match, body update is skipped (labels still reconciled).

### When to Use Hashing
| Scenario | Recommended? | Benefit |
|----------|--------------|---------|
| Large bodies with frequent re-sync | Yes | Fast equality check, minimal diff noise |
| Many runs with few edits | Yes | Avoids repeated PATCH calls |
| One-off initial import | Optional | Adds marker but no harm |
| Bodies manually edited on GitHub | Caution | Manual edits outside canonical format change hash; script will patch body to restore canonical + marker |

### Summary JSON (REST)
Adds `useBodyHash` boolean to previous schema:
```json
{
	"repository": "owner/repo",
	"dryRun": true,
	"updateExisting": false,
	"replaceLabels": false,
	"useBodyHash": true,
	"createdCount": 0,
	"updatedCount": 0,
	"skippedCount": 0,
	"failedCount": 0,
	"totalFromMarkdown": 71,
	"elapsedSeconds": 0.4
}
```

### Migration Tips
1. Run a `-ParseOnly -UseBodyHash` to preview and inject hashes locally (no API calls).
2. Perform a creation run without `-UpdateExisting` to add any new issues.
3. Follow with `-UpdateExisting -SkipUnchanged -UseBodyHash` for maintenance cycles.
4. Use chunk windows (`-FromIndex/-LimitItems`) only if you anticipate extremely large future backlogs; REST calls are typically stable without chunking.
5. Narrow scope with `-FilterTitle` when iterating on a subset (e.g., `-FilterTitle "^Story 3\\.|WiFi"`).

### Troubleshooting (REST)
| Symptom | Cause | Resolution |
|---------|-------|------------|
| Token error | Missing PAT | Provide `-GitHubToken` or set `GH_TOKEN` / `GITHUB_TOKEN` |
| 403 rate limit | Excessive rapid updates | Add `-ThrottleMs 250` or re-run later |
| Skips expected update | Hash unchanged | Change markdown body or omit `-SkipUnchanged` once |
| Marker visible in UI | Expected | It's a harmless HTML comment; remove `-UseBodyHash` for future runs to stop adding it |

The legacy CLI script remains available; prefer the REST variant for reliability on large sets.

### Merging Multiple Runs

Use `merge_issue_summaries.ps1` to consolidate JSON summaries from both CLI and REST scripts.

```powershell
# Basic merge (auto-glob issues_summary_v2*.json)
./merge_issue_summaries.ps1

# Specify explicit files
./merge_issue_summaries.ps1 -Paths issues_summary_v2_rest_parseonly.json,rest_update_live.json

# Include distinct title lists and write to custom output
./merge_issue_summaries.ps1 -IncludeDetails -Output merged_detailed.json

# Dry run (print to console only)
./merge_issue_summaries.ps1 -DryRun -Glob "rest_*.json"
```

Merged output fields:
- `files`, `totalFiles`
- `repositories` (file count per repo)
- `totals` (created/updated/skipped/failed/defined/filtered)
- `rollup` (net summary)
- `distinctTitles` (only when `-IncludeDetails`)

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
