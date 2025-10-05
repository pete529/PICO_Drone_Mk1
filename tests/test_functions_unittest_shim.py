"""Shim to allow unittest discovery to run function-style tests.

This module scans the tests directory for modules named test_*.py and wraps any
module-level functions starting with 'test' into unittest.TestCase methods so
that `python -m unittest discover` runs them.
"""
from __future__ import annotations

import importlib.util
import inspect
import types
import unittest
from pathlib import Path


def _iter_function_tests(tests_dir: Path):
    for py in sorted(tests_dir.glob("test_*.py")):
        # Skip this shim file to avoid importing itself
        if py.name == Path(__file__).name:
            continue
        spec = importlib.util.spec_from_file_location(py.stem, py)
        if spec and spec.loader:  # type: ignore[attr-defined]
            mod = importlib.util.module_from_spec(spec)
            try:
                spec.loader.exec_module(mod)  # type: ignore[assignment]
            except Exception as e:
                # Represent import errors as a failing test case per-module
                yield (py.stem, None, e)
                continue
            for name, obj in inspect.getmembers(mod):
                if name.startswith("test") and isinstance(obj, types.FunctionType):
                    # Only top-level module functions
                    if obj.__qualname__ == obj.__name__:
                        yield (py.stem, obj, None)


# Dynamically construct a TestCase at import time so unittest can discover it
class FunctionStyleTests(unittest.TestCase):
    pass


def _attach_tests():
    tests_dir = Path(__file__).parent
    for mod_name, fn, import_err in _iter_function_tests(tests_dir):
        if import_err is not None:
            # Create a test that fails with the import error when run
            def _make_import_test(err: Exception, module_name: str):
                def test(self):
                    raise AssertionError(f"Import failed for {module_name}: {err}")
                return test
            test_name = f"test_import_{mod_name}"
            setattr(FunctionStyleTests, test_name, _make_import_test(import_err, mod_name))
            continue
        if fn is None:
            continue

        # Bind function into a method that just calls it
        def _make_fn_test(func: types.FunctionType, module_name: str):
            def test(self):
                func()
            return test

        safe_fn_name = fn.__name__
        test_name = f"test_{mod_name}__{safe_fn_name}"
        # Avoid accidental overwrite
        if hasattr(FunctionStyleTests, test_name):
            i = 2
            base = test_name
            while hasattr(FunctionStyleTests, f"{base}_{i}"):
                i += 1
            test_name = f"{base}_{i}"
        setattr(FunctionStyleTests, test_name, _make_fn_test(fn, mod_name))


_attach_tests()
