from drivers.gps_neo6m import parse_nmea_line


def test_parse_rmc_and_gga_basic():
	# Example RMC: valid, moderate speed and course
	rmc = "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A"
	msg = parse_nmea_line(rmc)
	assert msg and msg['type'] == 'RMC'
	assert msg['valid'] is True
	assert abs(msg['lat'] - 48.1173) < 1e-4
	assert abs(msg['lon'] - 11.5166667) < 1e-4
	assert msg['speed_mps'] is not None and msg['speed_mps'] > 0
	assert msg['course_deg'] == 84.4

	# Example GGA: 1 = GPS fix, 08 sats, altitude present
	gga = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47"
	msg2 = parse_nmea_line(gga)
	assert msg2 and msg2['type'] == 'GGA'
	assert msg2['fix_quality'] == 1
	assert msg2['sats'] == 8
	assert abs(msg2['alt_m'] - 545.4) < 1e-6
