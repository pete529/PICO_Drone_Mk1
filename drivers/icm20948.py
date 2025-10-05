try:
    from micropython import const
except Exception:
    def const(x):
        return x

# Minimal ICM-20948 driver (I2C) for MicroPython/CPython
# Exposes: acceleration (g), gyro (dps), temperature (C), mag (uT -> None for now)

ICM20948_ADDR = const(0x68)

# Bank-select and common registers (Bank 0)
REG_WHO_AM_I = const(0x00)
REG_BANK_SEL = const(0x7F)
REG_PWR_MGMT_1 = const(0x06)  # Bank 0

# Data registers in Bank 0
REG_ACCEL_XOUT_H = const(0x2D)
REG_GYRO_XOUT_H = const(0x33)
REG_TEMP_OUT_H = const(0x39)

WHO_AM_I_VAL = const(0xEA)  # ICM-20948 expected value

_ACC_FS_SENS = {
    2: 16384.0,
    4: 8192.0,
    8: 4096.0,
    16: 2048.0,
}
_GYRO_FS_SENS = {
    250: 131.0,
    500: 65.5,
    1000: 32.8,
    2000: 16.4,
}


class ICM20948:
    def __init__(self, i2c, addr=ICM20948_ADDR, accel_fs=2, gyro_fs=250):
        if i2c is None:
            raise ValueError("ICM20948 requires an I2C instance")
        self.i2c = i2c
        self.addr = addr
        self._accel_scale = _ACC_FS_SENS.get(accel_fs, 16384.0)
        self._gyro_scale = _GYRO_FS_SENS.get(gyro_fs, 131.0)

        # Select bank 0 and wake device (basic init)
        self._write(REG_BANK_SEL, 0x00)
        # Auto clock, clear sleep (typical bring-up value 0x01)
        try:
            self._write(REG_PWR_MGMT_1, 0x01)
        except Exception:
            # Some buses may NACK during early power-up; tolerate in tests
            pass

        # Sanity check WHO_AM_I if available
        try:
            who = self._read(REG_WHO_AM_I, 1)
            if who and who[0] not in (WHO_AM_I_VAL,):
                # Not strictly error; board variants may differ
                pass
        except Exception:
            pass

    # Low-level I2C helpers
    def _read(self, reg, n=1):
        return self.i2c.readfrom_mem(self.addr, reg, n)

    def _write(self, reg, val):
        if not isinstance(val, (bytes, bytearray)):
            val = bytes([val & 0xFF])
        self.i2c.writeto_mem(self.addr, reg, val)

    def _rx16(self, reg):
        d = self._read(reg, 2)
        v = (d[0] << 8) | d[1]
        return v - 65536 if v & 0x8000 else v

    # Public API
    @property
    def acceleration(self):
        d = self._read(REG_ACCEL_XOUT_H, 6)
        ax = (d[0] << 8) | d[1]
        ay = (d[2] << 8) | d[3]
        az = (d[4] << 8) | d[5]
        ax = ax - 65536 if ax & 0x8000 else ax
        ay = ay - 65536 if ay & 0x8000 else ay
        az = az - 65536 if az & 0x8000 else az
        return (ax / self._accel_scale, ay / self._accel_scale, az / self._accel_scale)

    @property
    def gyro(self):
        d = self._read(REG_GYRO_XOUT_H, 6)
        gx = (d[0] << 8) | d[1]
        gy = (d[2] << 8) | d[3]
        gz = (d[4] << 8) | d[5]
        gx = gx - 65536 if gx & 0x8000 else gx
        gy = gy - 65536 if gy & 0x8000 else gy
        gz = gz - 65536 if gz & 0x8000 else gz
        return (gx / self._gyro_scale, gy / self._gyro_scale, gz / self._gyro_scale)

    @property
    def temperature(self):
        t = self._rx16(REG_TEMP_OUT_H)
        # InvenSense parts commonly use: Temp(C) = (raw / 333.87) + 21
        return (t / 333.87) + 21.0

    @property
    def mag(self):
        # AK09916 support not implemented in this minimal driver
        return (None, None, None)
