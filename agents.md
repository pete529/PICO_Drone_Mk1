# Agents for Pete Drone Mk1 Project

This document describes the main software agents and their roles in the Pete Drone Mk1 project.

## 1. Android Mobile Application Agent

**Purpose:**  
Provides a user interface for controlling the drone via dual joysticks and toggle switches (Armed, DRN).  
Sends UDP packets to the Raspberry Pi Pico W running the UDP server.

**Key Features:**  
- Reads Wi-Fi credentials and security key from `wifi_credentials.json`
- Signs UDP packets with HMAC if a key is present
- Supports dark mode and custom launcher icon
- Allows real-time control of throttle, roll, pitch, and yaw

**Location:**  
`android/app/src/main/java/com/petedrone/udpsender/`

---

## 2. UDP Server Agent (Pico W)

**Purpose:**  
Receives UDP packets from the Android app, verifies security, and translates commands to motor outputs.

**Key Features:**  
- Loads Wi-Fi credentials and optional UDP key from `wifi_credentials.json`
- Verifies HMAC signatures on incoming packets
- Implements failsafe and soft landing logic
- Sends telemetry and ACK responses

**Location:**  
`firmware/pico/udp_server.py`

---

## 3. UDP Monitor Agent (Testing/Debug)

**Purpose:**  
Listens for UDP packets on port 8888 to verify Android app communication and packet integrity.

**Key Features:**  
- Connects to Wi-Fi using credentials
- Prints IP address and connection status
- Logs and summarizes incoming UDP packets
- Verifies HMAC signatures if a key is present

**Location:**  
`firmware/pico/udp_monitor.py`

---

## 4. Icon Generation Agent

**Purpose:**  
Automates resizing and creation of launcher icons for the Android app.

**Key Features:**  
- Loads source image and generates icons for all Android densities
- Ensures correct background and foreground layers

**Location:**  
`android/tools/generate_launcher_icons.py`

---

## 5. Test Agents

**Purpose:**  
Automated scripts for validating protocol, security, and firmware logic.

**Key Features:**  
- Unit tests for packet parsing, HMAC validation, and control logic
- Integration tests for end-to-end communication

**Location:**  
`tests/`

---

## Agent Interactions

- The Android app agent sends signed UDP packets to the Pico UDP server agent.
- The UDP monitor agent can be used for debugging and verifying packet transmission.
- The icon generation agent ensures the app has correct visual branding.
- Test agents validate the reliability and security of all communication.

---

**Maintainer:**  
Pete529  
[GitHub Repository](https://github.com/pete529/PICO_Drone_Mk1)
