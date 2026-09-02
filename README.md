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
- 实现了全屏 Overlay 动态分辨率与坐标适配（支持多显示器并可通过 `TAB` 键自由切换）；
- 小猫移动范围自动适配全屏显示区域并在屏幕边界反弹转向；
- 提供了 ESC 键与 Alt+F4 安全退出机制。

### T03：Mouse Passthrough + Cat 点击互动
- 实现了窗口级鼠标穿透（Mouse Passthrough）：除小猫包围盒区域外，其余透明区域鼠标完全穿透至 Windows 桌面及下方所有应用；
- 鼠标可交互区域（Passthrough Polygon）实时跟随小猫移动动态更新；
- 实现了小猫点击交互检测：点击小猫时在控制台输出 `Cat clicked!` 并触发轻量向上弹跳视觉反馈；
- 点击互动不中断小猫原有的自主左右巡逻与碰边反弹逻辑。

### T04：AnimatedSprite2D + Idle / Walk 动画框架
- 将 Cat 独立为正式场景 `scenes/cat.tscn`，使用 `AnimatedSprite2D` 驱动角色表现层；
- 建立了原创临时动画素材（`idle` 4 帧 @ 4 FPS，`walk` 6 帧 @ 10 FPS）；
- 实现了基础走走停停状态机（WALK 行走 3~7 秒 ↔ IDLE 停歇 1.5~3.5 秒）；
- 行走时通过 `AnimatedSprite2D.flip_h` 精准翻转左右朝向；
- 保持点击弹跳、鼠标穿透、多显示器切换与单文件独立 EXE 构建；
- 说明：当前仍使用临时原创动画素材，后续会替换正式 Cat 美术资产。

## 运行方式

### 1. 双击独立 EXE 运行（已打包生成）
直接双击运行构建产物：
- `D:\projects\godot\DesktopCat\build\DesktopCat_Standalone.exe` （单文件独立版本，即开即用）

### 2. 通过 Godot 引擎运行源码
```bash
"E:\Program Files\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path "D:\projects\godot\DesktopCat"
```
- **快捷键**：`TAB` 切换多显示器，`ESC` / `Alt + F4` 安全退出。
