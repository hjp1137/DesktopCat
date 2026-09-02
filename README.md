# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T07：基础工程、Overlay、穿透点击、动画、Command、跳跃物理与拖拽抛掷
- 已实现桌面透明 Overlay、多显示器 TAB 切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager 指令中枢、完整垂直物理系统（JUMP/FALL/LAND）与鼠标拖拽抛掷（Drag/Throw）。

### T08：生活行为系统（Life Behavior System）
- 建立了基础生活节奏系统，扩展状态机与指令体系；
- 当前完整 `CatState`：`IDLE`、`WALK`、`RUN`、`SIT`、`SLEEP`、`JUMP`、`FALL`、`DRAG`；
- 当前完整 `CatCommand`：`STOP`、`WALK_LEFT`、`WALK_RIGHT`、`RESUME_AUTO`、`JUMP`、`DRAG_START`、`DRAG_MOVE`、`DRAG_END`、`RUN_LEFT`、`RUN_RIGHT`、`SIT`、`SLEEP`、`WAKE`；
- 行为特点：
  - `RUN`：冲刺速度（220 px/s）明显高于普通步行（120 px/s），空中跳跃继承冲刺速度形成高速抛物线；
  - `SIT`：静止蹲坐（3~8 秒）；
  - `SLEEP`：静止卧倒呼吸闭眼（8~16 秒），可自动醒来或由 `WAKE` 指令立即唤醒；
  - 睡眠时收到 JUMP 自动唤醒起跳，被鼠标拖拽抓起立即进入 DRAG 并在落地后恢复 IDLE；
- 自主行为调度器（Autonomous Behavior Scheduler）：
  - AUTO 模式下通过行为转移权重池（WALK 40%, SIT 25%, IDLE 15%, RUN 15%, SLEEP 5%）、持续时间范围与冷却时间（`sleep_cooldown` 15s, `run_cooldown` 6s）实现自然的自主生活节奏；
  - 具备边缘感知朝向选择，靠近屏幕边缘时优先转向屏幕内侧。

## 运行方式

### 1. 双击独立 EXE 运行（已打包生成）
直接双击运行构建产物：
- `D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe` （单文件独立版本，即开即用）

### 2. 通过 Godot 引擎运行源码
```bash
"E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
```
- **快捷键**：
  - `1`：STOP
  - `2`：WALK_LEFT
  - `3`：WALK_RIGHT
  - `4`：RESUME_AUTO
  - `5`：JUMP
  - `6`：RUN_LEFT
  - `7`：RUN_RIGHT
  - `8`：SIT
  - `9`：SLEEP
  - `0`：WAKE
  - `TAB`：切换多显示器
  - `ESC` / `Alt + F4`：安全退出
