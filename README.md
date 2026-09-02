# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01：基础工程与移动验证
- 建立了基础工程与目录结构，实现临时猫咪绘制与左右巡逻碰边转向。

### T02：透明桌面 Overlay
- 启用了逐像素透明与视口透明背景，实现真实桌面透显、无边框、窗口置顶与多显示器适配。

### T03：Mouse Passthrough + Cat 点击互动
- 实现了窗口级鼠标穿透，仅小猫包围盒响应输入，其余区域穿透桌面；实现小猫点击轻微弹跳反馈。

### T04：AnimatedSprite2D + Idle / Walk 动画框架
- 将 Cat 独立为 `scenes/cat.tscn`，使用 `AnimatedSprite2D` 驱动角色表现层，实现基础走走停停与 `flip_h` 翻转。

### T05：行为状态机 + 统一 Command 系统
- 建立了独立的 `CommandManager` 控制中枢，定义了统一标准指令；
- 实现了 `AUTO`（自主走停）与 `COMMAND`（指令控制）双模式，支持即时打断与恢复。

### T06：Jump + Gravity + Falling
- 为 Cat 建立了完整的垂直运动系统（JUMP → FALL → LAND），支持重力与下落物理；
- 扩展 `CatState`（`IDLE`, `WALK`, `JUMP`, `FALL`）与 `CatCommand`（`JUMP`）。

### T07：Mouse Drag + Throw
- 新建 `MouseController`，统一接入 `CommandManager` 控制小猫；
- 新增 `CatCommand`：`DRAG_START`、`DRAG_MOVE`、`DRAG_END`；
- 新增 `CatState`：`DRAG`；
- Click 与 Drag 判定：通过 8 像素移动阈值精确区分单击与拖拽，单击保留 16px 视觉微跳，按住拖拽保持相对抓取偏移（`drag_offset`）；
- 抛掷（Throw）速度估算：基于最近 120ms 样本平滑计算释放速度，并对极速做安全钳制（X: 1200 px/s, Y: 1000 px/s）；
- 抛出后完全复用 T06 重力、抛物线与着陆逻辑，落地后无缝恢复原意图行为；
- 拖拽期间全屏接收鼠标事件并在松开后立即恢复穿透，具备物理释放 Fail-safe 保护；
- 拖拽期间外部 Command 冲突策略：采用忽略保护，防止拖拽过程中小猫被瞬移或打断。

## 运行方式

### 1. 双击独立 EXE 运行（已打包生成）
直接双击运行构建产物：
- `D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe` （单文件独立版本，即开即用）

### 2. 通过 Godot 引擎运行源码
```bash
"E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
```
- **快捷键**：
  - `1`：发送 STOP 指令
  - `2`：发送 WALK_LEFT 指令
  - `3`：发送 WALK_RIGHT 指令
  - `4`：发送 RESUME_AUTO 恢复自主模式
  - `5`：发送 JUMP 指令
  - `TAB`：切换多显示器
  - `ESC` / `Alt + F4`：安全退出
