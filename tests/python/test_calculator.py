"""Tests for calculator module."""

from calculator import add, subtract


def test_add() -> None:
    """Verify addition."""
    assert add(2, 3) == 5
    assert add(-1, 1) == 0


def test_subtract() -> None:
    """Verify subtraction."""
    assert subtract(5, 3) == 2
    assert subtract(0, 0) == 0
