"""
DesktopCat - Unified Perception Runner (T14)
同时启动并管理 Window Perception Service 与 UI Automation Perception Service。
支持多感知服务职责分离且共存运行。
"""

import threading
import time
import sys

from tools.perception.window_perception import WindowPerceptionService
from tools.perception.ui_automation_perception import UIAutomationPerceptionService

def run_window_service():
    print("[UnifiedPerception] Starting WindowPerceptionService...")
    svc = WindowPerceptionService()
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] WindowPerceptionService exited: {e}")

def run_uia_service():
    print("[UnifiedPerception] Starting UIAutomationPerceptionService...")
    svc = UIAutomationPerceptionService()
    try:
        svc.run()
    except Exception as e:
        print(f"[UnifiedPerception] UIAutomationPerceptionService exited: {e}")

def main():
    print("==================================================")
    print("DesktopCat - Unified Perception Service (T14)")
    print("同时托管: Window Geometry (10Hz) + UI Automation (2Hz)")
    print("全局快捷键: [F8] 窗口 | [F9] 物理表面 | [F10] 物理接触点 | [F11] UI控件")
    print("==================================================")
    
    t_win = threading.Thread(target=run_window_service, daemon=True)
    t_uia = threading.Thread(target=run_uia_service, daemon=True)
    
    t_win.start()
    time.sleep(0.2)
    t_uia.start()
    
    try:
        while True:
            time.sleep(1.0)
    except KeyboardInterrupt:
        print("\n[UnifiedPerception] Stopping all perception services...")

if __name__ == "__main__":
    main()
