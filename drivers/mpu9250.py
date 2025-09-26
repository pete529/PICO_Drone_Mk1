from micropython import const

# Minimal reusable MPU9250 I2C driver for MicroPython with AK8963 mag via I2C bypass
# Exposes properties: acceleration (g), gyro (dps), temperature (C), mag (uT)

MPU9250_ADDR = const(0x68)

# Registers
REG_PWR_MGMT_1 = const(0x6B)
REG_SMPLRT_DIV = const(0x19)
REG_CONFIG = const(0x1A)
REG_GYRO_CONFIG = const(0x1B)
REG_ACCEL_CONFIG = const(0x1C)
REG_ACCEL_CONFIG2 = const(0x1D)
REG_INT_PIN_CFG = const(0x37)
REG_ACCEL_XOUT_H = const(0x3B)
REG_TEMP_OUT_H = const(0x41)
REG_GYRO_XOUT_H = const(0x43)

# AK8963 (magnetometer) registers via bypass
AK8963_ADDR = const(0x0C)
AK8963_WIA = const(0x00)
AK8963_ST1 = const(0x02)
AK8963_HXL = const(0x03)
AK8963_CNTL1 = const(0x0A)
AK8963_ASAX = const(0x10)
AK8963_MODE_POWERDOWN = const(0x00)
AK8963_MODE_CONT1 = const(0x02)  # 8 Hz
AK8963_MODE_CONT2 = const(0x06)  # 100 Hz
AK8963_BIT_16BIT = const(0x10)

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

class MPU9250:
    def __init__(self, i2c, addr=MPU9250_ADDR, accel_fs=2, gyro_fs=250, dlpf=True, mag_hz=100):
        self.i2c = i2c
        self.addr = addr
        self._accel_scale = _ACC_FS_SENS.get(accel_fs, 16384.0)
        self._gyro_scale = _GYRO_FS_SENS.get(gyro_fs, 131.0)
        # Wake device
        self._write(REG_PWR_MGMT_1, 0x00)  # set clock to internal, wake up
        self._write(REG_SMPLRT_DIV, 0x00)  # sample rate divider
        self._write(REG_CONFIG, 0x03 if dlpf else 0x00)   # DLPF config
        # Gyro FS config
        gyro_bits = {250:0, 500:1, 1000:2, 2000:3}.get(gyro_fs, 0) << 3
        self._write(REG_GYRO_CONFIG, gyro_bits)
        # Accel FS config
        acc_bits = {2:0, 4:1, 8:2, 16:3}.get(accel_fs, 0) << 3
        self._write(REG_ACCEL_CONFIG, acc_bits)
        self._write(REG_ACCEL_CONFIG2, 0x03 if dlpf else 0x00)
        # Enable I2C bypass to access AK8963 directly
        self._write(REG_INT_PIN_CFG, 0x02)  # BYPASS_EN=1
        # Setup AK8963 16-bit continuous mode
        self._ak8963_setup(mag_hz)

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
        return (t / 333.87) + 21.0

    @property
    def mag(self):
        # Returns microtesla (uT) if available
        if not hasattr(self, '_mag_adj'):  # not initialized
            return (None, None, None)
        # Check ST1 DRDY
        st1 = self._read_ext(AK8963_ADDR, AK8963_ST1, 1)
        if not st1 or not (st1[0] & 0x01):
            return (None, None, None)
        d = self._read_ext(AK8963_ADDR, AK8963_HXL, 7)
        if not d or len(d) < 7:
            return (None, None, None)
        # Little-endian order
        hx = (d[1] << 8) | d[0]
        hy = (d[3] << 8) | d[2]
        hz = (d[5] << 8) | d[4]
        hx = hx - 65536 if hx & 0x8000 else hx
        hy = hy - 65536 if hy & 0x8000 else hy
        hz = hz - 65536 if hz & 0x8000 else hz
        # Apply factory sensitivity adjustment and scale to uT
        adj = self._mag_adj
        # 0.15 uT/LSB for 16-bit output
        mx = hx * adj[0] * 0.15
        my = hy * adj[1] * 0.15
        mz = hz * adj[2] * 0.15
        return (mx, my, mz)

    # AK8963 helpers
    def _read_ext(self, dev_addr, reg, n=1):
        return self.i2c.readfrom_mem(dev_addr, reg, n)

    def _write_ext(self, dev_addr, reg, val):
        if not isinstance(val, (bytes, bytearray)):
            val = bytes([val & 0xFF])
        self.i2c.writeto_mem(dev_addr, reg, val)

    def _ak8963_setup(self, mag_hz):
        # Power down
        self._write_ext(AK8963_ADDR, AK8963_CNTL1, AK8963_MODE_POWERDOWN)
        # Read factory sensitivity adjustments
        asa = self._read_ext(AK8963_ADDR, AK8963_ASAX, 3)
        if not asa or len(asa) < 3:
            self._mag_adj = (1.0, 1.0, 1.0)
        else:
            self._mag_adj = tuple(((x - 128) / 256.0) + 1.0 for x in asa)
        # Set to 16-bit continuous mode
        mode = AK8963_MODE_CONT2 if mag_hz >= 100 else AK8963_MODE_CONT1
        self._write_ext(AK8963_ADDR, AK8963_CNTL1, (AK8963_BIT_16BIT | mode))
