"""
DesktopCat - Visual Geometry Perception Service (T15)
基于原生 Windows GDI + 降采样灰度梯度分析，提取纯几何 LINE 与 RECT。
零第三方依赖、低频扫描、静态页面跳过、不落盘、不传像素。
"""

import ctypes
from ctypes import wintypes, c_void_p, POINTER, Structure, byref, WINFUNCTYPE, c_int, c_uint8
import socket
import json
import time
import sys

try:
    import numpy as np
    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False

from tools.perception.visual_perception_config import (

    SCAN_HZ, MAX_SCAN_HZ, ANALYSIS_SCALE, SCREEN_CHANGE_THRESHOLD,
    EDGE_THRESHOLD, MIN_VISUAL_LINE_LENGTH, LINE_MERGE_Y_TOLERANCE,
    LINE_MERGE_GAP, MIN_VISUAL_RECT_WIDTH, MIN_VISUAL_RECT_HEIGHT,
    GEOMETRY_QUANTIZATION, APPEAR_CONFIRM_COUNT, DISAPPEAR_CONFIRM_COUNT,
    MAX_VISUAL_GEOMETRIES
)

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

h_def = user32.OpenDesktopW("default", 0, False, 0x01FF)
if h_def:
    user32.SetThreadDesktop(h_def)

class BITMAPINFOHEADER(Structure):
    _fields_ = [
        ("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG),
        ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
        ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG),
        ("biYPelsPerMeter", wintypes.LONG), ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD)
    ]

class MONITORINFO(Structure):
    _fields_ = [("cbSize", wintypes.DWORD), ("rcMonitor", wintypes.RECT), ("rcWork", wintypes.RECT), ("dwFlags", wintypes.DWORD)]

class VisualGeometryDetector:
    def __init__(self):
        self.hdc_screen = user32.GetDC(0)
        self.hdc_mem = gdi32.CreateCompatibleDC(self.hdc_screen)
        gdi32.SetStretchBltMode(self.hdc_mem, 3) # COLORONCOLOR
        self.cur_bm_w = 0
        self.cur_bm_h = 0
        self.hbm = None
        self.raw_buf = None
        self.bmi = BITMAPINFOHEADER()
        self.bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
        self.bmi.biPlanes = 1
        self.bmi.biBitCount = 32
        self.bmi.biCompression = 0
        self.last_fingerprint = None

    def __del__(self):
        if self.hbm: gdi32.DeleteObject(self.hbm)
        if self.hdc_mem: gdi32.DeleteDC(self.hdc_mem)
        if self.hdc_screen: user32.ReleaseDC(0, self.hdc_screen)

    def _ensure_buffer(self, w: int, h: int):
        if w != self.cur_bm_w or h != self.cur_bm_h or not self.hbm:
            if self.hbm: gdi32.DeleteObject(self.hbm)
            self.cur_bm_w = w; self.cur_bm_h = h
            self.hbm = gdi32.CreateCompatibleBitmap(self.hdc_screen, w, h)
            gdi32.SelectObject(self.hdc_mem, self.hbm)
            self.bmi.biWidth = w
            self.bmi.biHeight = -h # top-down
            self.raw_buf = (c_uint8 * (w * h * 4))()

    def capture_downsampled_lum(self, sx: int, sy: int, sw: int, sh: int, dw: int, dh: int):
        if sw <= 0 or sh <= 0 or dw <= 0 or dh <= 0: return None
        self._ensure_buffer(dw, dh)
        gdi32.StretchBlt(self.hdc_mem, 0, 0, dw, dh, self.hdc_screen, sx, sy, sw, sh, 0x00CC0020)
        gdi32.GetDIBits(self.hdc_mem, self.hbm, 0, dh, ctypes.byref(self.raw_buf), ctypes.byref(self.bmi), 0)
        # Fast BGRA -> Luminance conversion: lum = (B*29 + G*150 + R*77) >> 8
        raw = bytes(self.raw_buf)
        lum = bytearray(dw * dh)
        for i in range(dw * dh):
            idx = i * 4
            lum[i] = (raw[idx] * 29 + raw[idx + 1] * 150 + raw[idx + 2] * 77) >> 8
        return lum

    def check_screen_changed(self, lum: bytearray, w: int, h: int, gw: int = 32, gh: int = 18) -> bool:
        if not lum or w <= 0 or h <= 0: return False
        step_x = max(1, w // gw); step_y = max(1, h // gh)
        fp = []
        for gy in range(gh):
            y = min(h - 1, gy * step_y)
            row_offset = y * w
            for gx in range(gw):
                x = min(w - 1, gx * step_x)
                fp.append(lum[row_offset + x])
        if self.last_fingerprint is None or len(self.last_fingerprint) != len(fp):
            self.last_fingerprint = fp
            return True
        diff_sum = sum(abs(a - b) for a, b in zip(fp, self.last_fingerprint))
        avg_diff = diff_sum / len(fp)
        if avg_diff >= SCREEN_CHANGE_THRESHOLD:
            self.last_fingerprint = fp
            return True
        return False

    def detect_geometry(self, lum: bytearray, dw: int, dh: int, scale_inv: float):
        if not lum or dw < 4 or dh < 4:
            return [], [], []

        min_pts = max(4, int(MIN_VISUAL_LINE_LENGTH / scale_inv))
        h_lines = []
        v_lines = []
        if HAVE_NUMPY:
            arr = np.frombuffer(lum, dtype=np.uint8).reshape((dh, dw))
            h_diff = np.abs(arr[:-1, :].astype(np.int16) - arr[1:, :].astype(np.int16)) >= EDGE_THRESHOLD
            for y in range(dh - 1):
                row = h_diff[y]
                if not np.any(row): continue
                idx = np.where(row)[0]
                if len(idx) < min_pts: continue
                splits = np.where(np.diff(idx) > 1)[0]
                starts = np.insert(idx[splits + 1], 0, idx[0])
                ends = np.append(idx[splits], idx[-1])
                for s, e in zip(starts, ends):
                    if (e - s + 1) >= min_pts: h_lines.append((y, int(s), int(e)))

            v_diff = np.abs(arr[:, :-1].astype(np.int16) - arr[:, 1:].astype(np.int16)) >= EDGE_THRESHOLD
            for x in range(dw - 1):
                col = v_diff[:, x]
                if not np.any(col): continue
                idx = np.where(col)[0]
                if len(idx) < min_pts: continue
                splits = np.where(np.diff(idx) > 1)[0]
                starts = np.insert(idx[splits + 1], 0, idx[0])
                ends = np.append(idx[splits], idx[-1])
                for s, e in zip(starts, ends):
                    if (e - s + 1) >= min_pts: v_lines.append((x, int(s), int(e)))
        else:
            for y in range(0, dh - 1, 2):
                row_c = y * dw; row_n = (y + 1) * dw; x_start = None
                for x in range(0, dw, 2):
                    if abs(lum[row_c + x] - lum[row_n + x]) >= EDGE_THRESHOLD:
                        if x_start is None: x_start = x
                    else:
                        if x_start is not None:
                            if (x - x_start) >= min_pts: h_lines.append((y, x_start, x - 1))
                            x_start = None
                if x_start is not None and (dw - x_start) >= min_pts: h_lines.append((y, x_start, dw - 1))

            for x in range(0, dw - 1, 2):
                y_start = None
                for y in range(0, dh, 2):
                    if abs(lum[y * dw + x] - lum[y * dw + x + 1]) >= EDGE_THRESHOLD:
                        if y_start is None: y_start = y
                    else:
                        if y_start is not None:
                            if (y - y_start) >= min_pts: v_lines.append((x, y_start, y - 1))
                            y_start = None
                if y_start is not None and (dh - y_start) >= min_pts: v_lines.append((x, y_start, dh - 1))

        merged_h = []

        h_lines.sort(key=lambda t: (t[0], t[1]))
        for y, x1, x2 in h_lines:
            merged = False
            for i, (my, mx1, mx2) in enumerate(merged_h):
                if abs(y - my) * scale_inv <= LINE_MERGE_Y_TOLERANCE:
                    if not (x2 * scale_inv < mx1 * scale_inv - LINE_MERGE_GAP or x1 * scale_inv > mx2 * scale_inv + LINE_MERGE_GAP):
                        merged_h[i] = (my, min(x1, mx1), max(x2, mx2))
                        merged = True; break
            if not merged: merged_h.append((y, x1, x2))

        merged_v = []
        v_lines.sort(key=lambda t: (t[0], t[1]))
        for x, y1, y2 in v_lines:
            merged = False
            for i, (mx, my1, my2) in enumerate(merged_v):
                if abs(x - mx) * scale_inv <= LINE_MERGE_Y_TOLERANCE:
                    if not (y2 * scale_inv < my1 * scale_inv - LINE_MERGE_GAP or y1 * scale_inv > my2 * scale_inv + LINE_MERGE_GAP):
                        merged_v[i] = (mx, min(y1, my1), max(y2, my2))
                        merged = True; break
            if not merged: merged_v.append((x, y1, y2))

        rects = []
        for i, (ty, tx1, tx2) in enumerate(merged_h):
            for by, bx1, bx2 in merged_h[i+1:]:
                rh = (by - ty) * scale_inv
                if rh < MIN_VISUAL_RECT_HEIGHT: continue
                ix1 = max(tx1, bx1); ix2 = min(tx2, bx2)
                rw = (ix2 - ix1) * scale_inv
                if rw < MIN_VISUAL_RECT_WIDTH: continue
                has_left = any(abs(vx - ix1) * scale_inv <= 12.0 and vy1 <= ty + 4 and vy2 >= by - 4 for vx, vy1, vy2 in merged_v)
                has_right = any(abs(vx - ix2) * scale_inv <= 12.0 and vy1 <= ty + 4 and vy2 >= by - 4 for vx, vy1, vy2 in merged_v)
                if has_left or has_right:
                    rects.append((ix1, ty, rw, rh))
                    if len(rects) >= 80: break
            if len(rects) >= 80: break

        return merged_h, merged_v, rects

class VisualPerceptionService:
    def __init__(self, host: str = "127.0.0.1", port: int = 47831):
        self.host = host
        self.port = port
        self.sock = None
        self.reader = None
        self.detector = VisualGeometryDetector()
        self.godot_hwnd = None
        self.screen_info = {"index": 0, "width": 1920, "height": 1080}
        self.visual_revision = 0
        self.last_signature = ""
        self.tracked_geometries = {}
        self.hotkey_states = {}
        self.last_stat_time = time.time()
        self.stats = {"cap_ms": 0.0, "chg_ms": 0.0, "det_ms": 0.0, "frames": 0, "skipped": 0, "geoms": 0}

    def _send_msg(self, obj: dict) -> bool:
        if not self.sock: return False
        try:
            line = json.dumps(obj, separators=(',', ':')) + "\n"
            self.sock.sendall(line.encode("utf-8"))
            return True
        except Exception:
            self.sock = None
            return False

    def _recv_line(self) -> dict:
        if not self.reader: return {}
        try:
            line = self.reader.readline()
            if not line: return {}
            return json.loads(line.strip())
        except Exception:
            return {}

    def _update_status(self):
        self._send_msg({"v": 1, "type": "get_status"})
        res = self._recv_line()
        if res.get("type") == "status":
            screen = res.get("screen", {})
            self.screen_info = {
                "index": int(screen.get("index", 0)),
                "width": int(screen.get("width", 1920)),
                "height": int(screen.get("height", 1080))
            }

    def _ensure_godot_hwnd(self):
        def cb(h, _):
            buf = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(h, buf, 256)
            if buf.value == "Godot_Engine":
                self.godot_hwnd = h
                return 0
            return 1
        user32.EnumWindows(WINFUNCTYPE(c_int, c_void_p, c_void_p)(cb), 0)

    def connect(self) -> bool:
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((self.host, self.port))
            self.reader = self.sock.makefile("r", encoding="utf-8")
            self._update_status()
            self._ensure_godot_hwnd()
            print(f"[Visual] Connected to DesktopCat ({self.host}:{self.port}), Screen {self.screen_info.get('index', 0)}")
            print("[Visual] 提示: 按 [F12] 或 [J] 切换【Visual Geometry 视觉几何】调试线框！")
            return True
        except Exception:
            if self.sock: self.sock.close()
            self.sock = None; self.reader = None
            return False

    def _check_global_hotkeys(self):
        # F12: 0x7B, J: 0x4A
        hotkeys = {0x7B: "F12", 0x4A: "J"}
        for vk, name in hotkeys.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[Visual] 检测到快捷键 [{name}]，切换【Visual Geometry 视觉几何】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_VISUAL"})
                self._recv_line()

    def scan_visual_geometry(self):
        t_start = time.perf_counter()
        target_scr = self.screen_info.get("index", 0)
        overlay_w = self.screen_info.get("width", 1920)
        overlay_h = self.screen_info.get("height", 1080)

        sx, sy, sw, sh = 0, 0, 1920, 1080
        if self.godot_hwnd:
            mi = MONITORINFO(); mi.cbSize = ctypes.sizeof(MONITORINFO)
            h_mon = user32.MonitorFromWindow(self.godot_hwnd, 2)
            if h_mon and user32.GetMonitorInfoW(h_mon, ctypes.byref(mi)):
                sx = mi.rcWork.left; sy = mi.rcWork.top
                sw = mi.rcWork.right - sx; sh = mi.rcWork.bottom - sy

        scale_x = (float(overlay_w) / sw) if (overlay_w > 0 and sw > 0) else 1.0
        scale_y = (float(overlay_h) / sh) if (overlay_h > 0 and sh > 0) else 1.0

        # 优先 Foreground Window，剪裁到当前屏幕
        fg_hwnd = user32.GetForegroundWindow()
        cap_x, cap_y, cap_w, cap_h = sx, sy, sw, sh
        if fg_hwnd and user32.IsWindowVisible(fg_hwnd) and not user32.IsIconic(fg_hwnd) and fg_hwnd != self.godot_hwnd:
            rect = wintypes.RECT()
            user32.GetWindowRect(fg_hwnd, byref(rect))
            il = max(rect.left, sx); it = max(rect.top, sy)
            ir = min(rect.right, sx + sw); ib = min(rect.bottom, sy + sh)
            if (ir - il) >= 120 and (ib - it) >= 100:
                cap_x, cap_y, cap_w, cap_h = il, it, ir - il, ib - it

        # 降采样目标尺寸
        dw = max(16, int(cap_w * ANALYSIS_SCALE))
        dh = max(16, int(cap_h * ANALYSIS_SCALE))

        # 1. 屏幕捕获并降采样灰度化
        t0 = time.perf_counter()
        lum = self.detector.capture_downsampled_lum(cap_x, cap_y, cap_w, cap_h, dw, dh)
        t_cap = (time.perf_counter() - t0) * 1000

        # 2. 画面变化检测
        t1 = time.perf_counter()
        changed = self.detector.check_screen_changed(lum, dw, dh)
        t_chg = (time.perf_counter() - t1) * 1000

        t_det = 0.0
        current_frame_geoms = {}
        if changed and lum:
            t2 = time.perf_counter()
            scale_inv = 1.0 / ANALYSIS_SCALE
            m_h, m_v, rects = self.detector.detect_geometry(lum, dw, dh, scale_inv)
            t_det = (time.perf_counter() - t2) * 1000

            win_ox = (cap_x - sx) * scale_x
            win_oy = (cap_y - sy) * scale_y

            # 转换至 Overlay 局部像素坐标并进行 4px 量化
            q = GEOMETRY_QUANTIZATION
            for y, x1, x2 in m_h:
                oy = round((win_oy + y * scale_inv * scale_y) / q) * q
                ox1 = round((win_ox + x1 * scale_inv * scale_x) / q) * q
                ox2 = round((win_ox + x2 * scale_inv * scale_x) / q) * q
                if (ox2 - ox1) >= MIN_VISUAL_LINE_LENGTH:
                    gid = f"vg_lh_{int(oy)}_{int(ox1)}_{int(ox2)}"
                    current_frame_geoms[gid] = {
                        "id": gid, "type": "LINE", "orientation": "HORIZONTAL",
                        "x1": ox1, "y1": oy, "x2": ox2, "y2": oy
                    }

            for x, y1, y2 in m_v:
                ox = round((win_ox + x * scale_inv * scale_x) / q) * q
                oy1 = round((win_oy + y1 * scale_inv * scale_y) / q) * q
                oy2 = round((win_oy + y2 * scale_inv * scale_y) / q) * q
                if (oy2 - oy1) >= MIN_VISUAL_LINE_LENGTH:
                    gid = f"vg_lv_{int(ox)}_{int(oy1)}_{int(oy2)}"
                    current_frame_geoms[gid] = {
                        "id": gid, "type": "LINE", "orientation": "VERTICAL",
                        "x1": ox, "y1": oy1, "x2": ox, "y2": oy2
                    }

            for x, y, w, h in rects:
                ox = round((win_ox + x * scale_inv * scale_x) / q) * q
                oy = round((win_oy + y * scale_inv * scale_y) / q) * q
                ow = round((w * scale_x) / q) * q
                oh = round((h * scale_y) / q) * q
                if ow >= MIN_VISUAL_RECT_WIDTH and oh >= MIN_VISUAL_RECT_HEIGHT:
                    gid = f"vg_rect_{int(ox)}_{int(oy)}_{int(ow)}_{int(oh)}"
                    current_frame_geoms[gid] = {
                        "id": gid, "type": "RECT",
                        "x": ox, "y": oy, "width": ow, "height": oh
                    }

            # 3. 时序平滑更新 (Temporal Stability)
            for gid, geom in current_frame_geoms.items():
                if gid not in self.tracked_geometries:
                    self.tracked_geometries[gid] = {"seen": 1, "miss": 0, "geom": geom}
                else:
                    self.tracked_geometries[gid]["seen"] += 1
                    self.tracked_geometries[gid]["miss"] = 0
                    self.tracked_geometries[gid]["geom"] = geom

            to_del = []
            for gid, item in self.tracked_geometries.items():
                if gid not in current_frame_geoms:
                    item["miss"] += 1
                    if item["miss"] >= DISAPPEAR_CONFIRM_COUNT:
                        to_del.append(gid)
            for gid in to_del: del self.tracked_geometries[gid]

        # 4. 筛选已确认稳定的几何对象
        confirmed = [item["geom"] for item in self.tracked_geometries.values() if item["seen"] >= APPEAR_CONFIRM_COUNT]

        # 5. 超限优先级排序保留 (长线与大 Rect 优先)
        if len(confirmed) > MAX_VISUAL_GEOMETRIES:
            def geom_score(g):
                if g["type"] == "RECT": return g.get("width", 0) * g.get("height", 0)
                elif g["orientation"] == "HORIZONTAL": return g.get("x2", 0) - g.get("x1", 0)
                else: return g.get("y2", 0) - g.get("y1", 0)
            confirmed.sort(key=geom_score, reverse=True)
            confirmed = confirmed[:MAX_VISUAL_GEOMETRIES]

        # 6. 变动签名与快照发送
        sig = ",".join(f"{g['id']}:{g['type']}:{g.get('x', g.get('x1', 0))}:{g.get('y', g.get('y1', 0))}" for g in confirmed)
        if sig != self.last_signature:
            self.last_signature = sig
            self.visual_revision += 1
            snapshot = {
                "v": 1, "type": "visual_snapshot", "revision": self.visual_revision,
                "screen": {"index": target_scr, "width": overlay_w, "height": overlay_h},
                "geometries": confirmed
            }
            if self._send_msg(snapshot): self._recv_line()

        # 统计指标累加
        self.stats["frames"] += 1
        self.stats["cap_ms"] += t_cap
        self.stats["chg_ms"] += t_chg
        self.stats["det_ms"] += t_det
        self.stats["geoms"] = len(confirmed)
        if not changed: self.stats["skipped"] += 1

        now = time.time()
        if now - self.last_stat_time >= 30.0:
            f = max(1, self.stats["frames"])
            print(f"[Visual Stats] 抓屏: {self.stats['cap_ms']/f:.1f}ms | 变动比对: {self.stats['chg_ms']/f:.1f}ms | 几何分析: {self.stats['det_ms']/f:.1f}ms | 稳定几何: {self.stats['geoms']} | 静态跳过率: {self.stats['skipped']*100/f:.0f}%")
            self.stats = {"cap_ms": 0.0, "chg_ms": 0.0, "det_ms": 0.0, "frames": 0, "skipped": 0, "geoms": 0}
            self.last_stat_time = now

    def run(self):
        print("[Visual] Windows Visual Geometry Perception Service Starting...")
        interval = 1.0 / SCAN_HZ
        while True:
            if not self.sock:
                if not self.connect():
                    time.sleep(2.0); continue
            self._check_global_hotkeys()
            self._update_status()
            self.scan_visual_geometry()
            time.sleep(interval)

if __name__ == "__main__":
    service = VisualPerceptionService()
    try: service.run()
    except KeyboardInterrupt: print("\n[Visual] Service Stopped.")





