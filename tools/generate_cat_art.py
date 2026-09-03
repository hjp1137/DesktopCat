import os
import math
from PIL import Image, ImageDraw

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "cat", "sprites")
CANVAS_SIZE = (64, 64)

# 统一原创暖金橘白萌系桌宠猫配色方案
COLOR_MAIN = (255, 155, 55, 255)       # 暖金橙背毛
COLOR_MAIN_DARK = (210, 100, 20, 255)  # 阴影与背部虎斑
COLOR_BELLY = (255, 250, 242, 255)     # 软萌雪白肚皮与爪套
COLOR_EAR_INNER = (255, 175, 170, 255) # 粉嫩内耳
COLOR_EYE = (40, 24, 18, 255)          # 水灵大杏眼
COLOR_EYE_HIGHLIGHT = (255, 255, 255, 255) # 眼睛双高光
COLOR_NOSE = (255, 135, 155, 255)      # 粉嘟嘟小鼻子
COLOR_OUTLINE = (165, 70, 15, 255)     # 柔和深色外轮廓线
COLOR_WHISKER = (140, 60, 15, 200)     # 灵动胡须线

def create_base_canvas():
    scale = 4
    im = Image.new("RGBA", (CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    return im, draw, scale

def downsample_and_save(im, filename):
    final_im = im.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)
    filepath = os.path.join(OUTPUT_DIR, filename)
    final_im.save(filepath, "PNG")
    print(f"[Art] Generated: {filename}")

def draw_cat_tail(draw, s, root_x, root_y, angle_deg, length=18, curve=0.0):
    rx, ry = root_x * s, root_y * s
    rad = math.radians(angle_deg)
    mid_x = rx + math.cos(rad) * (length * 0.5 * s)
    mid_y = ry - math.sin(rad) * (length * 0.5 * s) + curve * s
    end_x = rx + math.cos(rad + 0.3) * (length * s)
    end_y = ry - math.sin(rad + 0.3) * (length * s) + curve * 2 * s
    draw.line([(rx, ry), (mid_x, mid_y), (end_x, end_y)], fill=COLOR_MAIN, width=max(2, int(4.0 * s)), joint="curve")
    draw.ellipse([end_x - 2.0 * s, end_y - 2.0 * s, end_x + 2.0 * s, end_y + 2.0 * s], fill=COLOR_MAIN_DARK)

def draw_cat_head(draw, s, cx_log, cy_log, eye_open=1.0, look_dir=(0, 0)):
    cx, cy = cx_log * s, cy_log * s
    r = 13.0 * s
    # 头部底色与轮廓 (圆润饱满的大猫脸)
    draw.ellipse([cx - r, cy - r * 0.95, cx + r, cy + r * 0.95], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
    # 双耳
    draw.polygon([(cx - 10.5 * s, cy - 6 * s), (cx - 13.5 * s, cy - 19 * s), (cx - 3.5 * s, cy - 11 * s)], fill=COLOR_MAIN, outline=COLOR_OUTLINE)
    draw.polygon([(cx - 9.5 * s, cy - 7 * s), (cx - 12.5 * s, cy - 17 * s), (cx - 4.5 * s, cy - 11 * s)], fill=COLOR_EAR_INNER)
    draw.polygon([(cx + 10.5 * s, cy - 6 * s), (cx + 13.5 * s, cy - 19 * s), (cx + 3.5 * s, cy - 11 * s)], fill=COLOR_MAIN, outline=COLOR_OUTLINE)
    draw.polygon([(cx + 9.5 * s, cy - 7 * s), (cx + 12.5 * s, cy - 17 * s), (cx + 4.5 * s, cy - 11 * s)], fill=COLOR_EAR_INNER)
    # 面颊白毛包 (饱满白嘴套)
    draw.ellipse([cx - 9.5 * s, cy + 0.5 * s, cx + 9.5 * s, cy + 10.5 * s], fill=COLOR_BELLY)
    # 左右胡须
    for sign in [-1, 1]:
        wx = cx + sign * 9.0 * s
        draw.line([(wx, cy + 4.0 * s), (wx + sign * 6.0 * s, cy + 2.5 * s)], fill=COLOR_WHISKER, width=max(1, int(0.8 * s)))
        draw.line([(wx, cy + 6.5 * s), (wx + sign * 6.0 * s, cy + 7.5 * s)], fill=COLOR_WHISKER, width=max(1, int(0.8 * s)))
    # 小粉鼻
    draw.polygon([(cx - 1.8 * s, cy + 3.0 * s), (cx + 1.8 * s, cy + 3.0 * s), (cx, cy + 5.0 * s)], fill=COLOR_NOSE)
    # 大眼睛与双高光
    er_x, er_y = 3.2 * s, 4.0 * s * eye_open
    if eye_open > 0.2:
        for ex_sign in [-1, 1]:
            ex = cx + ex_sign * 6.5 * s + look_dir[0] * s
            ey = cy - 1.2 * s + look_dir[1] * s
            draw.ellipse([ex - er_x, ey - er_y, ex + er_x, ey + er_y], fill=COLOR_EYE)
            draw.ellipse([ex - 1.8 * s, ey - 2.8 * s, ex + 0.5 * s, ey - 0.5 * s], fill=COLOR_EYE_HIGHLIGHT)
            draw.ellipse([ex + 0.8 * s, ey + 0.8 * s, ex + 2.0 * s, ey + 2.0 * s], fill=COLOR_EYE_HIGHLIGHT)
    else:
        for ex_sign in [-1, 1]:
            ex = cx + ex_sign * 6.5 * s
            draw.arc([ex - 4 * s, cy - 2 * s, ex + 4 * s, cy + 3 * s], 10, 170, fill=COLOR_EYE, width=max(1, int(1.5 * s)))

def draw_cat_body_grounded(draw, s, bx_log, by_log, bw_log, bh_log, leg_phases, foot_y_log=58):
    bx, by = bx_log * s, by_log * s
    bw, bh = bw_log * s, bh_log * s
    foot_y = foot_y_log * s
    foot_r = 3.6 * s

    # 1. 远侧双腿 (左侧后腿与右侧前腿在深层)
    # 远侧后腿 (X 约 20)
    bl_x = bx - bw * 0.55 + leg_phases[2] * s
    draw.ellipse([bl_x - foot_r, foot_y - foot_r * 2.2, bl_x + foot_r, foot_y], fill=COLOR_MAIN_DARK)
    draw.ellipse([bl_x - foot_r * 0.9, foot_y - foot_r * 0.9, bl_x + foot_r * 0.9, foot_y], fill=COLOR_BELLY)
    # 远侧前腿 (X 约 36)
    fl_x = bx + bw * 0.45 + leg_phases[0] * s
    draw.ellipse([fl_x - foot_r, foot_y - foot_r * 2.4, fl_x + foot_r, foot_y], fill=COLOR_MAIN_DARK)
    draw.ellipse([fl_x - foot_r * 0.9, foot_y - foot_r * 0.9, fl_x + foot_r * 0.9, foot_y], fill=COLOR_BELLY)

    # 2. 躯干主椭圆 (圆润身体)
    draw.ellipse([bx - bw, by - bh, bx + bw, by + bh], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
    # 雪白大肚皮 (贴在胸腹前下方)
    draw.ellipse([bx - bw * 0.35, by - bh * 0.1, bx + bw * 0.85, by + bh * 0.95], fill=COLOR_BELLY)
    # 背部柔和虎斑纹
    draw.line([(bx - 5 * s, by - bh + 2 * s), (bx - 5 * s, by - bh * 0.25)], fill=COLOR_MAIN_DARK, width=max(1, int(1.6 * s)))
    draw.line([(bx + 2 * s, by - bh + 2 * s), (bx + 2 * s, by - bh * 0.25)], fill=COLOR_MAIN_DARK, width=max(1, int(1.6 * s)))

    # 3. 近侧双腿 (处于前景浅层)
    # 近侧后腿 (饱满后大腿肉包 + 白爪)
    br_x = bx - bw * 0.4 + leg_phases[3] * s
    draw.ellipse([br_x - foot_r * 1.3, foot_y - foot_r * 3.0, br_x + foot_r * 1.3, foot_y], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
    draw.ellipse([br_x - foot_r * 0.9, foot_y - foot_r * 1.0, br_x + foot_r * 0.9, foot_y], fill=COLOR_BELLY)
    # 近侧前腿 (挺拔前肢 + 白爪)
    fr_x = bx + bw * 0.7 + leg_phases[1] * s
    draw.ellipse([fr_x - foot_r, foot_y - foot_r * 2.6, fr_x + foot_r, foot_y], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
    draw.ellipse([fr_x - foot_r * 0.9, foot_y - foot_r * 1.0, fr_x + foot_r * 0.9, foot_y], fill=COLOR_BELLY)

def generate_idle():
    for f in range(6):
        im, draw, s = create_base_canvas()
        breath_y = math.sin(f * math.pi / 3.0) * 0.6
        tail_ang = 45 + math.sin(f * math.pi / 3.0) * 12
        eye_open = 0.0 if f == 4 else 1.0 # 偶尔眨眼
        draw_cat_tail(draw, s, 15, 43 + breath_y, tail_ang, length=18, curve=-2)
        draw_cat_body_grounded(draw, s, 26, 42 + breath_y, 14, 11, [0, 0, 0, 0], foot_y_log=58)
        draw_cat_head(draw, s, 38, 28 + breath_y, eye_open=eye_open)
        downsample_and_save(im, f"idle_{f+1:02d}.png")

def generate_walk():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_y = abs(math.sin(t)) * 1.2
        tail_ang = 40 + math.sin(t) * 15
        leg_phases = [math.sin(t) * 3.5, -math.sin(t) * 3.5, -math.sin(t) * 3.0, math.sin(t) * 3.0]
        draw_cat_tail(draw, s, 15, 42 - bob_y, tail_ang, length=18, curve=1)
        draw_cat_body_grounded(draw, s, 26, 41 - bob_y, 14, 11, leg_phases, foot_y_log=58)
        draw_cat_head(draw, s, 38, 28 - bob_y * 1.1, eye_open=1.0)
        downsample_and_save(im, f"walk_{f+1:02d}.png")

def generate_run():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        bob_y = abs(math.sin(t)) * 2.0
        tail_ang = 18 + math.sin(t) * 20
        leg_phases = [math.sin(t) * 6.5, -math.sin(t) * 6.5, -math.sin(t) * 6.0, math.sin(t) * 6.0]
        draw_cat_tail(draw, s, 14, 43 - bob_y, tail_ang, length=20, curve=-3)
        draw_cat_body_grounded(draw, s, 26, 42 - bob_y, 16, 10, leg_phases, foot_y_log=58)
        draw_cat_head(draw, s, 40, 29 - bob_y * 0.8, eye_open=1.0, look_dir=(1.5, 0))
        downsample_and_save(im, f"run_{f+1:02d}.png")

def generate_sit():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath_y = math.sin(f * math.pi / 2.0) * 0.5
        tail_ang = 15 + math.sin(f * math.pi / 2.0) * 6
        draw_cat_tail(draw, s, 18, 52 + breath_y, tail_ang, length=16, curve=4)
        # 坐姿端正躯干 (底部宽圆，收腹胸脯挺立)
        draw.ellipse([(32 - 13.5) * s, (38 + breath_y) * s, (32 + 13.5) * s, 57 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        # 雪白前胸大肚皮
        draw.ellipse([(32 - 7.5) * s, (41 + breath_y) * s, (32 + 7.5) * s, 56 * s], fill=COLOR_BELLY)
        # 两侧后腿大腿包
        draw.ellipse([(20 - 4) * s, (49 + breath_y) * s, (20 + 4) * s, 57 * s], fill=COLOR_MAIN_DARK)
        draw.ellipse([(44 - 4) * s, (49 + breath_y) * s, (44 + 4) * s, 57 * s], fill=COLOR_MAIN_DARK)
        # 两只端正前爪踩在 Y=58
        for px in [27.5, 36.5]:
            draw.ellipse([(px - 3.2) * s, 52 * s, (px + 3.2) * s, 58 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw_cat_head(draw, s, 32, 25 + breath_y, eye_open=1.0)
        downsample_and_save(im, f"sit_{f+1:02d}.png")

def generate_sleep():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath = math.sin(f * math.pi / 2.0) * 0.8
        # 温暖圆润橘猫团子 (大椭圆)
        draw.ellipse([(32 - 17) * s, (36 - breath * 0.4) * s, (32 + 17) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 10) * s, (44 - breath * 0.4) * s, (32 + 10) * s, 57 * s], fill=COLOR_BELLY)
        # 尾巴裹在身侧
        draw_cat_tail(draw, s, 45, 50, 160, length=22, curve=7)
        # 头部侧靠在身前 (闭目沉睡)
        draw_cat_head(draw, s, 24, 43 - breath * 0.3, eye_open=0.0)
        downsample_and_save(im, f"sleep_{f+1:02d}.png")

def generate_wake():
    for f in range(4):
        im, draw, s = create_base_canvas()
        arch_y = (1.0 - f / 3.0) * 3.5
        eye = 0.4 if f < 2 else 1.0
        draw_cat_tail(draw, s, 15, 43 - arch_y, 45 + f * 15, length=18)
        # 拱背伸懒腰
        draw.ellipse([(28 - 14) * s, (39 - arch_y) * s, (28 + 14) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(28 - 7) * s, (44 - arch_y) * s, (28 + 7) * s, 58 * s], fill=COLOR_BELLY)
        for px in [33 + f * 2, 39 + f * 2]:
            draw.ellipse([(px - 3) * s, 53 * s, (px + 3) * s, 58 * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 40, 29 - arch_y * 0.5, eye_open=eye)
        downsample_and_save(im, f"wake_{f+1:02d}.png")

def generate_jump():
    for f in range(4):
        im, draw, s = create_base_canvas()
        rot_y = (f / 3.0) * 4.0
        draw_cat_tail(draw, s, 13, 46 - rot_y, 25, length=20, curve=-4)
        draw.ellipse([(28 - 15) * s, (39 - rot_y) * s, (28 + 15) * s, (53 - rot_y) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(28 - 7) * s, (42 - rot_y) * s, (28 + 7) * s, (52 - rot_y) * s], fill=COLOR_BELLY)
        # 前探双爪，后蹬双腿
        draw.ellipse([(43 - 3.5) * s, (42 - rot_y) * s, (43 + 3.5) * s, (48 - rot_y) * s], fill=COLOR_BELLY)
        draw.ellipse([(13 - 3.5) * s, (48 - rot_y) * s, (13 + 3.5) * s, (54 - rot_y) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 41, 26 - rot_y * 1.1, eye_open=1.0)
        downsample_and_save(im, f"jump_{f+1:02d}.png")

def generate_fall():
    for f in range(4):
        im, draw, s = create_base_canvas()
        tail_ang = 60 + math.sin(f * math.pi) * 10
        draw_cat_tail(draw, s, 15, 37, tail_ang, length=18, curve=-2)
        draw.ellipse([(29 - 14) * s, 34 * s, (29 + 14) * s, 50 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(29 - 7) * s, 38 * s, (29 + 7) * s, 49 * s], fill=COLOR_BELLY)
        for px, py in [(17, 52), (23, 54), (39, 54), (45, 52)]:
            draw.ellipse([(px - 3) * s, (py - 3) * s, (px + 3) * s, (py + 3) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 40, 27, eye_open=1.0)
        downsample_and_save(im, f"fall_{f+1:02d}.png")

def generate_land():
    for f in range(3):
        im, draw, s = create_base_canvas()
        squish = (2 - f) * 2.5
        draw_cat_tail(draw, s, 15, 47 + squish, 30, length=16)
        # 落地压扁屈膝 (四足锁紧 Y=58)
        draw.ellipse([(30 - (15 + squish)) * s, (44 + squish * 0.5) * s, (30 + (15 + squish)) * s, 58 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(30 - 8) * s, (47 + squish * 0.5) * s, (30 + 8) * s, 58 * s], fill=COLOR_BELLY)
        for px in [17 - squish, 25, 36, 44 + squish]:
            draw.ellipse([(px - 3.5) * s, 53 * s, (px + 3.5) * s, 58 * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 37, 32 + squish * 0.8, eye_open=1.0)
        downsample_and_save(im, f"land_{f+1:02d}.png")

def generate_dragged():
    for f in range(4):
        im, draw, s = create_base_canvas()
        sway = math.sin(f * math.pi / 2.0) * 2.0
        draw_cat_tail(draw, s, 32 + sway * 0.5, 47, -80, length=18)
        draw.ellipse([(32 - 11 + sway * 0.5) * s, 26 * s, (32 + 11 + sway * 0.5) * s, 50 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 6 + sway * 0.5) * s, 29 * s, (32 + 6 + sway * 0.5) * s, 48 * s], fill=COLOR_BELLY)
        for px, py in [(24, 52), (28, 54), (36, 54), (40, 52)]:
            draw.ellipse([(px - 3 + sway) * s, py * s, (px + 3 + sway) * s, (py + 5) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 32 + sway * 0.3, 20, eye_open=1.0)
        downsample_and_save(im, f"dragged_{f+1:02d}.png")

def generate_edge_grab():
    for f in range(3):
        im, draw, s = create_base_canvas()
        stretch = f * 1.5
        draw_cat_tail(draw, s, 24, 46 + stretch, -40, length=16)
        draw.ellipse([(32 - 12) * s, (34 + stretch) * s, (32 + 12) * s, (52 + stretch) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 6) * s, (36 + stretch) * s, (32 + 6) * s, (50 + stretch) * s], fill=COLOR_BELLY)
        draw.ellipse([43 * s, 35 * s, 49 * s, 41 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw_cat_head(draw, s, 36, 25 + stretch, eye_open=1.0)
        downsample_and_save(im, f"edge_grab_{f+1:02d}.png")

def generate_edge_hang():
    for f in range(4):
        im, draw, s = create_base_canvas()
        sway = math.sin(f * math.pi / 2.0) * 1.2
        draw_cat_tail(draw, s, 26 + sway * 0.5, 50, -50, length=16, curve=3)
        draw.ellipse([(33 - 11 + sway * 0.5) * s, 34 * s, (33 + 11 + sway * 0.5) * s, 54 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(33 - 6 + sway * 0.5) * s, 36 * s, (33 + 6 + sway * 0.5) * s, 52 * s], fill=COLOR_BELLY)
        draw.ellipse([43 * s, 35 * s, 49 * s, 41 * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw.ellipse([(31 - 4 + sway) * s, 53 * s, (31 + 4 + sway) * s, 59 * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 37 + sway * 0.3, 24, eye_open=1.0)
        downsample_and_save(im, f"edge_hang_{f+1:02d}.png")

def generate_climb_up():
    for f in range(6):
        im, draw, s = create_base_canvas()
        p = f / 5.0
        up_y = p * 14.0
        shift_x = p * 6.0
        draw_cat_tail(draw, s, 22 - p * 6, 48 - up_y, -30 + p * 65, length=17)
        draw.ellipse([(30 + shift_x - 13) * s, (38 - up_y) * s, (30 + shift_x + 13) * s, (54 - up_y) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(30 + shift_x - 7) * s, (40 - up_y) * s, (30 + shift_x + 7) * s, (52 - up_y) * s], fill=COLOR_BELLY)
        draw.ellipse([(43 + shift_x) * s, (36 - up_y) * s, (49 + shift_x) * s, (42 - up_y) * s], fill=COLOR_BELLY)
        draw.ellipse([(20 + shift_x) * s, (50 - up_y) * s, (26 + shift_x) * s, (56 - up_y) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 38 + shift_x, 26 - up_y, eye_open=1.0)
        downsample_and_save(im, f"climb_up_{f+1:02d}.png")

def generate_wall_cling():
    for f in range(4):
        im, draw, s = create_base_canvas()
        breath = math.sin(f * math.pi / 2.0) * 0.8
        draw_cat_tail(draw, s, 24, 46 + breath, -70, length=18, curve=-2)
        draw.ellipse([(32 - 12) * s, (34 + breath) * s, (32 + 12) * s, (54 + breath) * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 6) * s, (37 + breath) * s, (32 + 6) * s, (52 + breath) * s], fill=COLOR_BELLY)
        draw.ellipse([44 * s, (35 + breath) * s, 50 * s, (41 + breath) * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw.ellipse([44 * s, (46 + breath) * s, 50 * s, (52 + breath) * s], fill=COLOR_BELLY, outline=COLOR_OUTLINE, width=max(1, int(1.0 * s)))
        draw_cat_head(draw, s, 36, 24 + breath, eye_open=1.0)
        downsample_and_save(im, f"wall_cling_{f+1:02d}.png")

def generate_wall_climb_up():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        step = math.sin(t) * 3.5
        draw_cat_tail(draw, s, 24, 46, -75 + step * 2, length=18)
        draw.ellipse([(32 - 12) * s, 34 * s, (32 + 12) * s, 54 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 6) * s, 37 * s, (32 + 6) * s, 52 * s], fill=COLOR_BELLY)
        draw.ellipse([44 * s, (33 - step) * s, 50 * s, (39 - step) * s], fill=COLOR_BELLY)
        draw.ellipse([44 * s, (45 + step) * s, 50 * s, (51 + step) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 36, 23 - abs(step) * 0.3, eye_open=1.0)
        downsample_and_save(im, f"wall_climb_up_{f+1:02d}.png")

def generate_wall_climb_down():
    for f in range(6):
        im, draw, s = create_base_canvas()
        t = f * math.pi / 3.0
        step = math.sin(t) * 3.2
        draw_cat_tail(draw, s, 24, 44, -50 + step * 2, length=18)
        draw.ellipse([(32 - 12) * s, 35 * s, (32 + 12) * s, 55 * s], fill=COLOR_MAIN, outline=COLOR_OUTLINE, width=max(1, int(1.2 * s)))
        draw.ellipse([(32 - 6) * s, 38 * s, (32 + 6) * s, 53 * s], fill=COLOR_BELLY)
        draw.ellipse([44 * s, (37 + step) * s, 50 * s, (43 + step) * s], fill=COLOR_BELLY)
        draw.ellipse([44 * s, (47 - step) * s, 50 * s, (53 - step) * s], fill=COLOR_BELLY)
        draw_cat_head(draw, s, 36, 25 + abs(step) * 0.3, eye_open=1.0)
        downsample_and_save(im, f"wall_climb_down_{f+1:02d}.png")

if __name__ == "__main__":
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("========== 开始生成高品质原创 16 组猫咪动画序列帧 ==========")
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
    print("========== 全套 74 帧原创高精动画生成完毕 ==========")
