"""Desktop test runner supporting unittest.TestCase and function-style tests.

Usage:
    python run_tests.py
"""

import importlib.util
import inspect
import sys
import types
import unittest
from pathlib import Path


def _discover_function_tests(tests_dir: Path):
    """Yield (module_name, function) for plain functions named test_* in test_*.py modules."""
    for py in sorted(tests_dir.glob("test_*.py")):
        mod_name = f"tests.{py.stem}" if (tests_dir / "__init__.py").exists() else py.stem
        spec = importlib.util.spec_from_file_location(mod_name, py)
        if spec and spec.loader:  # type: ignore[attr-defined]
            mod = importlib.util.module_from_spec(spec)
            try:
                sys.modules[mod_name] = mod
                spec.loader.exec_module(mod)  # type: ignore[assignment]
            except Exception as e:
                print(f"ERROR importing {py.name}: {e}")
                yield (mod_name, None, e)
                continue
            for name, obj in inspect.getmembers(mod):
                if name.startswith("test") and isinstance(obj, types.FunctionType):
                    # Only top-level functions (module-level)
                    if obj.__qualname__ == obj.__name__:
                        yield (mod_name, obj, None)


def main() -> int:
    root = Path(__file__).parent
    tests_dir = root / "tests"
    # Ensure project root on path for imports
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    # 1) Run unittest-style tests
    suite = unittest.defaultTestLoader.discover(str(tests_dir))
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    overall_ok = result.wasSuccessful()

    # 2) Run plain function tests (pytest-style) if any
    print("\nRunning function-style tests (test_* functions)...")
    func_failures = 0
    func_count = 0
    for mod_name, fn, import_err in _discover_function_tests(tests_dir):
        if import_err is not None:
            func_failures += 1
            continue
        if fn is None:
            continue
        func_count += 1
        try:
            fn()
            print(f"OK  - {mod_name}.{fn.__name__}")
        except AssertionError as e:
            func_failures += 1
            print(f"FAIL- {mod_name}.{fn.__name__}: {e}")
        except Exception as e:
            func_failures += 1
            print(f"ERR - {mod_name}.{fn.__name__}: {e}")

    if func_count == 0:
        print("No function-style tests found.")

    return 0 if (overall_ok and func_failures == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
