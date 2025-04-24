import pytest

import git


class Test:

    def test_execute_command(self):
        res, out = git.execute_command("ls")
        assert len(out) < 1 and len(res) > 0, "Expected output with no errors"

    def test_apply_check_simple(self):
        res, out = git.apply_check("0001-Test-patch.patch", "tests/data")
        assert res is True, "A simple patch should work correctly"

    def test_apply_check_complex(self):
        res, out = git.apply_check("0002-Complex-file-patch.patch", "tests/data")
        assert res is False and len(out) > 0, "A complex patch should not work so easily"
