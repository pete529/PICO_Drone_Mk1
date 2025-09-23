from machine import Pin, I2C
import utime
import bmp280

i2c = I2C(0, scl=Pin(5), sda=Pin(4), freq=100000)
sensor = bmp280.BMP280(i2c)

while True:
    temp = sensor.temperature   # °C
    press = sensor.pressure     # Pa
    alt = 44330 * (1 - (press/101325) ** (1/5.255))  # meters

    print("Temp: {:.2f} °C".format(temp))
    print("Pressure: {:.2f} Pa".format(press))
    print("Altitude: {:.2f} m".format(alt))
    print("----")
    utime.sleep(2)