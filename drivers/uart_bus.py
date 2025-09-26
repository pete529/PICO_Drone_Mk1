try:
    from machine import UART, Pin
except ImportError:
    UART = None
    Pin = None

# Defaults can be overridden by config.pins
UART_ID = 1
UART_TX_PIN = 20
UART_RX_PIN = 21
UART_BAUD = 115200

try:
    from config import pins as _pins_mod
    UART_ID = int(getattr(_pins_mod, 'UART_ID', UART_ID))
    UART_TX_PIN = int(getattr(_pins_mod, 'UART_TX_PIN', UART_TX_PIN))
    UART_RX_PIN = int(getattr(_pins_mod, 'UART_RX_PIN', UART_RX_PIN))
    UART_BAUD = int(getattr(_pins_mod, 'UART_BAUD', UART_BAUD))
except Exception:
    pass

_uart = None

def get_uart():
    global _uart
    if _uart is None:
        if UART and Pin:
            try:
                # On Pico, UART(id, baudrate, tx=Pin(...), rx=Pin(...))
                _uart = UART(UART_ID, baudrate=UART_BAUD, tx=Pin(UART_TX_PIN), rx=Pin(UART_RX_PIN))
            except Exception:
                _uart = None
        else:
            _uart = None
    return _uart


def uart_write(line: str):
    u = get_uart()
    if not u:
        return False
    try:
        if not line.endswith('\n'):
            line += '\n'
        u.write(line)
        return True
    except Exception:
        return False
