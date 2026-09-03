# 20260903 Windows UI Automation 元素感知方案 (T14)

## 1. 目标与定位
- **核心定位**：建立外部 UI 自动化感知服务与 Godot `UIElementWorldModel`，使 DesktopCat 首次能够感知 Windows 窗口内部的细粒度控件几何（Button, Edit, Text, Image, Pane, Document 等）；
- **严格范围约束**：T14 仅实现 UI 元素感知、几何提取、过滤、协议传输与 F11 调试线框可视化；**严禁将 UI 元素直接转换为物理表面（Surface）或让小猫产生物理交互**（留待 T16 Surface Fusion 统一去重与简化）；
- **零外部依赖原则**：基于 Windows 原生 COM API（`IUIAutomation` + `IUIAutomationTreeWalker` via Python 标准库 `ctypes`），不引入任何重量级 GUI 自动化或计算机视觉库，零第三方 pip 依赖。

## 2. 总体数据链路
```
Windows Desktop UI
       ↓ (Win32 IUIAutomation COM API via ctypes / 0 第三方依赖)
UIAutomationProvider (tools/perception/ui_automation_provider.py)
       ↓ (窗口过滤: 仅限前台与当前屏幕顶层窗口; 深度<=10; 预算<=40ms; 数量<=1000)
UI Element Geometry (id, window_id, control_type, x, y, width, height)
       ↓ (T10/T14 NDJSON 协议: ui_snapshot)
ExternalBridge (Godot 47831)
       ↓
UIElementWorldModel (scripts/world/ui_element_world_model.gd)
       ↓ (F11 / K 调试线框渲染, 限制前300个大尺寸元素, 不破坏穿透)
Debug Canvas Rendering
```

## 3. 关键性能与隐私安全设计
1. **范围限制**：只扫描当前显示器可见顶层窗口（优先前台窗口 + 最多 3~5 个可见窗口），绝不从 Desktop Root 递归整机；
2. **三维约束**：
   - 深度限制：`MAX_DEPTH = 10`；
   - 元素上限：`MAX_UI_ELEMENTS = 1000`；
   - 时间预算：`SCAN_BUDGET_MS = 35.0ms`，单次扫描超时即时退出，由下轮继续调度；
3. **扫描频率与变动检测**：
   - 扫描频率：2Hz（500ms 一次）；
   - 变动签名对比：基于元素集合的 `(id, type, x, y, w, h)` 计算签名，无变动时不发送数据包；
4. **绝对隐私保护**：
   - 不读取控件 Value / Text / Password 字段；
   - 仅提取控件类型 ControlType 与屏幕包围盒 BoundingRectangle；
   - 元素 ID 采用官方 `RuntimeId`（或 `WindowId:ControlType:TreePath` 回退），严禁使用控件文本内容作为 ID。

## 4. UI Snapshot 协议与 Godot 端模型
- **NDJSON 消息协议**：
  ```json
  {
    "v": 1,
    "type": "ui_snapshot",
    "revision": 1,
    "screen": { "index": 0, "width": 1920, "height": 1080 },
    "elements": [
      {
        "id": "0x00030094:42-197028",
        "window_id": "0x00030094",
        "control_type": "Button",
        "x": 420.0,
        "y": 180.0,
        "width": 80.0,
        "height": 32.0
      }
    ]
  }
  ```
- **Godot `UIElementWorldModel`**：
  - 管理 `elements_by_id: Dictionary`；
  - 维护版本号防倒退 `ui_revision`；
  - 提供空间与类型查询 API：`get_all_elements()`, `get_elements_by_type()`, `get_elements_near()`；
  - 实现 `_draw()` 绘制 F11 调试线框，支持按类型着色并限制绘制最大数量（`MAX_DEBUG_UI_ELEMENTS = 300`）。

## 5. 调试快捷键与回归保护
- **快捷键映射**：`F11` 及免 Fn 兼容键 `K`（以及测试客户端指令 `TOGGLE_DEBUG_UI` / `f11`）；
- **回归与安全性**：断开连接保留最后已知有效快照（Last Known Good Snapshot）；T13 多表面物理（落地/边缘脱落/行走/跟随）与 T12 窗口表面世界零侵入零干扰；保持全屏鼠标穿透正常。

