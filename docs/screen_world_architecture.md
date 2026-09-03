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
                    ├─ (T13 Multi-Surface Physics: Swept Landing / One-Way / Move Follow)
                    │    ↓
                    │  [Cat Physics & Behavior] (在窗口、按钮、文本、视觉线条上真实着陆与生活行走)
                    │    ↓
                    │  [Edge Grab & Hang System] (T19: F16/Z/G: Swept Grab / Grab Zone / Outside Approach / Hang & Release)
                    │    ↓
                    │  [Edge Climb-Up System] (T20: F17/H/G: Procedural PULL_UP / SHIFT_IN / Clearance / Rebind)
                    │    ↓
                    │  [Vertical Wall Attachment & Climbing System] (T21: F18/U/J/G: Wall Cling / Dual Climb / Top Transition)
                    │
                    └─ (T17/T22 Surface Traversal Graph: Platform + Wall Nodes / Dijkstra Route Search)
                         ↓
                       [ScreenExplorationController] (T23: F21/E: Bounded BFS / Goal Scoring / Top-K Selection / Memory / Loop Break)
                         ↓
                       [AutonomousJumpPlanner] (T18/T22: F15/F20: TraversalRoute / Phased Execution / Wall Cling / Edge Recovery)
                         ↓
                       [CommandManager] ──> [Cat Physics (T13 Landing / T19 Grab / T20 Climb-Up / T21 Wall Climb)]
```

## 3. Visual Layer 与 CatMetrics 职责解耦 (T24 架构核心)
- **Physics Root 与 Visual Root 彻底分离**：
  - `Cat.position` 代表绝对物理足底接触锚点（Physics Root），由物理状态机、Swept 着陆与 CatMetrics 严密驱动；
  - `VisualRoot` 作为其子节点独立承载缩放、朝向（`flip_h`）与弹性动画（落地 Squash & Stretch 0.15s 回弹），任何视觉摆动绝不反馈并污染真实物理位置与轨迹；
- **Foot Lock 契约**：地面所有动画（`idle`, `walk`, `run`, `sit`, `sleep`, `wake`）在 64x64 画布中足底接触像素必须严格对齐于 `Y=58`，彻底杜绝小猫在物理表面行走时出现上下浮空或陷地漂移；
- **纯代码动态纹理装配 (`CatSpriteLoader`)**：采用 `Image.load_from_file` 原生解析 PNG 序列帧生成 `ImageTexture`，彻底杜绝 Godot 引擎 Headless 模式或独立运行时丢失 `.ctex` 缓存导致的贴图黑屏与丢失问题。

## 4. 阶段演进规划
1. **T11～T21（已完成）**：窗口、UIA、视觉感知、物理着陆、抓边、攀爬与自适应 CatMetrics；
2. **T22（已完成）**：攀爬与跳跃融合导航路径规划 (Climb Navigation Integration)；
3. **T23（已完成）**：自主屏幕探索系统 (Autonomous Screen Exploration) —— **M1 核心移动与导航闭环正式达成，已停止新增核心 Movement / Navigation 功能**；
4. **T24（已完成）**：美术与动画全面升级 (Art & Animation Upgrade) —— 16 组原创动画契约、Foot Lock、VisualRoot 解耦与软阴影；
5. **T25（下一阶段）**：M1 核心玩法集中总体验收与收口 (M1 Core Gameplay Acceptance & Consolidation)；
6. **T26**：性能优化、稳定性与产品化打包 (Performance / Stability / Productization)。
