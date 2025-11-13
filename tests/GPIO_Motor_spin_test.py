import time
from machine import Pin

# Each motor uses a forward (A) and reverse (B) pin.
# Motors 1-4 consume GPIO 2-9 as:
#   Motor 1 -> (GP2, GP3)
#   Motor 2 -> (GP4, GP5)
#   Motor 3 -> (GP6, GP7)
#   Motor 4 -> (GP8, GP9)
MOTOR_PIN_MAP = [
    (2, 3),
    (4, 5),
    (6, 7),
    (8, 9),
]

FORWARD = True
REVERSE = False
FULL_POWER = True


def build_pin_bank():
    bank = []
    for a, b in MOTOR_PIN_MAP:
        pin_a = Pin(a, Pin.OUT, value=0)
        pin_b = Pin(b, Pin.OUT, value=0)
        bank.append((pin_a, pin_b))
    return bank


def drive_motor(pair, direction: bool, enabled: bool):
    pin_a, pin_b = pair
    if not enabled:
        pin_a.low()
        pin_b.low()
        return
    if direction is FORWARD:
        pin_a.high()
        pin_b.low()
    else:
        pin_a.low()
        pin_b.high()


def drive_all(bank, direction: bool, enabled: bool):
    for pair in bank:
        drive_motor(pair, direction, enabled)


def main(
    forward_time: float = 3.0,
    pause_time: float = 2.0,
    reverse_time: float = 3.0,
):
    bank = build_pin_bank()

    # Idle to start
    drive_all(bank, FORWARD, False)
    time.sleep(1.0)

    # Forward spin
    print("Spinning all motors FORWARD at full power")
    drive_all(bank, FORWARD, FULL_POWER)
    time.sleep(forward_time)

    # Pause / brake
    print("Pausing motors")
    drive_all(bank, FORWARD, False)
    time.sleep(pause_time)

    # Reverse spin
    print("Spinning all motors REVERSE at full power")
    drive_all(bank, REVERSE, FULL_POWER)
    time.sleep(reverse_time)

    # Final idle
    print("Test complete — motors idle")
    drive_all(bank, FORWARD, False)


if __name__ == "__main__":
    main()