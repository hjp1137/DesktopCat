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
- 扩展 `CatState`：`IDLE`、`WALK`、`JUMP`、`FALL`；
- 扩展 `CatCommand`：`STOP`、`WALK_LEFT`、`WALK_RIGHT`、`RESUME_AUTO`、`JUMP`；
- 动态计算 `ground_y`，落地位置稳定且自动恢复原模式地面行为；
- 保持空中水平位移与防二段跳；
- 架构分离：Jump 是改变小猫根节点世界坐标的真实物理运动，点击 Cat 的 16px 微跳属于 Visual Feedback，两套机制彼此独立。

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
  - `5`：发送 JUMP 指令（小猫起跳）
  - `TAB`：切换多显示器
  - `ESC` / `Alt + F4`：安全退出
