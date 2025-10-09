"""
Pico W MicroPython UDP server for drone control.

Features:
- Connects to STA Wi-Fi using credentials from wifi_credentials.json (no hardcoded secrets)
- Listens on UDP port 8888 for CSV controls: "DRN,{t},{r},{p},{y}[,nonce,signature]\n"
- Optional HMAC authentication of packets when udp_key is present in the credentials file
- Sends "ACK\n" on any valid packet; responds to "PING" with "ACK\n"
- Failsafe: if > FAILSAFE_MS without packet, throttle->0 (soft landing ramp)
- Optional: arming via hold-throttle-low+switch (placeholder hook)

Note: Hook the control outputs to your motor mix / ESC driver where indicated.
"""
from __future__ import annotations

import json
try:
    import uhashlib as hashlib  # type: ignore
except ImportError:
    import hashlib  # type: ignore

try:
    import network  # type: ignore
    import socket   # type: ignore
    import time     # type: ignore
except Exception:
    # Desktop linting stubs
    class _NW:
        AP_IF = 0
        STA_IF = 1
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

from firmware.shared.control_protocol import parse_packet, process_controls, ThrottleSmoother
from firmware.pico.drv8833_stub import DRV8833Mixer, quad_x_mixer

try:
    from firmware.pico.drv8833 import DRV8833Driver  # real driver
except Exception:
    DRV8833Driver = None  # type: ignore


CONFIG_PATH = "wifi_credentials.json"
UDP_PORT = 8888
FAILSAFE_MS = 500
SOFT_LAND_MS = 1500  # ramp-down duration when failsafe triggers
ADC_BAT_PIN = None  # e.g., 29 if wired to a VSYS divider
ADC_SCALE = 3.3 / 65535  # adjust with divider ratio if used


class _ThrottleSmoother(ThrottleSmoother):
    def __init__(self, soft_ms: int = SOFT_LAND_MS):
        super().__init__(soft_ms)


def _load_config(path: str = CONFIG_PATH) -> dict[str, str]:
    try:
        with open(path, "r", encoding="utf-8") as fp:
            cfg = json.loads(fp.read())
    except OSError as exc:
        raise RuntimeError(
            f"Wi-Fi credentials file '{path}' not found. "
            "Copy wifi_credentials.json to the device with STA/AP settings."
        ) from exc
    required = ("sta_ssid", "sta_password")
    for key in required:
        if key not in cfg:
            raise RuntimeError(f"Missing required key '{key}' in {path}")
    return cfg


def _compute_hmac(payload: str, nonce: str, secret: str) -> str:
    data = (payload + "|" + nonce).encode("utf-8")
    mac = hashlib.sha256(secret.encode("utf-8") + data).hexdigest()
    return mac


def _compare_digest(a: str, b: str) -> bool:
    if len(a) != len(b):
        return False
    result = 0
    for x, y in zip(a.encode("utf-8"), b.encode("utf-8")):
        result |= x ^ y
    return result == 0


def start_ap(ssid: str, password: str):
    ap = network.WLAN(network.AP_IF)
    try:
        am = network.AUTH_WPA_WPA2_PSK  # type: ignore[attr-defined]
    except Exception:
        am = None
    if am is not None:
        ap.config(essid=ssid, password=password, authmode=am)
    else:
        ap.config(essid=ssid, password=password)
    ap.active(True)
    for _ in range(50):
        if ap.active():
            break
        time.sleep_ms(100)
    return ap


def connect_sta(ssid: str, password: str, timeout_ms: int = 20000):
    """Connect to an existing Wi-Fi network and wait until connected or raise error after ~20s."""
    sta = network.WLAN(getattr(network, "STA_IF", 1))
    sta.active(True)
    try:
        sta.connect(ssid, password)  # type: ignore[attr-defined]
    except Exception:
        pass
    t0 = time.ticks_ms()
    while True:
        try:
            if getattr(sta, "isconnected", lambda: False)():
                break
        except Exception:
            pass
        if time.ticks_diff(time.ticks_ms(), t0) > timeout_ms:
            raise RuntimeError(
                "Failed to connect to Wi-Fi SSID '%s' within %ds"
                % (ssid, timeout_ms // 1000)
            )
        time.sleep_ms(1000)
    return sta


def _validate_payload(raw: str, secret: str | None) -> tuple[str, bool]:
    """
    Return (payload_without_auth, signature_present).
    Raises ValueError if authentication fails when a secret is provided.
    """
    if not secret:
        return raw, False

    try:
        payload, nonce, signature = raw.rsplit(",", 2)
    except ValueError as exc:
        raise ValueError("missing nonce/signature fields") from exc

    expected = _compute_hmac(payload, nonce, secret)
    if not _compare_digest(expected, signature):
        raise ValueError("invalid signature")
    return payload, True


def run_server(
    *,
    port: int = UDP_PORT,
    expect_signature: bool | None = None,
    deadzone: float = 0.05,
    expo: float = 0.2,
    use_ap: bool = False,
    config_path: str = CONFIG_PATH,
):
    cfg = _load_config(config_path)
    ap_ssid = cfg.get("ap_ssid")
    ap_pw = cfg.get("ap_password")
    sta_ssid = cfg["sta_ssid"]
    sta_pw = cfg["sta_password"]
    auth_key = cfg.get("udp_key")
    if expect_signature is None:
        expect_signature = bool(auth_key)

    if use_ap:
        if not ap_ssid or not ap_pw:
            raise RuntimeError("AP credentials missing in config")
        wlan = start_ap(ap_ssid, ap_pw)
    else:
        wlan = connect_sta(sta_ssid, sta_pw)

    addr = ("0.0.0.0", port)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0.05)
    s.bind(addr)

    smoother = _ThrottleSmoother()
    mixer = DRV8833Mixer()

    real_drv = None
    if DRV8833Driver is not None:
        try:
            real_drv = DRV8833Driver(
                {
                    1: (8, 9),
                    2: (2, 3),
                    3: (4, 5),
                    4: (6, 7),
                }
            )
        except Exception:
            real_drv = None
    try:
        from machine import Pin  # type: ignore

        Pin(15, Pin.OUT).value(1)
        Pin(17, Pin.OUT).value(1)
    except Exception:
        pass
    if real_drv is None:
        try:
            mixer.configure_test_pins([2, 3, 4, 5])
        except Exception:
            pass

    last_ok_ms = time.ticks_ms()

    print("UDP server listening on:", addr)
    try:
        print("WLAN ifconfig:", wlan.ifconfig())
    except Exception:
        pass

    while True:
        try:
            data, src = s.recvfrom(256)
        except OSError:
            data = None

        now_ms = time.ticks_ms()
        if data:
            msg = data.decode("utf-8", "ignore").strip()
            if msg == "PING" or msg == "PING\n":
                s.sendto(build_ack().encode(), src)
                continue
            try:
                payload, signed = _validate_payload(msg, auth_key)
                t, r, p, y = parse_packet(payload, expect_signature=expect_signature)
                t, r, p, y = process_controls(t, r, p, y, deadzone=deadzone, expo=expo)
                t_out = smoother.on_valid(t)
                last_ok_ms = now_ms
                m1, m2, m3, m4 = quad_x_mixer(t_out, r, p, y)
                if real_drv:
                    real_drv.apply_motors(m1, m2, m3, m4)
                else:
                    mixer.apply_motors(m1, m2, m3, m4)
                s.sendto(build_ack(signed).encode(), src)
            except Exception:
                # Ignore bad packet
                pass
        else:
            if time.ticks_diff(now_ms, last_ok_ms) > FAILSAFE_MS:
                smoother.on_fail(now_ms)
        time.sleep_ms(5)


def build_ack(signature_received: bool = False) -> str:
    bat = read_battery_voltage()
    rssi = read_rssi()
    parts = ["ACK"]
    if signature_received:
        parts.append("AUTH=OK")
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
        sta = network.WLAN(getattr(network, "STA_IF", 0))
        r = sta.status("rssi")  # type: ignore[arg-type]
        return r if isinstance(r, int) else None
    except Exception:
        return None


if __name__ == "__main__":
    run_server()