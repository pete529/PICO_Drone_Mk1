@echo off
REM GitHub Issues Creation Batch Script
REM This script calls the PowerShell script to create GitHub issues

echo Creating GitHub issues for Drone Project...
echo.

REM Check if GitHub CLI is installed
gh --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI (gh) is not installed.
    echo Please install it from https://cli.github.com/
    echo.
    pause
    exit /b 1
)

REM Prompt for GitHub token if not set as environment variable
if "%GITHUB_TOKEN%"=="" (
    set /p GITHUB_TOKEN=Enter your GitHub Personal Access Token: 
)

if "%GITHUB_TOKEN%"=="" (
    echo ERROR: GitHub token is required.
    echo Please create a Personal Access Token at https://github.com/settings/tokens
    echo.
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "create_github_issues.ps1" -GitHubToken "%GITHUB_TOKEN%"

echo.
echo Done! Check your GitHub repository for the created issues.
pause