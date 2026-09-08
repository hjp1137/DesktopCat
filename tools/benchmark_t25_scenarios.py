"""
DesktopCat - T25 Multi-Scenario Benchmark & Quantitative Metrics Evaluator
针对任务书要求的典型桌面场景执行量化指标评估与 A/B/C 三路对比：
Scene 1: 普通网页大段文字 (Text Paragraph)
Scene 2: ChatGPT / 常规 Web 界面 (Complex Web UI)
Scene 3: 浏览器顶部导航 (Browser Top - Tabs & Address Bar)
Scene 4: 图片较多网站 (High Texture Image - 纹理抑制验证)
Scene 5: 深色模式 (Dark Mode)
Scene 6: 浅色模式 (Light Mode)
Scene 7: 密集表格与列表 (Dense Table)
Scene 8: 动态页面 / 闪烁光标 (Dynamic / Temporal Jitter)
Scene 9: Windows 真实桌面环境 (Real Screen Capture)
"""

import time
import math
import numpy as np
import cv2
import os
import sys

_ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _ROOT_DIR not in sys.path:
    sys.path.insert(0, _ROOT_DIR)

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

from tools.perception.cat_physics_compiler import ScreenPhysicsCompiler

def generate_scene_1_text_paragraph():
    """Scene 1: 普通网页大段文字"""
    h, w = 600, 800
    img = np.full((h, w), 250, dtype=np.uint8) # 浅色底
    # 模拟 12 行段落文字，每行有 15 个单词
    for r in range(12):
        y = 50 + r * 42
        for c in range(15):
            x = 40 + c * 48
            img[y:y+12, x:x+36:2] = 25 # 笔画交替
    return img, "Scene 1: 普通网页大段文字"

def generate_scene_2_chatgpt_ui():
    """Scene 2: ChatGPT / 常规 Web 页面 (标题 + 消息块 + 按钮 + 输入框)"""
    h, w = 700, 900
    img = np.full((h, w), 245, dtype=np.uint8)
    # 顶部标题栏
    img[20:50, 40:240] = 30
    # 左侧侧边栏
    img[60:660, 20:180] = 230
    # 消息气泡 1 (用户)
    img[100:160, 400:850] = 220
    # 消息气泡 2 (AI回复，带多行文字)
    img[180:360, 220:850] = 255
    for r in range(4):
        y = 200 + r * 35
        img[y:y+10, 240:800:3] = 40
    # 底部输入框
    img[600:660, 220:850] = 255
    cv2.rectangle(img, (220, 600), (850, 660), 180, 2)
    # 发送按钮
    img[615:645, 800:840] = 30
    return img, "Scene 2: ChatGPT / Web UI"

def generate_scene_3_browser_top():
    """Scene 3: 浏览器顶部 (Tab + 地址栏 + 收藏栏)"""
    h, w = 300, 1000
    img = np.full((h, w), 235, dtype=np.uint8)
    # 3 个 Tab
    img[10:45, 20:180] = 255
    img[10:45, 185:340] = 220
    img[10:45, 345:500] = 220
    # 地址栏
    img[55:95, 80:850] = 255
    cv2.rectangle(img, (80, 55), (850, 95), 190, 1)
    # 收藏栏图标与字
    for i in range(8):
        x = 40 + i * 110
        img[110:135, x:x+90] = 240
    return img, "Scene 3: 浏览器顶部导航"

def generate_scene_4_high_texture_image():
    """Scene 4: 图片较多网站 (验证照片内部纹理抑制)"""
    h, w = 600, 800
    img = np.full((h, w), 245, dtype=np.uint8)
    # 模拟两张复杂的照片 (高斯噪点与密集斑纹)
    rng = np.random.RandomState(101)
    # 照片 1: 300x200
    img[100:300, 50:350] = rng.randint(20, 230, (200, 300), dtype=np.uint8)
    # 照片 2: 300x200
    img[100:300, 420:720] = rng.randint(20, 230, (200, 300), dtype=np.uint8)
    # 照片下方文字标题
    img[320:335, 50:300:2] = 30
    img[320:335, 420:680:2] = 30
    return img, "Scene 4: 高纹理图片网站"

def generate_scene_5_dark_mode():
    """Scene 5: 深色模式"""
    h, w = 500, 800
    img = np.full((h, w), 30, dtype=np.uint8) # 深黑底
    # 浅色文字与卡片
    img[40:180, 40:740] = 45 # 稍浅卡片
    cv2.rectangle(img, (40, 40), (740, 180), 70, 1)
    for r in range(3):
        y = 65 + r * 35
        img[y:y+10, 60:680:2] = 210 # 白字
    # 底部发光按钮
    img[220:260, 40:180] = 160
    return img, "Scene 5: 深色模式 UI"

def generate_scene_6_light_mode():
    """Scene 6: 浅色模式"""
    h, w = 500, 800
    img = np.full((h, w), 255, dtype=np.uint8)
    img[40:180, 40:740] = 245
    cv2.rectangle(img, (40, 40), (740, 180), 210, 1)
    for r in range(3):
        y = 65 + r * 35
        img[y:y+10, 60:680:2] = 40
    img[220:260, 40:180] = 60
    return img, "Scene 6: 浅色模式 UI"

def generate_scene_7_dense_table():
    """Scene 7: 密集表格与列表"""
    h, w = 600, 800
    img = np.full((h, w), 250, dtype=np.uint8)
    # 表头
    img[40:80, 40:760] = 225
    # 8 行数据，每行 5 列
    for r in range(8):
        y = 90 + r * 45
        cv2.line(img, (40, y + 35), (760, y + 35), 215, 1) # 分隔线
        for c in range(5):
            x = 50 + c * 140
            img[y+8:y+20, x:x+90:3] = 30
    return img, "Scene 7: 密集列表/表格"

def generate_scene_8_dynamic_video():
    """Scene 8: 视频 / 动态页面与闪烁光标"""
    h, w = 500, 800
    img = np.full((h, w), 240, dtype=np.uint8)
    # 视频播放器区域 (400x240)
    rng = np.random.RandomState(int(time.time() * 100) % 1000)
    img[60:300, 100:500] = rng.randint(40, 200, (240, 400), dtype=np.uint8)
    # 闪烁光标 (每半秒闪烁)
    if int(time.time() * 2) % 2 == 0:
        img[340:370, 100:104] = 20
    return img, "Scene 8: 动态页面/视频"

def capture_scene_9_real_desktop():
    """Scene 9: Windows 真实桌面环境捕获"""
    import ctypes
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32

    sw = user32.GetSystemMetrics(0)
    sh = user32.GetSystemMetrics(1)
    if sw <= 0 or sh <= 0:
        sw, sh = 1920, 1080

    dw, dh = max(16, sw // 2), max(16, sh // 2)

    hdc_screen = user32.GetDC(0)
    hdc_mem = gdi32.CreateCompatibleDC(hdc_screen)
    gdi32.SetStretchBltMode(hdc_mem, 3)

    hbm = gdi32.CreateCompatibleBitmap(hdc_screen, dw, dh)
    gdi32.SelectObject(hdc_mem, hbm)
    gdi32.StretchBlt(hdc_mem, 0, 0, dw, dh, hdc_screen, 0, 0, sw, sh, 0x00CC0020)

    from tools.perception.visual_perception import BITMAPINFOHEADER
    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = dw
    bmi.biHeight = -dh
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    bmi.biCompression = 0
    buf = (ctypes.c_uint8 * (dw * dh * 4))()
    gdi32.GetDIBits(hdc_mem, hbm, 0, dh, ctypes.byref(buf), ctypes.byref(bmi), 0)

    gdi32.DeleteObject(hbm)
    gdi32.DeleteDC(hdc_mem)
    user32.ReleaseDC(0, hdc_screen)

    arr = np.frombuffer(buf, dtype=np.uint8).reshape((dh, dw, 4))
    gray = (arr[:, :, 0].astype(np.uint16) * 29 +
            arr[:, :, 1].astype(np.uint16) * 150 +
            arr[:, :, 2].astype(np.uint16) * 77) >> 8
    return gray.astype(np.uint8), "Scene 9: Windows 真实工作区桌面"

def run_benchmarks():
    print("================================================================================")
    print("[T25] DesktopCat T25 场景基准评估与 A/B/C 三路量化指标报告")
    print("================================================================================")

    compiler = ScreenPhysicsCompiler(cat_scale=1.0)

    scenarios = [
        generate_scene_1_text_paragraph(),
        generate_scene_2_chatgpt_ui(),
        generate_scene_3_browser_top(),
        generate_scene_4_high_texture_image(),
        generate_scene_5_dark_mode(),
        generate_scene_6_light_mode(),
        generate_scene_7_dense_table(),
        generate_scene_8_dynamic_video(),
        capture_scene_9_real_desktop()
    ]

    results = []

    for img, scene_name in scenarios:
        # 预热并运行 3 帧（验证时间稳定性）
        snap = None
        for _ in range(3):
            snap = compiler.compile(img, scale_inv=2.0)

        m = snap["metrics"]
        leg = m["legacy"]
        cv_res = m["opencv"]
        hy = m["hybrid"]
        t = m["timing"]

        row = {
            "scene": scene_name,
            "leg_surfs": leg["final_surface_count"],
            "leg_frag": leg["fragmentation_count"],
            "cv_surfs": cv_res["final_surface_count"],
            "cv_stable": cv_res["stable_surface_count"],
            "cv_frag": cv_res["fragmentation_count"],
            "hy_candidates": hy["candidate_region_count"],
            "hy_surfs": hy["final_surface_count"],
            "hy_stable": hy["stable_surface_count"],
            "hy_frag": hy["fragmentation_count"],
            "hy_jitter": hy["temporal_jitter"],
            "reduction_ratio": hy["reduction_ratio"],
            "total_ms": t["total_ms"]
        }
        results.append(row)

        print(f"\n[{scene_name}]")
        print(f"  Legacy (Mode A) : 表面数 = {row['leg_surfs']}, 碎片数 = {row['leg_frag']}")
        print(f"  OpenCV (Mode B) : 候选 = {cv_res['candidate_region_count']}, 稳定表面 = {row['cv_stable']}, 碎片 = {row['cv_frag']}")
        print(f"  Hybrid (Mode C) : 候选 = {row['hy_candidates']} -> 稳定表面 = {row['hy_stable']}, 碎片 = {row['hy_frag']}, Jitter = {row['hy_jitter']}")
        print(f"  量化改善: 压缩比 = {row['reduction_ratio']:.2f}x | 碎片下降: {row['leg_frag']} -> {row['hy_frag']} | 耗时: {row['total_ms']}ms")

    print("\n================================================================================")
    print("[Report] T25 全场景量化汇总表格 (Legacy vs OpenCV vs Hybrid)")
    print("--------------------------------------------------------------------------------")
    print(f"{'场景名称':<28} | {'Legacy(碎片)':<14} | {'OpenCV(稳定)':<14} | {'Hybrid(极简)':<14} | {'压缩比':<8} | {'耗时':<8}")
    print("--------------------------------------------------------------------------------")
    for r in results:
        leg_str = f"{r['leg_surfs']} ({r['leg_frag']}碎)"
        cv_str = f"{r['cv_stable']} ({r['cv_frag']}碎)"
        hy_str = f"{r['hy_stable']} ({r['hy_frag']}碎)"
        print(f"{r['scene']:<28} | {leg_str:<14} | {cv_str:<14} | {hy_str:<14} | {r['reduction_ratio']:<6.1f}x | {r['total_ms']:<5.1f}ms")
    print("================================================================================")

if __name__ == "__main__":
    run_benchmarks()
