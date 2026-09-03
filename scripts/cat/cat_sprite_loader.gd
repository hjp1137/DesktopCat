class_name CatSpriteLoader
extends RefCounted

const ANIM_DEFINITIONS = [
	{"name": "idle", "count": 6, "fps": 8.0, "loop": true},
	{"name": "walk", "count": 6, "fps": 10.0, "loop": true},
	{"name": "run", "count": 6, "fps": 14.0, "loop": true},
	{"name": "sit", "count": 4, "fps": 4.0, "loop": true},
	{"name": "sleep", "count": 4, "fps": 3.0, "loop": true},
	{"name": "wake", "count": 4, "fps": 6.0, "loop": false},
	{"name": "jump", "count": 4, "fps": 10.0, "loop": true},
	{"name": "fall", "count": 4, "fps": 10.0, "loop": true},
	{"name": "land", "count": 3, "fps": 12.0, "loop": false},
	{"name": "dragged", "count": 4, "fps": 8.0, "loop": true},
	{"name": "edge_grab", "count": 3, "fps": 12.0, "loop": false},
	{"name": "edge_hang", "count": 4, "fps": 6.0, "loop": true},
	{"name": "climb_up", "count": 6, "fps": 10.0, "loop": false},
	{"name": "wall_cling", "count": 4, "fps": 6.0, "loop": true},
	{"name": "wall_climb_up", "count": 6, "fps": 10.0, "loop": true},
	{"name": "wall_climb_down", "count": 6, "fps": 10.0, "loop": true},
]

static func load_cat_sprite_frames(base_dir: String = "res://assets/cat/sprites") -> SpriteFrames:
	var sf := SpriteFrames.new()
	# 移除默认的 default 动画
	if sf.has_animation("default"):
		sf.remove_animation("default")

	for def in ANIM_DEFINITIONS:
		var anim_name: String = def["name"]
		var count: int = def["count"]
		var fps: float = def["fps"]
		var loop: bool = def["loop"]

		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)

		for i in range(1, count + 1):
			var filename = "%s_%02d.png" % [anim_name, i]
			var path = base_dir.path_join(filename)
			var tex: Texture2D = null

			# 优先直接使用 Image.load_from_file 无损加载
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
			elif ResourceLoader.exists(path):
				tex = load(path)

			if tex != null:
				sf.add_frame(anim_name, tex)
			else:
				push_warning("[CatSpriteLoader] Missing texture: " + path)

	print("[CatSpriteLoader] Loaded %d animations from %s" % [ANIM_DEFINITIONS.size(), base_dir])
	return sf
