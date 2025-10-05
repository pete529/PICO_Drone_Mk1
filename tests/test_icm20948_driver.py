import math

from drivers.icm20948 import ICM20948, ICM20948_ADDR


class FakeI2C:
    def __init__(self):
        # Minimal register map for tests
        self.mem = {}
        # WHO_AM_I at 0x00 = 0xEA
        self.mem[(ICM20948_ADDR, 0x00)] = bytes([0xEA])
        # Accel XYZ (raw) = +16384 (1g), 0, 0
        self.mem[(ICM20948_ADDR, 0x2D)] = bytes([0x40, 0x00, 0x00, 0x00, 0x00, 0x00])
        # Gyro XYZ (raw) = 131, 0, 0 -> 1 dps at 250 dps scale
        self.mem[(ICM20948_ADDR, 0x33)] = bytes([0x00, 0x83, 0x00, 0x00, 0x00, 0x00])
        # Temp raw producing ~21C (0)
        self.mem[(ICM20948_ADDR, 0x39)] = bytes([0x00, 0x00])

    def readfrom_mem(self, addr, reg, n):
        return self.mem.get((addr, reg), bytes([0] * n))

    def writeto_mem(self, addr, reg, data):
        # Record writes; not needed for this test
        self.mem[(addr, reg)] = bytes(data)


def test_icm20948_basic_scaling():
    i2c = FakeI2C()
    imu = ICM20948(i2c)
    ax, ay, az = imu.acceleration
    # Expect ~1g,0,0
    assert math.isclose(ax, 1.0, rel_tol=1e-3)
    assert math.isclose(ay, 0.0, abs_tol=1e-6)
    assert math.isclose(az, 0.0, abs_tol=1e-6)

    gx, gy, gz = imu.gyro
    # Expect ~1 dps,0,0
    assert math.isclose(gx, 1.0, rel_tol=1e-3)
    assert math.isclose(gy, 0.0, abs_tol=1e-6)
    assert math.isclose(gz, 0.0, abs_tol=1e-6)

    t = imu.temperature
    # With raw=0 -> ~21C using generic formula
    assert 20.5 <= t <= 21.5

    mx, my, mz = imu.mag
    # Not implemented -> None tuple
    assert mx is None and my is None and mz is None
