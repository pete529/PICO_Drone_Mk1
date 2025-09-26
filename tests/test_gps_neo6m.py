"""GPS (NEO-6M) UART smoke test.

On CPython without hardware, ensure the UART helper can be imported and called
without raising. If UART is unavailable, the helper returns None/False.
"""

from drivers.uart_bus import get_uart, uart_write


def test_uart_helper_import_and_noop_write():
	u = get_uart()
	ok = uart_write("$TEST,NMEA*00")
	# Either UART exists and write returns True, or no UART and it returns False.
	assert ok in (True, False)
