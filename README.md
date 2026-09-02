# DesktopCat

基于 Godot 4.7.2 的 Windows 桌面宠物应用。

## 开发阶段记录

### T01：基础工程与移动验证
- 建立了基础工程与目录结构；
- 实现了无外部美术资源依赖的临时猫咪绘制；
- 实现了小猫基于 delta 的左右自动往返巡逻移动与边界转向逻辑。

### T02：透明桌面 Overlay
- 启用了逐像素透明（Per-pixel Transparency）与视口透明背景，实现真实桌面透显；
- 启用了无边框（Borderless）与窗口置顶（Always On Top）；
- 实现了全屏 Overlay 动态分辨率与坐标适配（自动读取当前主屏幕尺寸）；
- 小猫移动范围自动适配全屏显示区域并在屏幕边界反弹转向；
- 提供了 ESC 键与 Alt+F4 安全退出机制。

> **开发说明**：当前阶段尚未实现鼠标穿透（Mouse Passthrough），因此运行 Overlay 时全屏透明窗口仍可能接收鼠标输入。测试时可随时按下 `ESC` 键或 `Alt + F4` 安全退出程序。

## 运行方式

### 1. 双击独立 EXE 运行（已打包生成）
直接双击运行构建产物：
- `D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe` （单文件独立版本，即开即用）

### 2. 通过 Godot 引擎运行源码
```bash
"E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
```
