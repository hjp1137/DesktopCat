import unittest
from unittest.mock import patch
import numpy as np
from tools.perception.cat_physics_compiler import TemporalFilter, ScreenPhysicsCompilerService, HybridPhysicalPerceptionProvider, CatScaleAdapter, TextureSuppressor

class TestPerceptionLifecycle(unittest.TestCase):
    def test_large_cat_keeps_three_real_tk_text_rows(self):
        import cv2
        from pathlib import Path
        gray = cv2.imread(str(Path(__file__).parent / 'fixtures/large_cat_text.png'), 0)
        provider = HybridPhysicalPerceptionProvider(
            CatScaleAdapter(2.813, 148, 148, 135), TextureSuppressor())
        surfaces, _, _ = provider.extract(gray, scale_inv=2)
        platforms = [s for s in surfaces if s['type'] == 'PLATFORM'
                     and s['x1'] < 400 and 200 < s['y1'] < 450]
        self.assertEqual(len(platforms), 3)
        for expected in (216, 306, 396):
            self.assertTrue(any(abs(s['y1'] - expected) <= 2 for s in platforms))

    def test_first_observation_is_not_missing(self):
        tracker = TemporalFilter(confirm_frames=1)
        surfaces, _ = tracker.update([dict(type='PLATFORM', x1=10, y1=30, x2=150, y2=30, confidence=.7)])
        self.assertEqual(len(surfaces), 1)
        self.assertEqual(next(iter(tracker.tracked_surfaces.values()))['missing_count'], 0)

    def test_static_confirmation_expiry_and_small_pixel_change(self):
        service = ScreenPhysicsCompilerService()
        area = dict(screen=0, x=0, y=0, width=400, height=200)
        gray = np.full((200, 400), 245, np.uint8)
        gray[40:52, 30:190:2] = 20
        with patch.object(service.compiler.hybrid_provider, 'extract', wraps=service.compiler.hybrid_provider.extract) as extract:
            service.compile_work_area_if_changed(gray, area, now=0)
            stable = service.compile_work_area_if_changed(gray, area, now=.2)
            self.assertTrue(stable['surfaces']['hybrid'])
            self.assertEqual(extract.call_count, 1)
            blank = np.full_like(gray, 245)
            service.compile_work_area_if_changed(blank, area, now=.4)
            expired = service.compile_work_area_if_changed(blank, area, now=1.1)
            self.assertFalse(expired['surfaces']['hybrid'])
            blank[101, 101] = 244
            service.compile_work_area_if_changed(blank, area, now=1.3)
            self.assertEqual(extract.call_count, 3)

    def test_text_has_no_container_platform_and_image_has_two_sides(self):
        provider = HybridPhysicalPerceptionProvider(CatScaleAdapter(), TextureSuppressor())
        gray = np.full((200, 400), 245, np.uint8)
        gray[40:52, 30:190:2] = 20
        elements = [dict(id='text', control_type='Text', x=20, y=30, width=180, height=70),
                    dict(id='image', control_type='Image', x=240, y=40, width=100, height=100)]
        surfaces, _, _ = provider.extract(gray, elements)
        text = [s for s in surfaces if s['type']=='PLATFORM' and s['x1']<200]
        self.assertEqual(len(text), 1)
        self.assertLessEqual(abs(text[0]['y1']-40), 2)
        walls = [s for s in surfaces if s['type']=='WALL' and s['source']=='hybrid_uia']
        self.assertEqual({s['orientation'] for s in walls}, {'LEFT', 'RIGHT'})

    def test_occluded_window_top_is_split(self):
        provider = HybridPhysicalPerceptionProvider(CatScaleAdapter(), TextureSuppressor())
        windows = [dict(id='front', x=100,y=20,width=100,height=150,z_order=0),
                   dict(id='back', x=20,y=60,width=300,height=100,z_order=1)]
        surfaces, _, _ = provider.extract(np.full((240,400),245,np.uint8), windows=windows)
        tops = [s for s in surfaces if s['type']=='PLATFORM' and s['y1']==60]
        self.assertEqual([(s['x1'],s['x2']) for s in tops], [(20,100),(200,320)])

    def test_article_body_keeps_all_twelve_visible_rows_at_half_scale(self):
        import cv2
        from tools.evaluate_real_desktop_perception import create_real_article_page_bgr
        image = cv2.cvtColor(create_real_article_page_bgr(), cv2.COLOR_BGR2GRAY)
        gray = cv2.resize(image, (640, 400), interpolation=cv2.INTER_AREA)
        provider = HybridPhysicalPerceptionProvider(CatScaleAdapter(), TextureSuppressor())
        surfaces, _, _ = provider.extract(gray, scale_inv=2)
        platforms = [s for s in surfaces if s['type']=='PLATFORM' and 180<=s['y1']<=510]
        expected = [185 + paragraph*88 + line*24 for paragraph in range(4) for line in range(3)]
        self.assertEqual(len(platforms), 12)
        for y in expected:
            self.assertTrue(any(abs(s['y1']-y)<=2 and s['x2']-s['x1']>600 for s in platforms), y)

    def test_slow_motion_keeps_identity_and_single_frame_noise_does_not_confirm(self):
        tracker = TemporalFilter(confirm_frames=2)
        def platform(x):
            return dict(type='PLATFORM', x1=x,y1=50,x2=x+150,y2=50,confidence=.7)
        self.assertFalse(tracker.update([platform(10)], now=0)[0])
        stable = tracker.update([platform(12)], now=.2)[0]
        identity = stable[0]['id']
        for i in range(2,10):
            result = tracker.update([platform(10+i*2)], now=i*.2)[0]
            self.assertEqual(result[0]['id'], identity)
            self.assertLess(abs(result[0]['x1']-(10+i*2)), 2)
        tracker.reset()
        tracker.update([platform(10)], now=3)
        self.assertFalse(tracker.update([], now=3.2)[0])

    def test_reset_and_screen_change_do_not_retain_old_surfaces(self):
        service = ScreenPhysicsCompilerService()
        gray = np.full((120,240),245,np.uint8)
        area = dict(screen=0,x=0,y=0,width=240,height=120)
        image = [dict(id='image',control_type='Image',x=20,y=20,width=100,height=70)]
        self.assertTrue(service.compile_work_area_if_changed(gray,area,image,now=0)['surfaces']['hybrid'])
        service.reset_tracking()
        self.assertFalse(service.compile_work_area_if_changed(gray,area,now=.2)['surfaces']['hybrid'])
        service.compile_work_area_if_changed(gray,area,image,now=.4)
        switched = service.compile_work_area_if_changed(gray,dict(area,screen=1),now=.5)
        self.assertFalse(switched['surfaces']['hybrid'])

    def test_image_texture_does_not_make_interior_steps(self):
        provider = HybridPhysicalPerceptionProvider(CatScaleAdapter(),TextureSuppressor())
        gray = np.full((240,400),245,np.uint8)
        gray[50:190,40:240] = np.random.default_rng(12).integers(0,255,(140,200),dtype=np.uint8)
        image = [dict(id='image',control_type='Image',x=40,y=50,width=200,height=140)]
        surfaces,_,_ = provider.extract(gray,image)
        self.assertFalse([s for s in surfaces if s['type']=='PLATFORM' and 56<s['y1']<184 and 40<=s['x1']<240])

    def test_occluded_image_mask_does_not_erase_foreground_text(self):
        from tools.perception.surface_visibility import visible_image_boxes
        windows = [dict(id='front',x=80,y=0,width=100,height=200,z_order=0),
                   dict(id='back',x=0,y=0,width=300,height=220,z_order=1)]
        images = [dict(control_type='Image',window_id='back',x=20,y=40,width=240,height=100)]
        self.assertEqual(visible_image_boxes(images,windows,1),[(20,40,60,100),(180,40,80,100)])

    def test_noisy_preview_packet_fits_existing_bridge_limit(self):
        import json
        service = ScreenPhysicsCompilerService()
        service.debug_window_visible = True
        gray = np.random.default_rng(42).integers(0,256,(540,960),dtype=np.uint8)
        area = dict(screen=0,x=0,y=0,width=1920,height=1080)
        snapshot = service.compile_work_area_if_changed(gray,area,scale_inv=2)
        self.assertLess(len((json.dumps(snapshot,ensure_ascii=False)+'\n').encode('utf-8')),256*1024)
