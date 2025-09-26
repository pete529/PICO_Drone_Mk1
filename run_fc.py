try:
    from fc.flight_computer import FlightComputer
except ImportError as e:
    print("Import error:", e)
    raise

if __name__ == '__main__':
    fc = FlightComputer(loop_hz=100)
    try:
        fc.run(seconds=10)  # Run for 10s; set to None for continuous
    except KeyboardInterrupt:
        print("Flight computer stopped.")
