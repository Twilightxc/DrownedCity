"""Draw a mock game HUD over the rendered scene."""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC, DST = sys.argv[1], sys.argv[2]
F = "/usr/share/fonts/opentype/inter/"
def font(w, s): return ImageFont.truetype(F + f"Inter-{w}.otf", s)
fB, fSB, fM, fR = font("Bold", 22), font("SemiBold", 17), font("Medium", 15), font("Regular", 14)
fBig = font("ExtraBold", 30)

base = Image.open(SRC).convert("RGBA")
W, H = base.size
ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
d = ImageDraw.Draw(ov)

PANEL = (18, 24, 28, 200)
EDGE = (255, 255, 255, 28)
TXT = (240, 236, 228, 255)
MUTED = (170, 178, 180, 255)
ACC = (125, 255, 176, 255)
WARN = (255, 138, 72, 255)

def panel(xy, r=14, fill=PANEL):
    d.rounded_rectangle(xy, r, fill=fill, outline=EDGE, width=1)

def bar(x, y, w, h, v, col):
    d.rounded_rectangle((x, y, x + w, y + h), h // 2, fill=(255, 255, 255, 30))
    d.rounded_rectangle((x, y, x + max(h, int(w * v)), y + h), h // 2, fill=col)

def icon(x, y, kind, col, s=18):
    """Tiny geometric resource icons (no external art)."""
    if kind == "food":
        d.ellipse((x, y + 3, x + s, y + s + 1), fill=col); d.rectangle((x + s/2 - 1, y, x + s/2 + 1, y + 5), fill=(90, 160, 80, 255))
    elif kind == "water":
        d.polygon([(x + s/2, y), (x + s, y + s*0.65), (x + s/2, y + s), (x, y + s*0.65)], fill=col)
    elif kind == "fuel":
        d.rounded_rectangle((x + 2, y + 2, x + s - 2, y + s), 3, fill=col); d.rectangle((x + s - 7, y - 1, x + s - 3, y + 3), fill=col)
    elif kind == "mat":
        d.rectangle((x, y + 4, x + s, y + 9), fill=col); d.rectangle((x, y + 11, x + s, y + 16), fill=col)
    elif kind == "med":
        d.rounded_rectangle((x, y, x + s, y + s), 4, fill=col)
        d.rectangle((x + s/2 - 2, y + 4, x + s/2 + 2, y + s - 4), fill=(255, 255, 255, 255))
        d.rectangle((x + 4, y + s/2 - 2, x + s - 4, y + s/2 + 2), fill=(255, 255, 255, 255))
    elif kind == "morale":
        d.ellipse((x, y, x + s, y + s), fill=col)
        d.arc((x + 4, y + 4, x + s - 4, y + s - 3), 20, 160, fill=(30, 30, 30, 255), width=2)

# ---------------- top-left: clock / day
panel((24, 22, 320, 92))
d.text((44, 30), "DAY 12", font=fBig, fill=TXT)
d.text((168, 36), "07:40  ·  Dawn", font=fSB, fill=MUTED)
bar(44, 74, 256, 6, 0.32, (255, 199, 107, 255))

# ---------------- top-center: resources
res = [("food", "42", (231, 111, 81, 255), "-6/day"),
       ("water", "18", (76, 175, 224, 255), "-9/day"),
       ("fuel", "7", (190, 150, 90, 255), "-1/day"),
       ("mat", "126", (180, 150, 120, 255), "+4/day"),
       ("med", "3", (230, 80, 90, 255), "±0"),
       ("morale", "64%", (242, 193, 78, 255), "stable")]
rw = 132
rx0 = W // 2 - len(res) * rw // 2
panel((rx0 - 12, 22, rx0 + len(res) * rw + 4, 92))
for i, (k, v, c, delta) in enumerate(res):
    x = rx0 + i * rw + 10
    icon(x, 38, k, c, 22)
    d.text((x + 34, 30), v, font=fB, fill=TXT)
    dc = WARN if delta.startswith("-") and k == "water" else MUTED
    d.text((x + 34, 60), delta, font=fR, fill=dc)

# ---------------- top-right: alert
panel((W - 420, 22, W - 24, 92), fill=(60, 22, 14, 210))
d.ellipse((W - 400, 44, W - 376, 68), fill=WARN)
d.text((W - 392, 44), "!", font=fB, fill=(40, 20, 10, 255))
d.text((W - 362, 32), "Infected spotted", font=fSB, fill=TXT)
d.text((W - 362, 58), "West rooftops · 2 walkers · 140 m", font=fR, fill=(255, 200, 170, 255))

# ---------------- left: survivor roster
survivors = [("Maya", "Scavenger", 0.86, 0.55, (217, 83, 79, 255), True, "Tending fire"),
             ("Somchai", "Builder", 0.72, 0.80, (242, 193, 78, 255), False, "Crossing bridge"),
             ("Ana", "Farmer", 0.95, 0.40, (78, 154, 107, 255), False, "Watering crops"),
             ("Dr. Lek", "Medic", 0.60, 0.70, (232, 226, 208, 255), False, "Sorting supplies")]
y = 130
for name, role, hp, st, col, sel, task in survivors:
    h = 96
    panel((24, y, 320, y + h), fill=(18, 24, 28, 225) if sel else PANEL)
    if sel:
        d.rounded_rectangle((24, y, 320, y + h), 14, outline=ACC, width=2)
    # portrait (blocky head like the 3D models)
    d.rounded_rectangle((38, y + 14, 92, y + 82), 8, fill=(40, 48, 54, 255))
    d.rectangle((52, y + 24, 78, y + 50), fill=(224, 176, 138, 255))
    d.rectangle((46, y + 52, 84, y + 82), fill=col)
    d.text((106, y + 12), name, font=fSB, fill=TXT)
    d.text((106 + d.textlength(name, font=fSB) + 8, y + 15), role, font=fR, fill=MUTED)
    d.text((106, y + 36), task, font=fR, fill=ACC if sel else MUTED)
    bar(106, y + 62, 196, 7, hp, (102, 214, 128, 255))
    bar(106, y + 76, 196, 7, st, (255, 199, 107, 255))
    y += h + 10

# ---------------- selected-unit nameplate in world
sx, sy = 1001, 300
lab = "MAYA"
tw = d.textlength(lab, font=fSB)
d.rounded_rectangle((sx - tw/2 - 12, sy - 18, sx + tw/2 + 12, sy + 10), 8, fill=(18, 24, 28, 220))
d.text((sx - tw/2, sy - 15), lab, font=fSB, fill=ACC)
d.polygon([(sx - 6, sy + 10), (sx + 6, sy + 10), (sx, sy + 17)], fill=(18, 24, 28, 220))

# ---------------- bottom-right: command bar
cmds = [("B", "Build"), ("S", "Scavenge"), ("E", "Expedition"), ("R", "Rest"), ("TAB", "Base")]
bw, bh, gap = 112, 84, 10
bx = W - 24 - len(cmds) * (bw + gap) + gap
by = H - 24 - bh
for i, (key, lbl) in enumerate(cmds):
    x = bx + i * (bw + gap)
    hot = lbl == "Expedition"
    panel((x, by, x + bw, by + bh), fill=(28, 52, 44, 230) if hot else PANEL)
    if hot:
        d.rounded_rectangle((x, by, x + bw, by + bh), 14, outline=ACC, width=2)
    kw = d.textlength(key, font=fR) + 14
    d.rounded_rectangle((x + 12, by + 12, x + 12 + kw, by + 34), 6, outline=(255, 255, 255, 90), width=1)
    d.text((x + 19, by + 14), key, font=fR, fill=MUTED)
    d.text((x + 12, by + 48), lbl, font=fSB, fill=TXT)

# ---------------- bottom-left: objective
panel((24, H - 128, 470, H - 24))
d.text((44, H - 116), "OBJECTIVE", font=fR, fill=MUTED)
d.text((44, H - 94), "Repair the boat motor", font=fSB, fill=TXT)
d.text((44, H - 68), "Scrap metal 12/20  ·  Fuel 7/5 ✓", font=fR, fill=MUTED)
bar(44, H - 44, 406, 6, 0.6, ACC)

out = Image.alpha_composite(base, ov).convert("RGB")
out.save(DST, quality=92)
print("saved", DST)
