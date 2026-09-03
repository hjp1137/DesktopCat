# DesktopCat 屏幕几何与物理世界演进架构

## 1. 核心设计原则
- **Raw Screen Pixels 严禁进入 Godot**：绝不在 Godot 内部执行截屏循环、OpenCV 识别、OCR 或像素比对；
- **几何与物理职责解耦**：外部感知服务仅负责 Windows 顶层窗口与 UI 轮廓的提取，以纯几何数据（Rect/Surface）传入；Godot 仅负责将其转化为小猫物理世界的 Platform、Wall 与导航网格；
- **低开销、低占用**：无 AI/CV 重型库，桌面静止时零开销，保障用户日常办公与游戏流畅。

## 2. 数据流动链条 (Data Pipeline)
```
[Windows Desktop Screen / Windows API / UIA / Native GDI]
     ├─ [Window Geometry Perception] (EnumWindows / DwmGetWindowAttribute, 10Hz)
     ├─ [UI Automation Perception] (IUIAutomation COM 纯轻量控件树, 2Hz)
     └─ [Visual Geometry Perception] (原生 GDI 截屏 + 降采样灰度梯度 LINE/RECT, 2Hz)
                  ↓ (NDJSON: window_snapshot / ui_snapshot / visual_snapshot)
[ExternalBridge (Godot 47831)]
     ├─ [WindowWorldModel] (F8 窗口轮廓)
     ├─ [SurfaceWorldModel] (F9 物理表面，T12 顶边切分)
     ├─ [UIElementWorldModel] (F11 控件几何)
     └─ [VisualWorldModel] (F12 视觉线条与矩形)
                  ↓ (T13 Multi-Surface Physics / T16 表面融合)
[Cat Physics & Behavior] (真实多表面着陆、行走、跳跃与探索)
```

## 3. 阶段演进规划
1. **T11（已完成）**：顶层窗口几何感知（Window Geometry Perception），完成 Win32 数据采集、局部坐标转换、裁剪与 `WindowWorldModel` 存储；
2. **T12（已完成）**：窗口几何转 Surface 物理世界（Surface World），提取 `PLATFORM`（顶边/底边/屏幕地面）与 `WALL`（左右侧边/屏幕墙），实现轻量顶边遮挡切分与空间查询 API，F9 独立调试渲染；
3. **T13（已完成）**：多表面动态物理系统（Multi-Surface Cat Physics），正式打破单一 `ground_y` 世界假设，实现小猫跳跃/下落着陆到 Window Top、在窗口上行走/跑/坐/睡、边缘自然掉落、窗口拖拽跟随与 F10 物理调试；
4. **T14（已完成）**：Windows UI Automation 元素感知（UI Automation Element Perception），通过原生 COM 提取窗口内部控件几何（Button/Edit/Text 等），三维预算控制，F11 独立调试线框，不影响鼠标穿透；
5. **T15（已完成）**：轻量视觉几何感知（Lightweight Visual Geometry Perception），原生 GDI 抓屏、降采样灰度边缘提取、线段合并与 Rect 组合、时序平滑滤波、`VisualWorldModel` 存储与 F12 调试线框；
6. **T16（下一阶段）**：视觉/控件/窗口多感知表面融合与跳跃规划 (Multi-Modal Surface Fusion & Jump Planning)；
7. **T17**：抓边与攀爬系统 (Edge Grab + Climb)；
8. **T18**：自主探索系统 (Autonomous Exploration)。

