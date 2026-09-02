extends SceneTree

func _init() -> void:
	print("[Build] 开始打包 DesktopCat.pck...")
	DirAccess.make_dir_recursive_absolute("res://build")
	
	var packer := PCKPacker.new()
	var err := packer.pck_start("build/DesktopCat.pck")
	if err != OK:
		printerr("创建 PCK 失败: ", err)
		quit(1)
		return
	
	var files := [
		"res://project.godot",
		"res://scenes/main.tscn",
		"res://scripts/main.gd",
		"res://scripts/cat.gd"
	]
	
	if FileAccess.file_exists("res://.godot/global_script_class_cache.cfg"):
		files.append("res://.godot/global_script_class_cache.cfg")
	
	for f in files:
		if FileAccess.file_exists(f):
			packer.add_file(f, f)
			print("[Build] 已添加: ", f)
		
	packer.flush()
	print("[Build] 打包完成: build/DesktopCat.pck")
	quit(0)
