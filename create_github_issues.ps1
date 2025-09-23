#!/usr/bin/env pwsh
# GitHub Issues Creation Script for Drone Project User Stories
# This script creates GitHub issues for all epics, features, and stories

param(
    [Parameter(Mandatory=$false, HelpMessage="GitHub Personal Access Token (optional if already authenticated)")]
    [string]$GitHubToken,
    [Parameter(Mandatory=$false)]
    [string]$Owner = "pete529",
    [Parameter(Mandatory=$false)]
    [string]$Repo = "PICO_Drone_Mk1",
    [Parameter(Mandatory=$false, HelpMessage="Write JSON summary file path (optional)")]
    [string]$SummaryPath = "",
    [Parameter(Mandatory=$false, HelpMessage="Write Markdown report file path (optional)")]
    [string]$MarkdownReportPath = "",
    [Parameter(Mandatory=$false, HelpMessage="Maximum number of new issues to create this run (0 = no limit)")]
    [int]$MaxCreate = 0,
    [Parameter(Mandatory=$false, HelpMessage="Write incremental summary after each creation/skip (default: true if SummaryPath provided)")]
    [bool]$Incremental = $true
)

# Ensure GitHub CLI is available
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
}

# Authentication (optional if already logged in)
Write-Host "Checking GitHub authentication..." -ForegroundColor Green
# Auto-read GH_TOKEN / GITHUB_TOKEN if present and -GitHubToken not supplied
if (-not $GitHubToken) {
    if ($env:GH_TOKEN) { $GitHubToken = $env:GH_TOKEN }
    elseif ($env:GITHUB_TOKEN) { $GitHubToken = $env:GITHUB_TOKEN }
}
$authStatus = gh auth status 2>$null
if ($LASTEXITCODE -ne 0) {
    if ($GitHubToken) {
        Write-Host "Authenticating with provided token (env or param)..." -ForegroundColor Green
        if ($GitHubToken.Length -lt 20) { Write-Warning "Token length seems short; ensure you passed a valid PAT" }
        $GitHubToken | gh auth login --with-token | Out-Null
    } else {
        Write-Error "Not authenticated and no token provided. Provide -GitHubToken or login manually with 'gh auth login' first."; exit 1
    }
} else {
    if ($GitHubToken) { Write-Host "Already authenticated; ignoring provided token value (session active)." -ForegroundColor Yellow }
    else { Write-Host "Already authenticated via existing gh session." -ForegroundColor Green }
}

# Pre-flight: verify repo access
Write-Host "Verifying repository access ($Owner/$Repo)..." -ForegroundColor Green
gh repo view "$Owner/$Repo" --json name > $null 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "Unable to access repository $Owner/$Repo. Check owner/repo names and permissions."; exit 1 }

# Gather existing issues (title set for idempotency)
Write-Host "Fetching existing issue titles..." -ForegroundColor Green
$existingIssuesRaw = gh issue list --limit 500 --state open --repo "$Owner/$Repo" --json title 2>$null
if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to fetch open issues; proceeding without skip list."; $existingIssueTitles = @() } else { $existingIssueTitles = ($existingIssuesRaw | ConvertFrom-Json).title }

# Also include closed issues to avoid recreation if desired
$closedRaw = gh issue list --limit 500 --state closed --repo "$Owner/$Repo" --json title 2>$null
if ($LASTEXITCODE -eq 0 -and $closedRaw) { $existingIssueTitles += ( ($closedRaw | ConvertFrom-Json).title ) }
$existingIssueTitles = $existingIssueTitles | Sort-Object -Unique
Write-Host "Found $($existingIssueTitles.Count) existing issue titles (open+closed)." -ForegroundColor Cyan

## Label synchronization moved below after $issues is defined

# Define the issues structure
$issues = @(
    # Epic 1: Hardware Design & PCB Development
    @{
        title = "Epic 1: Hardware Design & PCB Development"
        body = "**As a drone developer, I want a complete hardware platform so that I can build a functional quadcopter.**

This epic encompasses all hardware-related development including PCB design, component selection, and manufacturing preparation."
        labels = @("epic", "hardware", "pcb")
    },
    
    # Feature 1.1: Flight Controller PCB
    @{
        title = "Feature 1.1: Flight Controller PCB"
        body = "**As a developer, I want a custom PCB flight controller so that I have integrated motor control and sensor systems.**

This feature covers the complete PCB design with all integrated components for flight control."
        labels = @("feature", "hardware", "pcb", "flight-controller")
    },
    
    @{
        title = "Story 1.1.1: Raspberry Pi Pico 2W Integration"
        body = "**As a developer, I want a Raspberry Pi Pico 2W integrated on the PCB so that I have wireless connectivity and sufficient processing power for flight control**

## Acceptance Criteria:
- [ ] Pico 2W is properly connected to the PCB with all required pins accessible
- [ ] Power supply is correctly routed to the Pico 2W
- [ ] GPIO pins are available for motor control and sensor interfaces
- [ ] WiFi antenna connections are proper for wireless communication
- [ ] Programming/debug connections are accessible

## Technical Requirements:
- Use standard Pico 2W footprint and pinout
- Ensure proper decoupling capacitors for power
- Route high-speed signals with appropriate trace width
- Maintain signal integrity for critical connections"
        labels = @("story", "hardware", "pico2w", "microcontroller")
    },
    
    @{
        title = "Story 1.1.2: Dual DRV8833 Motor Driver Integration"
        body = "**As a developer, I want dual DRV8833 motor drivers on the PCB so that I can control 4 brushed DC motors independently**

## Acceptance Criteria:
- [ ] Two DRV8833 motor drivers are integrated on the PCB
- [ ] Each driver can control 2 motors independently
- [ ] Motor power and control signals are properly routed
- [ ] Heat dissipation is adequate for continuous operation
- [ ] Enable/sleep pins are controllable from the Pico

## Technical Requirements:
- Use DRV8833 in recommended configuration
- Add motor power filtering capacitors
- Include thermal vias for heat dissipation
- Route motor outputs to appropriate connectors"
        labels = @("story", "hardware", "motor-driver", "drv8833")
    },
    
    @{
        title = "Story 1.1.3: GY-91 9-DOF IMU Integration"
        body = "**As a developer, I want a GY-91 9-DOF IMU integrated so that I can measure orientation, acceleration, and magnetic heading**

## Acceptance Criteria:
- [ ] GY-91 module is connected via I2C interface
- [ ] Power supply is stable and filtered for accurate readings
- [ ] Interrupt pins are available for motion detection
- [ ] Module is positioned for optimal sensor performance
- [ ] I2C pull-up resistors are correctly sized

## Technical Requirements:
- Connect to I2C bus with proper addressing
- Use 3.3V power supply with filtering
- Route interrupt signals to available GPIO pins
- Consider mechanical isolation from vibrations"
        labels = @("story", "hardware", "imu", "sensors", "gy91")
    },
    
    @{
        title = "Story 1.1.4: Power Management with LiPo Support"
        body = "**As a developer, I want proper power management with LiPo battery support so that the drone can operate wirelessly**

## Acceptance Criteria:
- [ ] LiPo battery connector is present with proper polarity protection
- [ ] Voltage regulation provides stable 3.3V and 5V rails
- [ ] Battery monitoring is available for low-voltage warnings
- [ ] Charging circuit is integrated (if required)
- [ ] Power distribution is adequate for all components

## Technical Requirements:
- Use LiPo Amigo Pro or equivalent power module
- Include reverse polarity protection
- Add power indicator LEDs
- Size voltage regulators for maximum current draw"
        labels = @("story", "hardware", "power", "battery", "lipo")
    },
    
    @{
        title = "Story 1.1.5: Status LEDs and User Controls"
        body = "**As a developer, I want status LEDs and user controls so that I can monitor system state and interact with the drone**

## Acceptance Criteria:
- [ ] Status LEDs indicate power, activity, and error states
- [ ] User button/switch is available for mode changes
- [ ] LED current limiting resistors are properly sized
- [ ] Controls are accessible when drone is assembled
- [ ] Visual indicators are clearly visible during operation

## Technical Requirements:
- Use standard 0603 LEDs with appropriate colors
- Include current limiting resistors (typically 1kΩ)
- Position controls for easy access
- Route control signals to available GPIO pins"
        labels = @("story", "hardware", "ui", "leds", "controls")
    },
    
    # Feature 1.2: Component Selection & BOM
    @{
        title = "Feature 1.2: Component Selection & BOM"
        body = "**As a developer, I want a complete bill of materials so that I can manufacture the PCB.**

This feature ensures all components are properly selected, sourced, and documented for manufacturing."
        labels = @("feature", "hardware", "bom", "manufacturing")
    },
    
    @{
        title = "Story 1.2.1: Automated Part Selection from LCSC"
        body = "**As a developer, I want automated part selection from LCSC so that I can easily source components for manufacturing**

## Acceptance Criteria:
- [ ] All passive components have LCSC part numbers assigned
- [ ] Part picker automatically selects appropriate resistors and capacitors
- [ ] Component values and tolerances meet design requirements
- [ ] Parts are in stock and reasonably priced
- [ ] BOM generation includes LCSC part numbers

## Technical Requirements:
- Use atopile part picker system with LCSC database
- Specify component tolerances and packages
- Validate part availability and pricing
- Generate machine-readable BOM format"
        labels = @("story", "hardware", "bom", "lcsc", "automation")
    },
    
    @{
        title = "Story 1.2.2: Proper Footprint Assignments"
        body = "**As a developer, I want proper footprint assignments so that components can be placed and soldered correctly**

## Acceptance Criteria:
- [ ] All components have correct KiCad footprints assigned
- [ ] Footprints match the actual component packages
- [ ] Pin mappings are correct for all components
- [ ] Footprint libraries are properly referenced
- [ ] Custom footprints are created for non-standard parts

## Technical Requirements:
- Use standard KiCad footprint libraries where possible
- Create custom footprints for specialized components
- Verify footprint dimensions against component datasheets
- Include appropriate solder mask and paste layers"
        labels = @("story", "hardware", "footprints", "kicad", "pcb-layout")
    },
    
    @{
        title = "Story 1.2.3: Validated BOM with Pricing"
        body = "**As a developer, I want a validated BOM with pricing so that I can estimate manufacturing costs**

## Acceptance Criteria:
- [ ] Complete BOM includes all components with quantities
- [ ] Pricing information is current and accurate
- [ ] Alternative parts are identified for critical components
- [ ] Total cost estimation includes PCB fabrication
- [ ] BOM format is suitable for procurement and assembly

## Technical Requirements:
- Generate BOM in multiple formats (CSV, Excel, PDF)
- Include manufacturer part numbers and descriptions
- Calculate total costs with quantity breaks
- Identify potential supply chain risks"
        labels = @("story", "hardware", "bom", "pricing", "manufacturing")
    },
    
    # Feature 1.3: PCB Layout & Manufacturing
    @{
        title = "Feature 1.3: PCB Layout & Manufacturing"
        body = "**As a developer, I want manufacturable PCB files so that I can produce physical hardware.**

This feature covers the complete PCB layout and preparation of manufacturing files."
        labels = @("feature", "hardware", "pcb-layout", "manufacturing")
    },
    
    @{
        title = "Story 1.3.1: KiCad PCB Layout Files"
        body = "**As a developer, I want KiCad PCB layout files so that I can visualize and modify the board design**

## Acceptance Criteria:
- [ ] Complete PCB layout with all components placed
- [ ] Routing is optimized for signal integrity and manufacturability
- [ ] Design rules are satisfied with no violations
- [ ] Layer stackup is appropriate for the design complexity
- [ ] Files are compatible with current KiCad version

## Technical Requirements:
- Use appropriate trace widths for different signal types
- Maintain proper spacing for manufacturing tolerances
- Include ground planes for noise reduction
- Optimize component placement for assembly"
        labels = @("story", "hardware", "kicad", "pcb-layout", "design")
    },
    
    @{
        title = "Story 1.3.2: Gerber Files for Manufacturing"
        body = "**As a developer, I want Gerber files for manufacturing so that I can send the design to a PCB fab house**

## Acceptance Criteria:
- [ ] Complete Gerber file set is generated
- [ ] Drill files include all hole sizes and positions
- [ ] Pick and place files are available for assembly
- [ ] Files pass DRC checks for chosen manufacturer
- [ ] Documentation includes fabrication notes

## Technical Requirements:
- Generate standard Gerber RS-274X format
- Include all necessary layers (copper, solder mask, silk screen)
- Verify files with Gerber viewer before submission
- Include assembly drawings and specifications"
        labels = @("story", "hardware", "gerber", "manufacturing", "fabrication")
    },
    
    @{
        title = "Story 1.3.3: Assembly Instructions"
        body = "**As a developer, I want assembly instructions so that I can populate the PCB with components**

## Acceptance Criteria:
- [ ] Step-by-step assembly procedure is documented
- [ ] Component placement diagrams are clear and accurate
- [ ] Soldering guidelines are provided for different component types
- [ ] Testing procedures verify proper assembly
- [ ] Troubleshooting guide addresses common issues

## Technical Requirements:
- Include high-resolution assembly drawings
- Specify soldering temperature and time requirements
- Document component orientation and polarity
- Provide quality control checkpoints"
        labels = @("story", "hardware", "assembly", "documentation", "manufacturing")
    },
    
    # Epic 2: Flight Control Software
    @{
        title = "Epic 2: Flight Control Software"
        body = "**As a drone operator, I want stable and responsive flight control so that the drone flies predictably.**

This epic encompasses all software development for flight control, including sensor processing, motor control, and stabilization algorithms."
        labels = @("epic", "software", "flight-control")
    },
    
    # Feature 2.1: Sensor Data Processing
    @{
        title = "Feature 2.1: Sensor Data Processing"
        body = "**As a flight controller, I want accurate sensor readings so that I can determine the drone's orientation and motion.**

This feature covers all sensor integration and data processing for the IMU and other sensors."
        labels = @("feature", "software", "sensors", "imu")
    },
    
    @{
        title = "Story 2.1.1: Accelerometer Data Reading"
        body = "**As a flight controller, I want to read accelerometer data so that I can detect tilt and acceleration**

## Acceptance Criteria:
- [ ] Accelerometer data is read at sufficient frequency (>100Hz)
- [ ] Raw acceleration values are converted to meaningful units (m/s²)
- [ ] Data is filtered to remove noise and vibration
- [ ] Gravity vector can be determined for tilt calculation
- [ ] Calibration routine compensates for sensor bias

## Technical Requirements:
- Use I2C or SPI interface for high-speed data transfer
- Implement appropriate digital filtering (low-pass, Kalman)
- Store calibration parameters in non-volatile memory
- Handle sensor errors and communication failures gracefully"
        labels = @("story", "software", "accelerometer", "sensors", "data-processing")
    },
    
    @{
        title = "Story 2.1.2: Gyroscope Data Reading"
        body = "**As a flight controller, I want to read gyroscope data so that I can measure rotational rates**

## Acceptance Criteria:
- [ ] Gyroscope data is read at high frequency (>500Hz)
- [ ] Angular velocity is provided in degrees/second or radians/second
- [ ] Gyro bias is calibrated and compensated
- [ ] Data is integrated to provide angular position estimates
- [ ] Sensor range is appropriate for drone maneuvers

## Technical Requirements:
- Configure gyroscope for optimal range and resolution
- Implement bias compensation and temperature correction
- Use complementary filter or Kalman filter for integration
- Detect and handle gyroscope saturation conditions"
        labels = @("story", "software", "gyroscope", "sensors", "data-processing")
    },
    
    @{
        title = "Story 2.1.3: Magnetometer Data Reading"
        body = "**As a flight controller, I want to read magnetometer data so that I can determine heading/yaw**

## Acceptance Criteria:
- [ ] Magnetometer provides compass heading relative to magnetic north
- [ ] Hard and soft iron calibration is performed
- [ ] Magnetic declination is accounted for true north
- [ ] Data is filtered to remove electrical interference
- [ ] Heading accuracy is within ±5 degrees

## Technical Requirements:
- Implement 3D magnetometer calibration algorithm
- Account for local magnetic declination
- Filter out magnetic interference from motors and electronics
- Provide fallback heading estimation using gyro integration"
        labels = @("story", "software", "magnetometer", "compass", "sensors")
    },
    
    @{
        title = "Story 2.1.4: Barometric Pressure Reading"
        body = "**As a flight controller, I want to read barometric pressure so that I can estimate altitude**

## Acceptance Criteria:
- [ ] Barometric pressure is converted to altitude estimate
- [ ] Sea level pressure is calibrated for accurate readings
- [ ] Altitude resolution is sufficient for flight control (<0.1m)
- [ ] Data is filtered to remove short-term fluctuations
- [ ] Temperature compensation is applied

## Technical Requirements:
- Use high-resolution barometric sensor (BMP280 in GY-91)
- Implement altitude calculation using standard atmosphere model
- Apply digital filtering for smooth altitude estimates
- Calibrate sea level pressure at startup or via user input"
        labels = @("story", "software", "barometer", "altitude", "sensors")
    },
    
    @{
        title = "Story 2.1.5: Sensor Fusion Algorithms"
        body = "**As a flight controller, I want sensor fusion algorithms so that I can combine all sensor data into accurate state estimates**

## Acceptance Criteria:
- [ ] Attitude estimation combines accelerometer and gyroscope data
- [ ] Heading estimation incorporates magnetometer when available
- [ ] Altitude estimate fuses barometric and accelerometer data
- [ ] Filter handles sensor noise and temporary outages
- [ ] State estimates are updated at control loop frequency

## Technical Requirements:
- Implement Extended Kalman Filter or complementary filter
- Handle different sensor update rates appropriately
- Provide confidence intervals for state estimates
- Tune filter parameters for optimal performance"
        labels = @("story", "software", "sensor-fusion", "kalman-filter", "algorithms")
    },
    
    # Feature 2.2: Motor Control System
    @{ title = "Feature 2.2: Motor Control System"; body = "**As a flight controller, I want precise motor control so that I can stabilize and maneuver the drone.**\n\nThis feature covers PWM generation, motor speed/direction control, and safety mechanisms."; labels = @("feature", "software", "motor-control", "pwm") }
    @{ title = "Story 2.2.1: Individual Motor Speed Control"; body = "**As a flight controller, I want individual motor speed control so that I can adjust thrust for each rotor**\n\n## Acceptance Criteria:\n- [ ] Each motor receives independent speed commands\n- [ ] PWM resolution sufficient for stable control (>= 8 bits)\n- [ ] Update rate supports control loop timing\n- [ ] Command interface abstracts motor indices\n- [ ] Verified response with test harness\n\n## Technical Requirements:\n- Implement PWM outputs mapped to motor enable pins\n- Calibrate duty cycle to thrust response\n- Protect against out-of-range commands\n- Provide function for batch motor updates"; labels = @("story", "software", "motor", "pwm", "control") }
    @{ title = "Story 2.2.2: Motor Direction Control"; body = "**As a flight controller, I want motor direction control so that I can spin motors clockwise and counter-clockwise**\n\n## Acceptance Criteria:\n- [ ] Each motor direction can be set independently\n- [ ] Direction changes handled safely (no shoot-through)\n- [ ] Logical mapping documented (CW/CCW)\n- [ ] Test sequence validates direction outputs\n- [ ] Safe default direction on startup\n\n## Technical Requirements:\n- Use DRV8833 dual H-bridge IN1/IN2 mapping\n- Avoid simultaneous high outputs causing contention\n- Add small delay or braking logic if needed\n- Provide abstraction for setMotorDirection(index, dir)"; labels = @("story", "software", "motor", "direction", "control") }
    @{ title = "Story 2.2.3: Emergency Motor Shutoff"; body = "**As a flight controller, I want emergency motor shutoff so that I can stop all motors in case of problems**\n\n## Acceptance Criteria:\n- [ ] Single function stops all motors immediately\n- [ ] Triggerable via software flag or external input\n- [ ] Prevents restart until explicitly cleared\n- [ ] Logged event for post-mortem\n- [ ] Tested under simulated fault conditions\n\n## Technical Requirements:\n- Force PWM to zero and disable enable pins\n- Debounce hardware emergency input if present\n- Ensure idempotent repeated calls\n- Provide emergency reason codes"; labels = @("story", "software", "safety", "emergency-stop", "motor") }
    @{ title = "Story 2.2.4: Motor Speed Limiting"; body = "**As a flight controller, I want motor speed limiting so that I don't damage motors or draw excessive current**\n\n## Acceptance Criteria:\n- [ ] Configurable max duty cycle limit\n- [ ] Software clamps commands above limit\n- [ ] Telemetry exposes limit value\n- [ ] Over-limit attempts logged\n- [ ] Unit tests verify clamping behavior\n\n## Technical Requirements:\n- Provide setGlobalMotorLimit(percent)\n- Store limit in persistent config\n- Apply limit before writing PWM registers\n- Optionally implement ramp rate limiting"; labels = @("story", "software", "safety", "motor", "limits") }
    
    # Feature 2.3: Flight Stabilization
    @{ title = "Feature 2.3: Flight Stabilization"; body = "**As a drone operator, I want automatic stabilization so that the drone maintains level flight.**\n\nThis feature covers PID control loops and stabilization logic."; labels = @("feature", "software", "stabilization", "control-loops") }
    @{ title = "Story 2.3.1: PID Control Loops"; body = "**As a flight controller, I want PID control loops so that I can automatically correct for tilt and rotation**\n\n## Acceptance Criteria:\n- [ ] Separate PID loops for roll, pitch, yaw\n- [ ] Tunable gains via config interface\n- [ ] Integral windup protection implemented\n- [ ] Loop runs at fixed control frequency\n- [ ] Unit tests for step response\n\n## Technical Requirements:\n- Implement PID with derivative filtering\n- Use fixed-point or float consistent with performance\n- Provide API to update gains at runtime\n- Log loop timing jitter"; labels = @("story", "software", "pid", "control", "stabilization") }
    @{ title = "Story 2.3.2: Attitude Hold Mode"; body = "**As a flight controller, I want attitude hold mode so that the drone maintains level flight without input**\n\n## Acceptance Criteria:\n- [ ] Mode engages via command\n- [ ] Drift < specified threshold over test interval\n- [ ] Manual input overrides properly\n- [ ] Mode exit restores manual control cleanly\n- [ ] Telemetry indicates active mode\n\n## Technical Requirements:\n- Combine PID outputs with input mixing\n- Use attitude estimate from sensor fusion\n- Freeze reference attitude on engage\n- Provide failsafe if estimate invalid"; labels = @("story", "software", "stabilization", "attitude", "mode") }
    @{ title = "Story 2.3.3: Rate Limiting"; body = "**As a flight controller, I want rate limiting so that the drone doesn't make sudden dangerous movements**\n\n## Acceptance Criteria:\n- [ ] Configurable angular rate limits\n- [ ] Commands exceeding limit are clamped\n- [ ] Telemetry shows when limiting occurs\n- [ ] Tests verify saturation behavior\n- [ ] Safe defaults applied on startup\n\n## Technical Requirements:\n- Apply limit pre-PID (command) and/or post-PID (output)\n- Provide configuration persistence\n- Avoid integrator windup due to clamping\n- Log events when sustained limiting happens"; labels = @("story", "software", "safety", "rates", "stabilization") }
    @{ title = "Story 2.3.4: Fail-safe Behavior"; body = "**As a flight controller, I want fail-safe behavior so that the drone lands safely if control is lost**\n\n## Acceptance Criteria:\n- [ ] Detect loss of control signal within timeout\n- [ ] Initiate controlled descent sequence\n- [ ] Disarm motors after landing or timeout\n- [ ] Telemetry records fail-safe event\n- [ ] Tested with simulated signal loss\n\n## Technical Requirements:\n- Monitor command input freshness\n- Provide state machine for fail-safe states\n- Ensure safe throttle ramp down\n- Prevent arming until cause resolved"; labels = @("story", "software", "failsafe", "safety", "stabilization") }
    
    # Feature 3.1: WiFi Communication
    @{ title = "Feature 3.1: WiFi Communication"; body = "**As an operator, I want WiFi connectivity so that I can control the drone from my phone or computer.**\n\nThis feature covers both AP mode and client mode connectivity plus telemetry transport."; labels = @("feature", "software", "wifi", "communication") }
    @{ title = "Story 3.1.1: WiFi Access Point Mode"; body = "**As an operator, I want the drone to create a WiFi access point so that I can connect directly to it**\n\n## Acceptance Criteria:\n- [ ] AP mode SSID configurable\n- [ ] WPA2 security optional\n- [ ] Connection status telemetry\n- [ ] Stable connection under range test\n- [ ] Documented credentials handling\n\n## Technical Requirements:\n- Use Pico W WiFi APIs\n- Provide config storage for SSID/pass\n- Expose command to toggle AP mode\n- Handle simultaneous client attempts"; labels = @("story", "software", "wifi", "ap-mode") }
    @{ title = "Story 3.1.2: WiFi Client Mode"; body = "**As an operator, I want the drone to connect to my existing WiFi so that I can control it over my network**\n\n## Acceptance Criteria:\n- [ ] Auto-reconnect on drop\n- [ ] Configurable credentials persisted\n- [ ] Status shown via telemetry\n- [ ] Timeout if network unavailable\n- [ ] IPv4 address reported\n\n## Technical Requirements:\n- Network config CLI / web settings\n- Backoff retry strategy\n- Distinct state machine from AP mode\n- Event callbacks for connect/disconnect"; labels = @("story", "software", "wifi", "client-mode") }
    @{ title = "Story 3.1.3: Real-time Telemetry"; body = "**As an operator, I want real-time telemetry data so that I can monitor flight status and sensor readings**\n\n## Acceptance Criteria:\n- [ ] Telemetry stream at defined rate\n- [ ] Includes attitude, altitude, battery, motors\n- [ ] Packet loss metrics available\n- [ ] Bandwidth within constraints\n- [ ] Consumer API documented\n\n## Technical Requirements:\n- Use lightweight binary or JSON frames\n- Sequence numbers + timestamp\n- Optional compression if payload large\n- Graceful degradation on congestion"; labels = @("story", "software", "telemetry", "wifi") }
    @{ title = "Story 3.1.4: Command Acknowledgment"; body = "**As an operator, I want command acknowledgment so that I know my control inputs were received**\n\n## Acceptance Criteria:\n- [ ] ACK includes command id & status\n- [ ] Timeout triggers resend option\n- [ ] Telemetry logs missed ACK stats\n- [ ] Duplicate commands suppressed\n- [ ] Tested under packet loss simulation\n\n## Technical Requirements:\n- Lightweight ACK protocol layer\n- Unique incremental command IDs\n- Retransmit strategy with cap\n- Handle out-of-order packets"; labels = @("story", "software", "protocol", "ack", "reliability") }
    
    # Feature 3.2: Control Interface
    @{ title = "Feature 3.2: Control Interface"; body = "**As an operator, I want intuitive controls so that I can pilot the drone effectively.**\n\nThis feature includes mapping operator inputs to flight control outputs."; labels = @("feature", "software", "controls", "interface") }
    @{ title = "Story 3.2.1: Throttle Control"; body = "**As an operator, I want throttle control so that I can make the drone climb and descend**\n\n## Acceptance Criteria:\n- [ ] Smooth throttle response curve\n- [ ] Configurable deadband\n- [ ] Min/Max bounds enforced\n- [ ] Telemetry exposes commanded throttle\n- [ ] Tested for linearity\n\n## Technical Requirements:\n- Map input range to motor mix baseline\n- Apply smoothing filter for jitter\n- Provide calibration routine\n- Safe default at initialization"; labels = @("story", "software", "controls", "throttle") }
    @{ title = "Story 3.2.2: Pitch/Roll Control"; body = "**As an operator, I want pitch/roll control so that I can make the drone move forward/backward and left/right**\n\n## Acceptance Criteria:\n- [ ] Input scaling configurable\n- [ ] Center deadband implemented\n- [ ] Mix integrates with stabilization\n- [ ] Saturation handled gracefully\n- [ ] Telemetry shows pitch/roll commands\n\n## Technical Requirements:\n- Convert inputs to angular rate/angle targets\n- Combine with PID outputs\n- Provide expo/curve options\n- Validate sign conventions"; labels = @("story", "software", "controls", "pitch", "roll") }
    @{ title = "Story 3.2.3: Yaw Control"; body = "**As an operator, I want yaw control so that I can rotate the drone left and right**\n\n## Acceptance Criteria:\n- [ ] Smooth yaw response\n- [ ] Configurable sensitivity\n- [ ] Interaction with stabilization validated\n- [ ] Telemetry of yaw rate command\n- [ ] Tested for overshoot control\n\n## Technical Requirements:\n- Map input to yaw rate setpoint\n- Integrate with yaw PID\n- Apply rate limiting\n- Provide adjustable expo curve"; labels = @("story", "software", "controls", "yaw") }
    @{ title = "Story 3.2.4: Emergency Stop Functionality"; body = "**As an operator, I want emergency stop functionality so that I can immediately shut down the drone**\n\n## Acceptance Criteria:\n- [ ] Single input triggers motor kill\n- [ ] Confirmation or debounce logic\n- [ ] Telemetry flags emergency state\n- [ ] Requires explicit reset to arm\n- [ ] Tested under varying load\n\n## Technical Requirements:\n- Integrate with emergency motor shutoff\n- Dedicated command or GPIO\n- Ensure no race with normal control\n- Event logged with timestamp"; labels = @("story", "software", "safety", "emergency-stop") }
    @{ title = "Story 3.2.5: Flight Mode Selection"; body = "**As an operator, I want flight mode selection so that I can switch between manual, stabilized, and autonomous modes**\n\n## Acceptance Criteria:\n- [ ] Enumerated modes documented\n- [ ] Switching logic safe during flight\n- [ ] Telemetry indicates current mode\n- [ ] Invalid transitions rejected\n- [ ] Unit tests for mode FSM\n\n## Technical Requirements:\n- Implement mode state machine\n- Provide command/API to change mode\n- Validate dependencies before transition\n- Persist last mode if desired"; labels = @("story", "software", "modes", "controls") }
    
    # Feature 3.3: Web Interface
    @{ title = "Feature 3.3: Web Interface"; body = "**As an operator, I want a web-based control interface so that I can pilot the drone from any device.**\n\nThis feature includes UI, telemetry visualization, and control inputs via browser."; labels = @("feature", "software", "web", "ui") }
    @{ title = "Story 3.3.1: Responsive Web Interface"; body = "**As an operator, I want a responsive web interface so that I can control the drone from mobile devices**\n\n## Acceptance Criteria:\n- [ ] Layout adapts to phone/tablet/desktop\n- [ ] Control inputs low-latency\n- [ ] Minimal bundle size\n- [ ] Works offline after first load (optional)\n- [ ] Cross-browser tested\n\n## Technical Requirements:\n- Implement lightweight frontend\n- Use WebSocket or similar for live data\n- Optimize for low CPU usage on Pico\n- Provide build pipeline"; labels = @("story", "software", "web", "responsive") }
    @{ title = "Story 3.3.2: Real-time Flight Data Display"; body = "**As an operator, I want real-time flight data display so that I can monitor altitude, orientation, and battery level**\n\n## Acceptance Criteria:\n- [ ] Update rate meets telemetry spec\n- [ ] Displays key metrics clearly\n- [ ] Handles data gaps gracefully\n- [ ] Color/alerts for warning conditions\n- [ ] Performance profiling completed\n\n## Technical Requirements:\n- Data normalization layer\n- Efficient DOM update strategy\n- Historical buffer optional\n- Alert threshold config"; labels = @("story", "software", "telemetry", "ui") }
    @{ title = "Story 3.3.3: Virtual Joystick Controls"; body = "**As an operator, I want virtual joystick controls so that I can pilot the drone with touch controls**\n\n## Acceptance Criteria:\n- [ ] Touch inputs mapped to control axes\n- [ ] Multi-touch support\n- [ ] Visual feedback of stick position\n- [ ] Deadzone configurable\n- [ ] Latency within acceptable range\n\n## Technical Requirements:\n- Implement canvas or SVG control layer\n- Normalize device pixel ratio\n- Provide calibration & sensitivity settings\n- Integrate with command protocol"; labels = @("story", "software", "controls", "web", "joystick") }
    @{ title = "Story 3.3.4: Configuration Settings"; body = "**As an operator, I want configuration settings so that I can adjust PID parameters and flight modes**\n\n## Acceptance Criteria:\n- [ ] UI to view & edit config values\n- [ ] Validation of parameter ranges\n- [ ] Persistent storage applied\n- [ ] Change audit or log entry\n- [ ] Revert-to-defaults option\n\n## Technical Requirements:\n- Define config schema\n- Provide REST/WebSocket endpoints\n- Implement transactional updates\n- Protect critical parameters during flight"; labels = @("story", "software", "configuration", "web", "ui") }
    
    # Feature 4.1: Automated Building
    @{ title = "Feature 4.1: Automated Building"; body = "**As a developer, I want automated PCB building so that I can validate designs continuously.**\n\nThis feature covers CI workflows for hardware builds and BOM output."; labels = @("feature", "devops", "ci", "build") }
    @{ title = "Story 4.1.1: Automated Atopile Builds"; body = "**As a developer, I want automated atopile builds so that PCB changes are validated on every commit**\n\n## Acceptance Criteria:\n- [ ] CI workflow triggers on push/PR\n- [ ] Build logs attached to run\n- [ ] Failure blocks merge\n- [ ] Supports multiple build targets\n- [ ] Documentation of workflow steps\n\n## Technical Requirements:\n- GitHub Actions YAML build job\n- Cache dependencies where possible\n- Artifact uploads of outputs\n- Status badge in README"; labels = @("story", "devops", "ci", "build") }
    @{ title = "Story 4.1.2: BOM Validation"; body = "**As a developer, I want BOM validation so that I know if components can be sourced**\n\n## Acceptance Criteria:\n- [ ] CI flags missing part numbers\n- [ ] Out-of-stock parts reported\n- [ ] Summary comment on PR\n- [ ] Historical BOM snapshot stored\n- [ ] Threshold for acceptable stock configured\n\n## Technical Requirements:\n- Script queries part API (future)\n- Parse atopile BOM output\n- Generate markdown summary\n- Exit non-zero on critical issues"; labels = @("story", "devops", "bom", "validation") }
    @{ title = "Story 4.1.3: Build Artifacts"; body = "**As a developer, I want build artifacts so that I can download generated files**\n\n## Acceptance Criteria:\n- [ ] Gerbers packaged\n- [ ] BOM exported\n- [ ] Layout files archived\n- [ ] Retention policy defined\n- [ ] Accessible via CI interface\n\n## Technical Requirements:\n- Use actions/upload-artifact\n- Consistent artifact naming\n- Compress outputs to save space\n- Document retrieval steps"; labels = @("story", "devops", "artifacts", "build") }
    @{ title = "Story 4.1.4: Build Notifications"; body = "**As a developer, I want build notifications so that I know when builds pass or fail**\n\n## Acceptance Criteria:\n- [ ] Notifications on success/failure\n- [ ] Channel (email/Slack/etc.) configurable\n- [ ] Includes summary of changes\n- [ ] Links to artifacts provided\n- [ ] Quiet hours or rate limiting supported\n\n## Technical Requirements:\n- Integrate with chosen notification action\n- Provide templated message\n- Include commit metadata\n- Handle secret management securely"; labels = @("story", "devops", "notifications", "ci") }
    @{ title = "Feature 4.2: Version Management"; body = "**As a developer, I want automated versioning so that releases are tracked properly.**\n\nThis feature covers semantic versioning and release tagging."; labels = @("feature", "devops", "versioning") }
    @{ title = "Story 4.2.1: Semantic Versioning"; body = "**As a developer, I want semantic versioning so that release significance is clear**\n\n## Acceptance Criteria:\n- [ ] Version file updated appropriately\n- [ ] Major/minor/patch rules documented\n- [ ] CI validates version increment on release\n- [ ] Tags match VERSION file\n- [ ] Changelog references version\n\n## Technical Requirements:\n- Provide version bump script\n- Enforce conventional commit parsing (future)\n- Generate changelog template\n- Validate tag before publish"; labels = @("story", "devops", "versioning", "semver") }
    @{ title = "Story 4.2.2: Automated Tagging"; body = "**As a developer, I want automated tagging so that versions are created consistently**\n\n## Acceptance Criteria:\n- [ ] Tag created on release branch merge\n- [ ] Tag conforms to vMAJOR.MINOR.PATCH\n- [ ] Annotated tag includes summary\n- [ ] Failure surfaces clearly in CI\n- [ ] Duplicate tag prevention\n\n## Technical Requirements:\n- GitHub Action for tagging\n- Use git describe for validation\n- Fail if tag already exists\n- Sign tags optionally"; labels = @("story", "devops", "tagging", "versioning") }
    @{ title = "Story 4.2.3: Release Notes"; body = "**As a developer, I want release notes so that changes are documented**\n\n## Acceptance Criteria:\n- [ ] Notes generated or curated per release\n- [ ] Includes highlights & breaking changes\n- [ ] Linked to issues/PRs\n- [ ] Stored in CHANGELOG.md\n- [ ] Accessible from GitHub Releases page\n\n## Technical Requirements:\n- Template for release notes\n- Script to aggregate commits/issues\n- Provide manual edit stage\n- Publish with release tag"; labels = @("story", "devops", "documentation", "releases") }
    @{ title = "Feature 4.3: Code Quality"; body = "**As a developer, I want code quality checks so that the codebase remains maintainable.**\n\nThis feature covers linting, validation, and documentation quality."; labels = @("feature", "devops", "quality") }
    @{ title = "Story 4.3.1: Syntax Validation"; body = "**As a developer, I want syntax validation so that atopile files are correct**\n\n## Acceptance Criteria:\n- [ ] CI fails on invalid syntax\n- [ ] Pre-commit hook optional\n- [ ] Error messages surfaced clearly\n- [ ] Coverage of all .ato files\n- [ ] Report generated for failures\n\n## Technical Requirements:\n- Use atopile CLI for validation\n- Script to discover files\n- Integrate into build workflow\n- Provide local run instructions"; labels = @("story", "devops", "quality", "syntax") }
    @{ title = "Story 4.3.2: Component Validation"; body = "**As a developer, I want component validation so that all parts have proper connections**\n\n## Acceptance Criteria:\n- [ ] Automated check for unconnected pins\n- [ ] Warnings vs errors categorized\n- [ ] Report lists offending components\n- [ ] Integration with PR feedback\n- [ ] Tests for validation script\n\n## Technical Requirements:\n- Parse netlist output\n- Identify orphan or floating nets\n- Provide JSON & markdown outputs\n- Exit codes reflect severity"; labels = @("story", "devops", "quality", "validation") }
    @{ title = "Story 4.3.3: Documentation Checks"; body = "**As a developer, I want documentation checks so that all components are properly documented**\n\n## Acceptance Criteria:\n- [ ] Verify presence of key docs (README, PART_PICKING_GUIDE)\n- [ ] Ensure component files have headers\n- [ ] Spellcheck major docs (optional)\n- [ ] CI summary of missing docs\n- [ ] Threshold for pass/fail defined\n\n## Technical Requirements:\n- Script scans docs directory\n- Provide allowlist/ignore patterns\n- Output structured report\n- Integrate with status checks"; labels = @("story", "devops", "documentation", "quality") }
    
    # Feature 5.1: Hardware Testing
    @{ title = "Feature 5.1: Hardware Testing"; body = "**As a developer, I want hardware validation so that the PCB design works correctly.**\n\nThis feature includes electrical and functional hardware tests."; labels = @("feature", "testing", "hardware") }
    @{ title = "Story 5.1.1: Continuity Testing"; body = "**As a developer, I want continuity testing so that all connections are properly made**\n\n## Acceptance Criteria:\n- [ ] Net continuity list generated\n- [ ] Automated probing script (future)\n- [ ] Documented manual test procedure\n- [ ] Log of tested nets\n- [ ] Issues created for failures\n\n## Technical Requirements:\n- Use schematic/netlist export\n- Provide checklist template\n- Optional integration with test jig\n- Store results in /test/artifacts"; labels = @("story", "testing", "hardware", "continuity") }
    @{ title = "Story 5.1.2: Power Supply Testing"; body = "**As a developer, I want power supply testing so that all components receive correct voltages**\n\n## Acceptance Criteria:\n- [ ] Voltage rails measured within tolerance\n- [ ] Load test at max current\n- [ ] Ripple/noise characterized\n- [ ] Thermal check under load\n- [ ] Report documented\n\n## Technical Requirements:\n- Provide measurement points list\n- Use electronic load or resistive loads\n- Document instrumentation used\n- Capture waveform screenshots"; labels = @("story", "testing", "hardware", "power") }
    @{ title = "Story 5.1.3: Motor Driver Testing"; body = "**As a developer, I want motor driver testing so that motors can be controlled independently**\n\n## Acceptance Criteria:\n- [ ] Each motor spins independently\n- [ ] Direction control verified\n- [ ] Current draw within spec\n- [ ] Thermal performance acceptable\n- [ ] Shutdown behavior tested\n\n## Technical Requirements:\n- Provide motor test script\n- Measure current with inline sensor\n- Log RPM vs duty cycle\n- Capture thermal images (optional)"; labels = @("story", "testing", "hardware", "motors") }
    @{ title = "Story 5.1.4: Sensor Testing"; body = "**As a developer, I want sensor testing so that IMU readings are accurate**\n\n## Acceptance Criteria:\n- [ ] Accelerometer axes verified\n- [ ] Gyro stability checked\n- [ ] Magnetometer calibration validated\n- [ ] Barometer altitude drift measured\n- [ ] Test results documented\n\n## Technical Requirements:\n- Provide calibration scripts\n- Procedure for stationary vs dynamic tests\n- Data logging format defined\n- Statistical summary of noise"; labels = @("story", "testing", "hardware", "sensors") }
    @{ title = "Feature 5.2: Software Testing"; body = "**As a developer, I want software validation so that flight control algorithms work correctly.**\n\nThis feature covers unit, integration, and simulation tests."; labels = @("feature", "testing", "software") }
    @{ title = "Story 5.2.1: Unit Tests for Sensor Drivers"; body = "**As a developer, I want unit tests for sensor drivers so that readings are accurate**\n\n## Acceptance Criteria:\n- [ ] Mock interfaces for sensors\n- [ ] Tests cover edge cases & errors\n- [ ] Calibration functions tested\n- [ ] Continuous integration run\n- [ ] Coverage targets defined\n\n## Technical Requirements:\n- Testing framework selected\n- Provide hardware abstraction layer\n- Use fixture data sets\n- Generate coverage report"; labels = @("story", "testing", "software", "sensors") }
    @{ title = "Story 5.2.2: Unit Tests for Motor Control"; body = "**As a developer, I want unit tests for motor control so that commands are executed correctly**\n\n## Acceptance Criteria:\n- [ ] PWM generation logic tested\n- [ ] Safety checks covered\n- [ ] Direction mapping verified\n- [ ] Limit handling validated\n- [ ] Regression tests added\n\n## Technical Requirements:\n- Mock motor driver layer\n- Provide deterministic timing harness\n- Simulate fault conditions\n- Report coverage metrics"; labels = @("story", "testing", "software", "motors") }
    @{ title = "Story 5.2.3: Integration Tests for Flight Control"; body = "**As a developer, I want integration tests for flight control so that stabilization works**\n\n## Acceptance Criteria:\n- [ ] Full control loop test harness\n- [ ] Simulated sensor input sequences\n- [ ] Output matches expected corrections\n- [ ] Latency within target budget\n- [ ] Logs stored for analysis\n\n## Technical Requirements:\n- Simulation environment design\n- Deterministic timing scheduler\n- Compare outputs vs golden data\n- Provide failure diagnostics"; labels = @("story", "testing", "software", "integration") }
    @{ title = "Story 5.2.4: Simulation Testing"; body = "**As a developer, I want simulation testing so that I can validate control algorithms safely**\n\n## Acceptance Criteria:\n- [ ] Physics model approximates dynamics\n- [ ] Supports scripted flight scenarios\n- [ ] Performance metrics collected\n- [ ] Helps tuning PID parameters\n- [ ] Document simulation limitations\n\n## Technical Requirements:\n- Select simulation framework\n- Implement simplified dynamics model\n- Data export for analysis\n- Scenario scripting interface"; labels = @("story", "testing", "software", "simulation") }
    @{ title = "Feature 5.3: Safety Testing"; body = "**As a developer, I want safety validation so that the drone operates without causing harm.**\n\nThis feature addresses testing of safety-critical behaviors."; labels = @("feature", "testing", "safety") }
    @{ title = "Story 5.3.1: Fail-safe Testing"; body = "**As a developer, I want fail-safe testing so that the drone lands safely when problems occur**\n\n## Acceptance Criteria:\n- [ ] Simulated signal loss scenarios\n- [ ] Controlled descent verified\n- [ ] Data logging of fail-safe events\n- [ ] Recovery conditions validated\n- [ ] Test script documented\n\n## Technical Requirements:\n- Inject faults in control input stream\n- Monitor state machine transitions\n- Time descent profile\n- Store test artifacts"; labels = @("story", "testing", "safety", "failsafe") }
    @{ title = "Story 5.3.2: Emergency Stop Testing"; body = "**As a developer, I want emergency stop testing so that the drone can be immediately shut down**\n\n## Acceptance Criteria:\n- [ ] Test hardware/software trigger\n- [ ] Response time measured\n- [ ] Motors fully stop as expected\n- [ ] Recovery procedure validated\n- [ ] Repeatability confirmed\n\n## Technical Requirements:\n- Instrument timing measurement\n- Simulate multiple activations\n- Capture system state pre/post\n- Provide safety notes"; labels = @("story", "testing", "safety", "emergency-stop") }
    @{ title = "Story 5.3.3: Range Testing"; body = "**As a developer, I want range testing so that the drone doesn't fly beyond communication range**\n\n## Acceptance Criteria:\n- [ ] Measure control link RSSI vs distance\n- [ ] Document maximum reliable range\n- [ ] Fail-safe triggers near limit\n- [ ] Environmental factors noted\n- [ ] Report archived\n\n## Technical Requirements:\n- Log signal strength metrics\n- Use waypoint or path test\n- Provide safe test environment plan\n- Analyze packet loss versus distance"; labels = @("story", "testing", "wireless", "range") }
    @{ title = "Story 5.3.4: Battery Monitoring"; body = "**As a developer, I want battery monitoring so that the drone lands before power is exhausted**\n\n## Acceptance Criteria:\n- [ ] Low-voltage warning threshold\n- [ ] Critical voltage triggers landing\n- [ ] Voltage measurement calibrated\n- [ ] Telemetry includes battery stats\n- [ ] Test discharge profile recorded\n\n## Technical Requirements:\n- ADC sampling circuit specs\n- Calibration offset storage\n- Smoothing/averaging filter\n- Configurable thresholds"; labels = @("story", "testing", "battery", "safety") }
    
    # Feature 6.1: Build Instructions
    @{ title = "Feature 6.1: Build Instructions"; body = "**As a builder, I want step-by-step instructions so that I can construct the drone correctly.**\n\nThis feature covers hardware assembly documentation."; labels = @("feature", "documentation", "build") }
    @{ title = "Story 6.1.1: PCB Assembly Instructions"; body = "**As a builder, I want PCB assembly instructions so that I can populate the board correctly**\n\n## Acceptance Criteria:\n- [ ] Ordered assembly steps\n- [ ] Visual placement diagrams\n- [ ] Soldering guidelines included\n- [ ] Post-assembly checklist\n- [ ] Document versioned\n\n## Technical Requirements:\n- Export annotated placement images\n- Provide PDF + markdown versions\n- Include ESD handling notes\n- Link to troubleshooting section"; labels = @("story", "documentation", "assembly") }
    @{ title = "Story 6.1.2: Component Sourcing Guide"; body = "**As a builder, I want component sourcing guide so that I can obtain all necessary parts**\n\n## Acceptance Criteria:\n- [ ] Supplier links for each part\n- [ ] Alternative components listed\n- [ ] Price tiers for quantities\n- [ ] Lead time considerations\n- [ ] Guide kept updated\n\n## Technical Requirements:\n- Pull data from BOM if possible\n- Provide CSV export\n- Highlight critical/long lead items\n- Include anti-counterfeit tips"; labels = @("story", "documentation", "sourcing") }
    @{ title = "Story 6.1.3: Mechanical Assembly Instructions"; body = "**As a builder, I want mechanical assembly instructions so that I can attach motors and frame**\n\n## Acceptance Criteria:\n- [ ] Motor/frame assembly steps\n- [ ] Fastener list & torque guidance\n- [ ] Orientation diagrams\n- [ ] Cable routing guidance\n- [ ] Safety precautions\n\n## Technical Requirements:\n- Provide exploded view diagrams\n- Include recommended tools list\n- Document vibration mitigation\n- Include maintenance notes"; labels = @("story", "documentation", "mechanical", "assembly") }
    @{ title = "Story 6.1.4: Troubleshooting Guide"; body = "**As a builder, I want troubleshooting guide so that I can diagnose and fix problems**\n\n## Acceptance Criteria:\n- [ ] Common issues table\n- [ ] Diagnostic flowcharts\n- [ ] LED/status indicator meaning\n- [ ] Recovery procedures\n- [ ] Escalation path\n\n## Technical Requirements:\n- Structured by subsystem\n- Provide error code references\n- Include data collection steps\n- Link to issue tracker"; labels = @("story", "documentation", "troubleshooting") }
    @{ title = "Feature 6.2: Software Setup"; body = "**As a user, I want software installation instructions so that I can program and configure the drone.**\n\nThis feature covers firmware flashing and configuration."; labels = @("feature", "documentation", "software-setup") }
    @{ title = "Story 6.2.1: Firmware Installation Instructions"; body = "**As a user, I want firmware installation instructions so that I can program the Pico 2W**\n\n## Acceptance Criteria:\n- [ ] Flashing steps for UF2/bootloader\n- [ ] Required toolchain listed\n- [ ] Verification procedure\n- [ ] Troubleshooting flashing failures\n- [ ] Security considerations\n\n## Technical Requirements:\n- Provide CLI commands\n- Include screenshot examples\n- Support Windows/macOS/Linux\n- Document firmware versioning"; labels = @("story", "documentation", "firmware", "setup") }
    @{ title = "Story 6.2.2: WiFi Configuration Instructions"; body = "**As a user, I want WiFi configuration instructions so that I can connect to the drone**\n\n## Acceptance Criteria:\n- [ ] AP vs Client documented\n- [ ] Config editing steps\n- [ ] Credential storage explanation\n- [ ] Verification test\n- [ ] Troubleshooting connectivity\n\n## Technical Requirements:\n- Provide config file format\n- Include sample configs\n- Security best practices\n- Recovery instructions"; labels = @("story", "documentation", "wifi", "setup") }
    @{ title = "Story 6.2.3: Calibration Procedures"; body = "**As a user, I want calibration procedures so that sensors provide accurate readings**\n\n## Acceptance Criteria:\n- [ ] Step-by-step instructions per sensor\n- [ ] Visual orientation guidance\n- [ ] Data validation steps\n- [ ] Storage of calibration data\n- [ ] Recalibration triggers documented\n\n## Technical Requirements:\n- Provide calibration scripts\n- Define data format\n- Error handling guidance\n- Environmental considerations"; labels = @("story", "documentation", "calibration", "sensors") }
    @{ title = "Story 6.2.4: Tuning Guide"; body = "**As a user, I want tuning guide so that I can optimize flight performance**\n\n## Acceptance Criteria:\n- [ ] PID tuning steps\n- [ ] Symptom vs adjustment table\n- [ ] Logging guidance for analysis\n- [ ] Safe test environment tips\n- [ ] Example tuned profiles\n\n## Technical Requirements:\n- Provide initial gain presets\n- Describe oscillation indicators\n- Tools for log visualization\n- Include caution notes"; labels = @("story", "documentation", "tuning", "performance") }
    @{ title = "Feature 6.3: Operation Manual"; body = "**As an operator, I want operating instructions so that I can fly the drone safely and effectively.**\n\nThis feature covers operational procedures and safety guidelines."; labels = @("feature", "documentation", "operation") }
    @{ title = "Story 6.3.1: Pre-flight Checklist"; body = "**As an operator, I want pre-flight checklist so that I can ensure the drone is ready to fly**\n\n## Acceptance Criteria:\n- [ ] Checklist items grouped logically\n- [ ] Covers hardware, software, environment\n- [ ] Printable and mobile-friendly\n- [ ] Version controlled\n- [ ] Includes safety confirmations\n\n## Technical Requirements:\n- Provide markdown + PDF\n- Include placeholders for signatures\n- Link to troubleshooting for failures\n- Allow customization"; labels = @("story", "documentation", "checklist", "safety") }
    @{ title = "Story 6.3.2: Flight Control Instructions"; body = "**As an operator, I want flight control instructions so that I can pilot the drone effectively**\n\n## Acceptance Criteria:\n- [ ] Explanation of all control axes\n- [ ] Basic maneuvers described\n- [ ] Mode-specific behavior differences\n- [ ] Recovery techniques\n- [ ] Visual diagrams included\n\n## Technical Requirements:\n- Provide diagrams or GIFs (future)\n- Clarify safety boundaries\n- Include glossary of terms\n- Link to tuning section"; labels = @("story", "documentation", "controls", "operation") }
    @{ title = "Story 6.3.3: Safety Guidelines"; body = "**As an operator, I want safety guidelines so that I can operate the drone responsibly**\n\n## Acceptance Criteria:\n- [ ] Regulatory considerations\n- [ ] Environmental hazard warnings\n- [ ] Battery handling guidelines\n- [ ] Emergency procedures overview\n- [ ] Legal compliance references\n\n## Technical Requirements:\n- Provide region-agnostic advice\n- Highlight mandatory compliance checks\n- Include disclaimers\n- Encourage community best practices"; labels = @("story", "documentation", "safety", "guidelines") }
    @{ title = "Story 6.3.4: Maintenance Procedures"; body = "**As an operator, I want maintenance procedures so that I can keep the drone in good condition**\n\n## Acceptance Criteria:\n- [ ] Scheduled maintenance intervals\n- [ ] Component inspection checklist\n- [ ] Cleaning and storage practices\n- [ ] Replacement part guidance\n- [ ] Logging of maintenance actions\n\n## Technical Requirements:\n- Provide maintenance log template\n- Recommend consumables/tools\n- Document wear indicators\n- Include end-of-life disposal notes"; labels = @("story", "documentation", "maintenance", "operation") }
    
    # Epic 3: Wireless Communication & Control
    @{
        title = "Epic 3: Wireless Communication & Control"
        body = "**As a drone operator, I want wireless control capabilities so that I can pilot the drone remotely.**

This epic covers all wireless communication, remote control interfaces, and telemetry systems."
        labels = @("epic", "software", "wireless", "communication")
    },
    
    # Epic 4: Development Tools & CI/CD
    @{
        title = "Epic 4: Development Tools & CI/CD"
        body = "**As a developer, I want automated build and test systems so that I can develop efficiently and reliably.**

This epic encompasses all development infrastructure including automated builds, testing, and deployment."
        labels = @("epic", "devops", "ci-cd", "automation")
    },
    
    # Epic 5: Testing & Validation
    @{
        title = "Epic 5: Testing & Validation"
        body = "**As a developer, I want comprehensive testing so that the drone operates safely and reliably.**

This epic covers all testing activities including hardware validation, software testing, and safety verification."
        labels = @("epic", "testing", "validation", "safety")
    },
    
    # Epic 6: Documentation & User Guide
    @{
        title = "Epic 6: Documentation & User Guide"
        body = "**As a user, I want comprehensive documentation so that I can build, configure, and operate the drone.**

This epic covers all documentation including build instructions, user guides, and technical reference materials."
        labels = @("epic", "documentation", "user-guide", "instructions")
    }
)

# Now that $issues is defined, synchronize labels (create any missing) with reduced noise
Write-Host "Synchronizing labels..." -ForegroundColor Green
$allNeededLabels = ($issues | ForEach-Object { $_.labels }) | Sort-Object -Unique
$existingLabelsJson = gh label list --repo "$Owner/$Repo" --json name 2>$null
if ($LASTEXITCODE -eq 0 -and $existingLabelsJson) {
    $existingLabelNames = ($existingLabelsJson | ConvertFrom-Json).name
} else { $existingLabelNames = @() }
$defaultColor = "0e8a16"  # greenish
$createdLabelBatch = @()
foreach ($lbl in $allNeededLabels) {
    if (-not ($existingLabelNames -contains $lbl)) {
        gh label create $lbl --color $defaultColor --repo "$Owner/$Repo" 2>$null
        if ($LASTEXITCODE -eq 0) { $createdLabelBatch += $lbl } else { Write-Verbose "Label create failed (likely exists): $lbl" }
    }
}
if ($createdLabelBatch.Count -gt 0) { Write-Host ("Created {0} new labels" -f $createdLabelBatch.Count) -ForegroundColor Green } else { Write-Host "No new labels needed." -ForegroundColor DarkGray }

# Create issues
Write-Host "Creating GitHub issues (idempotent)..." -ForegroundColor Green
$createdCount = 0
$skippedCount = 0
$createdTitles = @()
$skippedTitles = @()
$startTime = Get-Date

# Fast resume optimization: build index of remaining titles not yet created
$existingSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($t in $existingIssueTitles) { $null = $existingSet.Add($t) }

function Write-IncrementalSummary {
    param(
        [int]$CreatedSoFar,
        [int]$SkippedSoFar,
        [datetime]$StartTime,
        [string[]]$CreatedList,
        [string[]]$SkippedList,
        [bool]$Complete = $false
    )
    if (-not $SummaryPath) { return }
    $el = (Get-Date) - $StartTime
    $obj = [pscustomobject]@{
        repository    = "$Owner/$Repo";
        createdCount  = $CreatedSoFar;
        skippedCount  = $SkippedSoFar;
        totalDefined  = $issues.Count;
        elapsedSeconds= [math]::Round($el.TotalSeconds,1);
        createdTitles = $CreatedList;
        skippedTitles = $SkippedList;
        complete      = $Complete;
        timestamp     = (Get-Date).ToString('o')
    }
    try { $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $SummaryPath -Encoding UTF8 } catch { }
}

foreach ($issue in $issues) {
    if ($existingSet.Contains($issue.title)) {
        # Skip without gh call for speed
        Write-Host "Skipping (exists/cache): $($issue.title)" -ForegroundColor DarkYellow
        $skippedCount++
        $skippedTitles += $issue.title
        if ($Incremental -and $SummaryPath) { Write-IncrementalSummary -CreatedSoFar $createdCount -SkippedSoFar $skippedCount -StartTime $startTime -CreatedList $createdTitles -SkippedList $skippedTitles }
        if ($MaxCreate -gt 0 -and $createdCount -ge $MaxCreate) { break }
        continue
    }
    try {
        $labelArgs = $issue.labels | ForEach-Object { "--label", $_ }
        if ($existingIssueTitles -contains $issue.title) {
            Write-Host "Skipping (exists): $($issue.title)" -ForegroundColor Yellow
            $skippedCount++
            $skippedTitles += $issue.title
            if ($Incremental -and $SummaryPath) { Write-IncrementalSummary -CreatedSoFar $createdCount -SkippedSoFar $skippedCount -StartTime $startTime -CreatedList $createdTitles -SkippedList $skippedTitles }
            Start-Sleep -Milliseconds 15
        } else {
            Write-Host "Creating: $($issue.title)" -ForegroundColor Cyan
            $null = gh issue create --title $issue.title --body $issue.body @labelArgs --repo "$Owner/$Repo" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $createdCount++
                $createdTitles += $issue.title
                Write-Host "Created: $($issue.title)" -ForegroundColor Green
            } else {
                Write-Warning "Failed to create: $($issue.title)"
            }
            if ($Incremental -and $SummaryPath) { Write-IncrementalSummary -CreatedSoFar $createdCount -SkippedSoFar $skippedCount -StartTime $startTime -CreatedList $createdTitles -SkippedList $skippedTitles }
            Start-Sleep -Milliseconds 150
        }
        if ($MaxCreate -gt 0 -and $createdCount -ge $MaxCreate) { Write-Host "Reached MaxCreate ($MaxCreate). Stopping early." -ForegroundColor Yellow; break }
    } catch {
        Write-Warning "Error creating issue '$($issue.title)': $($_.Exception.Message)"
    }
}

$elapsed = (Get-Date) - $startTime
Write-Host "`nIssue creation complete" -ForegroundColor Green
Write-Host "Created: $createdCount  Skipped: $skippedCount  Total Defined: $($issues.Count)  Elapsed: {0:n1}s" -f $elapsed.TotalSeconds -ForegroundColor Cyan
Write-Host "View issues: https://github.com/$Owner/$Repo/issues" -ForegroundColor Cyan

if ($SummaryPath) { Write-IncrementalSummary -CreatedSoFar $createdCount -SkippedSoFar $skippedCount -StartTime $startTime -CreatedList $createdTitles -SkippedList $skippedTitles -Complete $true }

if ($MarkdownReportPath) {
    try {
        $lines = @()
        $lines += "# Issue Creation Report"
        $lines += "Repository: $Owner/$Repo"
        $lines += ("Run Timestamp: {0}" -f (Get-Date).ToString('u'))
        $lines += ""
        $lines += ("Created: {0}  Skipped: {1}  Total Defined: {2}" -f $createdCount, $skippedCount, $issues.Count)
        $lines += ""
        if ($createdTitles.Count -gt 0) {
            $lines += "## Created Issues"
            $createdTitles | ForEach-Object { $lines += "- $_" }
            $lines += ""
        }
        if ($skippedTitles.Count -gt 0) {
            $lines += "## Skipped (Already Existed)"
            $skippedTitles | Select-Object -First 50 | ForEach-Object { $lines += "- $_" }
            if ($skippedTitles.Count -gt 50) { $lines += "- ... (truncated)" }
            $lines += ""
        }
        Set-Content -Path $MarkdownReportPath -Value $lines -Encoding UTF8
        Write-Host "Markdown report written to $MarkdownReportPath" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to write markdown report: $($_.Exception.Message)"
    }
}