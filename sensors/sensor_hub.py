try:
    import utime as time
except ImportError:
    import time

from .imu_wrapper import ImuSensor
from .bmp280_wrapper import Bmp280Sensor
from .gps_wrapper import GpsSensor

class SensorHub:
    def __init__(self, i2c):
        self.imu = ImuSensor(i2c)
        self.baro = Bmp280Sensor(i2c)
        self.gps = GpsSensor()

    def read(self):
        ts_ms = time.ticks_ms() if hasattr(time, 'ticks_ms') else int(time.time() * 1000)
        imu = self.imu.read()
        baro = self.baro.read()
        gps = self.gps.read()
        sample = {
            'ts_ms': ts_ms,
            'accel_g': imu.get('accel_g'),
            'gyro_dps': imu.get('gyro_dps'),
            'mag_uT': imu.get('mag_uT'),
            'imu_temp_c': imu.get('temp_c'),
            'temperature_c': baro.get('temperature_c'),
            'pressure_pa': baro.get('pressure_pa'),
            'altitude_m': baro.get('altitude_m'),
            'gps_has_fix': gps.get('has_fix'),
            'gps_lat': gps.get('lat'),
            'gps_lon': gps.get('lon'),
            'gps_alt_m': gps.get('alt_m'),
            'gps_sats': gps.get('sats'),
        }
        return sample
