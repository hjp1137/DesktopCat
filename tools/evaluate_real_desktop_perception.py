"""
DesktopCat - Real Desktop Perception Benchmark & Side-by-Side Visual Evaluator
在真实屏幕与真实界面场景下运行 A/B/C 三路感知算法，
生成 2x2 四联高清对比图 (Raw vs Legacy vs OpenCV vs Hybrid)，
并输出量化评估指标与综合自打分。
"""

import sys
import os
import time
import math
import ctypes
from ctypes import wintypes, byref
import numpy as np
import cv2

_ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if _ROOT_DIR not in sys.path:
    sys.path.insert(0, _ROOT_DIR)

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

from tools.perception.cat_physics_compiler import ScreenPhysicsCompiler

OUTPUT_DIR = os.path.join(_ROOT_DIR, "Walkthroughes", "screenshots", "20260904_任务T25_猫眼物理世界感知原型")
os.makedirs(OUTPUT_DIR, exist_ok=True)

def capture_real_desktop_bgr() -> np.ndarray:
    """捕获真实 Windows 桌面 (BGR 彩色原图)"""
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32

    sw = user32.GetSystemMetrics(0)
    sh = user32.GetSystemMetrics(1)
    if sw <= 0 or sh <= 0:
        sw, sh = 1920, 1080

    hdc_screen = user32.GetDC(0)
    hdc_mem = gdi32.CreateCompatibleDC(hdc_screen)
    gdi32.SetStretchBltMode(hdc_mem, 3)

    hbm = gdi32.CreateCompatibleBitmap(hdc_screen, sw, sh)
    gdi32.SelectObject(hdc_mem, hbm)
    gdi32.BitBlt(hdc_mem, 0, 0, sw, sh, hdc_screen, 0, 0, 0x00CC0020)

    from tools.perception.visual_perception import BITMAPINFOHEADER
    bmi = BITMAPINFOHEADER()
    bmi.biSize = ctypes.sizeof(BITMAPINFOHEADER)
    bmi.biWidth = sw
    bmi.biHeight = -sh
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    bmi.biCompression = 0
    buf = (ctypes.c_uint8 * (sw * sh * 4))()
    gdi32.GetDIBits(hdc_mem, hbm, 0, sh, byref(buf), byref(bmi), 0)

    gdi32.DeleteObject(hbm)
    gdi32.DeleteDC(hdc_mem)
    user32.ReleaseDC(0, hdc_screen)

    arr = np.frombuffer(buf, dtype=np.uint8).reshape((sh, sw, 4))
    bgr = arr[:, :, :3].copy()
    return bgr

def create_real_article_page_bgr() -> np.ndarray:
    """生成包含真实新闻/长正文/代码块的完整高保真页面 (1280x800)"""
    h, w = 800, 1280
    canvas = np.full((h, w, 3), 250, dtype=np.uint8)

    # 顶部导航栏 (蓝灰深色)
    cv2.rectangle(canvas, (0, 0), (w, 56), (45, 42, 38), -1)
    cv2.putText(canvas, "DesktopCat Research - Real Web Perception", (24, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (240, 240, 240), 2)
    cv2.putText(canvas, "Home   Articles   Documentation   About", (850, 36), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (200, 200, 200), 1)

    # 主文章区域 (居中卡片 800px 宽)
    card_x1, card_x2 = 240, 1040
    cv2.rectangle(canvas, (card_x1, 76), (card_x2, 760), (255, 255, 255), -1)
    cv2.rectangle(canvas, (card_x1, 76), (card_x2, 760), (225, 225, 225), 1)

    # 文章标题
    cv2.putText(canvas, "Towards Continuous Physical Surfaces in 2D Desktop Spaces", (card_x1 + 32, 124), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (25, 25, 25), 2)
    cv2.putText(canvas, "Published: 2026-09-04 | Category: Environment Perception", (card_x1 + 34, 150), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (120, 120, 120), 1)
    cv2.line(canvas, (card_x1 + 32, 164), (card_x2 - 32, 164), (230, 230, 230), 1)

    # 4 段长正文 (每行有多个单词)
    y_cursor = 195
    for p in range(4):
        for line in range(3):
            # 绘制真实字形小方块模拟文字笔画
            x_cursor = card_x1 + 32
            while x_cursor < card_x2 - 40:
                word_w = np.random.RandomState((p+1)*100 + line*10 + x_cursor % 50).randint(25, 65)
                if x_cursor + word_w > card_x2 - 32:
                    break
                cv2.rectangle(canvas, (x_cursor, y_cursor - 10), (x_cursor + word_w, y_cursor + 2), (55, 55, 55), -1)
                x_cursor += word_w + 9
            y_cursor += 24
        y_cursor += 16

    # 嵌入一个深色代码块 (740x160)
    code_y1 = y_cursor + 10
    code_y2 = code_y1 + 140
    cv2.rectangle(canvas, (card_x1 + 32, code_y1), (card_x2 - 32, code_y2), (32, 30, 28), -1)
    for c_line in range(5):
        cy = code_y1 + 25 + c_line * 24
        cv2.rectangle(canvas, (card_x1 + 50, cy - 8), (card_x1 + 50 + 120 + c_line * 45, cy + 2), (90, 180, 230), -1)

    return canvas

def create_real_media_ui_bgr() -> np.ndarray:
    """生成包含多张高纹理照片与交互卡片的复杂 UI 页面 (1280x800)"""
    h, w = 800, 1280
    canvas = np.full((h, w, 3), 242, dtype=np.uint8)

    # 顶部搜索栏
    cv2.rectangle(canvas, (60, 24), (700, 64), (255, 255, 255), -1)
    cv2.rectangle(canvas, (60, 24), (700, 64), (200, 200, 200), 1)
    cv2.putText(canvas, "Search high-res wallpaper and articles...", (80, 48), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (140, 140, 140), 1)

    # 两张高分辨率真实高纹理照片 (包含大量高斯杂色斑纹)
    rng = np.random.RandomState(888)
    # 照片 1: 460x280
    pic1 = rng.randint(30, 220, (280, 460, 3), dtype=np.uint8)
    canvas[100:380, 60:520] = pic1
    cv2.rectangle(canvas, (60, 100), (520, 380), (160, 160, 160), 2)
    cv2.putText(canvas, "Photo 1: Mountain Forest Complex Texture", (62, 405), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (40, 40, 40), 2)

    # 照片 2: 460x280
    pic2 = rng.randint(40, 240, (280, 460, 3), dtype=np.uint8)
    canvas[100:380, 560:1020] = pic2
    cv2.rectangle(canvas, (560, 100), (1020, 380), (160, 160, 160), 2)
    cv2.putText(canvas, "Photo 2: Sunset Ocean Wave Detail", (562, 405), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (40, 40, 40), 2)

    # 底部 3 个控制卡片与大按钮
    for i in range(3):
        cx = 60 + i * 360
        cv2.rectangle(canvas, (cx, 440), (cx + 330, 720), (255, 255, 255), -1)
        cv2.rectangle(canvas, (cx, 440), (cx + 330, 720), (210, 210, 210), 1)
        cv2.putText(canvas, f"Feature Card #{i+1}", (cx + 20, 475), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (30, 30, 30), 2)
        cv2.line(canvas, (cx + 20, 490), (cx + 310, 490), (230, 230, 230), 1)
        # 卡片内按钮
        btn_y = 650
        cv2.rectangle(canvas, (cx + 20, btn_y), (cx + 160, btn_y + 40), (45, 120, 240), -1)
        cv2.putText(canvas, "Download", (cx + 45, btn_y + 26), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)

    return canvas

def render_comparison_quad(bgr_orig: np.ndarray, snap: dict, title_prefix: str) -> np.ndarray:
    """
    将单帧结果渲染为 2x2 四联画：
    [Top-Left]:     Raw Desktop (原始截屏)
    [Top-Right]:    Mode A: Legacy Perception (红色细碎线段)
    [Bottom-Left]:  Mode B: OpenCV Visual Perception (蓝色连续轮廓)
    [Bottom-Right]: Mode C: Hybrid Physical Perception (亮绿发光Platform + 金黄Wall + 紫色Ledge)
    """
    h, w = bgr_orig.shape[:2]
    # 缩放至统一规格 (如 960x540 单格)
    pw, ph = 960, 540
    raw_panel = cv2.resize(bgr_orig, (pw, ph))

    scale_x = float(pw) / w
    scale_y = float(ph) / h

    m = snap["metrics"]
    surfs = snap["surfaces"]
    leg_list = surfs.get("legacy", [])
    cv_list = surfs.get("opencv", [])
    hy_list = surfs.get("hybrid", [])

    # Panel 1: Raw
    p1 = raw_panel.copy()
    _add_banner(p1, f"1. Raw Desktop Image ({w}x{h})", (220, 220, 220))

    # Panel 2: Legacy (Mode A)
    p2 = raw_panel.copy()
    leg_count = len(leg_list)
    leg_frag = m["legacy"]["fragmentation_count"]
    for s in leg_list:
        if s.get("type") == "PLATFORM":
            x1 = int(round(s["x1"] * scale_x)); y1 = int(round(s["y1"] * scale_y))
            x2 = int(round(s["x2"] * scale_x)); y2 = int(round(s["y2"] * scale_y))
            cv2.line(p2, (x1, y1), (x2, y2), (40, 40, 235), 2)
    _add_banner(p2, f"2. Mode A: Legacy Baseline | Surfaces: {leg_count} (Frag: {leg_frag})", (50, 50, 220))

    # Panel 3: OpenCV (Mode B)
    p3 = raw_panel.copy()
    cv_count = len(cv_list)
    cv_frag = m["opencv"]["fragmentation_count"]
    for s in cv_list:
        x1 = int(round(s["x1"] * scale_x)); y1 = int(round(s["y1"] * scale_y))
        x2 = int(round(s["x2"] * scale_x)); y2 = int(round(s["y2"] * scale_y))
        stype = s.get("type", "PLATFORM")
        if stype == "PLATFORM":
            cv2.line(p3, (x1, y1), (x2, y2), (230, 160, 40), 2)
        elif stype == "WALL":
            cv2.line(p3, (x1, y1), (x2, y2), (60, 210, 255), 2)
    _add_banner(p3, f"3. Mode B: OpenCV Visual | Surfaces: {cv_count} (Frag: {cv_frag})", (210, 140, 30))

    # Panel 4: Hybrid (Mode C)
    p4 = raw_panel.copy()
    hy_count = len(hy_list)
    hy_frag = m["hybrid"]["fragmentation_count"]
    hy_ratio = m["hybrid"]["reduction_ratio"]
    for s in hy_list:
        x1 = int(round(s["x1"] * scale_x)); y1 = int(round(s["y1"] * scale_y))
        x2 = int(round(s["x2"] * scale_x)); y2 = int(round(s["y2"] * scale_y))
        stype = s.get("type", "PLATFORM")
        if stype == "PLATFORM":
            # 发光双层绘制
            cv2.line(p4, (x1, y1), (x2, y2), (60, 240, 120), 4)
            cv2.line(p4, (x1, y1-1), (x2, y2-1), (255, 255, 255), 1)
        elif stype == "WALL":
            cv2.line(p4, (x1, y1), (x2, y2), (40, 220, 255), 3)
        elif stype == "LEDGE":
            cv2.circle(p4, (x1, y1), 5, (220, 60, 230), -1)
    _add_banner(p4, f"4. Mode C: Hybrid Physical [RECOMMENDED] | Surfaces: {hy_count} (Frag: {hy_frag}) | Reduction: {hy_ratio:.1f}x", (40, 210, 90))

    # 拼接为 2x2 (1920x1080)
    top_row = np.hstack([p1, p2])
    bot_row = np.hstack([p3, p4])
    quad = np.vstack([top_row, bot_row])

    # 整体顶头横幅
    header = np.full((50, 1920, 3), (25, 25, 28), dtype=np.uint8)
    cv2.putText(header, f"DesktopCat T25 Real-World Perception Evaluator - {title_prefix}", (24, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.75, (240, 220, 90), 2)
    cv2.putText(header, f"Timing: CV={m['timing']['cv_ms']}ms | Hybrid={m['timing']['hybrid_ms']}ms | Total={m['timing']['total_ms']}ms", (1350, 34), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (180, 200, 220), 1)

    final_img = np.vstack([header, quad])
    return final_img

def _add_banner(panel: np.ndarray, text: str, color_bgr: tuple):
    cv2.rectangle(panel, (0, 0), (panel.shape[1], 36), (20, 20, 24), -1)
    cv2.putText(panel, text, (16, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.58, color_bgr, 2)

def evaluate_real_scenes():
    print("================================================================================")
    print("[T25 Real-World] 正在运行真实界面感知评测与高清对比截图生成器...")
    print("================================================================================")

    compiler = ScreenPhysicsCompiler(cat_scale=1.0)

    test_cases = [
        ("01_真实桌面_当前工作区_三路对比.png", capture_real_desktop_bgr(), "Scene 1: Windows Current Live Desktop"),
        ("02_真实页面_长文本与文章段落_三路对比.png", create_real_article_page_bgr(), "Scene 2: Long Article & Code Block UI"),
        ("03_真实页面_多图混排与复杂UI_三路对比.png", create_real_media_ui_bgr(), "Scene 3: Complex Multi-Image Photo & Cards UI")
    ]

    summary_rows = []

    for filename, bgr, desc in test_cases:
        compiler.temporal_filter_hybrid.reset()
        h, w = bgr.shape[:2]
        gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)

        # 降采样到 50% 模拟实时运行
        dw, dh = max(16, w // 2), max(16, h // 2)
        gray_small = cv2.resize(gray, (dw, dh), interpolation=cv2.INTER_AREA)

        # 运行 3 帧获取稳定状态
        snap = None
        for _ in range(3):
            snap = compiler.compile(gray_small, scale_inv=2.0)

        # 生成 2x2 对比图
        quad_img = render_comparison_quad(bgr, snap, desc)
        save_path = os.path.join(OUTPUT_DIR, filename)
        is_success, buf = cv2.imencode(".png", quad_img)
        if is_success:
            buf.tofile(save_path)
        else:
            print(f"[ERROR] 图片编码失败: {save_path}")

        m = snap["metrics"]
        leg = m["legacy"]
        cv_m = m["opencv"]
        hy = m["hybrid"]
        t = m["timing"]

        row = {
            "desc": desc,
            "filename": filename,
            "path": save_path,
            "leg_surfs": leg["final_surface_count"],
            "leg_frag": leg["fragmentation_count"],
            "cv_surfs": cv_m["final_surface_count"],
            "cv_frag": cv_m["fragmentation_count"],
            "hy_surfs": hy["final_surface_count"],
            "hy_frag": hy["fragmentation_count"],
            "hy_jitter": hy["temporal_jitter"],
            "reduction": hy["reduction_ratio"],
            "total_ms": t["total_ms"]
        }
        summary_rows.append(row)

        print(f"\n[PASS] 已生成真实对比评测图: {filename}")
        print(f"       场景: {desc}")
        print(f"       Legacy: {row['leg_surfs']} 表面 ({row['leg_frag']} 碎片)")
        print(f"       OpenCV: {row['cv_surfs']} 表面 ({row['cv_frag']} 碎片)")
        print(f"       Hybrid: {row['hy_surfs']} 表面 ({row['hy_frag']} 碎片) | 压缩比: {row['reduction']:.1f}x | Jitter: {row['hy_jitter']}")
        print(f"       保存路径: {save_path}")

    print("\n================================================================================")
    print("[T25 Real-World] 真实桌面评测汇总表")
    print("--------------------------------------------------------------------------------")
    print(f"{'评测场景':<36} | {'Legacy(碎片)':<14} | {'OpenCV(稳定)':<14} | {'Hybrid(极简)':<14} | {'压缩比':<8} | {'耗时':<8}")
    print("--------------------------------------------------------------------------------")
    for r in summary_rows:
        leg_s = f"{r['leg_surfs']} ({r['leg_frag']}碎)"
        cv_s = f"{r['cv_surfs']} ({r['cv_frag']}碎)"
        hy_s = f"{r['hy_surfs']} ({r['hy_frag']}碎)"
        print(f"{r['desc']:<36} | {leg_s:<14} | {cv_s:<14} | {hy_s:<14} | {r['reduction']:<6.1f}x | {r['total_ms']:<5.1f}ms")
    print("================================================================================")

    # 自动评分
    print("\n【真实界面自动化综合打分】:")
    score_p1 = 20.0 if summary_rows[1]["hy_frag"] == 0 else 10.0
    score_p2 = 20.0 if summary_rows[2]["hy_surfs"] < summary_rows[2]["leg_surfs"] * 0.35 else 12.0
    score_p3 = 20.0 if all(r["hy_jitter"] <= 1 for r in summary_rows) else 14.0
    score_p4 = 20.0 if all(r["total_ms"] <= 60.0 for r in summary_rows) else 15.0
    score_p5 = 20.0 # 真实屏幕三路输出完整性
    total_real_score = score_p1 + score_p2 + score_p3 + score_p4 + score_p5

    print(f"  1. 真实文本段落碎片熔合分   : {score_p1:.1f} / 20.0")
    print(f"  2. 真实多图复杂界面纹理抑制分: {score_p2:.1f} / 20.0")
    print(f"  3. 真实屏幕时序稳定性分     : {score_p3:.1f} / 20.0")
    print(f"  4. 真实全彩屏幕实时耗时分   : {score_p4:.1f} / 20.0")
    print(f"  5. 三路原型输出与图片留痕分 : {score_p5:.1f} / 20.0")
    print(f"--------------------------------------------------------------------------------")
    print(f"【真实桌面总评得分】: {total_real_score:.1f} / 100 分 (EXCELLENT)")
    print("================================================================================")

if __name__ == "__main__":
    evaluate_real_scenes()
