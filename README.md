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
- 建立了独立的 `CommandManager` 控制中枢，定义了统一标准指令（`STOP`、`WALK_LEFT`、`WALK_RIGHT`、`RESUME_AUTO`）；
- 重构了小猫行为状态机（`enter_state`、`update_state`、`exit_state`、`change_state`）；
- 实现了 `AUTO`（自主走走停停）与 `COMMAND`（服从外部指令）两种控制模式，外部命令可即时打断自主行为；
- 架构原则：DesktopCat 的外部控制统一通过 `CommandManager`，未来 Mouse、Voice、Gesture、AI 均作为 Input Controller 接入 `CommandManager`，不得直接操作 Cat 内部状态。

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
  - `TAB`：切换多显示器
  - `ESC` / `Alt + F4`：安全退出
