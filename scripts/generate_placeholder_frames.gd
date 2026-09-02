extends SceneTree

func _init() -> void:
	print("[AssetGen] 开始生成 T08 原创小猫动画帧素材...")
	DirAccess.make_dir_recursive_absolute("res://assets/cat/placeholder")
	for i in range(4): _generate_frame("idle", i).save_png("res://assets/cat/placeholder/idle_0%d.png" % (i + 1))
	for i in range(6): _generate_frame("walk", i).save_png("res://assets/cat/placeholder/walk_0%d.png" % (i + 1))
	for i in range(6): _generate_frame("run", i).save_png("res://assets/cat/placeholder/run_0%d.png" % (i + 1))
	for i in range(2): _generate_frame("sit", i).save_png("res://assets/cat/placeholder/sit_0%d.png" % (i + 1))
	for i in range(4): _generate_frame("sleep", i).save_png("res://assets/cat/placeholder/sleep_0%d.png" % (i + 1))
	print("[AssetGen] T08 动画素材生成完毕！")
	quit(0)

func _generate_frame(anim: String, idx: int) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c_body := Color(0.98, 0.65, 0.25)
	var c_belly := Color(1.0, 0.9, 0.75)
	var c_eye := Color(0.12, 0.12, 0.12)
	var c_nose := Color(0.95, 0.45, 0.5)
	var cx := 32
	var cy := 36
	var leg_a := 0; var leg_b := 0
	
	if anim == "run":
		var r_y := [-2, 2, -2, 2, -2, 2]; cy += r_y[idx]
		var r_a := [-6, -3, 0, 5, 2, -3]; var r_b := [5, 2, -3, -6, -3, 0]
		leg_a = r_a[idx]; leg_b = r_b[idx]
	elif anim == "walk":
		var w_y := [-1, 1, -1, 1, -1, 1]; cy += w_y[idx]
		var w_a := [-4, -2, 0, 3, 1, -2]; var w_b := [3, 1, -2, -4, -2, 0]
		leg_a = w_a[idx]; leg_b = w_b[idx]
	elif anim == "sit":
		cy = 38 + (idx % 2)
	elif anim == "sleep":
		cy = 42 + (idx % 2) # 蜷缩卧倒
	
	# 绘制身体
	var rx := 18 if anim != "sit" else 14
	var ry := 12 if anim != "sleep" else 9
	for y in range(cy - ry, cy + ry):
		for x in range(cx - rx, cx + rx):
			if ((x - cx) / float(rx)) ** 2 + ((y - cy) / float(ry)) ** 2 <= 1.0: img.set_pixel(x, y, c_body)
	# 肚皮
	for y in range(cy, cy + ry - 2):
		for x in range(cx - 6, cx + 8):
			if ((x - cx) / 7.0) ** 2 + ((y - cy) / 7.0) ** 2 <= 0.8: img.set_pixel(x, y, c_belly)

	# 头部
	var hx := cx + (12 if anim == "run" else 10)
	var hy := cy - (6 if anim != "sleep" else 2)
	for y in range(hy - 9, hy + 9):
		for x in range(hx - 10, hx + 10):
			if ((x - hx) / 10.0) ** 2 + ((y - hy) / 9.0) ** 2 <= 1.0: img.set_pixel(x, y, c_body)
	# 耳朵
	for d in range(5):
		for w in range(d * 2 + 1):
			var ex1 := hx - 6 + w - d; var ey1 := hy - 9 - d
			if ex1 >= 0 and ex1 < 64 and ey1 >= 0 and ey1 < 64: img.set_pixel(ex1, ey1, c_body)
			var ex2 := hx + 2 + w - d; var ey2 := hy - 9 - d
			if ex2 >= 0 and ex2 < 64 and ey2 >= 0 and ey2 < 64: img.set_pixel(ex2, ey2, c_body)
	
	# 眼睛与鼻子
	if anim == "sleep": # 闭眼 (一横线)
		img.set_pixel(hx + 4, hy - 1, c_eye); img.set_pixel(hx + 5, hy - 1, c_eye); img.set_pixel(hx + 6, hy - 1, c_eye)
		img.set_pixel(hx + 1, hy - 1, c_eye); img.set_pixel(hx + 2, hy - 1, c_eye)
	else:
		img.set_pixel(hx + 5, hy - 2, c_eye); img.set_pixel(hx + 5, hy - 1, c_eye)
		img.set_pixel(hx + 1, hy - 2, c_eye); img.set_pixel(hx + 1, hy - 1, c_eye)
	img.set_pixel(hx + 8, hy + 1, c_nose)

	# 四肢
	if anim != "sit" and anim != "sleep":
		var base_leg_y := cy + 10
		_draw_rect(img, cx + 6 + leg_a, base_leg_y, 4, 8, c_body)
		_draw_rect(img, cx + 12 + leg_b, base_leg_y, 4, 8, c_body)
		_draw_rect(img, cx - 12 + leg_b, base_leg_y, 4, 8, c_body)
		_draw_rect(img, cx - 6 + leg_a, base_leg_y, 4, 8, c_body)
	return img

func _draw_rect(img: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if x >= 0 and x < 64 and y >= 0 and y < 64: img.set_pixel(x, y, col)
