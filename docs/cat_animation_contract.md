# DesktopCat 动画契约与状态映射规范 (Animation Contract)

## 一、架构层级解耦
```
Cat (CharacterBody2D/Node2D, Physics Root) ── [绝对位置事实来源]
  ├─ CatShadow (纯绘制软阴影, 随高度/状态自适应缩放透明度)
  ├─ VisualRoot (Node2D, 视觉根节点, 处理Squash/Stretch与朝向翻转)
  │    └─ AnimatedSprite2D (16套核心动画序列帧)
  ├─ Area2D (Hitbox, 物理碰撞/点击判定)
  └─ CatAnimationController (状态映射、过渡平滑、动画调试模式)
```
- **核心契约**：动画系统绝对禁止直接驱动或修改物理位置与速度；真实 `position` 永远属于 Physics Root；
- **Foot Lock**：小猫脚底接触点位于局部坐标 `(0, 0)`（`Cat.position` 即为 Foot Contact Point），所有地面动画帧严格对齐该基准，消除任何脚滑与上下跳变。

## 二、状态到动画映射规则
| CatState (底层物理状态) | 主播放动画 (Animation) | 触发条件与过渡逻辑 |
|:---|:---|:---|
| `IDLE` | `idle` | 地面静止，支持微呼吸与眨眼 |
| `WALK` | `walk` | 地面常规速度行走 ($\le 80\text{px/s}$) |
| `RUN` | `run` | 地面高速奔跑 ($> 80\text{px/s}$) |
| `SIT` | `sit` | 地面蹲坐，尾巴环绕 |
| `SLEEP` | `sleep` | 蜷缩睡眠，闭目呼吸 |
| `JUMP` | `jump` | 滞空且垂直速度向上 ($V_y \le 0$) |
| `FALL` | `fall` | 滞空且垂直速度向下 ($V_y > 0$) |
| `DRAG` | `dragged` | 鼠标拖拽悬空状态 |
| `EDGE_HANG` | `edge_hang` | 边缘悬挂状态，爪点扣住边缘 |
| `CLIMB_UP` | `climb_up` | 两段式翻越动画 (PULL_UP -> SHIFT_IN) |
| `WALL_CLING` | `wall_cling` | 竖直墙面附着静止 |
| `WALL_CLIMB` (向上) | `wall_climb_up` | 沿墙向上爬行 |
| `WALL_CLIMB` (向下) | `wall_climb_down`| 沿墙向下爬行 |

## 三、过渡动画与瞬态视觉反馈
1. **落地缓冲 (Landing Squash)**：
   - 监听物理着陆事件（`landed`）：先播放 3 帧专属 `land` 动画（深蹲缓冲），同时对 `VisualRoot` 施加瞬时纵向压缩（`scale.y = 0.85, scale.x = 1.15`），在 0.15 秒内平滑恢复，不改变脚底接触物理点；
2. **边缘抓取过渡 (Edge Grab)**：
   - 从 `FALL` 转入 `EDGE_HANG` 时先播放 3 帧 `edge_grab` 瞬间探爪，再无缝衔接 `edge_hang` 循环；
3. **苏醒过渡 (Wake)**：
   - 从 `SLEEP` 恢复时先播放 4 帧 `wake` 拱背伸懒腰打哈欠，再回归 `idle`；
4. **轻量阴影 (Cat Shadow)**：
   - 在 `Cat` 脚底局部 `(0, 0)` 处绘制半透明椭圆（`Color(0, 0, 0, 0.25)`）；
   - 地面状态下横纵轴为 `(20, 5)`；滞空时随高度提升等比缩小并淡化；挂壁与悬挂时自动隐退。

## 四、调试支持与快捷键
- **F22**：切换动画调试视图（显示 CatState、当前动画、帧号、VisualRoot 缩放比例与锚点）；
- **ANIM_TEST (数字键 7 或调试指令)**：开启全套 16 组动画顺序自动展示预览模式（不影响正式 AUTO）。
