"""真实 Windows 测试窗口；滚轮滚动，+ 放大，D 删除文字，O 遮挡。"""
import tkinter as tk
import ctypes
import sys
import json
from pathlib import Path
import tempfile

ctypes.windll.user32.SetProcessDPIAware()

root = tk.Tk()
root.tk.call("tk", "scaling", 1.0)
root.title("Cat Gym Acceptance Fixture")
root.geometry(sys.argv[1] if len(sys.argv) > 1 else "900x680+40+50")
canvas = tk.Canvas(root, bg="#f8f6ee", highlightthickness=0)
canvas.pack(fill="both", expand=True)
offset = 0
size = 22
deleted = False
occluder = None


def draw():
    canvas.delete("all")
    canvas.create_text(35, 25, anchor="nw", text="Desktop geometry acceptance", font=("Arial", 25))
    canvas.create_text(35, 75, anchor="nw", text="Wheel: scroll   +: zoom   D: delete text   O: overlap", font=("Arial", 14))
    if not deleted:
        for i, text in enumerate(("Cats can stand on visible words", "Whitespace must stay empty", "Scrolling moves every foothold")):
            canvas.create_text(55, 150 + i * 90 - offset, anchor="nw", text=text, font=("Arial", size))
    canvas.create_rectangle(570, 140 - offset, 820, 470 - offset, fill="#41778b", outline="#243740", width=3)
    canvas.create_oval(620, 220 - offset, 770, 360 - offset, fill="#c9e5ca", outline="")
    canvas.create_polygon(620, 250 - offset, 635, 190 - offset, 675, 230 - offset, fill="#c9e5ca")
    canvas.create_polygon(720, 230 - offset, 760, 190 - offset, 770, 250 - offset, fill="#c9e5ca")
    canvas.create_line(50, 520 - offset, 835, 520 - offset, fill="#333333", width=3)
    root.after(100, record_state)


def record_state():
    """记录真实 Tk 布局真值，供验收截图对应；不参与感知服务。"""
    state = dict(offset=offset, font_size=size, deleted=deleted,
                 origin=[canvas.winfo_rootx(), canvas.winfo_rooty()],
                 text_boxes=[canvas.bbox(item) for item in canvas.find_all()
                             if canvas.type(item) == "text"],
                 occluded=occluder is not None)
    (Path(tempfile.gettempdir()) / "DesktopCat-fixture-state.json").write_text(
        json.dumps(state), encoding="utf-8")


def scroll(event):
    global offset
    offset += 60 if event.delta < 0 else -60
    draw()


def key(event):
    global size, deleted, occluder
    if event.char in ("+", "="):
        size += 6
    elif event.char.lower() == "d":
        deleted = not deleted
    elif event.char.lower() == "o":
        if occluder is None:
            occluder = tk.Toplevel(root)
            occluder.title("Acceptance occluder")
            occluder.geometry("330x300+510+230")
            tk.Label(occluder, text="Foreground occlusion", bg="#eed9b2").pack(fill="both", expand=True)
        else:
            occluder.destroy()
            occluder = None
    draw()


root.bind("<MouseWheel>", scroll)
root.bind("<Key>", key)
draw()
root.mainloop()
