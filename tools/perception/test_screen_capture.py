import unittest
from unittest.mock import patch

from tools.perception.screen_capture import capture_bgra, gdi32


class ScreenCaptureTests(unittest.TestCase):
    def test_capture_uses_godot_system_dpi_coordinates(self):
        import ctypes
        api = ctypes.windll.user32
        api.GetThreadDpiAwarenessContext.restype = ctypes.c_void_p
        api.GetAwarenessFromDpiAwarenessContext.argtypes = [ctypes.c_void_p]
        self.assertEqual(api.GetAwarenessFromDpiAwarenessContext(
            api.GetThreadDpiAwarenessContext()), 1)

    def test_real_desktop_returns_full_bgra_frame(self):
        self.assertEqual(len(capture_bgra(0, 0, 160, 100, 80, 50)), 80 * 50 * 4)

    def test_failed_transfer_is_reported_instead_of_black_image(self):
        with patch.object(gdi32, "StretchBlt", return_value=0):
            with self.assertRaises(OSError):
                capture_bgra(0, 0, 160, 100)

    def test_partial_read_is_reported(self):
        with patch.object(gdi32, "GetDIBits", return_value=1):
            with self.assertRaisesRegex(OSError, "GetDIBits"):
                capture_bgra(0, 0, 160, 100)


if __name__ == "__main__":
    unittest.main()
