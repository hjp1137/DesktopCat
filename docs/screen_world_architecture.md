# DesktopCat 屏幕几何与物理世界演进架构

## 1. 核心设计原则
- **Raw Screen Pixels 严禁进入 Godot**：绝不在 Godot 内部执行截屏循环、OpenCV 识别、OCR 或像素比对；
- **几何与物理职责解耦**：外部感知服务仅负责 Windows 顶层窗口与 UI 轮廓的提取，以纯几何数据（Rect/Surface）传入；Godot 仅负责将其转化为小猫物理世界的 Platform、Wall 与导航网格；
- **低开销、低占用**：无 AI/CV 重型库，桌面静止时零开销，保障用户日常办公与游戏流畅。

## 2. 数据流动链条 (Data Pipeline)
```
[Windows Desktop UI / Windows API]
         ↓ (EnumWindows / DwmGetWindowAttribute / ctypes)
[Window Geometry] (Top-level window rects, screen-clipped)
         ↓ (T10/T11 NDJSON Protocol: window_snapshot)
[WindowWorldModel] (Godot 纯几何数据模型存储)
         ↓ (T12 SurfaceWorldModel: 顶边遮挡切分、48px过滤、屏幕边界)
[Surface World] (PLATFORM / WALL 线段表面模型)
         ↓ (T13 Multi-Surface Cat Physics: 动态多表面着陆与碰撞)
[Cat Physics & Behavior] (走台阶、立足、跳跃、抓边、攀爬与探索)
```

## 3. 阶段演进规划
1. **T11（已完成）**：顶层窗口几何感知（Window Geometry Perception），完成 Win32 数据采集、局部坐标转换、裁剪与 `WindowWorldModel` 存储；
2. **T12（已完成）**：窗口几何转 Surface 物理世界（Surface World），提取 `PLATFORM`（顶边/底边/屏幕地面）与 `WALL`（左右侧边/屏幕墙），实现轻量顶边遮挡切分与空间查询 API，F9 独立调试渲染；
3. **T13（已完成）**：多表面动态物理系统（Multi-Surface Cat Physics），正式打破单一 `ground_y` 世界假设，实现小猫跳跃/下落着陆到 Window Top、在窗口上行走/跑/坐/睡、边缘自然掉落、窗口拖拽跟随与 F10 物理调试；
4. **T14（已完成）**：Windows UI Automation 元素感知（UI Automation Element Perception），通过原生 COM 提取窗口内部控件几何（Button/Edit/Text 等），三维预算控制，F11 独立调试线框，不影响鼠标穿透；
5. **T15（下一阶段）**：平台导航图 (Platform Navigation Graph)，建立平台间可达性关系网络；
6. **T16**：UI 元素与物理表面融合与自主跳跃规划 (Surface Fusion & Jump Planning)；
7. **T17**：抓边与攀爬系统 (Edge Grab + Climb)；
8. **T18**：自主探索系统 (Autonomous Exploration)。
