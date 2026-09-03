import os

ANIM_CONFIG = [
    ("idle", 6, 8.0, True),
    ("walk", 6, 10.0, True),
    ("run", 6, 14.0, True),
    ("sit", 4, 4.0, True),
    ("sleep", 4, 3.0, True),
    ("wake", 4, 6.0, False),
    ("jump", 4, 10.0, True),
    ("fall", 4, 10.0, True),
    ("land", 3, 12.0, False),
    ("dragged", 4, 8.0, True),
    ("edge_grab", 3, 12.0, False),
    ("edge_hang", 4, 6.0, True),
    ("climb_up", 6, 10.0, False),
    ("wall_cling", 4, 6.0, True),
    ("wall_climb_up", 6, 10.0, True),
    ("wall_climb_down", 6, 10.0, True),
]

def generate_tscn():
    ext_resources = [
        'script = ExtResource("1_cat_script")',
        '[ext_resource type="Script" path="res://scripts/cat.gd" id="1_cat_script"]',
        '[ext_resource type="Script" path="res://scripts/cat/cat_shadow.gd" id="2_cat_shadow"]'
    ]
    ext_lines = [
        '[ext_resource type="Script" path="res://scripts/cat.gd" id="1_cat_script"]',
        '[ext_resource type="Script" path="res://scripts/cat/cat_shadow.gd" id="2_cat_shadow"]'
    ]
    
    ext_id = 3
    texture_map = {}
    for anim_name, count, _, _ in ANIM_CONFIG:
        for f in range(1, count + 1):
            tex_id = f"{ext_id}_{anim_name}_{f}"
            filename = f"{anim_name}_{f:02d}.png"
            ext_lines.append(f'[ext_resource type="Texture2D" path="res://assets/cat/sprites/{filename}" id="{tex_id}"]')
            texture_map[(anim_name, f)] = tex_id
            ext_id += 1

    load_steps = ext_id
    
    # 构造 SpriteFrames
    anim_blocks = []
    for anim_name, count, speed, loop in ANIM_CONFIG:
        frames = []
        for f in range(1, count + 1):
            tid = texture_map[(anim_name, f)]
            frames.append('{ "duration": 1.0, "texture": ExtResource("' + tid + '") }')
        frames_str = ", ".join(frames)
        loop_str = "true" if loop else "false"
        anim_blocks.append(f'{{\n"frames": [{frames_str}],\n"loop": {loop_str},\n"name": &"{anim_name}",\n"speed": {speed:.1f}\n}}')
    
    animations_content = ", ".join(anim_blocks)

    tscn_content = f"""[gd_scene load_steps={load_steps} format=3]

""" + "\n".join(ext_lines) + f"""

[sub_resource type="SpriteFrames" id="SpriteFrames_cat"]
animations = [{animations_content}]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_cat"]
size = Vector2(56, 56)

[node name="Cat" type="Node2D"]
script = ExtResource("1_cat_script")

[node name="CatShadow" type="Node2D" parent="."]
script = ExtResource("2_cat_shadow")

[node name="VisualRoot" type="Node2D" parent="."]

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="VisualRoot"]
sprite_frames = SubResource("SpriteFrames_cat")
animation = &"idle"
autoplay = "idle"

[node name="Area2D" type="Area2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = SubResource("RectangleShape2D_cat")
"""
    tscn_path = os.path.join(os.path.dirname(__file__), "..", "scenes", "cat.tscn")
    with open(tscn_path, "w", encoding="utf-8") as f:
        f.write(tscn_content)
    print(f"[TSCN] Generated: {tscn_path} with {len(ANIM_CONFIG)} animations.")

if __name__ == "__main__":
    generate_tscn()
