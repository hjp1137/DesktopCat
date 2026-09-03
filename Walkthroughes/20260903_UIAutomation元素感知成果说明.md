# 20260903 Windows UI Automation 元素感知成果说明 (T14)

## 1. 任务概述与核心交付
在 T13 多表面物理（Multi-Surface Cat Physics）完成的基础上，本次 T14 实现了轻量级 Windows UI Automation 元素感知系统，使 DesktopCat 外部感知链路首次具备了洞察窗口内部 UI 控件几何特征（Button, Edit, Text, Image, List, ListItem, Pane, Group, Document 等）的能力，并完整搭建了从 Win32 UIA COM 到 Godot `UIElementWorldModel` 的数据闭环与 F11 调试可视化。

### 核心交付物
1. **纯标准库零依赖 UIA 驱动**：`tools/perception/ui_automation_perception.py`
   - 基于纯 Python 标准库 `ctypes` + `ole32`/`oleaut32`，直接操纵 Windows 原生 `IUIAutomation` 与 `IUIAutomationTreeWalker` COM 接口，零第三方 pip 依赖；
   - 包含跨 Session 桌面绑定（`OpenDesktopW('default')`），自动适应任何终端运行环境。
2. **多客户端并发外部桥接**：`scripts/external_bridge.gd`
   - 升级支持多客户端并发接入（最多 8 个活动客户端），使 `window_perception.py` 与 `ui_automation_perception.py` 能够独立运行、同时连接并传输快照；
   - 扩展 `ui_snapshot` 协议解析、版本防倒退与 `TOGGLE_DEBUG_UI` 指令处理。
3. **Godot UI 几何模型**：`scripts/world/ui_element_world_model.gd`
   - 建立 UI 控件纯几何管理容器，支持根据 ControlType 映射丰富色彩与文字标签，提供高效空间与类型查询 API；
   - 严格限定调试最大渲染元素数（`MAX_DEBUG_UI_ELEMENTS = 300`），保证桌面鼠标全屏穿透零干扰。
4. **统一双轮驱动启动器**：`tools/perception/perception_service.py`
   - 提供可选的单进程双感知任务托管运行器，支持窗口几何（10Hz）与 UI 自动化（2Hz）并存。
5. **完整自动化测试与独立版打包**：
   - `test_runner.gd` 扩展测试 18~22（总计 22 项单元测试 100% 通过）；
   - `test_integration.gd` 完成端到端 UI 快照、F11 按键与着陆回归测试；
   - 重新打包生成 `build/DesktopCat_Standalone.exe`。

## 2. 协议设计与三维预算控制
- **协议格式**：
  ```json
  {
    "v": 1,
    "type": "ui_snapshot",
    "revision": 1,
    "screen": { "index": 0, "width": 2560, "height": 1392 },
    "elements": [
      {
        "id": "0x000A0254:42-919582-4--3387",
        "window_id": "0x000A0254",
        "control_type": "Button",
        "x": 1349.0,
        "y": 370.0,
        "width": 32.0,
        "height": 32.0
      }
    ]
  }
  ```
- **三维预算硬约束**：
  - 时间预算：`SCAN_BUDGET_MS = 35.0ms`，单次遍历超时即停止深层递归；
  - 深度限制：`MAX_DEPTH = 10`；
  - 数量限制：`MAX_UI_ELEMENTS = 1000`；
  - 变动抑制：基于集合签名 `id:type:x:y:w:h` 比较，无变动静默不发。
- **隐私原则执行**：
  - 绝对不读取 Value / Text / Password 敏感属性；
  - 元素 ID 基于 Windows 官方 `RuntimeId` 整数序列生成，脱敏且稳定；
  - 仅传输纯几何与控件类别标签。

## 3. 自验证结果与快捷键说明
- **自动化测试**：
  - 运行 `scripts/test_runner.gd`：测试 1~22 全量通过；
  - 运行 `scripts/test_integration.gd`：主场景 6 个阶段集成验证通过；
  - 实测真实 Windows 桌面（Chrome/ChatGPT、Explorer、Notepad）50ms 预算内提取数十个控件，渲染与鼠标穿透平稳。
- **快捷键体系（针对 Surface Pro 兼容）**：
  - `F8` / `-` / `V` / `W`：窗口几何线框；
  - `F9` / `=` / `B` / `P`：物理表面线框；
  - `F10` / `N` / `M`：Cat 物理接触点与表面高亮；
  - `F11` / `K` / `O` / `U`：UI Automation 控件几何线框。

