# 固定任务：DesktopCat Linux 构建运行交付规范 V1.0

> 状态：长期有效 / 固定交付门禁
>
> 适用范围：DesktopCat 项目所有 Linux x86_64 构建、导出、打包、成果交付、验收包生成任务。
>
> 核心原则：**源码修改完成 ≠ 任务完成。只有最终独立构建包真实 Export、真实启动、真实进入场景并通过门禁，才允许声明完成。**

---

## 1. 最终目标

最终必须生成：

```text
DesktopCat_Linux_x86_64.zip
```

解压后必须能够直接运行：

```bash
chmod +x DesktopCat.x86_64
./DesktopCat.x86_64
```

不得要求用户：

- 安装 Godot Editor；
- 打开 Godot 编辑器；
- 手动选择项目；
- 手动指定 `.pck`；
- 手动指定 `main.tscn`；
- 修改文件或重新编译；
- 补充源码或资源。

解压后即应是完整、独立、可运行的 Linux 构建。

---

## 2. P0 禁止项

以下任意一项存在，任务即为 FAIL，不得声称完成。

### P0-1 禁止把 Godot Editor 当成游戏程序

最终 `DesktopCat.x86_64` 必须来自 Godot 4.7.2 Linux x86_64 Release Export Template。

不得把 Godot Editor 复制或重命名成 `DesktopCat.x86_64`。

执行：

```bash
./DesktopCat.x86_64 --help
```

不得出现：

```text
this build = editor
```

### P0-2 必须存在有效 Main Scene

`project.godot` 必须正确配置主场景，例如：

```ini
[application]
run/main_scene="res://scenes/main.tscn"
```

实际启动不得出现：

```text
no main scene defined in the project
```

### P0-3 PCK 必须是真实有效资源包

必须通过 Godot 标准 Export 流程生成 `DesktopCat.pck`。

禁止：

- 自行拼接 PCK；
- 使用自写二进制打包器替代 Godot Export；
- 复制损坏旧 PCK；
- 只生成目录表而 payload 无效；
- 大量零字节资源；
- 无法解析的 `.tscn`；
- 无法加载的 PNG、GDScript、Resource。

运行时不得出现关键资源错误：

```text
Parse Error
Expected '['
Failed loading resource
Invalid resource
Cannot open file
```

---

## 3. Godot 源项目必须先通过解析检查

Export 前必须验证：

1. Godot 4.7.2 可以正常加载项目；
2. `project.godot` 有效；
3. 主场景真实存在；
4. 无 GDScript Parse Error；
5. 所有关键资源路径存在；
6. Linux 大小写路径完全正确；
7. 不依赖 `C:\`、`D:\`、`\Users\` 等 Windows 绝对路径；
8. 不依赖开发机绝对路径；
9. 不引用仓库外部文件。

至少执行一次项目解析检查，例如：

```bash
godot --headless --path . --editor --quit
```

或使用当前 Godot 4.7.2 环境中的等效命令。

若存在 `Parse Error`、`SCRIPT ERROR`、`Failed loading resource`、`Invalid scene`，必须先修复再 Export。

---

## 4. Linux 平台兼容要求

目标平台：

```text
Linux x86_64
```

必须主动搜索并检查：

```text
WinDLL
user32
dwmapi
kernel32
gdi32
UIAutomation
win32api
win32gui
pywin32
ctypes.windll
```

如果 Windows API 属于 Windows 桌面感知模块，必须采用平台隔离，例如：

```python
if platform.system() == "Windows":
    ...
elif platform.system() == "Linux":
    ...
```

Linux 启动时绝不能因为导入 Windows 专用模块直接崩溃。

若某功能暂时只支持 Windows，则 Linux 下必须：

1. 安全禁用该功能；
2. 输出明确日志；
3. 保证 DesktopCat 主程序继续运行。

---

## 5. 禁止为了“能启动”而删掉真实功能

必须尽量保留当前 DesktopCat 的真实功能和美术效果，包括：

- 猫咪角色；
- 动画；
- 状态机；
- 行走；
- 跳跃；
- 下落；
- 碰撞；
- 攀爬；
- 边缘识别；
- `demo-surfaces` 测试场景；
- 原有美术资源与视觉风格。

禁止以以下内容冒充正式成果：

- 空 Godot 窗口；
- 单一 Label；
- 单一 Sprite；
- 简单方块测试程序；
- 与 DesktopCat 无关的假 Demo。

---

## 6. 必须提供 Demo 审核入口

必须保留或实现：

```bash
./DesktopCat.x86_64 --demo-surfaces
```

该模式必须真实进入稳定物理测试场景，用于审核：

- 地面行走；
- 台阶；
- 不同高度平台；
- 窄平台；
- 墙壁；
- 边缘；
- 连续障碍物；
- 跳跃；
- 下落；
- 攀爬；
- 挂边；
- 碰撞恢复。

不得只在代码中声明参数但实际无效。

---

## 7. 建议提供 Review 模式

建议支持：

```bash
./DesktopCat.x86_64 --review
```

或：

```bash
./DesktopCat.x86_64 --demo-surfaces --review
```

Review 模式应尽可能：

- 固定窗口尺寸；
- 固定猫咪初始位置；
- 固定测试场景；
- 禁止随机出生；
- 输出完整日志；
- 尽量避免依赖真实桌面环境；
- 方便截图和自动化验收。

---

## 8. 启动日志要求

建议至少输出：

```text
[DesktopCat] Version: ...
[DesktopCat] Platform: Linux
[DesktopCat] Godot: 4.7.2
[DesktopCat] Main scene loaded
[DesktopCat] Cat scene loaded
[DesktopCat] Physics initialized
[DesktopCat] Perception backend: ...
[DesktopCat] Demo surfaces: enabled/disabled
[DesktopCat] Ready
```

不得启动后完全无可审计日志。

---

## 9. 必须真实 Export，不允许只写构建步骤

AI 必须实际执行 Godot Export。

不得只说“请在 Godot 里点击 Export”。
不得只修改 `export_presets.cfg` 后声称完成。

必须实际生成最终二进制，例如：

```bash
godot --headless \
  --path . \
  --export-release "Linux/X11" \
  build/linux/DesktopCat.x86_64
```

具体命令应根据当前 Godot 4.7.2 环境和实际 preset 调整。

如果环境缺少 Export Template，必须正确安装/配置后再构建；若客观无法安装，则明确 FAIL，不得伪造 PASS。

---

## 10. Export 后必须从最终目录真实运行

生成构建成果后，必须脱离源码目录执行：

```bash
cd build/linux
chmod +x DesktopCat.x86_64
./DesktopCat.x86_64
```

并至少再次测试：

```bash
./DesktopCat.x86_64 --demo-surfaces
```

不能只验证“进程能创建”，必须确认成功进入主场景或 Demo 场景。

---

## 11. 构建日志出现错误时禁止继续包装成成功

如果 Export 或运行日志存在：

```text
ERROR
Parse Error
Failed
Invalid
Missing
```

必须分析其是否为关键错误并先修复。

禁止使用以下逻辑：

> 虽然存在错误，但 ZIP 已成功生成，所以任务完成。

**ZIP 成功生成不等于构建成功。**

---

## 12. 最终 ZIP 内容

推荐结构：

```text
DesktopCat_Linux_x86_64/
├── DesktopCat.x86_64
├── DesktopCat.pck
├── README_Linux.md
├── VERSION
└── build_report.md
```

如果运行需要 `lib/`、`tools/`、`python/`、`assets/` 等，可以包含，但所有引用必须使用可迁移的相对路径。

不得包含：

- Godot Editor；
- `.git`；
- 开发缓存；
- 开发机绝对路径配置；
- 无关构建文件；
- 损坏旧版 PCK。

---

## 13. README 必须经过真实验证

`README_Linux.md` 至少包含：

```bash
chmod +x DesktopCat.x86_64
./DesktopCat.x86_64
```

Demo：

```bash
./DesktopCat.x86_64 --demo-surfaces
```

README 中每条启动命令必须由 AI 在最终交付目录中真实执行成功，不得写未经验证的说明。

---

## 14. 必须生成 build_report.md

至少记录：

```markdown
# DesktopCat Linux Build Report

## Environment
Godot: 4.7.2
Platform: Linux x86_64
Build: Release

## Project Validation
Main Scene: PASS / FAIL
GDScript Parse: PASS / FAIL
Resource Loading: PASS / FAIL

## Export
Linux Export: PASS / FAIL

## Runtime
Normal Start: PASS / FAIL
Demo Surfaces: PASS / FAIL

## Critical Errors
0 或真实数量

## Known Limitations
...
```

严禁伪造 PASS。

---

## 15. 最终交付十项硬门禁

只有以下 Gate 全部通过，才允许回复“任务完成”。

### Gate 1：ELF 格式

```bash
file DesktopCat.x86_64
```

必须确认是 Linux x86_64 ELF 64-bit 可执行文件。

### Gate 2：非 Editor Build

`DesktopCat.x86_64` 不得是 Godot Editor Build。

### Gate 3：普通启动成功

```bash
./DesktopCat.x86_64
```

必须成功进入 DesktopCat。

### Gate 4：Demo 启动成功

```bash
./DesktopCat.x86_64 --demo-surfaces
```

必须成功进入 Demo 测试场景。

### Gate 5：Main Scene 有效

运行过程中不得出现：

```text
no main scene defined
```

### Gate 6：场景与脚本可解析

不得存在阻塞性：

```text
Parse Error
```

### Gate 7：关键资源加载成功

不得存在阻塞性：

```text
Failed loading resource
```

### Gate 8：Linux 平台兼容

不得因 Windows API 导入导致 Linux 程序崩溃。

### Gate 9：真实 DesktopCat 功能存在

必须至少保留真实猫咪和当前核心交互功能，不能以空壳 Demo 替代。

### Gate 10：独立目录运行

必须把构建目录复制到一个不依赖源码目录的位置后再次启动，仍可正常运行。

此门禁用于排除程序偷偷依赖源码目录文件的问题。

---

## 16. 最终压缩包

全部 Gate 通过后再生成：

```text
DesktopCat_Linux_x86_64.zip
```

生成 ZIP 后建议再次解压到新的临时目录，对 ZIP 内真实内容执行最终 smoke test。

---

## 17. AI 最终回复格式

不得只回复“已经完成”。必须明确输出：

```text
构建状态：PASS / FAIL

Godot 项目解析：PASS / FAIL
Linux Export：PASS / FAIL
普通启动：PASS / FAIL
--demo-surfaces：PASS / FAIL
主场景加载：PASS / FAIL
资源加载：PASS / FAIL
Linux 平台兼容：PASS / FAIL
独立目录运行：PASS / FAIL

实际测试命令：
...

最终文件：
DesktopCat_Linux_x86_64.zip

已知问题：
...
```

若任一 P0 或硬门禁未解决，必须明确写：

```text
构建状态：FAIL
```

不得交付一个无法运行的 ZIP 并声称已经完成。

---

## 18. 固定执行原则

任何 AI 在执行 DesktopCat Linux 构建成果任务时，必须遵循：

```text
Build → Run → Observe → Fix → Rebuild → Run Again
```

直到最终独立构建真实运行成功为止。

再次强调：

> **本任务的“完成”标准不是代码已经写完，而是最终 ZIP 已经由执行 AI 亲自构建并实际运行成功。不要猜测“应该能运行”。没有真实运行成功，就不得声称完成。**

---

## 19. 后续调用方式

以后用户要求生成可供 ChatGPT / 独立 Linux 环境进行构建运行审核的成果时，应先阅读本文件，并明确以本文件作为最终交付门禁。

用户可使用极简指令：

```text
请完成当前开发任务，并按照《plans/固定任务_DesktopCat_Linux构建运行交付规范_V1.0.md》进行最终构建、运行、自验和打包。所有 Gate 全部通过后再交付 DesktopCat_Linux_x86_64.zip；任何 Gate 未通过不得声称完成。
```
