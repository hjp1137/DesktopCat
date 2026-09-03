# T20A 自适应小猫缩放与 CatMetrics 度量系统技术方案 (2026-09-03)

## 一、方案目标
彻底消除 DesktopCat 依赖固定 Sprite 尺寸和大量绝对像素常量的技术债，构建统一的 `Adaptive Cat Scale` + `CatMetrics` 体系。
支持显示器分辨率自适应（Responsive Scale）、用户缩放（User Scale）、运行时无缝重算以及为后续 T24 更换正式美术资产提供解耦的 `CatBodyProfile`。

## 二、架构设计
1. **数据流动与事实来源**:
   ```
   Display Metrics (Screen Height)
         ↓
   Adaptive Base Scale (CAT_SCREEN_HEIGHT_RATIO ≈ 0.10, Clamp 85~180px)
         ↓
   User Scale (MIN 0.70 ~ MAX 1.60, Default 1.00)
         ↓
   Final Cat Scale = base_scale * user_scale
         ↓
   CatBodyProfile (归一化几何与比例关系配置)
         ↓
   CatMetrics (Scale 后的实际像素尺寸，唯一事实来源，带 revision)
         ↓
   Physics / Navigation / Surface Usability / Grab / Climb / Hitbox
   ```
2. **CatBodyProfile (Normalized Reference Geometry)**:
   - 保存归一化身体包围盒、脚底偏移、抓边爪点、挂墙接触点、击中判定区域与各门槛比例。未来更换美术贴图仅需更新此配置。
3. **CatMetrics (Single Source of Truth)**:
   - 直接向物理、着陆、导航、抓边、攀爬与鼠标穿透输出 Scale 后的真实像素尺寸；禁止调用方自行二次乘以 Scale。

## 三、旧参数迁移策略
1. **改为 Metrics 驱动**:
   - `foot_offset`、`body_radius`、`support_margin`、`snap_tolerance`；
   - `edge_grab_x/y_tolerance`、`edge_hang_offset_x/y`、`grab_point_offset_x/y`；
   - `climb_inward_margin`、`climb_clearance_margin`、`min_climb_up_platform_length`；
   - `wall_attach_x_tolerance`、`wall_cling_offset_x`、`min_climbable_wall_length`、接触点与顶部过渡容差；
   - `update_mouse_passthrough` 与 `Area2D` 碰撞区。
2. **保持绝对物理不缩放**:
   - `gravity`、`jump_velocity`、`walk_speed`、`run_speed`、`wall_climb_speed`（屏幕世界未缩放，保持操作手感）。
3. **感知噪声门槛**:
   - 视觉线条检测最小像素阈值保持独立，不与小猫尺寸耦合。

## 四、运行时缩放与多显示器安全机制
- 按键 `[` 缩小 0.1，`]` 放大 0.1，`\` 重置为 1.0，`F19` 开启度量调试绘制；
- `metrics_changed` 信号触发 NavigationGraph 重建；
- 缩放变更时若处于挂边、翻越或爬墙，安全 detach 转为 FALL；若在地面重新贴地；
- TAB 切屏时根据新屏幕高度重新计算 Base Scale 并安全落到地面。

## 五、测试与验证矩阵
- 编写测试用例 81～90（用例总数达 90 项），覆盖 0.8、1.0、1.2、1.5 缩放完整功能测试；
- 运行回归物理验证（`test_fusion_landing.gd`）与独立打包 PCK 验证。
