# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T10：基础系统、物理、行为、指针感知与桥接通道
- 已实现桌面透明 Overlay、多显示器切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager、垂直物理系统（JUMP/FALL/LAND）、鼠标拖拽抛掷（Drag/Throw）、生活行为系统（RUN/SIT/SLEEP）、全局鼠标指针感知跟随与本地 TCP NDJSON 桥接通信通道。

### T11：Windows 顶层窗口几何感知 (Window Geometry Perception)
- 启动外部感知服务 `tools/perception/window_perception.py`，调用 Win32 API 5Hz 采集顶层窗口几何矩形，过滤无意义窗口，建立 `WindowWorldModel` 与 `F8` 调试线框。

### T12：窗口几何转物理表面模型 (Window Geometry → Surface World)
- 提取 `PLATFORM`（顶边/底边/屏幕地面）与 `WALL`（左右侧边/屏幕墙），实现轻量顶边遮挡切分（48px 过滤、2048 防护）与空间查询 API，`F9` 独立调试渲染。

### T13：多表面动态物理系统 (Multi-Surface Cat Physics)
- **正式移除单一地面假设**：小猫全面支持 `screen:ground` + `Window Top` 作为可站立行走的 walkable Surface；
- **物理接触点**：统一以 Cat 根节点作为脚底参考点（`get_foot_position() -> Vector2`），点击微跳解耦不影响接触点；
- **Swept Landing Detection**：下落时采用 `prev_foot_y` 到 `next_foot_y` 扫描判定，多平台候选优先着陆首个相交最小 Y 平台，杜绝穿透；
- **One-Way Platform**：向上跳跃（JUMP）阶段穿透平台，到达下落阶段（FALL）方可承接；
- **地面支撑与边缘脱落**：已着陆状态连续验证横向支撑（`support_margin = 4.0px`），走出边缘自然下落；
- **表面重绑 (Rebind)**：窗口遮挡切分重新编号时脚底自动重新绑定附近表面；
- **动态窗口跟随与脱落**：窗口移动时同步跟随，位移超过 `MAX_SURFACE_ATTACH_DELTA = 150px` 或窗口关闭时脱落坠落；
- **Drag & Throw 吸附**：拖拽释放支持 `snap_tolerance = 8.0px` 吸附着陆；
- **物理调试渲染 (F10)**：红点显示脚底接触点，高亮当前站立表面与状态 HUD；
- **未实现项说明**：T13 尚未包含自主跳跃规划、抓边攀爬或路径寻路（由 T14~T17 实现）。

### T14~T17：UI Automation、视觉几何、统一表面融合与平台导航图
- **T14**：纯原生 Windows UI Automation COM 感知，提取 Text/Button/Edit/Image 等结构化 UI 几何，支持 `F11` 调试；
- **T15**：原生 GDI 轻量视觉几何感知，0.25 降采样与均值指纹变化检测，提取横线、竖线与矩形，支持 `F12` 调试；
- **T16**：**统一表面融合系统 (Unified Surface Fusion & Simplification)**：
  - 建立 `SurfaceFusionBuilder`，将 Window、UIA 与 Visual 几何统一提取为标准 `SurfaceCandidate`；
  - 实施优先级矩阵（Screen 100 > Window 90 > UIA 80 > Visual 60），自动过滤容器，合并同行文本片段，裁剪高 Z 窗口遮挡；
  - 80% 重叠去重并外扩并集，近共线合并，4px 网格坐标量化与 600ms 丢失 Grace 缓冲；
  - 原子提交至唯一 `SurfaceWorldModel`，使小猫天然在窗口文本、按钮、输入框、图片与视觉线条上行走与着陆！
- **T17**：**平台导航图系统 (Platform Navigation Graph)**：
  - 建立 `CatMovementCapabilities`，完全复用 Cat 真实物理参数推导动力学极值；
  - 建立 `NavigationNode` 与 `NavigationEdge`，扣除半宽计算安全落地区间，区分 `JUMP_WALK`、`JUMP_RUN`、`DROP` 边；
  - 实施空间初筛、One-Way 下落解判定与连续段相交检测（Swept Crossing Occlusion）；
  - 支持 150ms Debounce 防抖原子提交与完整查询 API，支持 `F14`（免 Fn 键 `G` 切换、`T` 键输出）调试 HUD。
- **T18**：**自主跳跃规划与执行系统 (Autonomous Jump Planner & Execution)**：
  - 建立独立状态机（IDLE, APPROACH_TAKEOFF, READY_TO_JUMP, AIRBORNE, VERIFY_LANDING, SUCCESS, FAILED）；
  - 智能边加权选取与 Top-3 轮盘随机选择，结合助跑跑道物理检查（$\ge 35\text{ px}$）与历史去重惩罚；
  - 惯性起跳 Handover（到起跳点直接触发 JUMP 继承水平速度），飞行过程 100% 依赖 T13 Cat Physics（无 Teleport、无 Tween、无空中作弊吸附）；
  - 偏离目标判定为 `MISSED_TARGET` 并实施短期黑名单隔离；用户显式命令与鼠标拖拽（DRAG）最高优先级立即熔断；
  - 支持 `F15`（免 Fn 键 `X` 切换、`P` 键单次触发规划）调试视图，绘制起跳点、落地区间与 Predicted Arc 抛物线。

## 运行方式与快捷键

### 1. 运行桌面宠物
- 独立版运行：`D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe`
- 快捷键操作：
  - `F8` / `-` / `V`：切换【窗口矩形】调试线框
  - `F9` / `=` / `B`：切换【Surface 物理表面】调试线框（含融合后的全部表面）
  - `F10` / `N` / `M`：切换【Cat 物理接触点与站立表面】高亮
  - `F11` / `K` / `O` / `U`：切换【UI Automation 控件几何】调试线框
  - `F12` / `J`：切换【Visual Geometry 视觉几何】调试线框
  - `F13` / `H` / `Y`：切换【Unified Surface Fusion 融合诊断】HUD 视图
  - `F14` / `G`：切换【Platform Navigation Graph 平台导航图】调试线框（按 `T` 输出当前导航摘要）
  - `F15` / `X`：切换【Autonomous Jump Planner 自主跳跃规划】调试视图（按 `P` 单次触发自主规划）
  - `TAB`：切换多显示器并重新生成表面与清理UI缓存
  - `C`：切换指针好奇跟随模式
  - `ESC` / `Alt + F4`：安全退出

### 2. 启动 Windows 感知服务
- **统一多 Provider 感知调度器 (Window + UIA + Visual)**：
  ```bash
  python tools/perception/perception_service.py
  ```
  在控制台或桌面全局按 `F8`~`F15` 或免 Fn 键 `G`/`T`/`X`/`P` 查看实时导航图与自主跳跃规划！


