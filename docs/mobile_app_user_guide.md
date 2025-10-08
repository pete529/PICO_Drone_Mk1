# Android Controller App – User Manual

_Last updated: 2025-10-08_

The Android sender app provides a dual-stick remote for the Pico Drone Mk1 over Wi‑Fi UDP. This guide walks you through installing the app, pairing it with the Pico W, and understanding every control on the screen.

## 1. What's New
- High-contrast dark theme so all controls remain readable in night environments.
- Bright yellow drone launcher icon to quickly locate the app on your device.
- Default UDP destination port set to **8888** to match the Pico firmware out of the box.
- Inline telemetry badges for battery voltage and RSSI when the Pico returns `ACK` packets.

## 2. Requirements
- Android 8.0 (API 26) or newer phone/tablet.
- Access to the Pico Drone Mk1 Wi‑Fi network (`PicoDrone`).
- Pico W running the firmware in `firmware/pico/udp_server.py` (default settings assumed).

## 3. Installing the App
### Option A — Android Studio (recommended for development)
1. Open Android Studio Hedgehog or newer.
2. Choose **Open an Existing Project** and select the `android/` folder in this repository.
3. Let Gradle sync the project. Use the provided local Gradle distribution (`android/gradle-8.7.zip`) if requested.
4. Connect an Android device with USB debugging enabled.
5. Run the **app** configuration; Android Studio installs the debug build automatically.

### Option B — Gradle CLI
From a terminal in `android/`:
```powershell
./gradlew assembleDebug
./gradlew installDebug
```
This produces `app/build/outputs/apk/debug/app-debug.apk` and installs it on the connected device.

## 4. First-Time Connection
1. Power the Pico W and confirm the UDP server is running (default AP SSID `PicoDrone`, password `drone1234`).
2. On the Android device, join the `PicoDrone` Wi‑Fi network.
3. Launch the **Pico Drone Controller** app (yellow drone icon on black).
4. Leave `Pico IP (AP)` at `192.168.4.1` and `UDP Port` at `8888` unless you changed them on the Pico.
5. Toggle **Armed** on once you're ready to send throttle.
6. Tap **Start** to begin streaming packets. Stick movements should now update telemetry in Thonny or your Pico serial console.

## 5. UI Walkthrough
| Control | Description |
| --- | --- |
| **Pico IP (AP)** | Destination IP address. Defaults to the Pico W AP gateway `192.168.4.1`. |
| **UDP Port** | Destination port (default `8888`). Accepts 1024–1191 range. |
| **Armed** toggle | Forces throttle to 0 when off. Enable only when props are removed or safe. |
| **Signature DRN** toggle | Prepends `DRN,` to packets for firmware that enforces the signature. |
| **Dual joysticks** | Left stick: yaw (X), throttle (Y). Right stick: roll (X), pitch (Y). Both include a configurable deadzone in code. |
| **Start / Stop buttons** | Start launches a 50 Hz coroutine that sends packets; Stop halts the socket. |
| **ACK / BAT / RSSI readout** | Displays the latest acknowledgement message and parsed telemetry from the Pico. |

### Axis Mapping
- **Throttle**: Left joystick vertical axis (mapped from -1..1 to 0..1).
- **Yaw**: Left joystick horizontal axis.
- **Roll**: Right joystick horizontal axis.
- **Pitch**: Right joystick vertical axis (positive values = forward).

## 6. Dark Theme & Accessibility
The app forces the Material 3 dark color scheme for maximum readability in dim environments. All text and outlines meet WCAG AA contrast ratios. If you need larger text, use the Android system font scaling; Compose UI respects those settings.

## 7. Telemetry & Diagnostics
- `ACK` indicates the Pico received the last packet. If missing, check Wi‑Fi signal or port.
- Optional metrics appended by the Pico firmware:
  - `BAT=<volts>` (e.g., `BAT=3.78`) — requires `ADC_BAT_PIN` to be set in firmware.
  - `RSSI=<dBm>` (e.g., `RSSI=-46`) — reported when the Pico is in STA mode.
- If telemetry stops updating, press **Stop**, verify the Pico is still running, then **Start** again.

## 8. Safety Checklist
- Always test with propellers removed.
- Keep the **Armed** toggle off while configuring network settings.
- Confirm failsafe behavior: stop the app with the Pico powered and ensure motors ramp down.

## 9. Troubleshooting
| Symptom | Fix |
| --- | --- |
| No connection / ACK | Ensure you're on the PicoDrone Wi‑Fi, confirm port `8888`, verify Pico firmware is running. |
| App crashes on Start | Port field must be numeric; invalid entries fall back to 8888 but extreme values may fail. |
| Delayed response | Check for other apps using UDP on port 8888, reduce background network usage. |
| No telemetry values | Your Pico firmware may not enable battery/RSSI reporting; this is optional. |
| Text too small | Increase Android system font size; the UI layouts reflow automatically. |

## 10. Advanced Customisation
Developers can tweak defaults in `MainActivity.kt`:
- Change starting IP/port (`ip`, `port` state holders).
- Adjust send rate (`delay(20)` in the coroutine).
- Modify deadzone sensitivity (`DualJoysticks` `deadzone` parameter).
- Extend telemetry parsing by handling extra `ACK` space-separated tokens.

For deeper firmware integration tips, see `firmware/pico/udp_server.py` and `firmware/shared/control_protocol.py`.
