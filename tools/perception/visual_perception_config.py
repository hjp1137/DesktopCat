"""
DesktopCat - Visual Geometry Perception Config (T15)
集中管理视觉几何感知服务的所有性能、算法阈值与空间参数。
"""

# 扫描调度频率 (Hz)
SCAN_HZ = 2.0
MAX_SCAN_HZ = 4.0

# 降采样分析比例 (0.25 即 1/4 宽高，例如 2560x1440 -> 640x360)
ANALYSIS_SCALE = 0.25

# 画面变化检测阈值 (32x18 缩略图均值变化，低于此值跳过完整几何分析)
SCREEN_CHANGE_THRESHOLD = 3.0

# 边缘梯度亮度差分阈值 (0~255)
EDGE_THRESHOLD = 28

# 最小线段长度 (Overlay 像素，过滤文字笔画与小图标)
MIN_VISUAL_LINE_LENGTH = 60.0

# 线段合并容差 (Overlay 像素)
LINE_MERGE_Y_TOLERANCE = 4.0
LINE_MERGE_GAP = 16.0

# 矩形框检测最小尺寸 (Overlay 像素)
MIN_VISUAL_RECT_WIDTH = 64.0
MIN_VISUAL_RECT_HEIGHT = 40.0

# 坐标量化网格 (Overlay 像素，抑制像素抖动)
GEOMETRY_QUANTIZATION = 4.0

# 时序稳定性确认帧数
APPEAR_CONFIRM_COUNT = 2
DISAPPEAR_CONFIRM_COUNT = 2

# 快照最大保留几何数量 (超限优先保留长线与大框)
MAX_VISUAL_GEOMETRIES = 300
