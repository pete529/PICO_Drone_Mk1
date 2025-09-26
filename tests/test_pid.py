from control.pid import PID


def test_pid_integral_clamp_and_output_limit():
    pid = PID(kp=0.0, ki=1.0, kd=0.0, i_limit=0.5, out_limit=0.3)
    # Apply a constant error over time; integral should clamp at 0.5
    out = 0.0
    t = 0.0
    for _ in range(20):
        out = pid.update(err=1.0, dt=0.1)  # integrates 0.1 per step
        t += 0.1
    # Integral would be 2.0 without clamp; with clamp it's 0.5; out limit is 0.3
    assert abs(out - 0.3) < 1e-6


def test_pid_derivative_and_reset():
    pid = PID(kp=0.0, ki=0.0, kd=1.0, i_limit=None, out_limit=None)
    # First update has no prev_err; derivative term should be 0
    out1 = pid.update(err=1.0, dt=0.1)
    # Next update with a drop in error will give negative derivative
    out2 = pid.update(err=0.0, dt=0.1)
    assert out1 == 0.0
    assert out2 < 0.0
    pid.reset()
    out3 = pid.update(err=1.0, dt=0.1)
    # After reset, prev_err is None again, derivative term = 0
    assert out3 == 0.0
