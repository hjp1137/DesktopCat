import os
import math
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "cat", "sprites")
CANVAS_SIZE = (64, 64)

# 统一原创暖橙白腹萌系桌宠猫配色方案
COLOR_MAIN = (255, 158, 64, 255)       # 暖金橙
COLOR_MAIN_DARK = (217, 107, 26, 255)  # 阴影与虎斑纹
COLOR_BELLY = (255, 245, 235, 255)     # 乳白胸腹与爪套
COLOR_EAR_INNER = (255, 170, 166, 255) # 粉嫩内耳
COLOR_EYE = (58, 36, 26, 255)          # 深棕黑大猫眼
COLOR_EYE_HIGHLIGHT = (255, 255, 255, 255) # 眼睛高光
COLOR_NOSE = (255, 143, 163, 255)      # 粉色鼻头
COLOR_OUTLINE = (180, 80, 20, 255)     # 柔和深色外轮廓线

def create_base_canvas():
    # 4倍超采样以获得最佳边缘平滑度
    scale = 4
    im = Image.new("RGBA", (CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    return im, draw, scale

def downsample_and_save(im, filename):
    final_im = im.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)
    filepath = os.path.join(OUTPUT_DIR, filename)
    final_im.save(filepath, "PNG")
    print(f"[Art] Generated: {filename}")

def draw_cat_head(draw, s, cx, cy, eye_open=1.0, look_dir=(0, 0)):
    # 头部底色与轮廓 (圆润饱满的大猫头)
    r = 13 * s
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
    # 双耳
    draw.polygon([(cx - 10 * s, cy - 8 * s), (cx - 13 * s, cy - 20 * s), (cx - 3 * s, cy - 12 * s)], fill=COLOR_MAIN, outline=COLOR_OUTLINE)
    draw.polygon([(cx - 9 * s, cy - 9 * s), (cx - 12 * s, cy - 18 * s), (cx - 4 * s, cy - 12 * s)], fill=COLOR_EAR_INNER)
    draw.polygon([(cx + 10 * s, cy - 8 * s), (cx + 13 * s, cy - 20 * s), (cx + 3 * s, cy - 12 * s)], fill=COLOR_MAIN, outline=COLOR_OUTLINE)
    draw.polygon([(cx + 9 * s, cy - 9 * s), (cx + 12 * s, cy - 18 * s), (cx + 4 * s, cy - 12 * s)], fill=COLOR_EAR_INNER)
    # 面颊白毛包
    draw.ellipse([cx - 9 * s, cy + 1 * s, cx + 9 * s, cy + 11 * s], fill=COLOR_BELLY)
    # 粉色小鼻子
    draw.polygon([(cx - 2 * s, cy + 3 * s), (cx + 2 * s, cy + 3 * s), (cx, cy + 5 * s)], fill=COLOR_NOSE)
    # 大眼睛
    er_x = 3.2 * s
    er_y = 4.0 * s * eye_open
    if eye_open > 0.2:
        draw.ellipse([cx - 7 * s - er_x + look_dir[0] * s, cy - 1 * s - er_y + look_dir[1] * s, cx - 7 * s + er_x + look_dir[0] * s, cy - 1 * s + er_y + look_dir[1] * s], fill=COLOR_EYE)
        draw.ellipse([cx + 7 * s - er_x + look_dir[0] * s, cy - 1 * s - er_y + look_dir[1] * s, cx + 7 * s + er_x + look_dir[0] * s, cy - 1 * s + er_y + look_dir[1] * s], fill=COLOR_EYE)
        # 高光
        draw.ellipse([cx - 8 * s + look_dir[0] * s, cy - 3 * s + look_dir[1] * s, cx - 6 * s + look_dir[0] * s, cy - 1 * s + look_dir[1] * s], fill=COLOR_EYE_HIGHLIGHT)
        draw.ellipse([cx + 6 * s + look_dir[0] * s, cy - 3 * s + look_dir[1] * s, cx + 8 * s + look_dir[0] * s, cy - 1 * s + look_dir[1] * s], fill=COLOR_EYE_HIGHLIGHT)
    else:
        # 眯眼/闭眼弧线
        draw.arc([cx - 9 * s, cy - 2 * s, cx - 4 * s, cy + 2 * s], 0, 180, fill=COLOR_EYE, width=max(1, int(1.5 * s)))
        draw.arc([cx + 4 * s, cy - 2 * s, cx + 9 * s, cy + 2 * s], 0, 180, fill=COLOR_EYE, width=max(1, int(1.5 * s)))

def draw_cat_tail(draw, s, root_x, root_y, angle_deg, length=18, curve=0.0):
    rad = math.radians(angle_deg)
    mid_x = root_x + math.cos(rad) * (length * 0.5 * s)
    mid_y = root_y - math.sin(rad) * (length * 0.5 * s) + curve * s
    end_x = root_x + math.cos(rad + 0.3) * (length * s)
    end_y = root_y - math.sin(rad + 0.3) * (length * s) + curve * 2 * s
    draw.line([(root_x, root_y), (mid_x, mid_y), (end_x, end_y)], fill=COLOR_MAIN, width=max(1, int(3.6 * s)), joint="curve")
def draw_cat_body_grounded(draw, s, bx, by, bw, bh, leg_phases, foot_y=58):
    # 躯干 (圆润椭圆)
    draw.ellipse([bx - bw * s, by - bh * s, bx + bw * s, by + bh * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
    # 腹部白毛
    draw.ellipse([bx - bw * 0.65 * s, by - bh * 0.2 * s, bx + bw * 0.65 * s, by + bh * 0.9 * s], fill=COLOR_BELLY)
    # 背部虎斑纹
    draw.line([(bx - 3 * s, by - bh * s + 2 * s), (bx - 3 * s, by - bh * 0.4 * s)], fill=COLOR_MAIN_DARK, width=max(1, int(1.5 * s)))
    draw.line([(bx + 3 * s, by - bh * s + 2 * s), (bx + 3 * s, by - bh * 0.4 * s)], fill=COLOR_MAIN_DARK, width=max(1, int(1.5 * s)))
    # 四足绘制与 Foot Lock 对齐 (leg_phases 控制四腿前后摆动)
    # leg_phases: [fl_off_x, fr_off_x, bl_off_x, br_off_x]
    foot_r = 3.2 * s
    # 后左、后右 (深色/在后)
    for lx_ratio, off_x in [(-0.55, leg_phases[2]), (0.1, leg_phases[3])]:
        lx = bx + lx_ratio * bw * s + off_x * s
        ly = foot_y * s - foot_r
        draw.ellipse([lx - foot_r, ly - foot_r * 1.5, lx + foot_r, ly + foot_r], fill=COLOR_MAIN_DARK)
        draw.ellipse([lx - foot_r * 0.8, ly + foot_r * 0.2, lx + foot_r * 0.8, ly + foot_r], fill=COLOR_BELLY)
    # 前左、前右 (在前)
    for lx_ratio, off_x in [(-0.2, leg_phases[0]), (0.55, leg_phases[1])]:
        lx = bx + lx_ratio * bw * s + off_x * s
        ly = foot_y * s - foot_r
        draw.ellipse([lx - foot_r, ly - foot_r * 1.8, lx + foot_r, ly + foot_r], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw.ellipse([lx - foot_r * 0.8, ly + foot_r * 0.2, lx + foot_r * 0.8, ly + foot_r], fill=COLOR_BELLY)

def generate_idle():
    for f in range(6):
        im, draw, s = create_base_canvas()
        breath_y = math.sin(f * math.pi / 3.0) * 0.8
        tail_ang = 45 + math.sin(f * math.pi / 3.0) * 12
        eye_open = 0.0 if f == 4 else 1.0 # 偶尔眨眼
        # 躯干 (bx=30, by=40+breath_y)
        draw_cat_tail(draw, s, 18 * s, (44 + breath_y) * s, tail_ang, curve=-2)
        draw_cat_body_grounded(draw, s, 30, 41 + breath_y, 14, 11, [0, 0, 0, 0], foot_y=58)
        draw_cat_head(draw, s, 42 * s, (29 + breath_y) * s, eye_open=eye_open)
        downsample_and_save(im, f"idle_{f+1:02d}.png")

def generate_walk():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_y = abs(math.sin(t)) * 1.5
        tail_ang = 40 + math.sin(t) * 15
        leg_phases = [math.sin(t) * 3.5, -math.sin(t) * 3.5, -math.sin(t) * 3.0, math.sin(t) * 3.0]
        draw_cat_tail(draw, s, 18 * s, (43 - bob_y) * s, tail_ang, curve=1)
        draw_cat_body_grounded(draw, s, 30, 40 - bob_y, 14, 10.5, leg_phases, foot_y=58)
        draw_cat_head(draw, s, 43 * s, (29 - bob_y * 1.2) * s, eye_open=1.0)
        downsample_and_save(im, f"walk_{f+1:02d}.png")

def generate_run():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_y = abs(math.sin(t)) * 2.5
        tail_ang = 15 + math.sin(t) * 20 # 压低尾巴冲刺
        # 大步张开
        leg_phases = [math.sin(t) * 6.5, -math.sin(t) * 6.5, -math.sin(t) * 6.0, math.sin(t) * 6.0]
        draw_cat_tail(draw, s, 16 * s, (44 - bob_y) * s, tail_ang, length=20, curve=-3)
        draw_cat_body_grounded(draw, s, 30, 42 - bob_y, 16, 9.5, leg_phases, foot_y=58)
        draw_cat_head(draw, s, 45 * s, (31 - bob_y * 0.8) * s, eye_open=1.0, look_dir=(1.5, 0))
        downsample_and_save(im, f"run_{f+1:02d}.png")

def generate_sit():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath_y = math.sin(f * math.pi / 2.0) * 0.5
        tail_ang = 10 + math.sin(f * math.pi / 2.0) * 5
        # 坐姿：身体直立收缩
        draw_cat_tail(draw, s, 20 * s, 54 * s, tail_ang, length=16, curve=4)
        draw.ellipse([(32 - 13) * s, (45 + breath_y) * s, (32 + 13) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 7) * s, (48 + breath_y) * s, (32 + 7) * s, 58 * s], fill=COLOR_BELLY)
        # 两只端正前爪
        for px in [27, 37]:
            draw.ellipse([(px - 3) * s, 54 * s, (px + 3) * s, 58 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw_cat_head(draw, s, 32 * s, (30 + breath_y) * s, eye_open=1.0)
        downsample_and_save(im, f"sit_{f+1:02d}.png")

def generate_sleep():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath = math.sin(f * math.pi / 2.0) * 1.0
        # 蜷缩团子
        draw.ellipse([(32 - 17) * s, (46 - breath * 0.5) * s, (32 + 17) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw_cat_tail(draw, s, 44 * s, 53 * s, 175, length=18, curve=6)
        # 头部靠在身体边
        draw_cat_head(draw, s, 22 * s, 47 * s, eye_open=0.0)
        downsample_and_save(im, f"sleep_{f+1:02d}.png")

def generate_wake():
    for f in range(4):
        im, draw, s = create_base_canvas()
        # 伸懒腰拱背打哈欠
        arch_y = (1.0 - f / 3.0) * 4.0
        eye = 0.3 if f < 2 else 1.0
        draw_cat_tail(draw, s, 16 * s, (46 - arch_y) * s, 60 + f * 10, length=18)
        draw.ellipse([(32 - 14) * s, (42 - arch_y) * s, (32 + 14) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 前足伸展
        for px in [34 + f * 2, 40 + f * 2]:
            draw.ellipse([(px - 3) * s, 54 * s, (px + 3) * s, 58 * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 42 * s, (32 - arch_y * 0.5) * s, eye_open=eye)
        downsample_and_save(im, f"wake_{f+1:02d}.png")

def generate_jump():
    for f in range(4):
        im, draw, s = create_base_canvas()
        # 身体向上倾斜蹬起
        rot_y = (f / 3.0) * 4.0
        draw_cat_tail(draw, s, 16 * s, (45 + rot_y) * s, 10, length=18)
        draw.ellipse([(32 - 12) * s, (34 - rot_y) * s, (32 + 12) * s, (50 - rot_y) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 四足收缩向上
        for px, py in [(26, 50 - rot_y), (38, 48 - rot_y)]:
            draw.ellipse([(px - 3) * s, py * s, (px + 3) * s, (py + 4) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 42 * s, (24 - rot_y) * s, eye_open=1.0, look_dir=(1.0, -1.0))
        downsample_and_save(im, f"jump_{f+1:02d}.png")

def generate_fall():
    for f in range(4):
        im, draw, s = create_base_canvas()
        # 身体前倾下倾，四足微张准备缓冲
        bob = math.sin(f * math.pi / 2.0) * 1.5
        draw_cat_tail(draw, s, 18 * s, (38 + bob) * s, 70, length=20)
        draw.ellipse([(32 - 13) * s, (36 + bob) * s, (32 + 13) * s, (51 + bob) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        for px, py in [(24, 52 + bob), (40, 52 + bob)]:
            draw.ellipse([(px - 3.5) * s, py * s, (px + 3.5) * s, (py + 5) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 40 * s, (27 + bob) * s, eye_open=1.0, look_dir=(0.5, 1.0))
        downsample_and_save(im, f"fall_{f+1:02d}.png")

def generate_land():
    # 落地缓冲三帧：深屈 -> 回弹 -> 恢复
    squashes = [6.0, 3.0, 0.0]
    for f in range(3):
        im, draw, s = create_base_canvas()
        sq = squashes[f]
        draw_cat_tail(draw, s, 18 * s, (46 + sq * 0.5) * s, 35, length=18)
        # 身体横向变宽，纵向变扁
        draw.ellipse([(30 - (15 + sq * 0.5)) * s, (44 + sq) * s, (30 + (15 + sq * 0.5)) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 四足贴地
        for px in [20, 28, 36, 44]:
            draw.ellipse([(px - 3) * s, 54 * s, (px + 3) * s, 58 * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 42 * s, (32 + sq * 0.8) * s, eye_open=1.0)
        downsample_and_save(im, f"land_{f+1:02d}.png")

def generate_dragged():
    for f in range(4):
        im, draw, s = create_base_canvas()
        sway = math.sin(f * math.pi / 2.0) * 1.5
        # 身体悬挂下垂
        draw_cat_tail(draw, s, (30 + sway * 0.5) * s, 48 * s, 260 + sway * 8, length=18)
        draw.ellipse([(30 - 11 + sway) * s, 28 * s, (30 + 11 + sway) * s, 52 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 四足自然下垂
        for px, py in [(24, 52), (36, 52)]:
            draw.ellipse([(px - 2.5 + sway) * s, py * s, (px + 2.5 + sway) * s, (py + 6) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, (30 + sway) * s, 20 * s, eye_open=1.0, look_dir=(0, 1.0))
        downsample_and_save(im, f"dragged_{f+1:02d}.png")

def generate_edge_grab():
    for f in range(3):
        im, draw, s = create_base_canvas()
        # 空中前爪探出抓向右侧平台边缘 (46, 38)
        draw_cat_tail(draw, s, 20 * s, 46 * s, 210, length=16)
        draw.ellipse([(30 - 11) * s, 34 * s, (30 + 11) * s, 52 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 双前爪伸向 (46, 38)
        paw_x = 42 + f * 2
        draw.ellipse([(paw_x - 3) * s, 36 * s, (paw_x + 3) * s, 40 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE)
        draw_cat_head(draw, s, 38 * s, 26 * s, eye_open=1.0, look_dir=(1.0, 0))
        downsample_and_save(im, f"edge_grab_{f+1:02d}.png")

def generate_edge_hang():
    for f in range(4):
        im, draw, s = create_base_canvas()
        sway = math.sin(f * math.pi / 2.0) * 1.0
        # 双前爪精准扣住平台边缘 (46, 38)
        draw.ellipse([(46 - 4) * s, 36 * s, (46 + 4) * s, 40 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        # 身体下垂并在风中微晃
        draw_cat_tail(draw, s, (34 + sway) * s, 54 * s, 240 + sway * 10, length=16)
        draw.ellipse([(34 - 10 + sway) * s, 38 * s, (34 + 10 + sway) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw_cat_head(draw, s, (38 + sway * 0.5) * s, 28 * s, eye_open=1.0)
        downsample_and_save(im, f"edge_hang_{f+1:02d}.png")

def generate_climb_up():
    # 6帧两段式翻越: PULL_UP (1-2) -> SHIFT_IN (3-4) -> SETTLE (5-6)
    for f in range(6):
        im, draw, s = create_base_canvas()
        progress = f / 5.0
        # 整体重心从边缘下方 (34, 48) 平滑向上向前移动到平台表面 (30, 41)
        bx = 36 - progress * 6.0
        by = 52 - progress * 11.0
        tail_ang = 220 - progress * 160 # 尾巴从下垂转为向后自然扬起
        draw_cat_tail(draw, s, (bx - 10) * s, (by + 4) * s, tail_ang, length=16)
        draw.ellipse([(bx - 12) * s, (by - 9) * s, (bx + 12) * s, (by + 9) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 双爪用力撑平台
        paw_y = 38 if f < 4 else (by + 8)
        for px in [bx + 2, bx + 8]:
            draw.ellipse([(px - 3) * s, paw_y * s, (px + 3) * s, (paw_y + 4) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, (bx + 10) * s, (by - 8) * s, eye_open=1.0)
        downsample_and_save(im, f"climb_up_{f+1:02d}.png")

def generate_wall_cling():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath = math.sin(f * math.pi / 2.0) * 0.8
        # 面向右侧墙壁，四足抓附墙体 (x=48)
        draw_cat_tail(draw, s, 26 * s, (44 + breath) * s, 230, length=16)
        draw.ellipse([(34 - 10) * s, (38 + breath) * s, (34 + 10) * s, (52 + breath) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 四足贴右墙 (x=48)
        for py in [36 + breath, 42 + breath, 48 + breath, 52 + breath]:
            draw.ellipse([45 * s, (py - 2.5) * s, 49 * s, (py + 2.5) * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE)
        draw_cat_head(draw, s, 38 * s, (28 + breath) * s, eye_open=1.0, look_dir=(1.0, 0))
        downsample_and_save(im, f"wall_cling_{f+1:02d}.png")

def generate_wall_climb_up():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_x = math.sin(t) * 1.0
        # 向上爬行，爪子上下交替贴墙
        draw_cat_tail(draw, s, (26 + bob_x) * s, 45 * s, 240 + math.sin(t) * 15, length=16)
        draw.ellipse([(34 - 10 + bob_x) * s, 36 * s, (34 + 10 + bob_x) * s, 52 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        paw_offs = [math.sin(t) * 4.0, -math.sin(t) * 4.0, -math.sin(t) * 3.5, math.sin(t) * 3.5]
        for idx, base_y in enumerate([34, 40, 46, 52]):
            py = base_y + paw_offs[idx]
            draw.ellipse([45 * s, (py - 2.5) * s, 49 * s, (py + 2.5) * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE)
        draw_cat_head(draw, s, (38 + bob_x * 0.5) * s, 26 * s, eye_open=1.0, look_dir=(1.0, -1.0))
        downsample_and_save(im, f"wall_climb_up_{f+1:02d}.png")

def generate_wall_climb_down():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_x = math.sin(t) * 1.0
        # 向下倒退爬行
        draw_cat_tail(draw, s, (26 + bob_x) * s, 43 * s, 220 + math.sin(t) * 15, length=16)
        draw.ellipse([(34 - 10 + bob_x) * s, 38 * s, (34 + 10 + bob_x) * s, 54 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        paw_offs = [-math.sin(t) * 4.0, math.sin(t) * 4.0, math.sin(t) * 3.5, -math.sin(t) * 3.5]
        for idx, base_y in enumerate([36, 42, 48, 54]):
            py = base_y + paw_offs[idx]
            draw.ellipse([45 * s, (py - 2.5) * s, 49 * s, (py + 2.5) * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE)
        draw_cat_head(draw, s, (38 + bob_x * 0.5) * s, 29 * s, eye_open=1.0, look_dir=(0.8, 1.0))
        downsample_and_save(im, f"wall_climb_down_{f+1:02d}.png")

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("Generating full T24 original cat animation sprite suite...")
    generate_idle()
    generate_walk()
    generate_run()
    generate_sit()
    generate_sleep()
    generate_wake()
    generate_jump()
    generate_fall()
    generate_land()
    generate_dragged()
    generate_edge_grab()
    generate_edge_hang()
    generate_climb_up()
    generate_wall_cling()
    generate_wall_climb_up()
    generate_wall_climb_down()
    print("All 16 animation suites successfully generated!")
