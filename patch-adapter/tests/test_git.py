import pytest


class Test:

    def test_execute_command(self, git):
        res, out = git.execute_command("ls")
        assert len(out) < 1 and len(res) > 0, "Expected output with no errors"

    def test_apply_check_simple(self, git):
        res, out = git.apply_check("0001-Test-patch.patch")
        assert res is True, "A simple patch should work correctly"

    def test_apply_check_complex(self, git):
        res, out = git.apply_check("0002-Complex-file-patch.patch")
        assert res is False and len(out) > 0, "A complex patch should not work so easily"

    def test_apply_simple(self, git):
        res, out = git.apply("0001-Test-patch.patch")
        assert res is True, "A simple patch should work correctly"
        res, out = git.apply_R("0001-Test-patch.patch")
        assert res is True

    def test_apply_complex(self, git):
        res, out = git.apply("0002-Complex-file-patch.patch")
        assert res is False and len(out) > 0, "A complex patch should not work so easily"
