# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01～T09：基础系统、物理运动、拖拽生活行为与指针感知
- 已实现桌面透明 Overlay、多显示器切换、鼠标穿透、点击微跳、动画翻转、状态机与 CommandManager 指令中枢、完整垂直物理系统（JUMP/FALL/LAND）、鼠标拖拽抛掷（Drag/Throw）、生活行为系统（RUN/SIT/SLEEP自主调度）以及全局鼠标指针感知与目标跟随系统。

### T10：本地外部感知桥接通道 (Local External Perception Bridge)
- **核心定位与架构**：
  - **Godot (TCP Server)** ↔ **External Perception Service (TCP Client)**；
  - 严格限制本地 `127.0.0.1:47831`，非阻塞 poll 处理；
  - 传输协议：**TCP + UTF-8 + NDJSON (v1)**；
  - **最高架构原则**：永远传递轻量结构化几何感知数据，严禁持续传输屏幕位图（Bitmap/截图流），对用户日常办公与游戏零干扰；
  - **白名单与安全边界**：外部指令严格经由 `CommandManager` 白名单路由，支持非法数据与溢出容错；
- **支持消息信封**：
  - `hello`（服务端主动下发视口尺寸与屏幕）、`ping`/`pong`、`get_status`/`status`、`command`（分发至 CommandManager）、`error`；预留 `surface_snapshot` 几何数据；
- **Python 标准库测试客户端**：
  - `tools/bridge_test_client.py`，支持交互式指令控制与 20Hz 压力测试。

## 运行方式

### 1. 运行桌面宠物
- 双击运行构建产物：`D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe`
- 或通过 Godot 源码启动：
  ```bash
  "E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
  ```

### 2. 外部感知测试客户端连接
在终端中启动 Python 测试客户端：
```bash
python tools/bridge_test_client.py
```
输入 `ping`、`status`、`jump`、`sit`、`move 500 300`、`stress 30` 即可与小猫通信。
