"""
DesktopCat - Visual Geometry Perception Config (T15)
集中管理视觉几何感知服务的所有性能、算法阈值与空间参数。
"""

# 扫描调度频率 (Hz，3Hz 保证打字与滚屏时迅速响应)
SCAN_HZ = 3.0
MAX_SCAN_HZ = 5.0

# 降采样分析比例 (0.5 提高行解析度，保留文字笔画与小踏板)
ANALYSIS_SCALE = 0.5

# 画面变化检测阈值 (均值差分，灵敏捕捉打字输入与页面滚动)
SCREEN_CHANGE_THRESHOLD = 1.8

# 边缘梯度亮度差分阈值 (0~255)
EDGE_THRESHOLD = 18

# 文本行笔画差分敏感阈值
TEXT_DIFF_THRESHOLD = 10

# 最小线段长度 (Overlay 像素，支持文本行与短按钮形成踏板)
MIN_VISUAL_LINE_LENGTH = 24.0

# 文本行投射感知开关与参数
ENABLE_TEXT_LINE_DETECTION = True
MIN_TEXT_LINE_WIDTH = 24.0

# 线段合并容差 (Overlay 像素)
LINE_MERGE_Y_TOLERANCE = 4.0
LINE_MERGE_GAP = 16.0

# 矩形框检测最小尺寸 (Overlay 像素，过滤文字行误配对，仅保留真实大卡片/窗口框)
MIN_VISUAL_RECT_WIDTH = 120.0
MIN_VISUAL_RECT_HEIGHT = 80.0

# 坐标量化网格 (Overlay 像素，抑制像素抖动)
GEOMETRY_QUANTIZATION = 4.0

# 时序稳定性确认帧数
APPEAR_CONFIRM_COUNT = 1
DISAPPEAR_CONFIRM_COUNT = 2

# 快照最大保留几何数量 (超限优先保留长线与大框)
MAX_VISUAL_GEOMETRIES = 600
