from drivers.i2c_bus import get_i2c
from sensors.sensor_hub import SensorHub
try:
    import utime as time
except ImportError:
    import time

def main():
    i2c = get_i2c()
    hub = SensorHub(i2c)
    for _ in range(10):
        s = hub.read()
        print("accel_g:", s.get('accel_g'), "gyro_dps:", s.get('gyro_dps'),
              "mag_uT:", s.get('mag_uT'), "temp_c:", s.get('temperature_c') or s.get('imu_temp_c'),
              "press_pa:", s.get('pressure_pa'), "alt_m:", s.get('altitude_m'))
        if hasattr(time, 'sleep_ms'):
            time.sleep_ms(250)
        else:
            time.sleep(0.25)

if __name__ == '__main__':
    main()
