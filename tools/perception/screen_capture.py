"""Windows 桌面采集：显式声明指针宽度，并检查每次 GDI 调用。"""
import ctypes
from ctypes import wintypes as wt
from tools.perception import desktop_dpi

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)


class BitmapInfo(ctypes.Structure):
    _fields_ = [("size", wt.DWORD), ("width", wt.LONG), ("height", wt.LONG),
                ("planes", wt.WORD), ("bits", wt.WORD), ("compression", wt.DWORD),
                ("image_size", wt.DWORD), ("xppm", wt.LONG), ("yppm", wt.LONG),
                ("colors", wt.DWORD), ("important", wt.DWORD)]


user32.GetDC.argtypes = [wt.HWND]
user32.GetDC.restype = wt.HDC
user32.ReleaseDC.argtypes = [wt.HWND, wt.HDC]
gdi32.CreateCompatibleDC.argtypes = [wt.HDC]
gdi32.CreateCompatibleDC.restype = wt.HDC
gdi32.CreateCompatibleBitmap.argtypes = [wt.HDC, ctypes.c_int, ctypes.c_int]
gdi32.CreateCompatibleBitmap.restype = wt.HBITMAP
gdi32.SelectObject.argtypes = [wt.HDC, wt.HANDLE]
gdi32.SelectObject.restype = wt.HANDLE
gdi32.DeleteObject.argtypes = [wt.HANDLE]
gdi32.DeleteDC.argtypes = [wt.HDC]
gdi32.SetStretchBltMode.argtypes = [wt.HDC, ctypes.c_int]
gdi32.StretchBlt.argtypes = [wt.HDC] + [ctypes.c_int] * 4 + [wt.HDC] + [ctypes.c_int] * 4 + [wt.DWORD]
gdi32.GetDIBits.argtypes = [wt.HDC, wt.HBITMAP, wt.UINT, wt.UINT,
                           ctypes.c_void_p, ctypes.c_void_p, wt.UINT]


def capture_bgra(sx, sy, sw, sh, dw=None, dh=None):
    """返回 top-down BGRA。调用方负责排除自身窗口的显示捕获。"""
    dw = sw if dw is None else dw
    dh = sh if dh is None else dh
    if min(sw, sh, dw, dh) <= 0:
        raise ValueError("截图区域及输出尺寸必须为正数")
    screen = user32.GetDC(None)
    if not screen:
        raise ctypes.WinError(ctypes.get_last_error())
    memory = bitmap = previous = None
    try:
        memory = gdi32.CreateCompatibleDC(screen)
        if not memory:
            raise ctypes.WinError(ctypes.get_last_error())
        bitmap = gdi32.CreateCompatibleBitmap(screen, dw, dh)
        if not bitmap:
            raise ctypes.WinError(ctypes.get_last_error())
        previous = gdi32.SelectObject(memory, bitmap)
        if not previous or previous == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        if not gdi32.SetStretchBltMode(memory, 3):
            raise ctypes.WinError(ctypes.get_last_error())
        if not gdi32.StretchBlt(memory, 0, 0, dw, dh, screen, sx, sy, sw, sh, 0x00CC0020):
            raise ctypes.WinError(ctypes.get_last_error())
        # GetDIBits 要求目标位图不被选入 DC。
        gdi32.SelectObject(memory, previous)
        previous = None
        info = BitmapInfo(ctypes.sizeof(BitmapInfo), dw, -dh, 1, 32)
        buffer = (ctypes.c_ubyte * (dw * dh * 4))()
        if gdi32.GetDIBits(memory, bitmap, 0, dh, buffer, ctypes.byref(info), 0) != dh:
            raise OSError("GetDIBits 未返回完整截图")
        return bytes(buffer)
    finally:
        if previous:
            gdi32.SelectObject(memory, previous)
        if bitmap:
            gdi32.DeleteObject(bitmap)
        if memory:
            gdi32.DeleteDC(memory)
        user32.ReleaseDC(None, screen)
