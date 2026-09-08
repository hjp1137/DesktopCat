extends Control

var main_node: Node2D
var preview_texture: ImageTexture
var preview_revision := ""
var preview_size := Vector2(1920, 1080)
var drawn_surface_count := 0

func _process(_delta: float) -> void:
	var model = main_node.cat_physics_world_model
	var revision_key: String = "%s:%d" % [model.session_id, model.latest_revision]
	if revision_key != preview_revision:
		preview_revision = revision_key
		var preview: Dictionary = model.debug_preview
		if preview.has("png_base64"):
			var image := Image.new()
			var error := image.load_png_from_buffer(Marshalls.base64_to_raw(preview.png_base64))
			if error == OK:
				preview_texture = ImageTexture.create_from_image(image)
				preview_size = Vector2(preview.width, preview.height)
			else: push_error("调试截图 PNG 解码失败: %s" % error)
		elif model.latest_revision == 0:
			preview_texture = null
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("151b24"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18, 26), "最终物理表面 | 绿：平台  黄：墙面  粉：脚底 | F7 / F9 / V：关闭", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var info: Dictionary = main_node.get_overlay_info()
	var world_size := Vector2(info.width, info.height)
	var factor := minf(size.x / world_size.x, (size.y - 65.0) / world_size.y)
	var origin := Vector2((size.x - world_size.x * factor) * 0.5, 40)
	if preview_texture:
		draw_texture_rect(preview_texture, Rect2(origin, world_size * factor), false)
	else:
		draw_string(font, origin + Vector2(20, 35), "等待屏幕采集……", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	drawn_surface_count = 0
	for surface in main_node.surface_world_model.surfaces_by_id.values():
		var color := Color("64ff96") if surface.walkable else Color("ffda63")
		draw_line(origin + surface.get_start().clamp(Vector2.ZERO, world_size) * factor, origin + surface.get_end().clamp(Vector2.ZERO, world_size) * factor, color, 2, true)
		drawn_surface_count += 1
	if is_instance_valid(main_node.cat):
		var cat = main_node.cat
		var foot: Vector2 = cat.get_foot_position()
		var half_width: float = cat.metrics.foot_width * 0.5
		draw_line(origin + (foot - Vector2(half_width, 0)) * factor, origin + (foot + Vector2(half_width, 0)) * factor, Color("ff559c"), 4, true)
		draw_circle(origin + foot * factor, 4, Color("ff559c"))
	draw_string(font, Vector2(18, size.y - 8), "快照 %d | 最终表面 %d" % [main_node.cat_physics_world_model.latest_revision, drawn_surface_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
