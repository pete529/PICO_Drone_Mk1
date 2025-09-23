# GitHub Issues Creation for Drone Project

This directory contains scripts to automatically create GitHub issues from the user stories defined in `user_stories.md`.

## Overview

The project is organized into 6 major epics with multiple features and user stories:

1. **Epic 1: Hardware Design & PCB Development** - Complete hardware platform
2. **Epic 2: Flight Control Software** - Stable and responsive flight control
3. **Epic 3: Wireless Communication & Control** - Remote control capabilities  
4. **Epic 4: Development Tools & CI/CD** - Automated build and test systems
5. **Epic 5: Testing & Validation** - Comprehensive testing for safety and reliability
6. **Epic 6: Documentation & User Guide** - Complete documentation and instructions

## Files

- `user_stories.md` - Complete user stories organized by epic and feature
- `create_github_issues.ps1` - PowerShell script to create GitHub issues
- `create_issues.bat` - Windows batch file to run the PowerShell script
- `GITHUB_ISSUES_README.md` - This documentation file

## Prerequisites

1. **GitHub CLI**: Install from https://cli.github.com/
2. **GitHub Personal Access Token**: Create at https://github.com/settings/tokens
   - Required scopes: `repo` (full repository access)
3. **PowerShell**: Available on Windows by default

## Usage

### Method 1: Using the Batch File (Recommended for Windows)

1. Double-click `create_issues.bat`
2. Enter your GitHub Personal Access Token when prompted
3. Wait for the script to create all issues

### Method 2: Using PowerShell Directly

```powershell
# Set your GitHub token as an environment variable
$env:GITHUB_TOKEN = "your_token_here"

# Run the script
.\create_github_issues.ps1 -GitHubToken $env:GITHUB_TOKEN
```

### Method 3: Custom Repository

If you want to create issues in a different repository:

```powershell
.\create_github_issues.ps1 -GitHubToken "your_token" -Owner "your_username" -Repo "your_repo"
```

## What Gets Created

The script will create GitHub issues with the following structure:

### Labels Used:
- `epic` - High-level business objectives
- `feature` - Major functional areas
- `story` - Individual user stories/requirements
- `hardware` - Hardware-related work
- `software` - Software development
- `pcb` - PCB design and layout
- `sensors` - Sensor integration
- `testing` - Testing and validation
- `documentation` - Documentation work
- `ci-cd` - CI/CD and automation

### Issue Hierarchy:
```
Epic 1: Hardware Design & PCB Development
├── Feature 1.1: Flight Controller PCB
│   ├── Story 1.1.1: Raspberry Pi Pico 2W Integration
│   ├── Story 1.1.2: Dual DRV8833 Motor Driver Integration
│   ├── Story 1.1.3: GY-91 9-DOF IMU Integration
│   ├── Story 1.1.4: Power Management with LiPo Support
│   └── Story 1.1.5: Status LEDs and User Controls
├── Feature 1.2: Component Selection & BOM
│   ├── Story 1.2.1: Automated Part Selection from LCSC
│   ├── Story 1.2.2: Proper Footprint Assignments
│   └── Story 1.2.3: Validated BOM with Pricing
└── Feature 1.3: PCB Layout & Manufacturing
    ├── Story 1.3.1: KiCad PCB Layout Files
    ├── Story 1.3.2: Gerber Files for Manufacturing
    └── Story 1.3.3: Assembly Instructions
```

## Troubleshooting

### GitHub CLI Not Found
```
ERROR: GitHub CLI (gh) is not installed.
```
**Solution**: Install GitHub CLI from https://cli.github.com/

### Authentication Failed
```
ERROR: Authentication failed
```
**Solution**: 
1. Verify your Personal Access Token is correct
2. Ensure the token has `repo` scope permissions
3. Check that you have write access to the repository

### Rate Limiting
If you encounter rate limiting errors, the script includes small delays between issue creation. For persistent issues, you may need to:
1. Wait and retry later
2. Use a token with higher rate limits
3. Create issues in smaller batches

### Permission Denied
```
ERROR: Resource not accessible by personal access token
```
**Solution**: 
1. Verify you have write access to the repository
2. Check that your token has the correct scopes
3. Ensure the repository owner and name are correct

## Customization

### Adding New Issues
To add new user stories:
1. Edit `user_stories.md` to add your stories
2. Edit `create_github_issues.ps1` to add the corresponding issue definitions
3. Run the script to create the new issues

### Modifying Labels
To change the labels used:
1. Edit the `labels` array in each issue definition
2. Consider creating the labels in GitHub first if they don't exist

### Changing Repository
The script defaults to `pete529/PICO_Drone_Mk1`. To use a different repository:
```powershell
.\create_github_issues.ps1 -GitHubToken "token" -Owner "your_username" -Repo "your_repo_name"
```

## Next Steps

After creating the issues:
1. Review and organize issues using GitHub Projects
2. Assign issues to team members
3. Set milestones for epic and feature completion
4. Use issue templates for consistent formatting
5. Link related issues and pull requests

## Support

For issues with the scripts:
1. Check the troubleshooting section above
2. Verify GitHub CLI is properly installed and authenticated
3. Review the PowerShell execution policy settings
4. Check repository permissions and token scopes