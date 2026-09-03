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
                  ↓ (T16 SurfaceFusionBuilder: Debounce / Dedup / Merge / Grace)
[SurfaceWorldModel (唯一物理世界入口)] (F9 物理表面，汇聚三路感知)
                  ↓ (T13 Multi-Surface Physics: Swept Landing / One-Way / Move Follow)
[Cat Physics & Behavior] (在窗口、按钮、文本、视觉线条上真实着陆与生活行走)
```

## 3. 阶段演进规划
1. **T11（已完成）**：顶层窗口几何感知（Window Geometry Perception）；
2. **T12（已完成）**：窗口几何转 Surface 物理世界（Surface World）；
3. **T13（已完成）**：多表面动态物理系统（Multi-Surface Cat Physics）；
4. **T14（已完成）**：Windows UI Automation 元素感知（UI Automation Element Perception）；
5. **T15（已完成）**：轻量视觉几何感知（Lightweight Visual Geometry Perception）；
6. **T16（已完成）**：统一表面融合与几何简化（Unified Surface Fusion & Simplification），通过 `SurfaceFusionBuilder` 建立唯一 `SurfaceWorldModel`，使小猫天然在文本、按钮、输入框、图片与视觉线条上行走与着陆；
7. **T17**：导航图与跳跃规划系统 (Platform Navigation Graph & Jump Planning)；
8. **T18**：抓边与攀爬系统 (Edge Grab + Climb)；
9. **T19**：自主探索系统 (Autonomous Exploration)。


