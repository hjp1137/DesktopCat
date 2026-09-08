"""按顶层窗口 Z 序裁剪结构线段；屏幕像素候选已是可见结果。"""

def clip_visible_surfaces(surfaces, windows):
    ordered = sorted(windows, key=lambda w: w.get('z_order', 0))
    result = []
    for surface in surfaces:
        owner = surface.get('window_id')
        if not owner:
            result.append(surface)
            continue
        owner_index = next((i for i, w in enumerate(ordered) if w['id'] == owner), None)
        if owner_index is None:
            continue  # 已关闭或不在当前工作区的窗口语义不能生成平台。
        pieces = [surface]
        for window in ordered[:owner_index]:
            wx, wy = window['x'], window['y']
            right, bottom = wx + window['width'], wy + window['height']
            visible = []
            for piece in pieces:
                horizontal = piece['type'] == 'PLATFORM'
                fixed = piece['y1'] if horizontal else piece['x1']
                low, high = (wy, bottom) if horizontal else (wx, right)
                if not low <= fixed < high:
                    visible.append(piece)
                    continue
                start, end = (piece['x1'], piece['x2']) if horizontal else (piece['y1'], piece['y2'])
                cut_start, cut_end = (wx, right) if horizontal else (wy, bottom)
                if cut_end <= start or cut_start >= end:
                    visible.append(piece)
                    continue
                for a, b in ((start, min(end, cut_start)), (max(start, cut_end), end)):
                    if b <= a:
                        continue
                    part = dict(piece)
                    axis = 'x' if horizontal else 'y'
                    part[axis+'1'], part[axis+'2'] = a, b
                    visible.append(part)
            pieces = visible
        result.extend(pieces)
    return result


def visible_image_boxes(elements, windows, scale_inv):
    ordered = sorted(windows, key=lambda w: w.get('z_order', 0))
    result = []
    for element in elements:
        if element.get('control_type') != 'Image':
            continue
        rectangles = [(element['x'],element['y'],element['width'],element['height'])]
        owner = element.get('window_id')
        index = next((i for i,w in enumerate(ordered) if w['id']==owner), None)
        if owner and index is None:
            continue
        for window in ordered[:index] if index is not None else []:
            visible = []
            for x,y,w,h in rectangles:
                left,top = max(x,window['x']),max(y,window['y'])
                right,bottom = min(x+w,window['x']+window['width']),min(y+h,window['y']+window['height'])
                if right<=left or bottom<=top:
                    visible.append((x,y,w,h))
                    continue
                for box in ((x,y,w,top-y),(x,bottom,w,y+h-bottom),
                            (x,top,left-x,bottom-top),(right,top,x+w-right,bottom-top)):
                    if box[2]>0 and box[3]>0:
                        visible.append(box)
            rectangles = visible
        result.extend(tuple(value/scale_inv for value in box) for box in rectangles)
    return result
