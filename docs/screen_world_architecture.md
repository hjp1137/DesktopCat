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
[WindowWorldModel] (Godot 纯数据模型存储)
         ↓ (T12+ Surface Extraction: 顶边/侧边提取)
[Dynamic World Map] (Platform / Wall / Obstacle 几何抽象)
         ↓ (T13+ StaticBody2D / Navigation Graph)
[Cat Physics & Behavior] (走台阶、立足、跳跃、抓边、攀爬与探索)
```

## 3. 阶段演进规划
1. **T11（当前阶段）**：顶层窗口几何感知（Window Geometry Perception），完成 Win32 数据采集、局部坐标转换、裁剪与 `WindowWorldModel` 存储；
2. **T12**：表面与平台提取（Surface Extraction），将 Window 顶边缘提炼为水平可站立平台（Platform）与侧边垂直墙面（Wall）；
3. **T13**：动态物理碰撞与多层着陆（Dynamic Physical Ground & Multi-tier Landing），让小猫真正站立在窗口顶边上；
4. **T14+**：抓边攀爬、窗口跟随与 UI 深度语义感知。
