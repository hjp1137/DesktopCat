"""
DesktopCat - Unified Perception Runner (T14)
同时启动并管理 Window Perception Service 与 UI Automation Perception Service。
支持多感知服务职责分离且共存运行。
"""

import threading
import time
import os
import sys

# 动态确保项目根目录在 sys.path 中
_ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _ROOT_DIR not in sys.path:
    sys.path.insert(0, _ROOT_DIR)

from tools.perception import desktop_dpi
from tools.perception.window_perception import WindowPerceptionService
from tools.perception.ui_automation_perception import UIAutomationPerceptionService
from tools.perception.visual_perception import VisualPerceptionService
from tools.perception.cat_physics_compiler import ScreenPhysicsCompilerService

_context_lock = threading.Lock()
_shared_context = {"windows": [], "ui_elements": [],
                   "windows_screen": {}, "ui_elements_screen": {}}

def _cache_semantic_snapshot(kind, items, screen):
    sx = float(screen.get("x", 0)); sy = float(screen.get("y", 0))
    global_items = [dict(item, x=float(item.get("x", 0)) + sx,
                         y=float(item.get("y", 0)) + sy) for item in items]
    with _context_lock:
        _shared_context[kind] = global_items
        _shared_context[kind + "_screen"] = dict(screen)

def _get_semantic_context(work_area):
    with _context_lock:
        screen_index = int(work_area.get("screen", 0))
        ui = list(_shared_context["ui_elements"]) if int(
            _shared_context["ui_elements_screen"].get("index", -1)) == screen_index else []
        windows = list(_shared_context["windows"]) if int(
            _shared_context["windows_screen"].get("index", -1)) == screen_index else []
        return ui, windows

def run_t25_compiler_service():
    print("[UnifiedPerception] Starting T25 ScreenPhysicsCompilerService (猫眼物理世界)...")
    svc = ScreenPhysicsCompilerService(context_provider=_get_semantic_context)
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] T25 ScreenPhysicsCompilerService exited: {e}")

def run_window_service():
    print("[UnifiedPerception] Starting WindowPerceptionService...")
    svc = WindowPerceptionService(snapshot_sink=_cache_semantic_snapshot)
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] WindowPerceptionService exited: {e}")

def run_uia_service():
    print("[UnifiedPerception] Starting UIAutomationPerceptionService...")
    svc = UIAutomationPerceptionService(snapshot_sink=_cache_semantic_snapshot)
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] UIAutomationPerceptionService exited: {e}")

def run_visual_service():
    print("[UnifiedPerception] Starting VisualPerceptionService...")
    svc = VisualPerceptionService()
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] VisualPerceptionService exited: {e}")

import ctypes
from ctypes import wintypes, c_void_p, POINTER, WINFUNCTYPE, c_int, c_long, Structure, byref
import socket
import json

user32 = ctypes.windll.user32

class SmartMousePassthroughController:
    """
    方案 1A: Win32 智能动态穿透守护器
    利用 WS_EX_TRANSPARENT 实现：
    1. 全屏发光台阶与攀爬立柱时时刻刻直接完整显示在桌面上，绝不进行 Region 裁剪；
    2. 鼠标未触碰小猫时，系统级 100% 穿透到底层应用，打字、网页浏览毫不受限；
    3. 鼠标靠近小猫身体时（<= 55px），瞬间解除穿透，小猫可正常抚摸、拖拽与交互。
    """
    def __init__(self, host="127.0.0.1", port=47831):
        self.host = host
        self.port = port
        self.godot_hwnd = None
        self.cat_gx = -1000.0
        self.cat_gy = -1000.0
        self.is_transparent = False

    def _ensure_godot_hwnd(self):
        if self.godot_hwnd and user32.IsWindow(self.godot_hwnd):
            return
        def cb(h, _):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(h, buf, 256)
            if buf.value == "Godot_Engine":
                self.godot_hwnd = h
                return 0
            return 1
        user32.EnumWindows(WINFUNCTYPE(c_int, c_void_p, c_void_p)(cb), 0)

    def set_passthrough(self, enable: bool):
        if not self.godot_hwnd or not user32.IsWindow(self.godot_hwnd):
            return
        # GWL_EXSTYLE = -20, WS_EX_TRANSPARENT = 0x20
        style = user32.GetWindowLongW(self.godot_hwnd, -20)
        if enable and not (style & 0x20):
            user32.SetWindowLongW(self.godot_hwnd, -20, style | 0x20)
            self.is_transparent = True
        elif not enable and (style & 0x20):
            user32.SetWindowLongW(self.godot_hwnd, -20, style & ~0x20)
            self.is_transparent = False

    def run(self):
        print("[SmartPassthrough] Win32 智能动态穿透守护器已就绪 (方案 1A)")
        sock = None
        reader = None
        last_query_t = 0.0

        while True:
            self._ensure_godot_hwnd()
            now = time.perf_counter()

            # 保持状态更新连接 (每 100ms 查询一次小猫物理坐标)
            if (now - last_query_t) >= 0.10:
                last_query_t = now
                try:
                    if not sock:
                        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                        sock.connect((self.host, self.port))
                        reader = sock.makefile("r", encoding="utf-8")
                    msg = json.dumps({"v": 1, "type": "get_status"}) + "\n"
                    sock.sendall(msg.encode("utf-8"))
                    line = reader.readline()
                    if line:
                        res = json.loads(line.strip())
                        cat_info = res.get("cat", {})
                        scr_info = res.get("screen", {})
                        sx = float(scr_info.get("x", 0.0))
                        sy = float(scr_info.get("y", 0.0))
                        cx = float(cat_info.get("x", -1000.0))
                        cy = float(cat_info.get("y", -1000.0))
                        self.cat_gx = sx + cx
                        self.cat_gy = sy + cy
                except Exception:
                    if sock: sock.close()
                    sock = None
                    reader = None

            # 40Hz 实时全局鼠标距离判定
            if self.godot_hwnd and self.cat_gx > -500.0:
                pt = wintypes.POINT()
                user32.GetCursorPos(byref(pt))
                dx = abs(pt.x - self.cat_gx)
                dy = abs(pt.y - self.cat_gy)
                if dx <= 55.0 and dy <= 55.0:
                    # 鼠标靠近小猫，解除穿透，允许交互
                    self.set_passthrough(False)
                elif dx > 65.0 or dy > 65.0:
                    # 鼠标离开小猫，开启系统级全屏穿透，无阻碍打字与浏览
                    self.set_passthrough(True)

            time.sleep(0.025)

def run_passthrough_service():
    ctrl = SmartMousePassthroughController()
    try:
        ctrl.run()
    except Exception as e:
        print(f"[SmartPassthrough] Controller exited: {e}")

def main():
    print("==================================================")
    print("DesktopCat - Unified Perception Service (T25)")
    print("托管: Window (10Hz) + UIA (2Hz) + Visual (3Hz) + T25猫眼物理编译器 (5Hz)")
    print("全局快捷键:")
    print("  [F7] T25 猫眼物理世界总开关 | [Ctrl+Alt+1~7] 切换调试图层")
    print("  [F6 / Ctrl+Alt+8] 切换感知路线 (A:Legacy / B:OpenCV / C:Hybrid)")
    print("  [F8] 窗口 | [F9/V] 物理表面 | [F10] 接触点 | [F11] UI控件 | [F12] 视觉几何")
    print("==================================================")

    t_win = threading.Thread(target=run_window_service, daemon=True)
    t_uia = threading.Thread(target=run_uia_service, daemon=True)
    t_vis = threading.Thread(target=run_visual_service, daemon=True)
    t_t25 = threading.Thread(target=run_t25_compiler_service, daemon=True)

    t_win.start()
    time.sleep(0.2)
    t_uia.start()
    time.sleep(0.2)
    t_vis.start()
    time.sleep(0.2)
    t_t25.start()

    
    try:
        while True:
            time.sleep(1.0)
    except KeyboardInterrupt:
        print("\n[UnifiedPerception] Stopping all perception services...")

if __name__ == "__main__":
    main()
