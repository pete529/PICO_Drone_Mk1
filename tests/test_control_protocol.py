from firmware.shared.control_protocol import (
    parse_packet,
    process_controls,
    apply_deadzone,
    apply_expo,
    ThrottleSmoother,
)


def test_parse_plain_and_signed():
    assert parse_packet("0.5,0,-0.2,1\n") == (0.5, 0.0, -0.2, 1.0)
    assert parse_packet("DRN,1,1,1,1\n") == (1.0, 1.0, 1.0, 1.0)
    try:
        parse_packet("DRN,1,1,1\n")
        assert False, "expected error"
    except ValueError:
        pass


def test_ranges_clamped():
    t, r, p, y = parse_packet("2,-2,0,3\n")
    assert t == 1.0 and r == -1.0 and p == 0.0 and y == 1.0


def test_deadzone_and_expo():
    assert apply_deadzone(0.02, 0.05) == 0.0
    out = apply_expo(0.5, 0.5)
    assert 0.0 < out < 0.5  # cubic pulls down mid values

    t, r, p, y = process_controls(0.8, 0.02, -0.04, 0.2, deadzone=0.05, expo=0.3)
    assert t == 0.8 and r == 0.0 and p == 0.0 and -1.0 <= y <= 1.0


def test_failsafe_smoother():
    sm = ThrottleSmoother(soft_ms=1000)
    assert sm.on_valid(0.6) == 0.6
    # After 500ms into fail, expect ~60% -> ~30%
    out = sm.on_fail(500)
    assert 0.25 <= out <= 0.35
    # After 1s, should be 0
    out = sm.on_fail(1000)
    assert out == 0.0
