# DesktopCat Local External Perception Bridge Protocol (v1)

## 1. 架构原则
- **极轻量本地通信**：仅监听 `127.0.0.1`，严禁外部网络访问；
- **结构化几何数据**：禁止持续传输屏幕 Bitmap（PNG/JPEG/Raw RGB/截图流），仅传输结构化感知与几何数据；
- **非阻塞零干扰**：桥接通道作为可选基础设施，无客户端时小猫行为与系统开销不受任何影响。

## 2. 传输与帧格式
- **Transport**：TCP on `127.0.0.1:47831`
- **Encoding**：UTF-8
- **Framing**：NDJSON（每个 JSON 对象后以换行符 `\n` 分隔）
- **Protocol Version**：`1`
- **限制约束**：
  - 单条消息最大大小：256 KB (`MAX_MESSAGE_SIZE = 262144`)
  - 客户端输入缓冲区上限：512 KB (`MAX_BUFFER_SIZE = 524288`)

## 3. 消息信封规范
所有消息必须包含协议版本号 `v` 与消息类型 `type`：
```json
{
  "v": 1,
  "type": "<message_type>",
  ...
}
```

## 4. 消息类型与交互流程
### 4.1 HELLO (Server -> Client)
客户端成功连接后服务端主动发送：
```json
{"v":1,"type":"hello","app":"DesktopCat","bridge_version":1,"screen_index":0,"overlay":{"width":2880,"height":1812}}
```

### 4.2 PING / PONG
- Client 发送：`{"v":1,"type":"ping"}`
- Server 响应：`{"v":1,"type":"pong"}`

### 4.3 GET_STATUS / STATUS
- Client 发送：`{"v":1,"type":"get_status"}`
- Server 响应：
```json
{"v":1,"type":"status","cat_state":"IDLE","control_mode":"AUTO","screen_index":0,"overlay":{"width":2880,"height":1812},"bridge_connected":true}
```

### 4.4 COMMAND (Client -> Server)
通过白名单严格映射至 CommandManager：
```json
{"v":1,"type":"command","name":"JUMP","payload":{}}
```
位置类指令（如 `LOOK_AT_POSITION`、`MOVE_TO_POSITION`）：
```json
{"v":1,"type":"command","name":"MOVE_TO_POSITION","payload":{"x":1200.0,"y":500.0,"speed_mode":"RUN"}}
```
坐标定义统一为当前 Overlay Local Pixel Coordinates。

### 4.5 ERROR (Server -> Client)
格式或验证失败时返回：
```json
{"v":1,"type":"error","code":"UNKNOWN_COMMAND","message":"Command not allowed"}
```

### 4.6 WINDOW_SNAPSHOT (Client -> Server)
T11 正式引入的顶层窗口几何快照：
```json
{
  "v": 1,
  "type": "window_snapshot",
  "revision": 15,
  "screen": {
    "index": 0,
    "width": 2880,
    "height": 1812
  },
  "windows": [
    {
      "id": "0x000A17BC",
      "title": "Google Chrome",
      "class_name": "Chrome_WidgetWin_1",
      "x": 320,
      "y": 180,
      "width": 1400,
      "height": 850,
      "is_foreground": true,
      "z_order": 0
    }
  ]
}
```
- **限制约束**：单次最多 256 个窗口 (`MAX_WINDOWS = 256`)；
- **坐标定义**：必须为当前 Overlay 局部像素坐标，且已完成屏幕边界裁剪；
- **非物理性**：T11 窗口几何仅供 WorldModel 数据存储与 F8 调试绘制，不直接生成物理碰撞。

### 4.7 SURFACE_SNAPSHOT (预留)
预留未来几何表面格式（当前版本接收后响应 `NOT_IMPLEMENTED` 错误）：
```json
{"v":1,"type":"surface_snapshot","revision":1,"surfaces":[]}
```

### 4.8 UI_SNAPSHOT (T14 Client -> Server)
通过 Windows UI Automation 提取的可见 UI 控件几何数据：
```json
{
  "v": 1,
  "type": "ui_snapshot",
  "revision": 3,
  "screen": { "index": 0, "width": 2880, "height": 1812 },
  "elements": [
    {
      "id": "0x30094:btn_submit",
      "window_id": "0x30094",
      "control_type": "Button",
      "name": "Submit",
      "x": 250.0,
      "y": 160.0,
      "width": 90.0,
      "height": 32.0
    }
  ]
}
```

### 4.9 VISUAL_SNAPSHOT (T15 Client -> Server)
通过原生 GDI 抓屏与降采样灰度梯度提取的纯几何 LINE 与 RECT：
```json
{
  "v": 1,
  "type": "visual_snapshot",
  "revision": 1,
  "screen": { "index": 0, "width": 2880, "height": 1812 },
  "geometries": [
    {
      "id": "vg_lh_610_420_960",
      "type": "LINE",
      "orientation": "HORIZONTAL",
      "x1": 420.0,
      "y1": 610.0,
      "x2": 960.0,
      "y2": 610.0
    },
    {
      "id": "vg_rect_420_1100_400_280",
      "type": "RECT",
      "x": 1100.0,
      "y": 420.0,
      "width": 400.0,
      "height": 280.0
    }
  ]
}
```
- **限制约束**：单次最多 300 个几何 (`MAX_VISUAL_GEOMETRIES = 300`)；
- **纯轻量几何**：禁止传输原图或任何 Bitmap 像素流，仅传输矢量几何数据；
- **非物理性**：T15 视觉几何仅供 VisualWorldModel 存储与 F12 调试呈现，严禁直接生成 Surface 物理碰撞（留待 T16 Fusion）。


