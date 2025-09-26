"""Simple desktop test runner using unittest discovery.

Usage:
    python run_tests.py
"""

import sys
import unittest


def main() -> int:
    suite = unittest.defaultTestLoader.discover("tests")
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())
