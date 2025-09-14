# MicroPython MPU9250 (GY-91) I2C Example for Raspberry Pi Pico
from machine import Pin, I2C
import time

# MPU9250 I2C address
MPU9250_ADDR = 0x68

# Register addresses
PWR_MGMT_1 = 0x6B
ACCEL_XOUT_H = 0x3B
GYRO_XOUT_H = 0x43
TEMP_OUT_H = 0x41

# Initialize I2C (adjust pins as needed)
i2c = I2C(0, scl=Pin(17), sda=Pin(16), freq=400000)

def write_reg(addr, reg, data):
    i2c.writeto_mem(addr, reg, bytes([data]))

def read_reg(addr, reg, nbytes=1):
    return i2c.readfrom_mem(addr, reg, nbytes)

def bytes_to_int(msb, lsb):
    value = (msb << 8) | lsb
    if value & 0x8000:
        value = -((65535 - value) + 1)
    return value

def init_mpu9250():
    # Wake up MPU9250
    write_reg(MPU9250_ADDR, PWR_MGMT_1, 0)
    time.sleep(0.1)

init_mpu9250()

while True:
    # Read accelerometer data
    accel = read_reg(MPU9250_ADDR, ACCEL_XOUT_H, 6)
    ax = bytes_to_int(accel[0], accel[1])
    ay = bytes_to_int(accel[2], accel[3])
    az = bytes_to_int(accel[4], accel[5])

    # Read gyroscope data
    gyro = read_reg(MPU9250_ADDR, GYRO_XOUT_H, 6)
    gx = bytes_to_int(gyro[0], gyro[1])
    gy = bytes_to_int(gyro[2], gyro[3])
    gz = bytes_to_int(gyro[4], gyro[5])

    # Read temperature data
    temp = read_reg(MPU9250_ADDR, TEMP_OUT_H, 2)
    temp_raw = bytes_to_int(temp[0], temp[1])
    temperature = (temp_raw / 333.87) + 21.0

    print('Accel:', ax, ay, az, 'Gyro:', gx, gy, gz, 'Temp:', temperature)
    time.sleep(0.5)
