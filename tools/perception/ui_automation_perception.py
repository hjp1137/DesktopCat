"""
DesktopCat - Windows UI Automation Element Perception Service (T14)
使用纯 Python 标准库 + ctypes (零第三方依赖) 提取 Windows 窗口内部 UI 控件几何。
"""

import ctypes
from ctypes import wintypes, c_void_p, POINTER, Structure, byref, WINFUNCTYPE, c_int
import socket
import json
import time
import sys

user32 = ctypes.windll.user32
ole32 = ctypes.windll.ole32
oleaut32 = ctypes.windll.oleaut32

# 保证能访问交互式桌面的窗口
h_def_desk = user32.OpenDesktopW("default", 0, False, 0x01FF)
if h_def_desk:
    user32.SetThreadDesktop(h_def_desk)

class GUID(Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", wintypes.BYTE * 8)
    ]

def str_to_guid(guid_str: str) -> GUID:
    g = GUID()
    ole32.CLSIDFromString(ctypes.c_wchar_p(guid_str), byref(g))
    return g

CLSID_CUIAutomation = str_to_guid("{ff48dba4-60ef-4201-aa87-54103eef594e}")
IID_IUIAutomation = str_to_guid("{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")

UIA_CONTROL_TYPES = {
    50000: "Button", 50001: "Calendar", 50002: "CheckBox", 50003: "ComboBox",
    50004: "Edit", 50005: "Hyperlink", 50006: "Image", 50007: "ListItem",
    50008: "List", 50009: "Menu", 50010: "MenuBar", 50011: "MenuItem",
    50012: "ProgressBar", 50013: "RadioButton", 50014: "ScrollBar", 50015: "Slider",
    50016: "Spinner", 50017: "StatusBar", 50018: "Tab", 50019: "TabItem",
    50020: "Text", 50021: "ToolBar", 50022: "ToolTip", 50023: "Tree",
    50024: "TreeItem", 50025: "Custom", 50026: "Group", 50027: "Thumb",
    50028: "DataGrid", 50029: "DataItem", 50030: "Document", 50031: "SplitButton",
    50032: "Window", 50033: "Pane", 50034: "Header", 50035: "HeaderItem",
    50036: "Table", 50037: "TitleBar", 50038: "Separator", 50039: "SemanticZoom",
    50040: "AppBar"
}

class UIAutomationProvider:
    def __init__(self):
        ole32.CoInitialize(None)
        self.p_uia = c_void_p()
        hr = ole32.CoCreateInstance(
            byref(CLSID_CUIAutomation), None, 1, byref(IID_IUIAutomation), byref(self.p_uia)
        )
        if hr != 0 or not self.p_uia.value:
            raise RuntimeError(f"CoCreateInstance IUIAutomation failed: hr=0x{hr & 0xffffffff:x}")
        
        self.uia_vt = ctypes.cast(self.p_uia, POINTER(POINTER(c_void_p))).contents
        self.ElementFromHandle = WINFUNCTYPE(c_int, c_void_p, wintypes.HWND, POINTER(c_void_p))(self.uia_vt[6])
        self.get_ControlViewWalker = WINFUNCTYPE(c_int, c_void_p, POINTER(c_void_p))(self.uia_vt[14])
        
        self.p_walker = c_void_p()
        self.get_ControlViewWalker(self.p_uia, byref(self.p_walker))
        self.walker_vt = ctypes.cast(self.p_walker, POINTER(POINTER(c_void_p))).contents
        self.GetFirstChildElement = WINFUNCTYPE(c_int, c_void_p, c_void_p, POINTER(c_void_p))(self.walker_vt[4])
        self.GetNextSiblingElement = WINFUNCTYPE(c_int, c_void_p, c_void_p, POINTER(c_void_p))(self.walker_vt[6])

    def get_element_runtime_id(self, elem_ptr, default_id: str) -> str:
        try:
            e_vt = ctypes.cast(elem_ptr, POINTER(POINTER(c_void_p))).contents
            GetRuntimeId = WINFUNCTYPE(c_int, c_void_p, POINTER(c_void_p))(e_vt[4])
            psa = c_void_p()
            if GetRuntimeId(elem_ptr, byref(psa)) == 0 and psa.value:
                p_data = POINTER(c_int)()
                oleaut32.SafeArrayAccessData(psa, byref(p_data))
                lbound = c_int(); ubound = c_int()
                oleaut32.SafeArrayGetLBound(psa, 1, byref(lbound))
                oleaut32.SafeArrayGetUBound(psa, 1, byref(ubound))
                count = ubound.value - lbound.value + 1
                rids = [p_data[i] for i in range(count)]
                oleaut32.SafeArrayUnaccessData(psa)
                oleaut32.SafeArrayDestroy(psa)
                if rids:
                    return "-".join(str(x) for x in rids)
        except Exception:
            pass
        return default_id

    def scan_window_elements(self, hwnd: int, window_id: str, sx: int, sy: int, sw: int, sh: int,
                             scale_x: float, scale_y: float, start_t: float, budget_s: float,
                             max_depth: int = 10, max_elements: int = 1000) -> tuple:
        elements = []
        raw_count = 0
        elem = c_void_p()
        if self.ElementFromHandle(self.p_uia, hwnd, byref(elem)) != 0 or not elem.value:
            return elements, raw_count

        stack = [(elem, 0, "0")]
        while stack and len(elements) < max_elements:
            if (time.perf_counter() - start_t) > budget_s:
                break
            curr, depth, path = stack.pop()
            raw_count += 1
            c_vt = ctypes.cast(curr, POINTER(POINTER(c_void_p))).contents
            get_c_type = WINFUNCTYPE(c_int, c_void_p, POINTER(c_int))(c_vt[21])
            get_c_rect = WINFUNCTYPE(c_int, c_void_p, POINTER(wintypes.RECT))(c_vt[43])
            get_c_off = WINFUNCTYPE(c_int, c_void_p, POINTER(wintypes.BOOL))(c_vt[38])

            t = c_int(); r = wintypes.RECT(); off = wintypes.BOOL()
            get_c_type(curr, byref(t))
            get_c_rect(curr, byref(r))
            get_c_off(curr, byref(off))

            if not off.value and (r.right > r.left) and (r.bottom > r.top):
                il = max(r.left, sx); it = max(r.top, sy)
                ir = min(r.right, sx + sw); ib = min(r.bottom, sy + sh)
                if ir > il and ib > it:
                    lx = round((il - sx) * scale_x, 1)
                    ly = round((it - sy) * scale_y, 1)
                    lw = round((ir - il) * scale_x, 1)
                    lh = round((ib - it) * scale_y, 1)
                    if lw >= 4.0 and lh >= 4.0:
                        ctype = UIA_CONTROL_TYPES.get(t.value, "Other")
                        rid_str = self.get_element_runtime_id(curr, f"{ctype}:{path}")
                        eid = f"{window_id}:{rid_str}"
                        elements.append({
                            "id": eid,
                            "window_id": window_id,
                            "control_type": ctype,
                            "x": lx,
                            "y": ly,
                            "width": lw,
                            "height": lh
                        })

            if depth < max_depth:
                child = c_void_p()
                self.GetFirstChildElement(self.p_walker, curr, byref(child))
                c_curr = child
                child_list = []
                c_idx = 0
                while c_curr.value and len(child_list) < 80:
                    child_list.append((c_curr, f"{path}.{c_idx}"))
                    c_idx += 1
                    nxt = c_void_p()
                    self.GetNextSiblingElement(self.p_walker, c_curr, byref(nxt))
                    c_curr = nxt
                for c_ptr, c_path in reversed(child_list):
                    stack.append((c_ptr, depth + 1, c_path))

        return elements, raw_count

class MONITORINFO(Structure):
    _fields_ = [("cbSize", wintypes.DWORD), ("rcMonitor", wintypes.RECT), ("rcWork", wintypes.RECT), ("dwFlags", wintypes.DWORD)]

class UIAutomationPerceptionService:
    def __init__(self, host: str = "127.0.0.1", port: int = 47831):
        self.host = host
        self.port = port
        self.sock = None
        self.reader = None
        self.provider = UIAutomationProvider()
        self.godot_hwnd = None
        self.screen_info = {"index": 0, "width": 1920, "height": 1080}
        self.ui_revision = 0
        self.last_signature = ""
        self.hotkey_states = {}
        self.last_stat_time = time.time()

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
            print(f"[UIA] Connected to DesktopCat ({self.host}:{self.port}), Screen {self.screen_info.get('index', 0)}")
            print("[UIA] 提示: 按 [F11] 或 [K]/[O] 切换【UI Automation 控件几何】调试线框！")
            return True
        except Exception as e:
            if self.sock: self.sock.close()
            self.sock = None; self.reader = None
            return False

    def _check_global_hotkeys(self):
        hotkeys = {0x7A: "F11", 0x4B: "K", 0x4F: "O", 0x55: "U"}
        for vk, name in hotkeys.items():
            is_down = bool(user32.GetAsyncKeyState(vk) & 0x8000)
            was_down = self.hotkey_states.get(vk, False)
            self.hotkey_states[vk] = is_down
            if is_down and not was_down:
                print(f"[UIA] 检测到快捷键 [{name}]，切换【UI Automation 控件几何】调试线框...")
                self._send_msg({"v": 1, "type": "command", "name": "TOGGLE_DEBUG_UI"})
                self._recv_line()

    def scan_screen_ui(self):
        t0 = time.perf_counter()
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

        fg_hwnd = user32.GetForegroundWindow()
        target_hwnds = []
        def enum_cb(h, _):
            if not user32.IsWindowVisible(h) or user32.IsIconic(h): return 1
            if h == self.godot_hwnd: return 1
            buf = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(h, buf, 256)
            if buf.value in ("Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd"): return 1
            rect = wintypes.RECT()
            user32.GetWindowRect(h, ctypes.byref(rect))
            if (rect.right - rect.left) <= 32 or (rect.bottom - rect.top) <= 32: return 1
            if rect.right <= sx or rect.left >= (sx + sw) or rect.bottom <= sy or rect.top >= (sy + sh): return 1
            target_hwnds.append(h)
            return 1

        user32.EnumWindows(WINFUNCTYPE(c_int, c_void_p, c_void_p)(enum_cb), 0)

        ordered = []
        if fg_hwnd and fg_hwnd in target_hwnds: ordered.append(fg_hwnd)
        for h in target_hwnds:
            if h not in ordered and len(ordered) < 4: ordered.append(h)

        total_elements = []
        total_raw = 0
        budget_s = 0.035
        for h in ordered:
            wid = f"0x{h:08X}"
            elems, raw_cnt = self.provider.scan_window_elements(
                h, wid, sx, sy, sw, sh, scale_x, scale_y, t0, budget_s,
                max_depth=10, max_elements=(1000 - len(total_elements))
            )
            total_elements.extend(elems)
            total_raw += raw_cnt
            if (time.perf_counter() - t0) >= budget_s: break

        scan_ms = (time.perf_counter() - t0) * 1000
        now = time.time()
        if now - self.last_stat_time >= 20.0:
            print(f"[UIA Stats] 扫描耗时: {scan_ms:.1f}ms | 原始节点: {total_raw} | 保留元素: {len(total_elements)} | 窗口数: {len(ordered)}")
            self.last_stat_time = now

        sig_parts = [f"{e['id']}:{e['control_type']}:{e['x']}:{e['y']}:{e['width']}:{e['height']}" for e in total_elements]
        sig = ",".join(sig_parts)
        if sig != self.last_signature:
            self.last_signature = sig
            self.ui_revision += 1
            snapshot = {
                "v": 1,
                "type": "ui_snapshot",
                "revision": self.ui_revision,
                "screen": {"index": target_scr, "width": overlay_w, "height": overlay_h},
                "elements": total_elements
            }
            if self._send_msg(snapshot): self._recv_line()

    def run(self):
        print("[UIA] Windows UI Automation Perception Service Starting...")
        while True:
            if not self.sock:
                if not self.connect():
                    time.sleep(2.0); continue
            self._check_global_hotkeys()
            self._update_status()
            self.scan_screen_ui()
            time.sleep(0.5)

if __name__ == "__main__":
    service = UIAutomationPerceptionService()
    try: service.run()
    except KeyboardInterrupt: print("\n[UIA] Service Stopped.")




