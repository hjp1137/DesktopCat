# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T10：基础系统、物理、行为、指针感知与桥接通道
- 已实现桌面透明 Overlay、多显示器切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager、垂直物理系统（JUMP/FALL/LAND）、鼠标拖拽抛掷（Drag/Throw）、生活行为系统（RUN/SIT/SLEEP）、全局鼠标指针感知跟随与本地 TCP NDJSON 桥接通信通道。

### T11：Windows 顶层窗口几何感知 (Window Geometry Perception)
- 启动外部感知服务 `tools/perception/window_perception.py`，调用 Win32 API 5Hz 采集顶层窗口几何矩形，过滤无意义窗口，建立 `WindowWorldModel` 与 `F8` 调试线框。

### T12：窗口几何转物理表面模型 (Window Geometry → Surface World)
- **核心定位与边界**：
  - 将 Window Rect 转换为桌面物理世界几何线段表面（Surface），作为未来多表面物理（T13）的数据地基；
  - **当前仅建立数据模型，不创建物理碰撞体，小猫仍沿用原有 ground_y 物理，不改变跳跃落地**；
- **表面分类与方向**：
  - `PLATFORM`：可站立顶边（`walkable = true`）、底边平台（`walkable = false`）、屏幕地面 `screen:ground`（`walkable = true`）、屏幕顶部 `screen:top`；
  - `WALL`：窗口左侧边 `wid:left`、窗口右侧边 `wid:right`、屏幕左右墙 `screen:left` / `screen:right`；
  - 稳定 ID 机制：保持 `<wid>:top`, `<wid>:bottom`, `<wid>:left`, `<wid>:right` 恒定，窗口位移不改变 ID；
- **轻量顶边遮挡切分 (Top Platform Occlusion)**：
  - 对每个窗口的顶边，求交高 Z-Order 窗口的水平投影，执行线段相减（`_subtract_interval`）；
  - 被遮挡片段自动切分（`<wid>:top:0`, `<wid>:top:1`），完全被覆盖时可站立表面自动消除；
- **尺寸与容量安全控制**：
  - `MIN_PLATFORM_LENGTH = 48.0` px，`MIN_WALL_LENGTH = 48.0` px，过滤微小片段；
  - `MAX_SURFACES = 2048`，防止异常输入造成内存溢出；
  - 几何变动时递增 `surface_revision` 并触发 `surface_world_updated` 信号；
- **独立调试渲染 (F9)**：
  - `F9` 独立切换 Surface 线框显示（绿色平台，黄色墙体），与 `F8` 窗口矩形正交分离，不破坏鼠标穿透。

## 运行方式与快捷键

### 1. 运行桌面宠物
- 独立版运行：`D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe`
- 快捷键操作：
  - `F8` / `-` / `V`：切换【窗口矩形】调试线框
  - `F9` / `=` / `B`：切换【Surface 物理表面】调试线框
  - `TAB`：切换多显示器并重新生成表面
  - `C`：切换指针好奇跟随模式
  - `ESC` / `Alt + F4`：安全退出

### 2. 启动 Windows 窗口感知服务
```bash
python tools/perception/window_perception.py
```
按 `F8` 查看 Windows 窗口，按 `F9` 查看提炼出的物理平台与墙体。
