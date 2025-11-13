import socket
import datetime
import hmac
import hashlib
import json
from pathlib import Path

UDP_PORT = 8888  # match the Android sender
CFG_PATH = Path(__file__).resolve().parents[1] / "android" / "app" / "src" / "main" / "assets" / "wifi_credentials.json"


def load_udp_key() -> bytes | None:
    if CFG_PATH.exists():
        data = json.loads(CFG_PATH.read_text(encoding="utf-8"))
        key_hex = data.get("udp_key")
        if key_hex:
            return bytes.fromhex(key_hex)
    return None


def verify_signature(msg: str, key: bytes | None) -> bool:
    if not key or "SIG=" not in msg:
        return True
    body, sig = msg.rsplit("SIG=", 1)
    body = body.rstrip(",")
    mac = hmac.new(key, body.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(mac, sig.strip())


def main() -> None:
    key = load_udp_key()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", UDP_PORT))
    print(f"Listening for UDP packets on port {UDP_PORT}...")

    while True:
        data, addr = sock.recvfrom(2048)
        timestamp = datetime.datetime.utcnow().isoformat()
        text = data.decode(errors="replace").strip()
        ok = verify_signature(text, key)
        status = "OK" if ok else "BAD_SIG"
        print(f"[{timestamp}] {addr[0]}:{addr[1]} [{status}] -> {text!r}")


if __name__ == "__main__":
    main()