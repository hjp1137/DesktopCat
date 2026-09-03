# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T09：基础系统、物理运动、拖拽生活行为与指针感知
- 已实现桌面透明 Overlay、多显示器切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager 指令中枢、完整垂直物理系统（JUMP/FALL/LAND）、鼠标拖拽抛掷（Drag/Throw）、生活行为系统（RUN/SIT/SLEEP自主调度）以及全局鼠标指针感知与目标跟随系统。

### T10：本地外部感知桥接通道 (Local External Perception Bridge)
- 建立 Godot TCP Server（`127.0.0.1:47831`）与外部服务的 TCP + UTF-8 + NDJSON 通信；
- 提供 Python 标准库调试客户端 `tools/bridge_test_client.py`，支持指令注入与 20Hz 压力测试。

### T11：Windows 顶层窗口几何感知 (Window Geometry Perception)
- **核心定位与边界**：
  - 启动首个正式外部感知服务 `tools/perception/window_perception.py`；
  - 仅识别可见顶层窗口几何尺寸（x, y, width, height），**不截图、不识别文字、不使用 OpenCV、不创建物理碰撞体**；
  - 窗口尚未成为 Physics Surface，小猫当前不会跳到窗口上，保持现有 ground_y 世界活动；
- **轻量 Win32 API 采集与过滤**：
  - 仅依赖 Python 标准库 + `ctypes`（调用 `user32.dll` 与 `dwmapi.dll`），零第三方包依赖；
  - 使用 `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` 剔除 Windows 窗口阴影边框；
  - 过滤最小化（`IsIconic`）、不可见、微型辅助窗口、系统任务栏与桌面壁纸；
  - 过滤 DesktopCat 自身 Overlay 窗口与感知控制台自身；
- **虚拟桌面多屏转换与裁剪**：
  - 支持多显示器与高 DPI 缩放换算，将真实物理坐标投影转换为 Overlay Local Pixel Coordinates；
  - 自动对屏幕边界做矩形裁剪（Rect Clipping），防止几何越界；
- **5Hz 变动检测 (Change Detection)**：
  - 基础扫描频率 5Hz（200ms），仅在窗口新增、移动、缩放、关闭或前台切换时发送 `window_snapshot`，静止时零网络开销；
- **Godot WindowWorldModel 与 F8 调试渲染**：
  - 新建 `scripts/world/window_world_model.gd` 纯几何数据模型；
  - 按 `F8` 切换窗口矩形边框调试显示，纯线框渲染，完全不影响底层 Chrome / 文件夹等窗口的正常鼠标点击操作。

## 运行方式

### 1. 运行桌面宠物
- 双击运行构建产物：`D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe`
- 或通过 Godot 源码启动：
  ```bash
  "E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
  ```
- **快捷键**：
  - `F8`：切换窗口几何线框 Debug 绘制
  - `TAB`：切换多显示器
  - `C`：切换指针注视与跟随模式
  - `ESC` / `Alt + F4`：安全退出

### 2. 启动 Windows 窗口几何感知服务
在独立终端运行服务（自动重连 Bridge）：
```bash
python tools/perception/window_perception.py
```
小猫在桌面上时，按 `F8` 即可实时查看屏幕上识别到的各个窗口物理边框。
