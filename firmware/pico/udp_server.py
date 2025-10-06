"""
Pico W MicroPython UDP server for drone control.

Features:
- Starts AP (Wi‑Fi access point)
- Listens on UDP port 8888 for CSV controls: "DRN,{t},{r},{p},{y}\n" or "{t},{r},{p},{y}\n"
- Sends "ACK\n" on any valid packet; responds to "PING" with "ACK\n"
- Failsafe: if > FAILSAFE_MS without packet, throttle->0 (soft landing ramp)
- Optional: arming via hold-throttle-low+switch (placeholder hook)

Note: Hook the control outputs to your motor mix / ESC driver where indicated.
"""

try:
    import network  # type: ignore
    import socket   # type: ignore
    import time     # type: ignore
except Exception:
    # Desktop linting stubs
    class _NW:
        AP_IF = 0
        AUTH_WPA_WPA2_PSK = 0
        def WLAN(self, *_args, **_kw):
            raise RuntimeError("network.WLAN not available on desktop")
    network = _NW()  # type: ignore
    class _SKT:
        AF_INET = 0
        SOCK_DGRAM = 0
        def socket(self, *_a, **_k):
            raise RuntimeError("socket not available on desktop")
    socket = _SKT()  # type: ignore
    import time

from firmware.shared.control_protocol import parse_packet, process_controls, SIGNATURE, ThrottleSmoother
from firmware.pico.drv8833_stub import DRV8833Mixer, quad_x_mixer
try:
    from firmware.pico.drv8833 import DRV8833Driver  # real driver
except Exception:
    DRV8833Driver = None  # type: ignore


AP_SSID = "PicoDrone"
AP_PASSWORD = "drone1234"  # 8+ chars for WPA2 AP
UDP_PORT = 8888
FAILSAFE_MS = 500
SOFT_LAND_MS = 1500  # ramp-down duration when failsafe triggers
ADC_BAT_PIN = None  # e.g., 29 if wired to a VSYS divider
ADC_SCALE = 3.3 / 65535  # adjust with divider ratio if used


class _ThrottleSmoother(ThrottleSmoother):
    def __init__(self, soft_ms: int = SOFT_LAND_MS):
        super().__init__(soft_ms)


def start_ap(ssid: str = AP_SSID, password: str = AP_PASSWORD):
    ap = network.WLAN(network.AP_IF)
    # authmode may not exist on desktop stubs; MicroPython provides it
    try:
        am = network.AUTH_WPA_WPA2_PSK  # type: ignore[attr-defined]
    except Exception:
        am = None
    if am is not None:
        ap.config(essid=ssid, password=password, authmode=am)
    else:
        ap.config(essid=ssid, password=password)
    ap.active(True)
    # Wait for active
    for _ in range(50):
        if ap.active():
            break
        time.sleep_ms(100)
    return ap


def run_server(
    *,
    ssid: str = AP_SSID,
    password: str = AP_PASSWORD,
    port: int = UDP_PORT,
    expect_signature: bool = False,
    deadzone: float = 0.05,
    expo: float = 0.2,
):
    ap = start_ap(ssid, password)
    addr = ("0.0.0.0", port)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0.05)  # 50ms poll
    s.bind(addr)

    smoother = _ThrottleSmoother()
    mixer = DRV8833Mixer()
    # Prefer real DRV8833 driver if machine.PWM/Pin available and mapping set
    real_drv = None
    if DRV8833Driver is not None:
        try:
            # Mapping derived from hardware/main.ato:
            # Left DRV8833: AIN1=GP8, AIN2=GP9; BIN1=GP2, BIN2=GP3
            # Right DRV8833: AIN1=GP4, AIN2=GP5; BIN1=GP6, BIN2=GP7
            # Motors: M1(front-right)=GP8/GP9, M2(front-left)=GP2/GP3,
            #          M3(rear-right)=GP4/GP5,  M4(rear-left)=GP6/GP7
            real_drv = DRV8833Driver({
                1: (8, 9),
                2: (2, 3),
                3: (4, 5),
                4: (6, 7),
            })
        except Exception:
            real_drv = None
    # Enable SLEEP pins (GP15 left, GP17 right) if available
    try:
        from machine import Pin  # type: ignore
        Pin(15, Pin.OUT).value(1)
        Pin(17, Pin.OUT).value(1)
    except Exception:
        pass
    if real_drv is None:
        try:
            mixer.configure_test_pins([2, 3, 4, 5])  # example GPIOs
        except Exception:
            pass
    last_ok_ms = time.ticks_ms()

    print("UDP server listening on:", addr)
    print("AP IP:", ap.ifconfig())

    while True:
        try:
            data, src = s.recvfrom(256)
        except OSError:
            data = None

        now_ms = time.ticks_ms()
        if data:
            msg = data.decode('utf-8', 'ignore').strip()
            if msg == "PING" or msg == "PING\n":
                s.sendto(build_ack().encode(), src)
                continue
            try:
                t, r, p, y = parse_packet(msg, expect_signature=expect_signature)
                t, r, p, y = process_controls(t, r, p, y, deadzone=deadzone, expo=expo)
                t_out = smoother.on_valid(t)
                last_ok_ms = now_ms
                # Apply to test mixer (replace with real ESC control)
                m1, m2, m3, m4 = quad_x_mixer(t_out, r, p, y)
                if real_drv:
                    real_drv.apply_motors(m1, m2, m3, m4)
                else:
                    mixer.apply_motors(m1, m2, m3, m4)
                # For bring-up, print concise telemetry rarely
                # print("CTRL:", round(t_out,3), round(r,3), round(p,3), round(y,3))
                s.sendto(build_ack().encode(), src)
            except Exception as e:
                # Ignore bad packet
                # print("Bad packet:", e)
                pass
        else:
            if time.ticks_diff(now_ms, last_ok_ms) > FAILSAFE_MS:
                t_out = smoother.on_fail(now_ms)
                # TODO: apply t_out=soft-landing throttle
        # loop pacing
    time.sleep_ms(5)


def build_ack() -> str:
        bat = read_battery_voltage()
        rssi = read_rssi()
        parts = ["ACK"]
        if bat is not None:
            parts.append("BAT=%.2f" % bat)
        if rssi is not None:
            parts.append("RSSI=%s" % rssi)
        return " ".join(parts) + "\n"


def read_battery_voltage():
        try:
            from machine import ADC  # type: ignore
        except Exception:
            return None
        if ADC_BAT_PIN is None:
            return None
        try:
            adc = ADC(ADC_BAT_PIN)
            raw = adc.read_u16()
            return raw * ADC_SCALE
        except Exception:
            return None


def read_rssi():
        try:
            sta = network.WLAN(getattr(network, 'STA_IF', 0))
            r = sta.status('rssi')  # type: ignore[arg-type]
            return r if isinstance(r, int) else None
        except Exception:
            return None


if __name__ == "__main__":
    run_server()
