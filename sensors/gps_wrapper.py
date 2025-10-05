"""High-level GPS wrapper using NEO-6M driver when available.

Provides a simple read() that returns a fix dict with fields like lat, lon,
alt_m, sats, speed_mps, course_deg, has_fix, etc.
"""
from __future__ import annotations

from typing import Dict, Any

try:
	from drivers.gps_neo6m import NEO6M
except Exception:
	NEO6M = None  # type: ignore


class GpsSensor:
	def __init__(self, uart=None):
		self._gps = NEO6M(uart=uart) if NEO6M else None

	def read(self) -> Dict[str, Any]:
		if self._gps:
			# Poll up to a couple lines and then return the current fix snapshot
			for _ in range(2):
				self._gps.poll()
			return self._gps.read_fix()
		return {
			'type': None,
			'has_fix': False,
			'lat': None,
			'lon': None,
			'alt_m': None,
			'sats': 0,
		}
