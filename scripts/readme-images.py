#!/usr/bin/env python3
"""Render docs/banner.png, docs/screenshot.png and docs/themes.png for the README,
and the website images in docs/assets/.
Run ./scripts/build.sh --snapshots first. Requires Pillow."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S, F = 'dist/snapshots/', 'Resources/Fonts/'

def rounded(im, r):
    m = Image.new('L', im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, *im.size], r, fill=255)
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im.convert('RGBA'), (0, 0), m)
    return out

def place(canvas, im, xy, r=24, blur=30, alpha=110):
    sh = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([xy[0], xy[1] + 16, xy[0] + im.width, xy[1] + im.height + 16], r, fill=(0, 0, 0, alpha))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(im, xy)

def background(w, h):
    top, bot = (14, 10, 48), (40, 16, 90)
    im = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([w - 500, -300, w + 200, 300], fill=(255, 60, 170, 90))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    lines = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines)
    for y in range(0, h, 4):
        ld.line([(0, y), (w, y)], fill=(0, 0, 0, 40))
    im.alpha_composite(lines)
    return im

# Banner
W, H = 1600, 480
b = background(W, H)
icon = rounded(Image.open('Resources/Icon/AppIcon-art.png').resize((300, 300), Image.LANCZOS), 66)
place(b, icon, (150, 90), 66, 25, 140)
d = ImageDraw.Draw(b)
d.text((510, 120), "Pastlog", font=ImageFont.truetype(F + 'SpaceMono-Bold.ttf', 128), fill=(255, 255, 255))
d.text((516, 295), "Everything you copy, searchable.", font=ImageFont.truetype(F + 'SpaceMono-Regular.ttf', 44), fill=(150, 235, 255))
d.text((516, 365), "A free clipboard history for your Mac", font=ImageFont.truetype(F + 'SpaceMono-Regular.ttf', 30), fill=(205, 190, 255))
b.convert('RGB').save('docs/banner.png', optimize=True)

# Light + dark
hw, hh = 2 * 920 + 3 * 100, 1200 + 200
h = background(hw, hh)
place(h, rounded(Image.open(S + 'panel-light.png'), 28), (100, 90), 28)
place(h, rounded(Image.open(S + 'panel-dark.png'), 28), (1120, 90), 28)
h.convert('RGB').resize((hw // 2, hh // 2), Image.LANCZOS).save('docs/screenshot.png', optimize=True)

# All themes
names = ['light', 'dark', 'sunset', 'ocean', 'mint', 'rose', 'lavender', 'sepia', 'nord', 'graphite', 'citypop']
tw, th, cols, gap = 230, 300, 6, 40
g = background(cols * tw + (cols + 1) * gap, 2 * th + 3 * gap)
for i, n in enumerate(names):
    t = rounded(Image.open(S + f'panel-{n}.png').resize((tw, th), Image.LANCZOS), 12)
    c, r = i % cols, i // cols
    if r == 1:
        c += 0.5
    place(g, t, (int(gap + c * (tw + gap)), gap + r * (th + gap)), 12, 12, 120)
g.convert('RGB').save('docs/themes.png', optimize=True)
print("Wrote docs/banner.png, docs/screenshot.png, docs/themes.png")

# Website: one retina screenshot per theme (shown at 460 × 600), icons, and a social share image
A = 'docs/assets/'
os.makedirs(A, exist_ok=True)
for n in names:
    rounded(Image.open(S + f'panel-{n}.png'), 28).save(A + f'panel-{n}.webp', quality=86, method=6)

art = Image.open('Resources/Icon/AppIcon-art.png')
for size, name in [(512, 'icon-512.png'), (180, 'apple-touch-icon.png'), (48, 'favicon-48.png')]:
    rounded(art.resize((size, size), Image.LANCZOS), round(size * 0.225)).save(A + name, optimize=True)

W, H = 1200, 630
og = background(W, H)
panel = rounded(Image.open(S + 'panel-dark.png').resize((460, 600), Image.LANCZOS), 18)
place(og, panel, (700, 70), 18, 30, 150)
place(og, rounded(art.resize((120, 120), Image.LANCZOS), 27), (80, 110), 27, 20, 140)
d = ImageDraw.Draw(og)
d.text((76, 250), "Pastlog", font=ImageFont.truetype(F + 'SpaceMono-Bold.ttf', 96), fill=(255, 255, 255))
d.text((80, 385), "Everything you copy,", font=ImageFont.truetype(F + 'SpaceMono-Regular.ttf', 38), fill=(150, 235, 255))
d.text((80, 435), "searchable.", font=ImageFont.truetype(F + 'SpaceMono-Regular.ttf', 38), fill=(150, 235, 255))
d.text((80, 520), "Free clipboard history for Mac", font=ImageFont.truetype(F + 'SpaceMono-Regular.ttf', 26), fill=(205, 190, 255))
og.convert('RGB').save(A + 'og.png', optimize=True)
print(f"Wrote {len(names)} theme screenshots, icons and og.png to {A}")
