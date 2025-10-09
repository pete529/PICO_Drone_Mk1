#### filepath: c:\Users\pete5\pico_code_projects\Drone_mk1\firmware\pico\udp_monitor.py
"""
MicroPython UDP monitor for the Pete Drone Android app.

- Reads Wi-Fi + optional udp_key from wifi_credentials.json
- Connects in STA mode, prints assigned IP, and confirms link
- Listens on UDP 8888, verifies HMAC when udp_key provided
- Logs a succinct summary of each packet from the phone
"""

from __future__ import annotations

import json
import time
import network  # type: ignore
import socket  # type: ignore

try:
    import uhashlib as hashlib  # type: ignore
except ImportError:  # desktop lint fallback
    import hashlib  # type: ignore

CONFIG_PATH = "wifi_credentials.json"
UDP_PORT = 8888


def load_credentials(path: str = CONFIG_PATH) -> dict[str, str]:
    try:
        with open(path, "r", encoding="utf-8") as fp:
            cfg = json.loads(fp.read())
    except OSError as exc:
        raise RuntimeError(
            "wifi_credentials.json missing; copy it to the Pico "
            "with sta_ssid, sta_password, and optional udp_key."
        ) from exc

    for key in ("sta_ssid", "sta_password"):
        if key not in cfg or not cfg[key]:
            raise RuntimeError(f"Missing '{key}' in wifi_credentials.json")
    return cfg


def connect_wifi(ssid: str, password: str, timeout_ms: int = 20000) -> network.WLAN:  # type: ignore[name-defined]
    sta = network.WLAN(network.STA_IF)  # type: ignore[attr-defined]
    sta.active(True)
    sta.connect(ssid, password)  # type: ignore[attr-defined]

    deadline = time.ticks_add(time.ticks_ms(), timeout_ms)
    while not sta.isconnected():  # type: ignore[attr-defined]
        if time.ticks_diff(deadline, time.ticks_ms()) <= 0:
            raise RuntimeError(f"Wi-Fi join timeout for SSID '{ssid}'")
        time.sleep_ms(500)
    return sta


def compute_hmac(secret: str, payload: str, nonce: str) -> str:
    data = (payload + "|" + nonce).encode()
    digest = hashlib.sha256(secret.encode() + data).hexdigest()
    return digest


def constant_time_eq(a: str, b: str) -> bool:
    if len(a) != len(b):
        return False
    result = 0
    for x, y in zip(a.encode(), b.encode()):
        result |= x ^ y
    return result == 0


def extract_payload(message: str, secret: str | None) -> tuple[str, bool]:
    if not secret:
        return message, False
    try:
        payload, nonce, signature = message.rsplit(",", 2)
    except ValueError as exc:
        raise ValueError("packet missing nonce/signature") from exc

    expected = compute_hmac(secret, payload, nonce)
    if not constant_time_eq(expected, signature):
        raise ValueError("invalid HMAC")
    return payload, True


def summarize(payload: str) -> str:
    parts = payload.split(",")
    if len(parts) != 4:
        return f"raw='{payload}'"
    labels = ("thr", "roll", "pitch", "yaw")
    data = ", ".join(f"{name}={float(val):.3f}" for name, val in zip(labels, parts))
    return data


def main() -> None:
    cfg = load_credentials()
    udp_key = cfg.get("udp_key") or None

    print("[wifi] connecting…")
    sta = connect_wifi(cfg["sta_ssid"], cfg["sta_password"])
    ip_info = sta.ifconfig()  # type: ignore[attr-defined]
    print(f"[wifi] connected ✔  IP={ip_info[0]}  GW={ip_info[2]}")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", UDP_PORT))
    sock.settimeout(5.0)

    print(f"[udp] listening on :{UDP_PORT} (hmac={'on' if udp_key else 'off'})")

    while True:
        try:
            packet, addr = sock.recvfrom(256)
        except OSError:
            print("[udp] no packets in last 5s…")
            continue

        text = packet.decode("utf-8", "ignore").strip()
        timestamp = time.ticks_ms()

        if text == "PING":
            print(f"[{timestamp}] {addr[0]}:{addr[1]} heartbeat PING")
            continue

        try:
            payload, signed = extract_payload(text, udp_key)
            summary = summarize(payload)
            print(
                f"[{timestamp}] {addr[0]}:{addr[1]} "
                f"{'AUTH' if signed else 'UNSIGNED'} :: {summary}"
            )
        except ValueError as exc:
            print(f"[{timestamp}] {addr[0]}:{addr[1]} INVALID packet: {exc} :: {text}")


if __name__ == "__main__":
    main()