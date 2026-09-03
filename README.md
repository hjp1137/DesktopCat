# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T08：基础工程、Overlay、穿透点击、动画、Command、跳跃物理、拖拽抛掷与生活行为
- 已实现桌面透明 Overlay、多显示器 TAB 切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager 指令中枢、完整垂直物理系统（JUMP/FALL/LAND）、鼠标拖拽抛掷（Drag/Throw）与生活行为系统（RUN/SIT/SLEEP及自主调度器）。

### T09：指针感知、注意力与目标移动系统 (Pointer Perception + Attention + Target Movement)
- **架构分层**：
  ```
  MousePerceptionController -> CommandManager -> LOOK_AT_POSITION / MOVE_TO_POSITION / CLEAR_TARGET -> Cat
  ```
- **核心特性**：
  - **输入源无关**：小猫接收统一的当前 Overlay 局部像素坐标（`target_position`），未来手势（GestureController）与 AI 可无缝复用同一套移动与注视系统；
  - **全局鼠标感知**：基于 `DisplayServer.mouse_get_position()` 与当前屏幕可用矩形（`screen_get_usable_rect`）进行全局坐标到 Overlay 局部坐标的换算与离屏检测；
  - **注视与死区 (Attention)**：
    - `attention_radius = 400.0` px，`attention_exit_radius = 460.0` px（滞后区间）；
    - IDLE / SIT 状态下具备 20px 转头死区，WALK / RUN 状态下移动方向优先，SLEEP / DRAG 状态下忽略注视；
  - **好奇跟随 (Curiosity Chase)**：
    - AUTO 模式下检测到鼠标在 350px 范围内快速晃动（速度 >= 80 px/s）时触发 2.5~4.5 秒轻度追逐，结束后进入 15 秒冷却时间；
  - **目标移动与偏置**：
    - 维持 `pointer_follow_distance = 64.0` px 偏置，到达 `target_reached_radius = 50.0` px 时停下，不压住鼠标；
  - **调试快捷键**：
    - 按 `C` 键切换 Debug Follow 模式（持续跟随鼠标目标），再次按 `C` 恢复 AUTO。

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
  - `C`：切换 Debug Pointer Follow 模式
  - `TAB`：切换多显示器
  - `ESC` / `Alt + F4`：安全退出
