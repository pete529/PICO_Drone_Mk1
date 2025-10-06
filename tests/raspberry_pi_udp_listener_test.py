"""
Raspberry Pi UDP receiver test to verify it sees Android app signals.

Usage:
- Run this on a Raspberry Pi connected to the same Wi‑Fi as the Android phone (or on the Pico AP).
- In the Android app, set IP to the Raspberry Pi's IP address and Port to 8888.
- Start sending from the app; this script will print each CSV packet and reply with "ACK" so the app shows link health.
"""

import socket

PORT = 8888


def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("0.0.0.0", PORT))
    print(f"Listening on UDP {PORT} ...")
    try:
        while True:
            data, src = s.recvfrom(512)
            msg = data.decode(errors="ignore").strip()
            print("FROM", src, ":", msg)
            s.sendto(b"ACK\n", src)
    finally:
        s.close()


if __name__ == "__main__":
    main()
