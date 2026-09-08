"""
DesktopCat - Perception Layer Regression Tests
验证文本行投射感知与 UIA 文本行拆分逻辑
"""
import unittest
import numpy as np

from tools.perception.visual_perception_config import (
    MIN_VISUAL_LINE_LENGTH, ENABLE_TEXT_LINE_DETECTION, MIN_TEXT_LINE_WIDTH
)
from tools.perception.visual_perception import VisualGeometryDetector

class TestPerceptionRegression(unittest.TestCase):
    def test_config_values(self):
        self.assertEqual(MIN_VISUAL_LINE_LENGTH, 24.0, "最小线段长度应为24px")
        self.assertTrue(ENABLE_TEXT_LINE_DETECTION, "应开启文本行检测")
        self.assertEqual(MIN_TEXT_LINE_WIDTH, 24.0, "文本行最小宽度应为24px")

    def test_text_line_profiler_synthetic(self):
        detector = VisualGeometryDetector()
        dw = 400
        dh = 300
        # 构造一个白色背景、包含3行模拟黑色文字的灰度图像
        arr = np.full((dh, dw), 245, dtype=np.uint8)

        # 第 1 行文字：y=50~64, x=30~200 (笔画高频黑白交替)
        for y in range(50, 64):
            for x in range(30, 200, 3):
                arr[y, x] = 20

        # 第 2 行文字：y=100~114, x=30~320
        for y in range(100, 114):
            for x in range(30, 320, 3):
                arr[y, x] = 20

        # 第 3 行文字：y=160~174, x=50~150
        for y in range(160, 174):
            for x in range(50, 150, 3):
                arr[y, x] = 20

        lum = bytearray(arr.tobytes())
        scale_inv = 2.0 # 0.5 降采样
        m_h, m_v, rects = detector.detect_geometry(lum, dw, dh, scale_inv)

        # 检查是否成功提取出了水平踏板线段
        self.assertGreaterEqual(len(m_h), 3, "应至少检测出 3 条水平文本行踏板")

        # 验证 Y 坐标是否在模拟行区间内
        detected_ys = [y for y, x1, x2 in m_h]
        has_line_1 = any(abs(y - 50) <= 6 for y in detected_ys)
        has_line_2 = any(abs(y - 100) <= 6 for y in detected_ys)
        has_line_3 = any(abs(y - 160) <= 6 for y in detected_ys)
        self.assertTrue(has_line_1, "应检测到第1行文字踏板")
        self.assertTrue(has_line_2, "应检测到第2行文字踏板")
        self.assertTrue(has_line_3, "应检测到第3行文字踏板")
        print(f"[PASS] 视觉文本行投射感知测试成功: 检测出 {len(m_h)} 条踏板线！")

if __name__ == "__main__":
    unittest.main()
