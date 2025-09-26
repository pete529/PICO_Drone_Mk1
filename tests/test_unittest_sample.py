import unittest

from sensors.sensor_hub import SensorHub


def is_tuple3(x):
    return isinstance(x, (list, tuple)) and len(x) == 3


def is_num(x):
    return isinstance(x, (int, float))


class TestSensorHubSimulation(unittest.TestCase):
    def test_sensor_hub_outputs(self):
        hub = SensorHub(i2c=None)
        out = hub.read()
        self.assertIn("accel_g", out)
        self.assertTrue(is_tuple3(out["accel_g"]))
        self.assertTrue(all(is_num(v) for v in out["accel_g"]))
        self.assertIn("gyro_dps", out)
        self.assertTrue(is_tuple3(out["gyro_dps"]))
        self.assertTrue(all(is_num(v) for v in out["gyro_dps"]))
        self.assertIn("mag_uT", out)
        self.assertTrue(is_tuple3(out["mag_uT"]))
        self.assertTrue(all(is_num(v) for v in out["mag_uT"]))
        self.assertIn("temperature_c", out)
        self.assertTrue(is_num(out["temperature_c"]))
        self.assertIn("altitude_m", out)
        self.assertTrue(is_num(out["altitude_m"]))


if __name__ == "__main__":
    unittest.main()
