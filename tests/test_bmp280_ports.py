from machine import Pin, I2C
i2c = I2C(0, scl=Pin(5), sda=Pin(4), freq=100000)
print("I2C devices:", [hex(x) for x in i2c.scan()])
