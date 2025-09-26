from control.attitude import ComplementaryAHRS


def test_ahrs_static_1g_no_rate():
    ahrs = ComplementaryAHRS(alpha=0.98)
    # Static level: accel ~ (0,0,1) g, zero rates
    for _ in range(50):
        roll, pitch, yaw = ahrs.update((0.0, 0.0, 1.0), (0.0, 0.0, 0.0), 0.02)
    # Should remain near zero
    assert abs(roll) < 1.0
    assert abs(pitch) < 1.0
    assert abs(yaw) < 1e-6


def test_ahrs_roll_rate_response():
    ahrs = ComplementaryAHRS(alpha=0.98)
    # Apply a constant roll rate of 10 dps for 0.5s; accel suggests level
    dt = 0.02
    for _ in range(int(0.5 / dt)):
        roll, pitch, yaw = ahrs.update((0.0, 0.0, 1.0), (10.0, 0.0, 0.0), dt)
    # Expect roll to be positive and within a plausible range (gyro dominates with alpha=0.98)
    assert roll > 0.0
    assert roll < 10.0  # less than pure integration due to accel correction
