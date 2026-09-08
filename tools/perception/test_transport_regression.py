import json
import unittest
from unittest.mock import patch

import numpy as np

from tools.perception.cat_physics_compiler import ScreenPhysicsCompilerService


class TestTransportRegression(unittest.TestCase):
    def test_screen_edges_are_not_sent_as_t25_surfaces(self):
        service = ScreenPhysicsCompilerService()
        surfaces = [
            dict(id='screen_top', type='PLATFORM', x1=0, y1=0, x2=800, y2=0),
            dict(id='screen_left', type='WALL', x1=0, y1=0, x2=0, y2=600),
            dict(id='screen_right', type='WALL', x1=800, y1=0, x2=800, y2=600),
            dict(id='window_top', type='PLATFORM', x1=100, y1=80, x2=700, y2=80),
            dict(id='window_left', type='WALL', x1=100, y1=80, x2=100, y2=500),
        ]
        compiled = dict(mode='hybrid', surfaces={'hybrid': surfaces}, debug_layers={})
        with patch.object(service.compiler, 'compile', return_value=compiled):
            packet = service.compile_work_area_if_changed(
                np.full((300, 400), 245, np.uint8),
                dict(screen=0, x=0, y=0, width=800, height=600), scale_inv=2)
        self.assertEqual(
            [surface['id'] for surface in packet['surfaces']['hybrid']],
            ['window_top', 'window_left'])

    def test_dense_platforms_do_not_evict_long_walls(self):
        service = ScreenPhysicsCompilerService()
        surfaces = [dict(id=f'p{i}', type='PLATFORM', x1=0, y1=i, x2=40, y2=i)
                    for i in range(1024)]
        surfaces.append(dict(id='wall', type='WALL', orientation='RIGHT',
                             x1=100, y1=0, x2=100, y2=800))
        compiled = dict(mode='hybrid', surfaces={'hybrid': surfaces}, debug_layers={})
        with patch.object(service.compiler, 'compile', return_value=compiled):
            packet = service.compile_work_area_if_changed(
                np.full((100, 100), 245, np.uint8),
                dict(screen=0, x=0, y=0, width=100, height=100))
        active = packet['surfaces']['hybrid']
        self.assertEqual(len(active), 1024)
        self.assertEqual(active[0]['id'], 'wall')

    def test_dense_4k_text_static_packet_fits_bridge(self):
        gray = np.full((1080, 1920), 245, np.uint8)
        for row in range(74):
            for column in range(12):
                y, x = 10 + row * 14, 10 + column * 155
                gray[y:y + 7, x:x + 120:2] = 20
        service = ScreenPhysicsCompilerService()
        service.debug_window_visible = True
        area = dict(screen=0, x=0, y=0, width=3840, height=2160)
        service.compile_work_area_if_changed(gray, area, scale_inv=2, now=0)
        for mode in ('hybrid', 'opencv', 'legacy'):
            service.compiler.set_perception_mode(mode)
            packet = service.compile_work_area_if_changed(gray, area, scale_inv=2, now=.2)
            size = len((json.dumps(packet, ensure_ascii=False) + '\n').encode('utf-8'))
            self.assertLess(size, 256 * 1024, (mode, size))
            self.assertEqual(set(packet['surfaces']), {mode})
            self.assertNotIn('debug_layers', packet)
            surfaces = packet['surfaces'][mode]
            self.assertTrue(surfaces)
            self.assertLessEqual(len(surfaces), 1024)
            self.assertTrue(all(s['type'] in ('PLATFORM', 'WALL') for s in surfaces))
        full = service.compiler.compile(gray, scale_inv=2, now=.4)
        self.assertEqual(set(full['surfaces']), {'legacy', 'opencv', 'hybrid'})
        self.assertIn('debug_layers', full)

    def test_blank_semantic_containers_do_not_make_air_platforms(self):
        gray = np.full((240, 400), 245, np.uint8)
        area = dict(screen=0, x=0, y=0, width=400, height=240)
        windows = [dict(id='owner', x=0, y=0, width=400, height=240, z_order=0)]
        for control_type in ('Group', 'Pane', 'Other', 'Custom'):
            service = ScreenPhysicsCompilerService()
            elements = [dict(id='container', window_id='owner', control_type=control_type,
                             x=80, y=70, width=200, height=80)]
            packet = service.compile_work_area_if_changed(gray, area, elements, windows, now=0)
            air = [s for s in packet['surfaces']['hybrid'] if s.get('source') == 'hybrid_uia']
            self.assertFalse(air, control_type)
