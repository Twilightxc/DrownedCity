"""Horde-night HUD mock (management + action hybrid)."""
import sys
from PIL import Image, ImageDraw, ImageFont

SRC, DST = sys.argv[1], sys.argv[2]
F = "/usr/share/fonts/opentype/inter/"
def font(w, s): return ImageFont.truetype(F + f"Inter-{w}.otf", s)
fB, fSB, fR = font("Bold", 22), font("SemiBold", 17), font("Regular", 14)
fBig, fHuge, fXL = font("ExtraBold", 30), font("Black", 44), font("ExtraBold", 26)

base = Image.open(SRC).convert("RGBA")
W, H = base.size

# subtle dusk vignette (cheap post effect available on web too)
vig = Image.new("L", base.size, 0)
vd = ImageDraw.Draw(vig)
for i in range(60):
    a = int(110 * (i / 60) ** 2)
    vd.rectangle((i * 6, i * 4, W - i * 6, H - i * 4), outline=None)
mask = Image.radial_gradient("L").resize(base.size).point(lambda v: int(min(255, max(0, (v - 120) * 0.9))))
dark = Image.new("RGBA", base.size, (20, 12, 30, 255))
base = Image.composite(dark, base, mask.point(lambda v: int(v * 0.55)))

ov = Image.new("RGBA", base.size, (0, 0, 0, 0))
d = ImageDraw.Draw(ov)
PANEL = (16, 20, 26, 205); EDGE = (255, 255, 255, 28)
TXT = (242, 238, 230, 255); MUTED = (165, 172, 178, 255)
ACC = (125, 255, 176, 255); RED = (255, 84, 72, 255); AMBER = (255, 190, 90, 255)

def panel(xy, r=14, fill=PANEL, outline=EDGE, w=1):
    d.rounded_rectangle(xy, r, fill=fill, outline=outline, width=w)
def bar(x, y, w, h, v, col, bg=(255, 255, 255, 30)):
    d.rounded_rectangle((x, y, x + w, y + h), h // 2, fill=bg)
    d.rounded_rectangle((x, y, x + max(h, int(w * v)), y + h), h // 2, fill=col)
def ctext(cx, y, s, f, col):
    d.text((cx - d.textlength(s, font=f) / 2, y), s, font=f, fill=col)

# ---- top-left: night clock
panel((24, 22, 330, 92))
d.text((44, 30), "NIGHT 3", font=fBig, fill=TXT)
d.text((190, 36), "19:42 · Dusk", font=fSB, fill=AMBER)
bar(44, 74, 266, 6, 0.81, (124, 92, 200, 255))

# ---- top-center: horde wave
cx = W // 2
panel((cx - 260, 22, cx + 260, 104), fill=(48, 14, 16, 215), outline=(255, 84, 72, 90))
ctext(cx, 30, "HORDE ASSAULT", fXL, RED)
bar(cx - 230, 70, 460, 10, 38 / 60, RED, (255, 255, 255, 25))
d.text((cx - 230, 84), "38 / 60 infected remaining", font=fR, fill=(255, 205, 195, 255))
s = "Dawn in 04:12"
d.text((cx + 230 - d.textlength(s, font=fR), 84), s, font=fR, fill=AMBER)

# ---- top-right: combo / score
panel((W - 300, 22, W - 24, 104))
d.text((W - 280, 28), "x4", font=fHuge, fill=AMBER)
d.text((W - 205, 34), "KILL CHAIN", font=fR, fill=MUTED)
d.text((W - 205, 52), "+1,240", font=fXL, fill=TXT)
bar(W - 205, 88, 160, 5, 0.55, AMBER)

# ---- left: defenders
defs = [("Maya", "Shotgun", 0.82, "6/24", (217, 83, 79, 255), True),
        ("Dr. Lek", "Pistol", 0.55, "9/40", (232, 226, 208, 255), False),
        ("Somchai", "Repairing", 0.91, "—", (242, 193, 78, 255), False),
        ("Ana", "Garden · safe", 1.0, "—", (78, 154, 107, 255), False)]
y = 130
for name, role, hp, ammo, col, sel in defs:
    h = 76
    panel((24, y, 300, y + h), outline=ACC if sel else EDGE, w=2 if sel else 1)
    d.rounded_rectangle((38, y + 12, 82, y + 64), 8, fill=(40, 48, 54, 255))
    d.rectangle((50, y + 18, 70, y + 38), fill=(217, 167, 127, 255))
    d.rectangle((45, y + 40, 75, y + 64), fill=col)
    d.text((96, y + 10), name, font=fSB, fill=TXT)
    d.text((96, y + 32), role, font=fR, fill=ACC if sel else MUTED)
    if ammo != "—":
        d.text((288 - d.textlength(ammo, font=fR), y + 32), ammo, font=fR, fill=AMBER)
    bar(96, y + 56, 190, 7, hp, (102, 214, 128, 255) if hp > 0.6 else AMBER)
    y += h + 8

# ---- base status (management layer still visible during action)
panel((24, y + 6, 300, y + 120))
d.text((40, y + 16), "BASE", font=fR, fill=MUTED)
rows = [("Bridge barricade", 0.34, RED), ("Dock ladder", 0.0, RED), ("Sandbag wall", 0.78, (102, 214, 128, 255))]
yy = y + 40
for lbl, v, c in rows:
    d.text((40, yy), lbl, font=fR, fill=TXT)
    bar(180, yy + 5, 104, 6, v, c)
    yy += 24

# ---- in-world callouts
def nameplate(x, y, label, col):
    tw = d.textlength(label, font=fSB)
    d.rounded_rectangle((x - tw / 2 - 10, y - 16, x + tw / 2 + 10, y + 10), 7, fill=(16, 20, 26, 220))
    d.text((x - tw / 2, y - 14), label, font=fSB, fill=col)
    d.polygon([(x - 6, y + 10), (x + 6, y + 10), (x, y + 17)], fill=(16, 20, 26, 220))
nameplate(990, 296, "MAYA", ACC)
# damage popups on the bridge
for (px, py, t) in [(1135, 470, "+100"), (1180, 520, "+100"), (1100, 430, "CRIT +250")]:
    d.text((px + 2, py + 2), t, font=fB, fill=(0, 0, 0, 160)); d.text((px, py), t, font=fB, fill=AMBER)
# breach warning
bx, by = 780, 700
panel((bx - 150, by - 22, bx + 40, by + 22), fill=(70, 14, 14, 230), outline=RED, w=2)
d.text((bx - 136, by - 12), "⚠ BREACH: ladder", font=fSB, fill=TXT)
d.line((bx + 40, by, 836, 724), fill=RED, width=3)

# ---- bottom-center: weapon + abilities
panel((cx - 330, H - 112, cx + 352, H - 24))
d.rounded_rectangle((cx - 314, H - 98, cx - 120, H - 38), 10, fill=(255, 255, 255, 14))
d.text((cx - 300, H - 94), "SHOTGUN", font=fR, fill=MUTED)
d.text((cx - 300, H - 74), "6", font=fBig, fill=TXT)
d.text((cx - 276, H - 64), "/ 24", font=fSB, fill=MUTED)
for i in range(8):
    d.rectangle((cx - 210 + i * 10, H - 60, cx - 204 + i * 10, H - 44), fill=AMBER if i < 6 else (255, 255, 255, 40))
abil = [("Q", "Molotov", "2"), ("F", "Repair", "12 mat"), ("SPACE", "Dodge", ""), ("TAB", "Base mode", "")]
ax = cx - 100
for key, lbl, sub in abil:
    w = 102
    d.rounded_rectangle((ax, H - 98, ax + w, H - 38), 10, fill=(255, 255, 255, 14))
    kw = d.textlength(key, font=fR) + 12
    d.rounded_rectangle((ax + 10, H - 92, ax + 10 + kw, H - 72), 5, outline=(255, 255, 255, 90))
    d.text((ax + 16, H - 91), key, font=fR, fill=MUTED)
    d.text((ax + 10, H - 64), lbl, font=fSB, fill=TXT)
    if sub: d.text((ax + w - 8 - d.textlength(sub, font=fR), H - 91), sub, font=fR, fill=AMBER)
    ax += w + 8

# ---- bottom-right: resources (compact)
res = [("Food", "42"), ("Water", "18"), ("Mat", "126"), ("Med", "3")]
rx = W - 24 - len(res) * 96
panel((rx - 8, H - 76, W - 24, H - 24))
for i, (k, v) in enumerate(res):
    d.text((rx + i * 96 + 8, H - 70), k.upper(), font=fR, fill=MUTED)
    d.text((rx + i * 96 + 8, H - 52), v, font=fB, fill=TXT)

out = Image.alpha_composite(base, ov).convert("RGB")
out.save(DST, quality=92)
print("saved", DST)
