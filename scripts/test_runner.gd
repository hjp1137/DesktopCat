extends SceneTree

func _init() -> void:
	print("========== 开始执行 T01 自动化自验证 ==========")
	var cat := Cat.new()
	var vp_size := Vector2(640, 360)
	
	# 测试 1: 初始参数与位置设置
	cat.position = vp_size / 2.0
	cat.speed = 200.0
	cat.body_radius = 24.0
	cat.direction = 1.0
	assert(cat.position == Vector2(320, 180), "初始位置应当在窗口中心")
	print("[PASS] 测试 1: 初始位置居中验证成功: ", cat.position)

	# 模拟向右移动
	var delta := 0.1
	cat._move_and_bounce(delta)
	assert(cat.position.x == 320.0 + 200.0 * 0.1, "小猫应当向右移动 delta * speed")
	print("[PASS] 测试 2: 基础移动 delta 计算验证成功: x=", cat.position.x)

	# 模拟移动至右边界
	cat.position.x = 640.0 - 24.0 - 10.0 # 临近右边界
	cat._move_and_bounce(0.1) # 跨越右边界
	assert(cat.position.x == 640.0 - 24.0, "小猫应当被钳制在右边界")
	assert(cat.direction == -1.0, "小猫触碰右边界后应当转向向左")
	assert(cat.scale.x < 0, "小猫触碰右边界后水平朝向应当翻转")
	print("[PASS] 测试 3: 右边界碰撞转向与钳制验证成功: x=", cat.position.x, ", dir=", cat.direction)

	# 模拟向左移动至左边界
	cat.position.x = 24.0 + 10.0 # 临近左边界
	cat._move_and_bounce(0.1) # 跨越左边界
	assert(cat.position.x == 24.0, "小猫应当被钳制在左边界")
	assert(cat.direction == 1.0, "小猫触碰左边界后应当转向向右")
	assert(cat.scale.x > 0, "小猫触碰左边界后水平朝向应当翻转")
	print("[PASS] 测试 4: 左边界碰撞转向与钳制验证成功: x=", cat.position.x, ", dir=", cat.direction)

	cat.free()
	print("========== T01 移动逻辑所有单元测试全部通过 ==========")
	quit(0)
