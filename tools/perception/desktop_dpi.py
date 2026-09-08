"""Match Godot's Windows system-DPI desktop coordinates before using Win32."""
import ctypes

user32 = ctypes.WinDLL("user32", use_last_error=True)
user32.GetThreadDpiAwarenessContext.restype = ctypes.c_void_p
user32.GetAwarenessFromDpiAwarenessContext.argtypes = [ctypes.c_void_p]
user32.SetProcessDPIAware()
if user32.GetAwarenessFromDpiAwarenessContext(
        user32.GetThreadDpiAwarenessContext()) != 1:
    raise RuntimeError("DesktopCat perception requires a fresh system-DPI-aware process")
