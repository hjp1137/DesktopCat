"""
DesktopCat - Screen Physics Compiler (T25)
屏幕物理编译器核心引擎：
将复杂屏幕视觉信息从像素层与零碎 UI 元素层，编译为简单、稳定、连续的猫物理世界（Platform / Wall / Ledge / Void）。
支持三路感知模式：
- Mode A: Legacy Perception (基线对照组)
- Mode B: OpenCV Visual Perception (纯视觉路线)
- Mode C: Hybrid Physical Perception (混合物理感知核心路线)
"""

import time
import base64
from tools.perception.surface_visibility import clip_visible_surfaces, visible_image_boxes
import math
import socket
import json
import numpy as np
import cv2
from typing import List, Dict, Any, Tuple, Optional

class CatScaleAdapter:
    """
    根据猫咪自身尺寸自适应推导感知与物理编译尺度，杜绝硬编码魔法数字。
    """
    def __init__(self, cat_scale: float = 1.0, foot_width: float = 36.0, cat_width: float = 70.0, cat_height: float = 64.0):
        self.update_metrics(cat_scale, foot_width, cat_width, cat_height)

    def update_metrics(self, cat_scale: float, foot_width: float, cat_width: float, cat_height: float):
        self.cat_scale = max(0.5, float(cat_scale))
        self.foot_width = max(16.0, float(foot_width))
        self.cat_width = max(32.0, float(cat_width))
        self.cat_height = max(24.0, float(cat_height))

        # 自适应推导参数
        # 1. 表面横向间隙容差（小于半只脚宽度即可视为连续踏板）
        self.gap_tolerance = max(8.0, self.foot_width * 0.45)
        # 2. 垂直高度合并容差
        self.y_merge_tolerance = max(4.0, 6.0 * (self.cat_scale ** 0.5))
        # 3. 最小合法踏板长度（小猫站立最小支撑）
        self.min_platform_length = max(20.0, self.foot_width * 0.75)
        # 4. 最小可攀爬墙体高度
        self.min_wall_length = max(24.0, self.cat_height * 0.4)
        # 5. 形态学闭运算核大小（必须为奇数）
        k_size = int(round(self.foot_width * 0.22))
        if k_size % 2 == 0: k_size += 1
        self.morph_kernel_size = max(3, min(15, k_size))
        # 6. 噪点区域面积过滤阈值
        self.min_candidate_area = max(16.0, (self.foot_width * 0.5) ** 2)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "cat_scale": self.cat_scale,
            "foot_width": self.foot_width,
            "cat_width": self.cat_width,
            "cat_height": self.cat_height,
            "gap_tolerance": self.gap_tolerance,
            "y_merge_tolerance": self.y_merge_tolerance,
            "min_platform_length": self.min_platform_length,
            "min_wall_length": self.min_wall_length,
            "morph_kernel_size": self.morph_kernel_size,
            "min_candidate_area": self.min_candidate_area
        }

class TextureSuppressor:
    """
    高纹理区域（照片、插图、视频、密集图案）抑制器。
    识别高边缘密度与高局部方差的大块区域，抑制内部碎片边缘，只保留外部物理框架与顶边平台。
    """
    def __init__(self, edge_density_thresh: float = 0.16, min_texture_area: int = 4000):
        self.edge_density_thresh = edge_density_thresh
        self.min_texture_area = min_texture_area

    def find_texture_dense_regions(self, gray: np.ndarray, edges: np.ndarray) -> List[Tuple[int, int, int, int]]:
        """
        返回所有高纹理区域的包围盒 (x, y, w, h)。
        """
        h, w = gray.shape
        if w < 64 or h < 64:
            return []

        # 使用均值池化（BoxFilter）计算局部边缘密度
        # 窗口大小与尺度关联，约 32x32 像素
        win_w = max(16, min(64, w // 20))
        win_h = max(16, min(64, h // 20))
        edge_float = (edges > 0).astype(np.float32)
        density_map = cv2.boxFilter(edge_float, -1, (win_w, win_h))

        dense_mask = (density_map >= self.edge_density_thresh).astype(np.uint8) * 255
        # 形态学膨胀聚合相邻纹理簇
        close_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (win_w, win_h))
        dense_mask = cv2.morphologyEx(dense_mask, cv2.MORPH_CLOSE, close_kernel)

        contours, _ = cv2.findContours(dense_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        texture_boxes = []
        for c in contours:
            area = cv2.contourArea(c)
            if area >= self.min_texture_area:
                x, y, bw, bh = cv2.boundingRect(c)
                row_density = np.mean(edges[y:y+bh, x:x+bw] > 0, axis=1)
                # 多行正文有重复的低边缘密度行间空白，不能按照片整块抑制。
                if np.mean(row_density < 0.03) >= 0.12:
                    continue
                texture_boxes.append((x, y, bw, bh))

        return texture_boxes

    def is_inside_texture_box(self, x1: float, y1: float, x2: float, y2: float, boxes: List[Tuple[int, int, int, int]], margin: float = 6.0) -> bool:
        """
        检查线段是否完全处于高纹理区域内部（非顶边/非侧边）。
        """
        for bx, by, bw, bh in boxes:
            # 允许顶沿（y接近by）与侧沿（x接近bx或bx+bw）作为合法外表面
            is_in_x = (bx + margin <= x1 <= bx + bw - margin) and (bx + margin <= x2 <= bx + bw - margin)
            is_in_y = (by + margin <= y1 <= by + bh - margin) and (by + margin <= y2 <= by + bh - margin)
            if is_in_x and is_in_y:
                return True
        return False

class TemporalFilter:
    """
    时间稳定性滤波器：
    通过多帧追踪维护候选表面的时序置信度（Temporal Confidence），
    过滤光标闪烁、加载图标、短时阴影或高频抖动，仅允许高稳定性表面进入猫眼世界。
    """
    def __init__(self, confirm_frames: int = 2, max_grace_frames: int = 3, match_dist: float = 12.0, grace_seconds: float = 0.6):
        self.confirm_frames = confirm_frames
        self.max_grace_frames = max_grace_frames
        self.match_dist = match_dist
        self.grace_seconds = grace_seconds
        # id -> {"surface": dict, "seen_count": int, "missing_count": int, "stable": bool}
        self.tracked_surfaces: Dict[str, Dict[str, Any]] = {}
        self.next_id = 1
        self.last_jitter_stats = {"added": 0, "removed": 0, "moved": 0, "total_jitter": 0}

    def reset(self):
        self.tracked_surfaces.clear()
        self.next_id = 1
        self.last_jitter_stats = {"added": 0, "removed": 0, "moved": 0, "total_jitter": 0}

    def update(self, current_surfaces: List[Dict[str, Any]], now: Optional[float] = None) -> Tuple[List[Dict[str, Any]], Dict[str, int]]:
        """
        输入当前帧提取的原始候选表面，更新追踪器，返回稳定表面列表与抖动指标。
        """
        now = time.monotonic() if now is None else now
        matched_tracked_keys = set()
        matched_current_indices = set()
        added = 0
        removed = 0
        moved = 0

        # 帧间表面匹配
        for curr_idx, curr in enumerate(current_surfaces):
            c_type = curr.get("type", "PLATFORM")
            c_x1, c_y1 = curr["x1"], curr["y1"]
            c_x2, c_y2 = curr["x2"], curr["y2"]

            best_key = None
            best_dist = float("inf")

            for t_key, t_data in self.tracked_surfaces.items():
                if t_key in matched_tracked_keys:
                    continue
                t_surf = t_data["surface"]
                if (t_surf.get("type") != c_type or
                    t_surf.get("orientation") != curr.get("orientation") or
                    t_surf.get("window_id") != curr.get("window_id")):
                    continue

                t_x1, t_y1 = t_surf["x1"], t_surf["y1"]
                t_x2, t_y2 = t_surf["x2"], t_surf["y2"]

                d1 = math.hypot(c_x1 - t_x1, c_y1 - t_y1)
                d2 = math.hypot(c_x2 - t_x2, c_y2 - t_y2)
                dist = (d1 + d2) * 0.5

                if dist <= self.match_dist and dist < best_dist:
                    best_dist = dist
                    best_key = t_key

            if best_key is not None:
                matched_tracked_keys.add(best_key)
                matched_current_indices.add(curr_idx)
                entry = self.tracked_surfaces[best_key]
                entry["seen_count"] += 1
                entry["missing_count"] = 0
                entry["last_seen"] = now
                if best_dist > 1.5:
                    moved += 1
                # 平滑更新坐标 (指数移动平均 EMA)
                t_surf = entry["surface"]
                t_surf["x1"] = t_surf["x1"] * 0.3 + c_x1 * 0.7
                t_surf["y1"] = t_surf["y1"] * 0.3 + c_y1 * 0.7
                t_surf["x2"] = t_surf["x2"] * 0.3 + c_x2 * 0.7
                t_surf["y2"] = t_surf["y2"] * 0.3 + c_y2 * 0.7
                t_surf["confidence"] = min(1.0, t_surf.get("confidence", 0.5) + 0.15)
                if entry["seen_count"] >= self.confirm_frames:
                    entry["stable"] = True
            else:
                # 新表面加入追踪
                t_id = f"st_{self.next_id}"
                self.next_id += 1
                curr_copy = dict(curr)
                curr_copy["id"] = t_id
                curr_copy["confidence"] = curr.get("confidence", 0.5) * 0.8
                self.tracked_surfaces[t_id] = {
                    "surface": curr_copy,
                    "seen_count": 1,
                    "missing_count": 0,
                    "last_seen": now,
                    "stable": (self.confirm_frames <= 1 or curr.get("source") in ("hybrid_uia", "hybrid_window"))
                }
                matched_tracked_keys.add(t_id)
                added += 1

        # 处理未匹配的追踪项
        to_delete = []
        for t_key, t_data in self.tracked_surfaces.items():
            if t_key not in matched_tracked_keys:
                t_data["missing_count"] += 1
                if now - t_data["last_seen"] >= self.grace_seconds or not t_data["stable"]:
                    to_delete.append(t_key)
                    removed += 1

        for k in to_delete:
            del self.tracked_surfaces[k]

        stable_surfaces = []
        for t_key, t_data in self.tracked_surfaces.items():
            if t_data["stable"] and t_data["surface"].get("confidence", 0.0) >= 0.4:
                stable_surfaces.append(dict(t_data["surface"]))

        self.last_jitter_stats = {
            "added": added,
            "removed": removed,
            "moved": moved,
            "total_jitter": added + removed + moved
        }
        return stable_surfaces, self.last_jitter_stats

class LegacyPerceptionProvider:
    """
    Mode A: 基线对照组 (Legacy Baseline)
    模拟基于简单逐像素/文字行差分的旧逻辑，产生未经过 Cat-scale 深度聚合与时间滤波的碎片表面。
    """
    def __init__(self):
        pass

    def extract(self, gray: np.ndarray, scale_inv: float = 1.0) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        h, w = gray.shape
        if h < 8 or w < 8:
            return [], []

        # 双向笔画差分检测 (未做任何横向闭运算熔接)
        diff_v = np.abs(gray[1:, :].astype(np.int16) - gray[:-1, :].astype(np.int16)) >= 20
        diff_h = np.abs(gray[:, 1:].astype(np.int16) - gray[:, :-1].astype(np.int16)) >= 20
        edge_pts = np.zeros_like(gray, dtype=bool)
        edge_pts[:-1, :] |= diff_v
        edge_pts[:, :-1] |= diff_h

        surfaces = []
        raw_evidence = []
        min_len = 10

        # 逐行扫描（只要空隙超过2像素就断开，产生大量字符级碎片）
        step_y = max(1, h // 180)
        for y in range(0, h - 1, step_y):
            row = edge_pts[y]
            if not np.any(row):
                continue
            idx = np.where(row)[0]
            if len(idx) < 3:
                continue
            splits = np.where(np.diff(idx) > 2)[0]
            starts = np.insert(idx[splits + 1], 0, idx[0])
            ends = np.append(idx[splits], idx[-1])
            for s, e in zip(starts, ends):
                if (e - s + 1) >= min_len:
                    surfaces.append({
                        "id": f"leg_p_{len(surfaces)}",
                        "type": "PLATFORM",
                        "x1": float(s * scale_inv),
                        "y1": float(y * scale_inv),
                        "x2": float(e * scale_inv),
                        "y2": float(y * scale_inv),
                        "confidence": 0.60,
                        "source": "legacy"
                    })
                    if len(raw_evidence) < 150:
                        raw_evidence.append({
                            "type": "LINE", "x1": float(s * scale_inv), "y1": float(y * scale_inv),
                            "x2": float(e * scale_inv), "y2": float(y * scale_inv)
                        })

        return surfaces, raw_evidence

class OpenCVPerceptionProvider:
    """
    Mode B: 纯视觉感知路线 (OpenCV Visual Perception)
    截屏 -> 降采样灰度 -> 自适应对比度二值化 + Canny 边缘 -> 形态学闭运算 -> 连通域与轮廓 ->
    提取外轮廓物理表面，零语义依赖。
    """
    def __init__(self, scale_adapter: CatScaleAdapter):
        self.adapter = scale_adapter

    def extract(self, gray: np.ndarray, scale_inv: float = 1.0) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]]]:
        h, w = gray.shape
        if h < 16 or w < 16:
            return [], [], []

        # 1. 自适应阈值与边缘提取
        adapt_bin = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 15, 4)
        canny_edges = cv2.Canny(gray, 40, 110)
        combined_edges = cv2.bitwise_or(adapt_bin, canny_edges)

        # 2. 形态学闭运算：横向核填补文字字符间隙，形成连续物理踏板
        k_w = max(5, min(int(self.adapter.gap_tolerance / scale_inv), self.adapter.morph_kernel_size))
        k_h = 3
        close_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (k_w, k_h))
        closed = cv2.morphologyEx(combined_edges, cv2.MORPH_CLOSE, close_kernel)

        # 3. 连通域分析
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(closed, connectivity=8)

        candidate_regions = []
        surfaces = []
        raw_evidence = []

        min_area = (self.adapter.min_candidate_area / (scale_inv * scale_inv))
        min_p_len = (self.adapter.min_platform_length / scale_inv)
        min_w_len = (self.adapter.min_wall_length / scale_inv)

        for i in range(1, num_labels):
            bx, by, bw, bh, area = stats[i]
            if area < min_area and bw < min_p_len and bh < min_w_len:
                continue

            phys_x = float(bx * scale_inv)
            phys_y = float(by * scale_inv)
            phys_w = float(bw * scale_inv)
            phys_h = float(bh * scale_inv)

            candidate_regions.append({
                "x": phys_x, "y": phys_y, "w": phys_w, "h": phys_h, "area": float(area)
            })

            # 提取顶表面 (PLATFORM)
            if bw >= min_p_len:
                surfaces.append({
                    "id": f"cv_p_{len(surfaces)}",
                    "type": "PLATFORM",
                    "x1": phys_x, "y1": phys_y,
                    "x2": phys_x + phys_w, "y2": phys_y,
                    "confidence": min(0.90, 0.55 + (bw / (w * scale_inv)) * 0.4),
                    "source": "opencv"
                })

            # 提取垂直可攀爬墙体 (WALL) - 仅当高度显著时提取外侧墙面
            if bh >= min_w_len and bh >= bw * 0.4:
                surfaces.append({
                    "id": f"cv_w_l_{len(surfaces)}",
                    "type": "WALL", "orientation": "LEFT",
                    "x1": phys_x, "y1": phys_y,
                    "x2": phys_x, "y2": phys_y + phys_h,
                    "confidence": 0.80,
                    "source": "opencv"
                })
                surfaces.append({
                    "id": f"cv_w_r_{len(surfaces)}",
                    "type": "WALL", "orientation": "RIGHT",
                    "x1": phys_x + phys_w, "y1": phys_y,
                    "x2": phys_x + phys_w, "y2": phys_y + phys_h,
                    "confidence": 0.80,
                    "source": "opencv"
                })

        # 收集少量 Raw Evidence 用于 Mode 2 展示
        for i in range(0, min(100, len(candidate_regions)), max(1, len(candidate_regions) // 60)):
            r = candidate_regions[i]
            raw_evidence.append({"type": "RECT", "x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"]})

        return surfaces, candidate_regions, raw_evidence

class HybridPhysicalPerceptionProvider:
    """
    Mode C: 混合物理感知 (Hybrid Physical Perception) - 核心重点路线
    视觉多尺度证据 + UI 结构性线索 (Semantic Hint) + 高纹理区域抑制 + Cat-scale 尺度熔接 + 边缘 (Ledge) 标记
    """
    def __init__(self, scale_adapter: CatScaleAdapter, texture_suppressor: TextureSuppressor):
        self.adapter = scale_adapter
        self.texture_suppressor = texture_suppressor

    def extract(self, gray: np.ndarray, ui_elements: Optional[List[Dict[str, Any]]] = None,
                windows: Optional[List[Dict[str, Any]]] = None,
                scale_inv: float = 1.0) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]]]:
        h, w = gray.shape
        if h < 16 or w < 16:
            return [], [], []

        # 1. 边缘与局部对比度
        canny = cv2.Canny(gray, 35, 100)
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 17, 4)
        edges = cv2.bitwise_or(canny, thresh)

        # 2. 纹理密集区域检测 (Texture Dense Regions - 图片/视频/照片)
        texture_boxes = self.texture_suppressor.find_texture_dense_regions(gray, canny)
        image_boxes = visible_image_boxes(ui_elements or [], windows or [], scale_inv)
        texture_boxes.extend(image_boxes)
        for bx, by, bw, bh in image_boxes:
            edges[max(0,int(by)):min(h,int(by+bh)), max(0,int(bx)):min(w,int(bx+bw))] = 0

        # 3. 形态学聚合：深度水平闭运算（依据猫尺度与行间距动态扩展，强力连通文本行单词）
        kw = max(3, min(int(self.adapter.gap_tolerance / scale_inv), self.adapter.morph_kernel_size))
        close_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kw, 3))
        morphed = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, close_kernel)

        # 4. 连通区域分析
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(morphed, connectivity=8)

        candidate_regions = []
        raw_surfaces = []
        min_area = (self.adapter.min_candidate_area / (scale_inv * scale_inv))
        min_p_len = (self.adapter.min_platform_length / scale_inv)
        min_w_len = (self.adapter.min_wall_length / scale_inv)

        for i in range(1, num_labels):
            bx, by, bw, bh, area = stats[i]
            if area < min_area and bw < min_p_len and bh < min_w_len:
                continue

            phys_x = float(bx * scale_inv)
            phys_y = float(by * scale_inv)
            phys_w = float(bw * scale_inv)
            phys_h = float(bh * scale_inv)

            # 纹理区域内部抑制：如果处于纹理密集盒子内部，降低权重并不生成内部碎台阶
            is_inside_texture = self.texture_suppressor.is_inside_texture_box(
                bx, by, bx + bw, by + bh, texture_boxes
            )
            if is_inside_texture:
                continue

            candidate_regions.append({
                "x": phys_x, "y": phys_y, "w": phys_w, "h": phys_h, "area": float(area)
            })

            # Platform 候选
            if bw >= min_p_len:
                conf = 0.70
                # 语义加权 (Semantic Hint): 检查是否重合 UIA 控件或 Window 顶边
                if ui_elements:
                    for u in ui_elements:
                        ux = float(u.get("x", 0.0))
                        uy = float(u.get("y", 0.0))
                        uw = float(u.get("width", 0.0))
                        uh = float(u.get("height", 0.0))
                        if abs(phys_y - uy) <= self.adapter.y_merge_tolerance and not (phys_x + phys_w < ux or phys_x > ux + uw):
                            conf = min(0.98, conf + 0.20) # 语义命中，提升可信度
                            break

                raw_surfaces.append({
                    "id": f"hy_p_{len(raw_surfaces)}",
                    "type": "PLATFORM",
                    "x1": phys_x, "y1": phys_y,
                    "x2": phys_x + phys_w, "y2": phys_y,
                    "confidence": conf,
                    "source": "hybrid"
                })

            # Wall 候选：严格限制为高大立柱或窗体垂直边 (高度 >= min_wall_length 且显著纵向)，杜绝扁平文本行产生虚假侧墙
            if phys_h >= self.adapter.min_wall_length and (phys_h >= phys_w * 0.75 or phys_h >= 60.0):
                raw_surfaces.append({
                    "id": f"hy_w_l_{len(raw_surfaces)}",
                    "type": "WALL", "orientation": "LEFT",
                    "x1": phys_x, "y1": phys_y,
                    "x2": phys_x, "y2": phys_y + phys_h,
                    "confidence": 0.85,
                    "source": "hybrid"
                })
                raw_surfaces.append({
                    "id": f"hy_w_r_{len(raw_surfaces)}",
                    "type": "WALL", "orientation": "RIGHT",
                    "x1": phys_x + phys_w, "y1": phys_y,
                    "x2": phys_x + phys_w, "y2": phys_y + phys_h,
                    "confidence": 0.85,
                    "source": "hybrid"
                })

        # 纹理区域顶边保底：对大块照片/视频，在其外侧顶部注入一条整宽 Platform
        for tx, ty, tw, th in texture_boxes:
            if (tx, ty, tw, th) in image_boxes:
                continue
            phys_tx = float(tx * scale_inv)
            phys_ty = float(ty * scale_inv)
            phys_tw = float(tw * scale_inv)
            phys_th = float(th * scale_inv)
            raw_surfaces.append({
                "id": f"hy_tex_top_{len(raw_surfaces)}",
                "type": "PLATFORM",
                "x1": phys_tx, "y1": phys_ty,
                "x2": phys_tx + phys_tw, "y2": phys_ty,
                "confidence": 0.92,
                "source": "hybrid"
            })

        # UIA 直接提供可解释的物理轮廓，避免密集正文被纹理抑制误删。
        for ui in (ui_elements or []):
            ux = float(ui.get("x", 0.0)); uy = float(ui.get("y", 0.0))
            uw = float(ui.get("width", 0.0)); uh = float(ui.get("height", 0.0))
            control_type = str(ui.get("control_type", ""))
            source_id = str(ui.get("id", len(raw_surfaces)))
            if control_type not in ("Image", "Button", "CheckBox", "RadioButton", "ComboBox"):
                continue  # 仅实体控件提供轮廓；容器留白和文本由像素证据处理。
            if uw >= self.adapter.min_platform_length:
                platform_y = uy
                raw_surfaces.append({
                    "id": f"hy_ui_{source_id}", "type": "PLATFORM",
                    "window_id": ui.get("window_id"),
                    "x1": ux, "y1": platform_y, "x2": ux + uw,
                    "y2": platform_y, "confidence": 0.98,
                    "source": "hybrid_uia"
                })
            if control_type == "Image" and uh >= self.adapter.min_wall_length:
                for side, wall_x in (("l", ux), ("r", ux + uw)):
                    raw_surfaces.append({
                        "id": f"hy_ui_{source_id}_{side}", "type": "WALL",
                        "orientation": "LEFT" if side == "l" else "RIGHT",
                        "window_id": ui.get("window_id"),
                        "x1": wall_x, "y1": uy, "x2": wall_x,
                        "y2": uy + uh, "confidence": 0.96,
                        "source": "hybrid_uia"
                    })

        # 窗口结构作为稳定骨架；其余像素证据负责补足内容内部的平台。
        for window in (windows or []):
            wx = float(window.get("x", 0.0)); wy = float(window.get("y", 0.0))
            ww = float(window.get("width", 0.0)); wh = float(window.get("height", 0.0))
            source_id = str(window.get("id", len(raw_surfaces)))
            if ww >= self.adapter.min_platform_length:
                raw_surfaces.append({
                    "id": f"hy_win_{source_id}", "type": "PLATFORM",
                    "window_id": source_id,
                    "x1": wx, "y1": wy, "x2": wx + ww, "y2": wy,
                    "confidence": 0.97, "source": "hybrid_window"
                })
            if wh >= self.adapter.min_wall_length:
                for side, wall_x in (("l", wx), ("r", wx + ww)):
                    raw_surfaces.append({
                        "id": f"hy_win_{source_id}_{side}", "type": "WALL",
                        "orientation": "LEFT" if side == "l" else "RIGHT",
                        "window_id": source_id,
                        "x1": wall_x, "y1": wy, "x2": wall_x,
                        "y2": wy + wh, "confidence": 0.95,
                        "source": "hybrid_window"
                    })

        raw_surfaces = clip_visible_surfaces(raw_surfaces, windows or [])

        # 5. Cat-scale 连通表面合并（将同高度、小间隙的平台熔合）
        merged_platforms = self._merge_platforms(
            [s for s in raw_surfaces if s["type"] == "PLATFORM"],
            self.adapter.y_merge_tolerance,
            self.adapter.gap_tolerance
        )

        walls = [s for s in raw_surfaces if s["type"] == "WALL"]
        final_candidates = merged_platforms + walls

        # 6. Ledge（边缘/悬挂抓边点）推导
        ledges = self._extract_ledges(merged_platforms, walls)
        final_candidates.extend(ledges)

        # 构造 Merged Regions 用于 Mode 4
        merged_regions = [{"x": p["x1"], "y": p["y1"] - 4.0, "w": p["x2"] - p["x1"], "h": 8.0} for p in merged_platforms]

        return final_candidates, candidate_regions, merged_regions

    def _merge_platforms(self, platforms: List[Dict[str, Any]], y_tol: float, gap_tol: float) -> List[Dict[str, Any]]:
        if not platforms:
            return []
        # 按 y 排序
        platforms.sort(key=lambda p: (p["y1"], p["x1"]))
        merged = []
        for p in platforms:
            px1, py, px2 = p["x1"], p["y1"], p["x2"]
            p_conf = p.get("confidence", 0.7)
            fused = False
            for m in merged:
                if p.get("window_id") == m.get("window_id") and abs(py - m["y1"]) <= y_tol:
                    # 检查横向重叠或相邻 (间隙 <= gap_tol)
                    if not (px2 < m["x1"] - gap_tol or px1 > m["x2"] + gap_tol):
                        m["x1"] = min(m["x1"], px1)
                        m["x2"] = max(m["x2"], px2)
                        m["confidence"] = max(m["confidence"], p_conf)
                        fused = True
                        break
            if not fused:
                merged.append(dict(p))

        # 过滤过短平台
        return [m for m in merged if (m["x2"] - m["x1"]) >= self.adapter.min_platform_length]

    def _extract_ledges(self, platforms: List[Dict[str, Any]], walls: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        ledges = []
        for p in platforms:
            p_len = abs(p["x2"] - p["x1"])
            # 只有具有充分物理站立空间的合法长平台 (>= 48px) 才生成抓边转角 Ledge
            if p_len >= 48.0:
                ledges.append({
                    "id": f"ledge_l_{len(ledges)}",
                    "type": "LEDGE",
                    "side": "LEFT",
                    "x1": p["x1"], "y1": p["y1"],
                    "x2": p["x1"] + 12.0, "y2": p["y1"],
                    "confidence": p.get("confidence", 0.7),
                    "source": "hybrid"
                })
                ledges.append({
                    "id": f"ledge_r_{len(ledges)}",
                    "type": "LEDGE",
                    "side": "RIGHT",
                    "x1": p["x2"] - 12.0, "y1": p["y1"],
                    "x2": p["x2"], "y2": p["y1"],
                    "confidence": p.get("confidence", 0.7),
                    "source": "hybrid"
                })
        return ledges

class ScreenPhysicsCompiler:
    """
    屏幕物理编译器总入口：
    托管 Legacy、OpenCV、Hybrid 三路流水线，
    执行时序滤波、收集量化指标、产出多模式数据与 7 种 Debug 视图图层。
    """
    def __init__(self, cat_scale: float = 1.0, foot_width: float = 36.0, cat_width: float = 70.0, cat_height: float = 64.0):
        self.scale_adapter = CatScaleAdapter(cat_scale, foot_width, cat_width, cat_height)
        self.texture_suppressor = TextureSuppressor()
        # 视觉候选需连续两次观察；UIA/窗口结构可以立即确认。
        self.temporal_filter_hybrid = TemporalFilter(confirm_frames=2, max_grace_frames=3, match_dist=14.0)
        self.temporal_filter_opencv = TemporalFilter(confirm_frames=2, max_grace_frames=2, match_dist=16.0)

        self.legacy_provider = LegacyPerceptionProvider()
        self.opencv_provider = OpenCVPerceptionProvider(self.scale_adapter)
        self.hybrid_provider = HybridPhysicalPerceptionProvider(self.scale_adapter, self.texture_suppressor)

        self.current_mode: str = "hybrid" # "legacy" | "opencv" | "hybrid"
        self.frame_index: int = 0

    def update_cat_metrics(self, cat_scale: float, foot_width: float, cat_width: float, cat_height: float):
        self.scale_adapter.update_metrics(cat_scale, foot_width, cat_width, cat_height)

    def set_perception_mode(self, mode: str):
        if mode in ["legacy", "opencv", "hybrid"]:
            self.current_mode = mode

    def compile(self, gray: np.ndarray, ui_elements: Optional[List[Dict[str, Any]]] = None,
                windows: Optional[List[Dict[str, Any]]] = None,
                scale_inv: float = 1.0, reuse_extraction: bool = False,
                now: Optional[float] = None) -> Dict[str, Any]:
        """
        核心编译函数：
        输入屏幕灰度图像、UI/Window 语义线索，
        输出三路模式表面、Debug 阶段数据与量化指标。
        """
        t_start = time.perf_counter()
        self.frame_index += 1

        h, w = gray.shape

        # --- A. Legacy Baseline ---
        t_leg_start = time.perf_counter()
        if not reuse_extraction:
            self._legacy_candidates = self.legacy_provider.extract(gray, scale_inv)
        leg_surfaces, leg_raw_ev = self._legacy_candidates
        t_leg_end = time.perf_counter()

        # --- B. OpenCV Visual ---
        t_cv_start = time.perf_counter()
        if not reuse_extraction:
            self._cv_candidates = self.opencv_provider.extract(gray, scale_inv)
        cv_surfaces, cv_candidates, cv_raw_ev = self._cv_candidates
        cv_stable, cv_jitter = self.temporal_filter_opencv.update(cv_surfaces, now)
        t_cv_end = time.perf_counter()

        # --- C. Hybrid Physical ---
        t_hy_start = time.perf_counter()
        if not reuse_extraction:
            self._hy_candidates = self.hybrid_provider.extract(gray, ui_elements, windows, scale_inv)
        hy_surfaces, hy_candidates, hy_merged_regions = self._hy_candidates
        hy_stable, hy_jitter = self.temporal_filter_hybrid.update(hy_surfaces, now)
        t_hy_end = time.perf_counter()

        t_total_end = time.perf_counter()

        # 计算碎片率指标 (Fragmentation)：仅统计 PLATFORM 踏板中长度 < 48px 的碎片段
        leg_frag = sum(1 for s in leg_surfaces if s.get("type") == "PLATFORM" and math.hypot(s["x2"] - s["x1"], s["y2"] - s["y1"]) < 48.0)
        cv_frag = sum(1 for s in cv_stable if s.get("type") == "PLATFORM" and math.hypot(s["x2"] - s["x1"], s["y2"] - s["y1"]) < 48.0)
        hy_frag = sum(1 for s in hy_stable if s.get("type") == "PLATFORM" and math.hypot(s["x2"] - s["x1"], s["y2"] - s["y1"]) < 48.0)

        # 平均表面长度
        def calc_avg_len(surfs):
            if not surfs: return 0.0
            return sum(math.hypot(s["x2"] - s["x1"], s["y2"] - s["y1"]) for s in surfs) / len(surfs)

        leg_avg_len = calc_avg_len(leg_surfaces)
        cv_avg_len = calc_avg_len(cv_stable)
        hy_avg_len = calc_avg_len(hy_stable)

        # 压缩比 = 原始候选块数 / 最终稳定表面数
        hy_cand_count = max(1, len(hy_candidates))
        hy_reduction_ratio = hy_cand_count / max(1, len(hy_stable))

        timing_metrics = {
            "cv_ms": round((t_cv_end - t_cv_start) * 1000.0, 2),
            "hybrid_ms": round((t_hy_end - t_hy_start) * 1000.0, 2),
            "legacy_ms": round((t_leg_end - t_leg_start) * 1000.0, 2),
            "total_ms": round((t_total_end - t_start) * 1000.0, 2)
        }

        # 整合量化指标
        metrics = {
            "frame": self.frame_index,
            "current_mode": self.current_mode,
            "timing": timing_metrics,
            "cat_scale": self.scale_adapter.to_dict(),
            "legacy": {
                "final_surface_count": len(leg_surfaces),
                "fragmentation_count": leg_frag,
                "average_surface_length": round(leg_avg_len, 1)
            },
            "opencv": {
                "candidate_region_count": len(cv_candidates),
                "final_surface_count": len(cv_surfaces),
                "stable_surface_count": len(cv_stable),
                "fragmentation_count": cv_frag,
                "temporal_jitter": cv_jitter["total_jitter"],
                "average_surface_length": round(cv_avg_len, 1)
            },
            "hybrid": {
                "candidate_region_count": len(hy_candidates),
                "final_surface_count": len(hy_surfaces),
                "stable_surface_count": len(hy_stable),
                "fragmentation_count": hy_frag,
                "temporal_jitter": hy_jitter["total_jitter"],
                "reduction_ratio": round(hy_reduction_ratio, 2),
                "average_surface_length": round(hy_avg_len, 1)
            }
        }

        # 封装调试图层 (Debug Overlay Modes 1~6)
        debug_layers = {
            "raw_evidence": hy_candidates[:80], # Mode 2
            "candidates": hy_candidates,        # Mode 3
            "merged_regions": hy_merged_regions,# Mode 4
            "stable_regions": [
                {"x": s["x1"], "y": s["y1"] - 3.0, "w": max(4.0, abs(s["x2"] - s["x1"])), "h": 6.0}
                for s in hy_stable if s["type"] == "PLATFORM"
            ],                                  # Mode 5
            "final_surfaces": hy_stable         # Mode 6
        }

        return {
            "v": 1,
            "type": "t25_perception_snapshot",
            "revision": self.frame_index,
            "mode": self.current_mode,
            "surfaces": {
                "legacy": leg_surfaces,
                "opencv": cv_stable,
                "hybrid": hy_stable
            },
            "debug_layers": debug_layers,
            "metrics": metrics
        }

class ScreenPhysicsCompilerService:
    """
    T25 屏幕物理编译器守护服务：
    负责持续抓取屏幕、驱动 ScreenPhysicsCompiler 执行三路感知，
    并通过 TCP 将 t25_perception_snapshot 实时推送给 Godot 客户端。
    """
    def __init__(self, host: str = "127.0.0.1", port: int = 47831,
                 context_provider=None):
        self.host = host
        self.port = port
        self.compiler = ScreenPhysicsCompiler()
        self.sock: Optional[socket.socket] = None
        self.reader = None
        self.is_running = False
        self.context_provider = context_provider
        self.session_id = str(time.time_ns())
        self.debug_window_visible = False
        self.work_area = {"screen": 0, "x": 0, "y": 0,
                          "width": 1920, "height": 1080}
        self._last_frame = None
        self._last_context = None
        self._last_area = None

    def reset_tracking(self):
        self.compiler.temporal_filter_hybrid.reset()
        self.compiler.temporal_filter_opencv.reset()
        self._last_frame = None
        self._last_context = None
        self._last_area = None

    def connect(self) -> bool:
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.settimeout(2.0)
            self.sock.connect((self.host, self.port))
            self.reader = self.sock.makefile("r", encoding="utf-8")
            hello = json.loads(self.reader.readline().strip())
            screen = hello.get("screen", {})
            if screen:
                self.work_area = {
                    "screen": int(screen.get("index", 0)),
                    "x": int(screen.get("x", 0)),
                    "y": int(screen.get("y", 0)),
                    "width": int(screen.get("width", 1920)),
                    "height": int(screen.get("height", 1080)),
                }
            self.reset_tracking()
            return True
        except Exception:
            try:
                if self.reader: self.reader.close()
                if self.sock: self.sock.close()
            except Exception:
                pass
            self.sock = None
            self.reader = None
            return False

    def compile_work_area_if_changed(self, gray: np.ndarray,
                                     work_area: Dict[str, Any],
                                     ui_elements=None, windows=None,
                                     scale_inv: float = 1.0, now: Optional[float] = None):
        h, w = gray.shape
        area_key = (work_area.get("screen", 0), work_area.get("x", 0),
                    work_area.get("y", 0), work_area.get("width", w), work_area.get("height", h))
        if self._last_area is not None and self._last_area != area_key:
            self.reset_tracking()
        context = json.dumps([ui_elements or [], windows or [], scale_inv,
                              self.compiler.scale_adapter.to_dict()], sort_keys=True)
        unchanged = (self._last_area == area_key and self._last_context == context
                     and self._last_frame is not None and np.array_equal(gray, self._last_frame))
        offset_x = float(work_area.get("x", 0))
        offset_y = float(work_area.get("y", 0))
        local_ui = [dict(item, x=float(item.get("x", 0)) - offset_x,
                         y=float(item.get("y", 0)) - offset_y)
                    for item in (ui_elements or [])]
        local_windows = [dict(item, x=float(item.get("x", 0)) - offset_x,
                              y=float(item.get("y", 0)) - offset_y)
                         for item in (windows or [])]
        snapshot = self.compiler.compile(gray, local_ui, local_windows,
                                         scale_inv=scale_inv, reuse_extraction=unchanged, now=now)
        # 与 SurfaceFusionBuilder.MAX_SURFACES 保持一致，只传物理世界消费的当前模式。
        area_width = float(work_area.get("width", w * scale_inv))
        area_height = float(work_area.get("height", h * scale_inv))
        active = []
        for surface in snapshot["surfaces"][snapshot["mode"]]:
            if surface["type"] not in ("PLATFORM", "WALL"):
                continue
            x1, y1 = float(surface["x1"]), float(surface["y1"])
            x2, y2 = float(surface["x2"]), float(surface["y2"])
            duplicates_top = (surface["type"] == "PLATFORM" and
                              y1 == y2 == 0.0 and min(x1, x2) == 0.0 and
                              max(x1, x2) == area_width)
            duplicates_side = (surface["type"] == "WALL" and
                               x1 == x2 and x1 in (0.0, area_width) and
                               min(y1, y2) == 0.0 and max(y1, y2) == area_height)
            if not duplicates_top and not duplicates_side:
                active.append(surface)
        active.sort(key=lambda surface: math.hypot(surface["x2"] - surface["x1"],
                                                  surface["y2"] - surface["y1"]), reverse=True)
        snapshot["surfaces"] = {snapshot["mode"]: active[:1024]}
        del snapshot["debug_layers"]  # 完整阶段数据仍由本地 compile / 评估工具提供。
        snapshot["work_area"] = dict(work_area)
        snapshot["session_id"] = self.session_id
        if self.debug_window_visible:
            # 预览按整个消息剩余预算缩小，不增加 Bridge 的消息大小限制。
            remaining = 250000 - len(json.dumps(snapshot, ensure_ascii=False).encode("utf-8")) - 256
            preview_width = min(480, w)
            preview = cv2.resize(gray, (preview_width, max(1, round(h * preview_width / w))))
            ok, encoded = cv2.imencode(".png", preview)
            if not ok:
                raise RuntimeError("调试截图 PNG 编码失败")
            while len(encoded) * 4 / 3 > remaining and preview_width > 32:
                preview_width //= 2
                preview = cv2.resize(gray, (preview_width, max(1, round(h * preview_width / w))))
                ok, encoded = cv2.imencode(".png", preview)
                if not ok:
                    raise RuntimeError("调试截图 PNG 编码失败")
            snapshot["debug_preview"] = {"png_base64": base64.b64encode(encoded).decode("ascii"),
                                         "width": work_area["width"], "height": work_area["height"]}
        self._last_frame = gray.copy()
        self._last_context = context
        self._last_area = area_key
        return snapshot

    def send_snapshot(self, snapshot: Dict[str, Any]) -> bool:
        if not self.sock:
            if not self.connect():
                return False
        try:
            payload = json.dumps(snapshot, ensure_ascii=False, separators=(",", ":")) + "\n"
            self.sock.sendall(payload.encode("utf-8"))
            return True
        except Exception:
            try:
                if self.reader: self.reader.close()
                if self.sock: self.sock.close()
            except Exception: pass
            self.sock = None
            self.reader = None
            return False

    def run(self):
        from tools.perception.screen_capture import capture_bgra

        self.is_running = True
        print(f"[PhysicsCompilerService] T25 屏幕物理编译器服务启动 (TCP -> {self.host}:{self.port})")
        analysis_scale = 0.5
        scale_inv = 1.0 / analysis_scale
        last_status_at = 0.0

        try:
            while self.is_running:
                t0 = time.perf_counter()
                if not self.sock and not self.connect():
                    time.sleep(1.0)
                    continue
                if t0 - last_status_at >= 1.0:
                    last_status_at = t0
                    try:
                        self.sock.sendall(b'{"v":1,"type":"get_status"}\n')
                        for _ in range(12):
                            response = json.loads(self.reader.readline().strip())
                            if response.get("type") == "status":
                                self.debug_window_visible = response.get("debug_window_visible", False)
                                self.compiler.set_perception_mode(response.get("perception_mode", "hybrid"))
                                metrics = response.get("cat_metrics")
                                if metrics:
                                    self.compiler.update_cat_metrics(**metrics)
                                screen = response.get("screen", {})
                                self.work_area = {
                                    "screen": int(screen.get("index", 0)),
                                    "x": int(screen.get("x", 0)),
                                    "y": int(screen.get("y", 0)),
                                    "width": int(screen.get("width", 1920)),
                                    "height": int(screen.get("height", 1080)),
                                }
                                break
                    except Exception:
                        try:
                            if self.reader: self.reader.close()
                            if self.sock: self.sock.close()
                        except Exception:
                            pass
                        self.sock = None
                        self.reader = None
                        continue

                area = dict(self.work_area)
                sx, sy = int(area["x"]), int(area["y"])
                sw, sh = int(area["width"]), int(area["height"])
                dw = max(16, int(sw * analysis_scale))
                dh = max(16, int(sh * analysis_scale))
                buf = capture_bgra(sx, sy, sw, sh, dw, dh)
                arr = np.frombuffer(buf, dtype=np.uint8).reshape((dh, dw, 4))
                gray = ((arr[:, :, 0].astype(np.uint16) * 29 +
                         arr[:, :, 1].astype(np.uint16) * 150 +
                         arr[:, :, 2].astype(np.uint16) * 77) >> 8).astype(np.uint8)

                ui_elements, windows = (self.context_provider(area)
                                        if self.context_provider else ([], []))
                snapshot = self.compile_work_area_if_changed(
                    gray, area, ui_elements, windows, scale_inv)
                if snapshot is not None:
                    self.send_snapshot(snapshot)
                time.sleep(max(0.02, 0.20 - (time.perf_counter() - t0)))
        finally:
            if self.reader: self.reader.close()
            if self.sock: self.sock.close()
