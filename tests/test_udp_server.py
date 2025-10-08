import importlib
from unittest.mock import patch

udp_server = importlib.import_module("firmware.pico.udp_server")


def test_udp_port_default():
    assert udp_server.UDP_PORT == 8888


def test_build_ack_with_metrics():
    with patch.object(udp_server, "read_battery_voltage", return_value=3.76), \
         patch.object(udp_server, "read_rssi", return_value=-45):
        ack = udp_server.build_ack()
    assert ack.startswith("ACK")
    assert "BAT=3.76" in ack
    assert "RSSI=-45" in ack
    assert ack.endswith("\n")


def test_build_ack_without_metrics():
    with patch.object(udp_server, "read_battery_voltage", return_value=None), \
         patch.object(udp_server, "read_rssi", return_value=None):
        ack = udp_server.build_ack()
    assert ack == "ACK\n"
