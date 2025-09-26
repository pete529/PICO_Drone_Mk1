try:
    from machine import I2C, Pin
except ImportError:
    # Allow importing this module on CPython for tooling/tests
    I2C = None
    Pin = None

try:
    # Import module if available
    from config import pins as _pins_mod
except ImportError:
    _pins_mod = None

I2C_ID = 1
I2C_SDA_PIN = 26
I2C_SCL_PIN = 27
I2C_FREQ = 400000

if _pins_mod is not None:
    try:
        I2C_ID = int(getattr(_pins_mod, 'I2C_ID', I2C_ID))
        I2C_SDA_PIN = int(getattr(_pins_mod, 'I2C_SDA_PIN', I2C_SDA_PIN))
        I2C_SCL_PIN = int(getattr(_pins_mod, 'I2C_SCL_PIN', I2C_SCL_PIN))
        I2C_FREQ = int(getattr(_pins_mod, 'I2C_FREQ', I2C_FREQ))
    except Exception:
        pass

_i2c = None

def get_i2c():
    global _i2c
    if _i2c is not None:
        return _i2c
    if I2C is None or Pin is None:
        raise RuntimeError("machine.I2C not available (not running on MicroPython)")
    _i2c = I2C(I2C_ID, sda=Pin(I2C_SDA_PIN), scl=Pin(I2C_SCL_PIN), freq=I2C_FREQ)
    return _i2c

def scan_addresses():
    i2c = get_i2c()
    try:
        return i2c.scan()
    except Exception:
        return []
