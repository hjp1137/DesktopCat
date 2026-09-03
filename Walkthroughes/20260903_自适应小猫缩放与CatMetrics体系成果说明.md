# T20A 自适应小猫缩放与 CatMetrics 体系成果说明 (2026-09-03)

## 一、核心交付成果
1. **消除硬编码绝对像素技术债**:
   - 构建了响应式显示器缩放 `Adaptive Base Scale`（基于屏幕高度比 0.10，Clamp 85~180px）与用户缩放 `User Scale`（0.70~1.60）；
   - 建立了统一几何尺寸唯一事实来源 `CatMetrics` 与解耦配置 `CatBodyProfile`。
2. **逻辑锚点哲学统一**:
   - 统一确立 `Cat.position` 为小猫接触点（Foot/Contact Point），`foot_offset = Vector2.ZERO`；
   - 抓边锚点、挂墙接触点、鼠标穿透多边形、Hitbox 碰撞体全部基于 `CatMetrics` 等比派生。
3. **动态适应与安全机制**:
   - 快捷键 `[` / `]` 调节用户缩放，`\` 重置为 1.0，`F19` 开启度量调试视图；
   - 缩放突变时挂墙/悬挂安全脱落进入 `FALL`，地面缩放脚底精确贴合无缝；
   - `metrics_changed` 信号自动通知 `PlatformNavigationGraph` 重建导航图；
   - Surface 融合层根据 `min_platform_length` / `min_climbable_wall_length` 动态过滤。

## 二、自验证结果
1. **全量单元测试 90 项通过**:
   - `test_runner.gd` 执行用例 1～90 全部 PASS，包含 81～90 的缩放矩阵、Clamp、几何等比性、突变安全与 Hitbox 跟随测试。
2. **多源实体着陆物理回归通过**:
   - `test_fusion_landing.gd` 验证 Button、Text、Visual Line 上 Swept Landing 着陆正常。
3. **主场景与三路感知集成测试通过**:
   - `test_integration.gd` 验证 Bridge、快照接收、Chrome 窗口顶边下落着陆与各级 Debug 视图。
4. **独立包与 PCK 编译打包通过**:
   - `DesktopCat.pck` 与 `DesktopCat_Standalone.pck` 同步打包更新完成。

## 三、修改与新增文件清单
- `scripts/cat/cat_body_profile.gd`: 归一化几何与比例配置类 [NEW]
- `scripts/cat/cat_metrics.gd`: 唯一事实来源尺寸度量计算类 [NEW]
- `scripts/cat.gd`: 接入 CatMetrics，自适应缩放应用与 F19 绘制 [MODIFY]
- `scripts/navigation/cat_movement_capabilities.gd`: 尺寸参数优先读取 CatMetrics [MODIFY]
- `scripts/navigation/platform_navigation_graph.gd`: 监听 metrics_changed 触发图重建 [MODIFY]
- `scripts/world/surface_fusion_builder.gd`: 动态长度门槛判定 [MODIFY]
- `scripts/main.gd`: 动态穿透区域、切屏重算与 `[`/`]` 快捷键分发 [MODIFY]
- `scripts/external_bridge.gd`: 增加 SET_USER_SCALE 与 TOGGLE_DEBUG_METRICS [MODIFY]
- `scripts/test_runner.gd`: 扩展测试用例 81～90，适配动态支撑与端口重试 [MODIFY]
- `README.md` & `docs/screen_world_architecture.md`: 补充度量体系与快捷键说明 [MODIFY]
