"""
Shared control protocol utilities for Pico W UDP drone control.

Packet format:
  "DRN,{throttle},{roll},{pitch},{yaw}\n" or "{throttle},{roll},{pitch},{yaw}\n"

Ranges:
  throttle in [0.0, 1.0]
  roll, pitch, yaw in [-1.0, 1.0]

Optional processing:
  - deadzone: clamp small magnitudes to 0 within +/- deadzone
  - expo: apply exponential response curve (0..1)
"""

from typing import Tuple, Optional

SIGNATURE = "DRN"


def clamp(x: float, lo: float, hi: float) -> float:
    return hi if x > hi else lo if x < lo else x


def apply_deadzone(x: float, deadzone: float) -> float:
    if deadzone <= 0:
        return x
    if -deadzone <= x <= deadzone:
        return 0.0
    # Re-scale outside of deadzone to preserve full range
    sign = 1.0 if x > 0 else -1.0
    mag = (abs(x) - deadzone) / (1.0 - deadzone)
    return sign * clamp(mag, 0.0, 1.0)


def apply_expo(x: float, expo: float) -> float:
    """Expo curve: blends linear with cubic for more center resolution.
    expo in [0..1]; 0 = linear, 1 = full cubic.
    """
    expo = clamp(expo, 0.0, 1.0)
    return (1 - expo) * x + expo * (x ** 3)


def parse_packet(payload: str, expect_signature: bool = False) -> Tuple[float, float, float, float]:
    """Parse a CSV control packet. Supports optional signature prefix.

    Returns: tuple (throttle, roll, pitch, yaw)
    Raises: ValueError on format errors.
    """
    line = payload.strip()
    if not line:
        raise ValueError("empty payload")

    parts = line.split(',')
    if parts[0] == SIGNATURE:
        parts = parts[1:]
    elif expect_signature:
        raise ValueError("missing signature")

    if len(parts) != 4:
        raise ValueError("expected 4 CSV fields")

    try:
        t, r, p, y = (float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
    except Exception as e:
        raise ValueError(f"invalid numeric values: {e}")

    # Clamp ranges
    t = clamp(t, 0.0, 1.0)
    r = clamp(r, -1.0, 1.0)
    p = clamp(p, -1.0, 1.0)
    y = clamp(y, -1.0, 1.0)
    return t, r, p, y


def process_controls(
    throttle: float,
    roll: float,
    pitch: float,
    yaw: float,
    *,
    deadzone: float = 0.0,
    expo: float = 0.0,
) -> Tuple[float, float, float, float]:
    """Apply optional deadzone and expo to attitude axes (not throttle).
    Returns processed (t, r, p, y).
    """
    r = apply_expo(apply_deadzone(roll, deadzone), expo)
    p = apply_expo(apply_deadzone(pitch, deadzone), expo)
    y = apply_expo(apply_deadzone(yaw, deadzone), expo)
    return throttle, r, p, y


class ThrottleSmoother:
    """Soft-landing throttle ramp for failsafe.

    on_valid(t): updates immediately to t and clears failsafe timer
    on_fail(now_ms): ramps current output to 0 over soft_ms from first fail call
    """

    def __init__(self, soft_ms: int = 1500):
        self.soft_ms = soft_ms
        self._last_out = 0.0
        self._fail_started_ms: Optional[int] = None

    def on_valid(self, t: float) -> float:
        self._fail_started_ms = None
        self._last_out = clamp(t, 0.0, 1.0)
        return self._last_out

    def on_fail(self, now_ms: int) -> float:
        if self._fail_started_ms is None:
            self._fail_started_ms = now_ms
        dt = now_ms - self._fail_started_ms
        if dt >= self.soft_ms:
            self._last_out = 0.0
        else:
            k = 1.0 - (dt / self.soft_ms)
            self._last_out = max(0.0, self._last_out * k)
        return self._last_out
