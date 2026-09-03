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

## 运行方式与快捷键

### 1. 运行桌面宠物
- 独立版运行：`D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe`
- 快捷键操作：
  - `F8` / `-` / `V`：切换【窗口矩形】调试线框
  - `F9` / `=` / `B`：切换【Surface 物理表面】调试线框
  - `F10` / `N` / `M`：切换【Cat 物理接触点与站立表面】高亮
  - `F11` / `K` / `O` / `U`：切换【UI Automation 控件几何】调试线框
  - `TAB`：切换多显示器并重新生成表面与清理UI缓存
  - `C`：切换指针好奇跟随模式
  - `ESC` / `Alt + F4`：安全退出

### 2. 启动 Windows 感知服务
- **窗口几何感知服务** (10Hz)：
  ```bash
  python tools/perception/window_perception.py
  ```
- **UI Automation 控件感知服务** (2Hz，零第三方依赖)：
  ```bash
  python tools/perception/ui_automation_perception.py
  ```
- **统一多 Provider 感知调度器 (Window + UIA + Visual)**：
  ```bash
  python tools/perception/perception_service.py
  ```
按 `F8` 查看窗口，`F9` 查看物理表面，`F10` 查看小猫接触点，`F11` 查看 Windows 窗口内部 UI 控件几何，按 `F12`（或免Fn键 `J`）查看纯视觉几何线框（水平线暖橙、垂直线金黄、矩形紫红）！


