"""
DesktopCat - T25 Screen Physics Compiler Regression & Unit Tests
验证屏幕物理编译器核心模块：
1. CatScaleAdapter 参数动态自适应
2. TextureSuppressor 高纹理区域识别与内部抑制
3. Text Fragmentation 显著下降（Legacy vs OpenCV vs Hybrid）
4. TemporalFilter 时间置信度与 Jitter 抑制（瞬时闪烁光标过滤）
5. 完整编译流水线与量化指标输出
"""

import unittest
import numpy as np
import os
import sys

_ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
if _ROOT_DIR not in sys.path:
    sys.path.insert(0, _ROOT_DIR)

from tools.perception.cat_physics_compiler import (
    CatScaleAdapter, TextureSuppressor, TemporalFilter,
    LegacyPerceptionProvider, OpenCVPerceptionProvider,
    HybridPhysicalPerceptionProvider, ScreenPhysicsCompiler,
    ScreenPhysicsCompilerService,
)


class RecordingCompiler:
    def __init__(self):
        self.calls = []
        self.scale_adapter = CatScaleAdapter()

    def compile(self, gray, ui_elements=None, windows=None, scale_inv=1.0, reuse_extraction=False, now=None):
        self.calls.append({
            "reuse_extraction": reuse_extraction,
            "shape": gray.shape,
            "ui_elements": ui_elements,
            "windows": windows,
            "scale_inv": scale_inv,
        })
        return {
            "v": 1,
            "type": "t25_perception_snapshot",
            "revision": len(self.calls),
            "mode": "hybrid",
            "surfaces": {"legacy": [], "opencv": [], "hybrid": []},
            "debug_layers": {},
        }

class TestT25PhysicsCompiler(unittest.TestCase):
    def test_service_compiles_in_target_work_area_coordinates(self):
        service = ScreenPhysicsCompilerService()
        recorder = RecordingCompiler()
        service.compiler = recorder
        compile_frame = getattr(service, "compile_work_area_if_changed", None)
        self.assertTrue(callable(compile_frame),
                        "服务应提供目标工作区增量编译入口")

        gray = np.zeros((60, 80), dtype=np.uint8)
        work_area = {"screen": 1, "x": 120, "y": 80,
                     "width": 160, "height": 120}
        ui_elements = [{"id": "text", "x": 130, "y": 90,
                        "width": 40, "height": 20}]
        windows = [{"id": "browser", "x": 120, "y": 80,
                    "width": 160, "height": 120}]

        snapshot = compile_frame(gray, work_area, ui_elements, windows, 2.0)

        self.assertIsNotNone(snapshot)
        self.assertEqual(snapshot["work_area"], work_area)
        self.assertEqual(recorder.calls[0]["ui_elements"][0]["x"], 10)
        self.assertEqual(recorder.calls[0]["ui_elements"][0]["y"], 10)
        self.assertEqual(recorder.calls[0]["windows"][0]["x"], 0)
        self.assertEqual(recorder.calls[0]["windows"][0]["y"], 0)

    def test_service_skips_heavy_compile_when_work_area_is_unchanged(self):
        service = ScreenPhysicsCompilerService()
        recorder = RecordingCompiler()
        service.compiler = recorder
        compile_frame = getattr(service, "compile_work_area_if_changed", None)
        self.assertTrue(callable(compile_frame),
                        "服务应提供带画面指纹门控的增量编译入口")

        work_area = {"screen": 0, "x": 0, "y": 0,
                     "width": 64, "height": 48}
        frame = np.zeros((24, 32), dtype=np.uint8)
        first = compile_frame(frame, work_area, [], [], 2.0)
        unchanged = compile_frame(frame.copy(), work_area, [], [], 2.0)
        changed_frame = frame.copy()
        changed_frame[4:12, 6:18] = 255
        changed = compile_frame(changed_frame, work_area, [], [], 2.0)

        self.assertIsNotNone(first)
        self.assertIsNotNone(unchanged, "相同画面仍应推进时序并发送快照")
        self.assertIsNotNone(changed)
        self.assertEqual(len(recorder.calls), 3)
        self.assertTrue(recorder.calls[1]["reuse_extraction"])
        self.assertFalse(recorder.calls[2]["reuse_extraction"])

    def test_changed_frame_produces_immediately_usable_hybrid_snapshot(self):
        service = ScreenPhysicsCompilerService()
        frame = np.full((60, 120), 245, dtype=np.uint8)
        area = {"screen": 0, "x": 0, "y": 0,
                "width": 120, "height": 60}
        elements = [{"id": "line", "control_type": "Image", "x": 10,
                     "y": 10, "width": 90, "height": 20}]

        snapshot = service.compile_work_area_if_changed(
            frame, area, elements, [], 1.0)

        self.assertTrue(snapshot["surfaces"]["hybrid"],
                        "变化门控后的首个快照必须可直接构建物理世界")

    def test_cat_scale_adapter(self):
        """验证猫咪尺度自适应参数计算"""
        adapter = CatScaleAdapter(cat_scale=1.0, foot_width=36.0, cat_width=70.0, cat_height=64.0)
        self.assertAlmostEqual(adapter.foot_width, 36.0)
        self.assertGreaterEqual(adapter.min_platform_length, 24.0)
        self.assertTrue(adapter.morph_kernel_size % 2 == 1, "核尺寸应为奇数")

        # 调整为大猫 (scale=1.5, foot_width=54.0)
        adapter.update_metrics(cat_scale=1.5, foot_width=54.0, cat_width=105.0, cat_height=96.0)
        self.assertGreater(adapter.min_platform_length, 35.0)
        self.assertGreater(adapter.gap_tolerance, 20.0)
        self.assertGreater(adapter.morph_kernel_size, 7)

    def test_texture_suppressor(self):
        """验证高纹理区域（照片/视频）内部抑制"""
        suppressor = TextureSuppressor(edge_density_thresh=0.15, min_texture_area=1000)
        h, w = 300, 400
        gray = np.full((h, w), 200, dtype=np.uint8)

        # 模拟中间有一张 120x100 的复杂纹理照片（x=100~220, y=80~180）
        rng = np.random.RandomState(42)
        gray[80:180, 100:220] = rng.randint(0, 255, (100, 120), dtype=np.uint8)

        # 边缘图
        edges = np.zeros((h, w), dtype=np.uint8)
        edges[80:180, 100:220] = (rng.rand(100, 120) > 0.6).astype(np.uint8) * 255

        boxes = suppressor.find_texture_dense_regions(gray, edges)
        self.assertGreaterEqual(len(boxes), 1, "应识别出高纹理密集区域")

        bx, by, bw, bh = boxes[0]
        self.assertTrue(70 <= by <= 90 and 90 <= bx <= 110, f"纹理盒子位置应匹配实际范围，实际bx={bx}, by={by}")

        # 内部线段应被判定为 inside_texture
        self.assertTrue(suppressor.is_inside_texture_box(120, 120, 180, 120, boxes))
        # 外部线段不应被判定为 inside_texture
        self.assertFalse(suppressor.is_inside_texture_box(20, 40, 80, 40, boxes))

    def test_hybrid_does_not_create_platform_from_empty_text_container(self):
        provider = HybridPhysicalPerceptionProvider(CatScaleAdapter(), TextureSuppressor())
        gray = np.full((120, 240), 245, dtype=np.uint8)
        elements = [{"id": "line", "control_type": "Text", "x": 20,
                     "y": 30, "width": 160, "height": 80}]
        surfaces, _, _ = provider.extract(gray, elements, [], 1.0)
        self.assertFalse(surfaces, "空文本容器不能生成踏板")

    def test_hybrid_uses_image_and_window_structure(self):
        adapter = CatScaleAdapter(cat_scale=1.0, foot_width=36.0)
        provider = HybridPhysicalPerceptionProvider(adapter, TextureSuppressor())
        gray = np.full((160, 260), 245, dtype=np.uint8)
        elements = [{"id": "image", "control_type": "Image", "x": 40,
                     "y": 60, "width": 100, "height": 70}]
        windows = [{"id": "browser", "x": 10, "y": 20,
                    "width": 220, "height": 130}]

        surfaces, _, _ = provider.extract(gray, elements, windows, 1.0)

        self.assertTrue(any(s["type"] == "PLATFORM" and s["y1"] == 60
                            for s in surfaces), "图片顶沿应成为平台")
        self.assertTrue(any(s["type"] == "WALL" and s["x1"] == 40
                            for s in surfaces), "图片侧沿应成为攀爬墙")
        self.assertTrue(any(s["type"] == "PLATFORM" and s["y1"] == 20
                            for s in surfaces), "窗口顶沿应提供结构性平台")

    def test_text_fragmentation_reduction(self):
        """验证长文本行场景下 Hybrid 对比 Legacy 的碎片率显著下降"""
        adapter = CatScaleAdapter(cat_scale=1.0, foot_width=36.0)
        suppressor = TextureSuppressor()
        legacy_prov = LegacyPerceptionProvider()
        hybrid_prov = HybridPhysicalPerceptionProvider(adapter, suppressor)

        h, w = 200, 500
        gray = np.full((h, w), 250, dtype=np.uint8)

        # 构造一行有 10 个单词的模拟文字：y=80~92
        # 单词宽度 25px，间隔 10px
        for i in range(10):
            sx = 30 + i * 40
            ex = sx + 28
            for y in range(80, 92):
                gray[y, sx:ex:2] = 20 # 笔画交替

        leg_surfs, _ = legacy_prov.extract(gray, scale_inv=1.0)
        hy_surfs, _, _ = hybrid_prov.extract(gray, scale_inv=1.0)

        leg_platforms = [s for s in leg_surfs if s["type"] == "PLATFORM"]
        hy_platforms = [s for s in hy_surfs if s["type"] == "PLATFORM"]

        print(f"[Fragmentation Test] Legacy 生成平台数: {len(leg_platforms)}, Hybrid 生成平台数: {len(hy_platforms)}")
        self.assertGreater(len(leg_platforms), len(hy_platforms), "Legacy 生成的碎片表面数应显著多于 Hybrid")
        self.assertLessEqual(len(hy_platforms), 3, "Hybrid 应该将一整行文本熔合成极少数连续平台")

    def test_temporal_stability_filter(self):
        """验证时间稳定性追踪器：静态屏幕 Jitter 趋近于 0，闪烁噪点被过滤"""
        t_filter = TemporalFilter(confirm_frames=2, max_grace_frames=2, match_dist=12.0)

        # 稳定平台
        stable_p = {"id": "p1", "type": "PLATFORM", "x1": 50.0, "y1": 100.0, "x2": 200.0, "y2": 100.0, "confidence": 0.8}
        # 瞬时闪烁光标 (仅出现 1 帧)
        flicker_p = {"id": "cur", "type": "PLATFORM", "x1": 300.0, "y1": 100.0, "x2": 310.0, "y2": 100.0, "confidence": 0.5}

        # Frame 1: 出现稳定平台 + 闪烁光标
        surfs_f1, j1 = t_filter.update([stable_p, flicker_p])
        self.assertEqual(len(surfs_f1), 0, "第一帧未经 confirm 不应作为稳定表面输出")

        # Frame 2: 闪烁光标消失，稳定平台依然存在
        surfs_f2, j2 = t_filter.update([stable_p])
        self.assertEqual(len(surfs_f2), 1, "稳定平台经过 2 帧确认应升级为稳定表面")
        self.assertAlmostEqual(surfs_f2[0]["x1"], 50.0, delta=2.0)

        # Frame 3: 依然静态稳定
        surfs_f3, j3 = t_filter.update([stable_p])
        self.assertEqual(len(surfs_f3), 1)
        self.assertEqual(j3["added"], 0)
        self.assertEqual(j3["moved"], 0)
        self.assertLessEqual(j3["total_jitter"], 1, "静态屏幕抖动量应极低")

    def test_physics_compiler_pipeline(self):
        """验证物理编译器完整流水线及协议输出格式"""
        compiler = ScreenPhysicsCompiler(cat_scale=1.0)
        h, w = 240, 320
        gray = np.full((h, w), 240, dtype=np.uint8)

        # 模拟一个白色按钮 (x=40~140, y=60~90)
        gray[60:90, 40:140] = 30

        res = compiler.compile(gray, ui_elements=None, windows=None, scale_inv=1.0)
        self.assertEqual(res["v"], 1)
        self.assertEqual(res["type"], "t25_perception_snapshot")
        self.assertIn("surfaces", res)
        self.assertIn("legacy", res["surfaces"])
        self.assertIn("opencv", res["surfaces"])
        self.assertIn("hybrid", res["surfaces"])

        # 检查 Debug 阶段图层
        layers = res["debug_layers"]
        self.assertIn("raw_evidence", layers)
        self.assertIn("candidates", layers)
        self.assertIn("merged_regions", layers)
        self.assertIn("stable_regions", layers)
        self.assertIn("final_surfaces", layers)

        # 检查量化指标
        metrics = res["metrics"]
        self.assertIn("timing", metrics)
        self.assertIn("hybrid", metrics)
        self.assertIn("reduction_ratio", metrics["hybrid"])
        print(f"[Compiler Pipeline PASS] 耗时: {metrics['timing']['total_ms']}ms, 压缩比: {metrics['hybrid']['reduction_ratio']}")

if __name__ == "__main__":
    unittest.main()
