#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DesktopCat Windows Window Geometry Perception Service (T11)
Uses Python Standard Library + ctypes only. No 3rd-party dependencies.
"""
import ctypes
from ctypes import wintypes
import time

user32 = ctypes.windll.user32
dwmapi = ctypes.windll.dwmapi
kernel32 = ctypes.windll.kernel32

DWMWA_EXTENDED_FRAME_BOUNDS = 9
WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

class MONITORINFO(ctypes.Structure):
    _fields_ = [
        ('cbSize', wintypes.DWORD),
        ('rcMonitor', wintypes.RECT),
        ('rcWork', wintypes.RECT),
        ('dwFlags', wintypes.DWORD)
    ]

class WindowScanner:
    def __init__(self, godot_hwnd: int = 0):
        self.godot_hwnd = godot_hwnd
        self.console_hwnd = kernel32.GetConsoleWindow()
        h_desk = user32.OpenDesktopW("Default", 0, False, 0x01FF)
        if h_desk:
            user32.SetThreadDesktop(h_desk)

    def get_window_rect(self, hwnd: int):
        rect = wintypes.RECT()
        hr = dwmapi.DwmGetWindowAttribute(
            wintypes.HWND(hwnd),
            wintypes.DWORD(DWMWA_EXTENDED_FRAME_BOUNDS),
            ctypes.byref(rect),
            ctypes.sizeof(rect)
        )
        if hr != 0:
            user32.GetWindowRect(wintypes.HWND(hwnd), ctypes.byref(rect))
        return rect.left, rect.top, rect.right, rect.bottom

    def get_window_text(self, hwnd: int) -> str:
        length = user32.GetWindowTextLengthW(wintypes.HWND(hwnd))
        if length <= 0: return ""
        buf = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(wintypes.HWND(hwnd), buf, length + 1)
        return buf.value

    def get_class_name(self, hwnd: int) -> str:
        buf = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(wintypes.HWND(hwnd), buf, 256)
        return buf.value

    def scan_windows(self, scr_left: int, scr_top: int, scr_w: int, scr_h: int, overlay_w: int = 0, overlay_h: int = 0):
        windows = []
        fg_hwnd = user32.GetForegroundWindow()
        
        # 优先通过小猫窗口获取当前显示器实际物理工作区
        sx, sy, sw, sh = scr_left, scr_top, scr_w, scr_h
        if self.godot_hwnd:
            mi = MONITORINFO(); mi.cbSize = ctypes.sizeof(MONITORINFO)
            h_mon = user32.MonitorFromWindow(self.godot_hwnd, 2)
            if h_mon and user32.GetMonitorInfoW(h_mon, ctypes.byref(mi)):
                sx = mi.rcWork.left; sy = mi.rcWork.top
                sw = mi.rcWork.right - sx; sh = mi.rcWork.bottom - sy

        scale_x = (float(overlay_w) / sw) if (overlay_w > 0 and sw > 0) else 1.0
        scale_y = (float(overlay_h) / sh) if (overlay_h > 0 and sh > 0) else 1.0

        def enum_handler(hwnd, _lparam):
            if not user32.IsWindowVisible(hwnd): return 1
            if user32.IsIconic(hwnd): return 1
            if hwnd == self.console_hwnd or hwnd == self.godot_hwnd: return 1
            
            cname = self.get_class_name(hwnd)
            if cname in ("Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd", "Windows.UI.Core.CoreWindow"):
                return 1
            title = self.get_window_text(hwnd)
            if "DesktopCat" in title or cname == "Godot_Engine":
                return 1

            wl, wt, wr, wb = self.get_window_rect(hwnd)
            if wr - wl <= 32 or wb - wt <= 32: return 1

            il = max(wl, sx); it = max(wt, sy)
            ir = min(wr, sx + sw); ib = min(wb, sy + sh)
            if ir <= il or ib <= it: return 1

            lx = round((il - sx) * scale_x, 1)
            ly = round((it - sy) * scale_y, 1)
            lw = round((ir - il) * scale_x, 1)
            lh = round((ib - it) * scale_y, 1)
            if lw <= 0 or lh <= 0: return 1

            windows.append({
                "id": f"0x{hwnd:08X}",
                "title": title[:32],
                "class_name": cname[:32],
                "x": lx,
                "y": ly,
                "width": lw,
                "height": lh,
                "is_foreground": (hwnd == fg_hwnd),
                "z_order": len(windows)
            })
            return 1

        cb = ctypes.WINFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)(enum_handler)
        user32.EnumWindows(cb, 0)
        return windows



import socket
import json
import sys

class WindowPerceptionService:
    def __init__(self, host: str = "127.0.0.1", port: int = 47831):
        self.host = host
        self.port = port
        self.sock = None
        self.scanner = WindowScanner()
        self.revision = 0
        self.last_keys = None
        self.screen_info = {"index": 0, "x": 0, "y": 0, "width": 1920, "height": 1080}
        self.overlay_info = {"width": 1920, "height": 1080}
        self.hotkey_states = {}

    def connect(self) -> bool:
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(3.0)
            self.sock.connect((self.host, self.port))
            hello_raw = self._recv_line()
            if hello_raw:
                hello = json.loads(hello_raw)
                scr = hello.get("screen", {})
                if scr: self.screen_info = scr
                ov = hello.get("overlay", {})
                if ov: self.overlay_info = ov
                wh = hello.get("window_handle", "")
                if wh and wh.startswith("0x"):
                    self.scanner.godot_hwnd = int(wh, 16)
                self.revision = int(hello.get("latest_revision", 0))
            self._update_status()
            self._ensure_godot_hwnd()
            print(f"[Perception] Connected to DesktopCat ({self.host}:{self.port}), Screen {self.screen_info.get('index', 0)}")
            print("[Perception] 提示: 按 [-]/[V] 窗口外框(F8)，按 [=]/[B] 物理表面(F9)，按 [N]/[M] 物理接触点与站立表面(F10)！")
            return True




        except Exception as e:
            if self.sock: self.sock.close()
            self.sock = None
            return False

    def _ensure_godot_hwnd(self):
        if not self.scanner.godot_hwnd or not user32.IsWindow(self.scanner.godot_hwnd):
            def cb(hwnd, _):
                buf = ctypes.create_unicode_buffer(256)
                user32.GetWindowTextW(hwnd, buf, 256)
                if "DesktopCat" in buf.value:
                    self.scanner.godot_hwnd = hwnd
                    return 0
                return 1
            user32.EnumWindows(ctypes.WINFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)(cb), 0)

    def _send_msg(self, msg: dict):
        if not self.sock: return
        data = (json.dumps(msg) + "\n").encode("utf-8")
        self.sock.sendall(data)

    def _recv_line(self) -> str:
        if not self.sock: return ""
        buf = ""
        while "\n" not in buf:
            chunk = self.sock.recv(4096)
            if not chunk: return ""
            buf += chunk.decode("utf-8", errors="replace")
        line, _ = buf.split("\n", 1)
        return line.strip()

    def _update_status(self):
        self._send_msg({"v": 1, "type": "get_status"})
        st_raw = self._recv_line()
        if st_raw:
            st = json.loads(st_raw)
            scr = st.get("screen", {})
            if scr and scr.get("index") != self.screen_info.get("index"):
                print(f"[Perception] Screen changed to {scr.get('index')}")
                self.screen_info = scr
                self.last_keys = None
            ov = st.get("overlay", {})
            if ov: self.overlay_info = ov

    def run(self):
        print("[Perception] Starting Window Perception Service (5Hz)...")
        tick = 0
        wait_logged = False
        while True:
            if not self.sock:
                if not self.connect():
                    if not wait_logged:
                        print(f"[Perception] 正在等待 DesktopCat 启动 (未检测到 127.0.0.1:{self.port} 服务，请启动 DesktopCat_Standalone.exe)...")
                        wait_logged = True
                    time.sleep(2.0)
                    continue
                wait_logged = False

            try:
                tick += 1
                if tick % 10 == 0: self._update_status()
                sx = self.screen_info.get("x", 0); sy = self.screen_info.get("y", 0)
                sw = self.screen_info.get("width", 1920); sh = self.screen_info.get("height", 1080)
                ow = self.overlay_info.get("width", sw); oh = self.overlay_info.get("height", sh)
                windows = self.scanner.scan_windows(sx, sy, sw, sh, ow, oh)
                keys = [(w["id"], w["x"], w["y"], w["width"], w["height"], w["is_foreground"]) for w in windows]
                if keys != self.last_keys:
                    self.revision += 1
                    self.last_keys = keys
                    pkt = {
                        "v": 1,
                        "type": "window_snapshot",
                        "revision": self.revision,
                        "screen": {"index": self.screen_info.get("index", 0), "width": ow, "height": oh},
                        "windows": windows
                    }
                    self._send_msg(pkt)
                    self._recv_line()
                    print(f"[Perception] Window snapshot revision {self.revision}: {len(windows)} windows")
                self._check_global_hotkeys()
                time.sleep(0.1)
                self._check_global_hotkeys()
                time.sleep(0.1)
            except Exception as e:
                print(f"[Perception] Connection error: {e}, reconnecting in 2s...")
                if self.sock: self.sock.close()
                self.sock = None
                self.last_keys = None
                time.sleep(2.0)

    def _check_global_hotkeys(self):
        hotkeys_win = {0x77: "F8", 0xBD: "减号键(-)", 0x56: "V"}
        hotkeys_surf = {0x78: "F9", 0xBB: "等号键(=)", 0x42: "B"}
        for vk, name in hotkeys_win.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【窗口几何】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_WINDOWS"})
                self._recv_line()
        for vk, name in hotkeys_surf.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【Surface 物理表面】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_SURFACES"})
                self._recv_line()
        hotkeys_phys = {0x79: "F10", 0x4E: "N", 0x4D: "M"}
        for vk, name in hotkeys_phys.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【Cat 物理接触点与表面高亮】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_PHYSICS"})
                self._recv_line()
        hotkeys_ui = {0x7A: "F11", 0x4B: "K", 0x4F: "O"}
        for vk, name in hotkeys_ui.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【UI Automation 控件几何】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_UI"})
                self._recv_line()
        hotkeys_vis = {0x7B: "F12", 0x4A: "J"}
        for vk, name in hotkeys_vis.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【Visual Geometry 视觉几何】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_VISUAL"})
                self._recv_line()
        hotkeys_fusion = {0x48: "H", 0x59: "Y"}
        for vk, name in hotkeys_fusion.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Perception] 检测到快捷键 [{name}]，切换【Unified Surface Fusion 融合诊断】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_FUSION"})
                self._recv_line()
        hotkeys_nav = {0x47: "G", 0x54: "T"}
        for vk, name in hotkeys_nav.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                if name == "G":
                    print(f"[Perception] 检测到快捷键 [{name}]，切换【Platform Navigation Graph 平台导航图】调试线框...")
                    self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_NAV"})
                else:
                    print(f"[Perception] 检测到快捷键 [{name}]，输出当前平台导航可达摘要...")
                    self._send_msg({"v": 1, "type": "command", "name": "NAV"})
                self._recv_line()
        hotkeys_traversal = {0x58: "X", 0x50: "P"}
        for vk, name in hotkeys_traversal.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                if name == "X":
                    print(f"[Perception] 检测到快捷键 [{name}]，切换【F15 自主跳跃规划】调试线框...")
                    self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_TRAVERSAL"})
                else:
                    print(f"[Perception] 检测到快捷键 [{name}]，触发一次【自主跳跃规划】...")
                    self._send_msg({"v": 1, "type": "command", "name": "PLAN_TRAVERSAL"})
                self._recv_line()










if __name__ == "__main__":
    service = WindowPerceptionService()
    try: service.run()
    except KeyboardInterrupt: print("\n[Perception] Stopped.")

