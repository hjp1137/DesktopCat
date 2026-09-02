extends SceneTree

func _init() -> void:
	print("========== 开始执行 T02 自动化自验证 ==========")
	var cat := Cat.new()
	
	# 测试 1: 初始参数与居中位置设置
	cat.position = cat._get_viewport_size() / 2.0
	cat.speed = 200.0
	cat.body_radius = 24.0
	cat.direction = 1.0
	assert(is_equal_approx(cat.position.x, 320.0) and is_equal_approx(cat.position.y, 180.0), "初始位置应当在视口中心")
	print("[PASS] 测试 1: 视口中心位置验证成功: ", cat.position)

	# 测试 2: 模拟向右移动
	var delta := 0.1
	cat._move_and_bounce(delta)
	assert(is_equal_approx(cat.position.x, 340.0), "小猫应当向右移动 delta * speed")
	print("[PASS] 测试 2: 基础移动 delta 计算验证成功: x=", cat.position.x)

	# 测试 3: 模拟移动至右边界
	var right_bound := 640.0 - 24.0
	cat.position.x = right_bound - 5.0
	cat._move_and_bounce(0.1)
	assert(is_equal_approx(cat.position.x, right_bound), "小猫应当被钳制在右边界")
	assert(cat.direction == -1.0, "小猫触碰右边界后应当转向向左")
	assert(cat.scale.x < 0, "小猫触碰右边界后水平朝向应当翻转")
	print("[PASS] 测试 3: 右边界碰撞转向与钳制验证成功: x=", cat.position.x, ", dir=", cat.direction)

	# 测试 4: 模拟向左移动至左边界
	cat.position.x = 24.0 + 5.0
	cat._move_and_bounce(0.1)
	assert(is_equal_approx(cat.position.x, 24.0), "小猫应当被钳制在左边界")
	assert(cat.direction == 1.0, "小猫触碰左边界后应当转向向右")
	assert(cat.scale.x > 0, "小猫触碰左边界后水平朝向应当翻转")
	print("[PASS] 测试 4: 左边界碰撞转向与钳制验证成功: x=", cat.position.x, ", dir=", cat.direction)

	cat.free()
	print("========== T02 移动逻辑所有单元测试全部通过 ==========")
	quit(0)
