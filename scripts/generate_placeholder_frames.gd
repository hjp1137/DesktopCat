extends SceneTree

func _init() -> void:
	print("[AssetGen] 开始生成原创临时小猫动画帧素材...")
	DirAccess.make_dir_recursive_absolute("res://assets/cat/placeholder")
	
	# 生成 4 帧 idle 动画
	for i in range(4):
		var img := _generate_cat_frame(false, i)
		img.save_png("res://assets/cat/placeholder/idle_0%d.png" % (i + 1))
	
	# 生成 6 帧 walk 动画
	for i in range(6):
		var img := _generate_cat_frame(true, i)
		img.save_png("res://assets/cat/placeholder/walk_0%d.png" % (i + 1))
		
	print("[AssetGen] 临时动画素材生成完毕！")
	quit(0)

func _generate_cat_frame(is_walk: bool, frame_idx: int) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # 透明背景
	
	var c_body := Color(0.98, 0.65, 0.25)
	var c_belly := Color(1.0, 0.9, 0.75)
	var c_ear_in := Color(0.98, 0.75, 0.75)
	var c_eye := Color(0.12, 0.12, 0.12)
	var c_nose := Color(0.95, 0.45, 0.5)
	
	var body_y_offset := 0
	var leg_offset_1 := 0
	var leg_offset_2 := 0
	var tail_y_offset := 0
	
	if is_walk:
		var walk_offsets := [-1, 1, -1, 1, -1, 1]
		body_y_offset = walk_offsets[frame_idx]
		var leg_offsets_a := [-4, -2, 0, 3, 1, -2]
		var leg_offsets_b := [3, 1, -2, -4, -2, 0]
		leg_offset_1 = leg_offsets_a[frame_idx]
		leg_offset_2 = leg_offsets_b[frame_idx]
		tail_y_offset = (frame_idx % 3) - 1
	else:
		var idle_offsets := [0, 1, 0, -1]
		body_y_offset = idle_offsets[frame_idx]
		tail_y_offset = idle_offsets[frame_idx] * 2
	
	var center_x := 32
	var center_y := 36 + body_y_offset
	
	# 绘制身体 (椭圆 36x24)
	for y in range(center_y - 12, center_y + 12):
		for x in range(center_x - 18, center_x + 18):
			var dx: float = (x - center_x) / 18.0
			var dy: float = (y - center_y) / 12.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c_body)
	
	# 绘制肚皮亮色
	for y in range(center_y, center_y + 10):
		for x in range(center_x - 8, center_x + 10):
			var dx: float = (x - (center_x + 1)) / 9.0
			var dy: float = (y - center_y) / 9.0
			if dx * dx + dy * dy <= 0.8:
				img.set_pixel(x, y, c_belly)

	# 头部 (中心 x=42, y=28)
	var head_x := center_x + 10
	var head_y := center_y - 8
	for y in range(head_y - 10, head_y + 10):
		for x in range(head_x - 11, head_x + 11):
			var dx: float = (x - head_x) / 11.0
			var dy: float = (y - head_y) / 10.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, c_body)

	# 猫耳 (三角形)
	for d in range(6):
		for w in range(d * 2 + 1):
			var ex1 := head_x - 6 + w - d
			var ey1 := head_y - 10 - d
			if ex1 >= 0 and ex1 < 64 and ey1 >= 0 and ey1 < 64:
				img.set_pixel(ex1, ey1, c_body)
			var ex2 := head_x + 3 + w - d
			var ey2 := head_y - 10 - d
			if ex2 >= 0 and ex2 < 64 and ey2 >= 0 and ey2 < 64:
				img.set_pixel(ex2, ey2, c_body)
	
	# 眼睛与鼻子
	img.set_pixel(head_x + 5, head_y - 2, c_eye)
	img.set_pixel(head_x + 5, head_y - 1, c_eye)
	img.set_pixel(head_x + 1, head_y - 2, c_eye)
	img.set_pixel(head_x + 1, head_y - 1, c_eye)
	img.set_pixel(head_x + 8, head_y + 2, c_nose)

	# 尾巴 (在身体后侧 x=center_x - 16, y=center_y)
	for t in range(12):
		var tx := center_x - 16 - t
		var ty := center_y - 2 - int(sin(t * 0.3) * 6.0) + tail_y_offset
		if tx >= 0 and tx < 64 and ty >= 0 and ty < 64:
			img.set_pixel(tx, ty, c_body)
			img.set_pixel(tx, ty + 1, c_body)

	# 四肢
	var base_leg_y := center_y + 10
	_draw_rect(img, center_x + 6 + leg_offset_1, base_leg_y, 4, 8, c_body)
	_draw_rect(img, center_x + 12 + leg_offset_2, base_leg_y, 4, 8, c_body)
	_draw_rect(img, center_x - 12 + leg_offset_2, base_leg_y, 4, 8, c_body)
	_draw_rect(img, center_x - 6 + leg_offset_1, base_leg_y, 4, 8, c_body)

	return img

func _draw_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if x >= 0 and x < 64 and y >= 0 and y < 64:
				img.set_pixel(x, y, col)
