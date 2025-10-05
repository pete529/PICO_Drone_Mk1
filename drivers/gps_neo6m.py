"""u-blox NEO-6M GPS driver (UART/NMEA) - minimal parser.

Works on MicroPython/CPython. If no UART is available, you can use
parse_nmea_line() directly in tests.
"""
from __future__ import annotations

from typing import Optional, Dict, Any

from .uart_bus import get_uart

# Useful NMEA sentence IDs
_NMEA_RMC = "GPRMC"
_NMEA_GGA = "GPGGA"


def _hex2int(h: str) -> int:
	try:
		return int(h, 16)
	except Exception:
		return -1


def _nmea_checksum_ok(line: str) -> bool:
	"""Validate NMEA checksum for a full line like "$...*CS" (CS two hex digits)."""
	if not line or line[0] != '$' or '*' not in line:
		return False
	star = line.rfind('*')
	data = line[1:star]
	cs = line[star+1:].strip()
	calc = 0
	for ch in data:
		calc ^= ord(ch)
	return calc == _hex2int(cs[:2])


def _parse_latlon(nmea_val: str, hemi: str, is_lat: bool) -> Optional[float]:
	"""Convert ddmm.mmmm (lat) / dddmm.mmmm (lon) + hemisphere to signed degrees."""
	if not nmea_val or not hemi:
		return None
	try:
		if is_lat:
			deg = int(nmea_val[0:2])
			mins = float(nmea_val[2:])
		else:
			deg = int(nmea_val[0:3])
			mins = float(nmea_val[3:])
		val = deg + mins / 60.0
		if hemi in ('S', 'W'):
			val = -val
		return val
	except Exception:
		return None


def _knots_to_mps(kn: Optional[float]) -> Optional[float]:
	if kn is None:
		return None
	return kn * 0.514444


def parse_nmea_line(line: str) -> Optional[Dict[str, Any]]:
	"""Parse a single NMEA sentence (RMC or GGA). Returns a dict or None.

	Returned keys (subset depending on sentence):
	- type: "RMC" or "GGA"
	- valid: bool (RMC A=valid)
	- time_utc: str (hhmmss.sss)
	- date: str (ddmmyy)
	- lat: float deg
	- lon: float deg
	- speed_mps: float
	- course_deg: float
	- fix_quality: int (GGA)
	- sats: int (GGA)
	- hdop: float (GGA)
	- alt_m: float (GGA)
	"""
	if not line:
		return None
	line = line.strip()
	if '*' in line and not _nmea_checksum_ok(line):
		return None
	if line.startswith('$'):
		line = line[1:]
	parts = line.split(',')
	if not parts:
		return None
	msg = parts[0]
	out: Dict[str, Any] = {}
	if msg.endswith('RMC'):
		# $GPRMC,time,status,lat,N,lon,E,speed,course,date, ...
		out['type'] = 'RMC'
		out['time_utc'] = parts[1] or None
		status = parts[2] or 'V'
		out['valid'] = (status == 'A')
		out['lat'] = _parse_latlon(parts[3], parts[4], True)
		out['lon'] = _parse_latlon(parts[5], parts[6], False)
		try:
			spd_kn = float(parts[7]) if parts[7] else None
		except Exception:
			spd_kn = None
		out['speed_mps'] = _knots_to_mps(spd_kn) if spd_kn is not None else None
		try:
			out['course_deg'] = float(parts[8]) if parts[8] else None
		except Exception:
			out['course_deg'] = None
		out['date'] = parts[9] or None
		return out
	elif msg.endswith('GGA'):
		# $GPGGA,time,lat,N,lon,E,fix,sats,hdop,alt,M,geoid,M,...
		out['type'] = 'GGA'
		out['time_utc'] = parts[1] or None
		out['lat'] = _parse_latlon(parts[2], parts[3], True)
		out['lon'] = _parse_latlon(parts[4], parts[5], False)
		try:
			out['fix_quality'] = int(parts[6]) if parts[6] else 0
		except Exception:
			out['fix_quality'] = 0
		try:
			out['sats'] = int(parts[7]) if parts[7] else 0
		except Exception:
			out['sats'] = 0
		try:
			out['hdop'] = float(parts[8]) if parts[8] else None
		except Exception:
			out['hdop'] = None
		try:
			out['alt_m'] = float(parts[9]) if parts[9] else None
		except Exception:
			out['alt_m'] = None
		return out
	return None


class NEO6M:
	"""High-level helper for reading NMEA from UART and providing a combined fix.

	Call read_fix() to get a dict containing a merge of last-seen RMC/GGA fields.
	"""
	def __init__(self, uart=None):
		self.uart = uart if uart is not None else get_uart()
		self._last_rmc: Optional[Dict[str, Any]] = None
		self._last_gga: Optional[Dict[str, Any]] = None

	def _readline(self) -> Optional[str]:
		u = self.uart
		if not u:
			return None
		try:
			line = u.readline()
			if not line:
				return None
			if isinstance(line, bytes):
				line = line.decode('ascii', errors='ignore')
			return line.strip()
		except Exception:
			return None

	def poll(self):
		line = self._readline()
		if not line:
			return None
		msg = parse_nmea_line(line)
		if not msg:
			return None
		if msg.get('type') == 'RMC':
			self._last_rmc = msg
		elif msg.get('type') == 'GGA':
			self._last_gga = msg
		return msg

	def read_fix(self) -> Dict[str, Any]:
		"""Return a combined fix dict from the most recent RMC/GGA data."""
		fix: Dict[str, Any] = {}
		if self._last_rmc:
			fix.update(self._last_rmc)
		if self._last_gga:
			fix.update(self._last_gga)
		# Derive a simple 'has_fix' boolean
		valid = False
		if 'valid' in fix:
			valid = bool(fix['valid'])
		elif 'fix_quality' in fix:
			valid = fix.get('fix_quality', 0) > 0
		fix['has_fix'] = valid
		return fix
