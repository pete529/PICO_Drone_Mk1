class PID:
    def __init__(self, kp=0.0, ki=0.0, kd=0.0, i_limit=None, out_limit=None):
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.i = 0.0
        self.prev_err = None
        self.i_limit = i_limit
        self.out_limit = out_limit

    def reset(self):
        self.i = 0.0
        self.prev_err = None

    def update(self, err, dt):
        if dt <= 0:
            return 0.0
        p = self.kp * err
        self.i += self.ki * err * dt
        if self.i_limit is not None:
            self.i = max(-self.i_limit, min(self.i, self.i_limit))
        d = 0.0
        if self.prev_err is not None:
            d = self.kd * (err - self.prev_err) / dt
        self.prev_err = err
        out = p + self.i + d
        if self.out_limit is not None:
            out = max(-self.out_limit, min(out, self.out_limit))
        return out
