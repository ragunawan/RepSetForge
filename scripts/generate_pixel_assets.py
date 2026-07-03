#!/usr/bin/env python3
"""Generates original high-detail pixel-art assets for Setbound's RPG layer.

Sprites are drawn procedurally at their native pixel grids:

  hero classes   64x64   (idle 4, walk 4, attack 3, cast 3 frames)
  small monsters 48x48   (idle 3, attack 2, hit 1, defeat 3 frames)
  medium monsters 64x64
  large monsters 80x80
  bosses        128x128  (idle 4, attack 4, defeat 5 frames)
  equipment/skill icons 48x48
  backgrounds   480x270, composed from 32px tile stamps

Every sprite gets automatic rim lighting, rim shadow, and a dark outline for
readable silhouettes. PNGs are exported with nearest-neighbor upscaling so
they stay crisp at any display size. The RPG asset folder is wiped and fully
regenerated on each run — safe to re-run at any time.

Frame counts here must match RPGClass.HeroAnimation / RPGMonster.EnemyAnimation
/ RPGBoss frame constants on the Swift side.

Requires only the Python standard library (no Pillow).
"""

import json
import math
import os
import shutil
import struct
import zlib

SPRITE_SCALE = 4   # nearest-neighbor export upscale for sprites/icons
BG_SCALE = 2

HERO_FRAMES = {"idle": 4, "walk": 4, "attack": 3, "cast": 3}
MONSTER_FRAMES = {"idle": 3, "attack": 2, "hit": 1, "defeat": 3}
BOSS_FRAMES = {"idle": 4, "attack": 4, "defeat": 5}

ASSETS_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "Setbound", "Assets.xcassets", "RPG",
))


# ───────────────────────────────── Colors ─────────────────────────────────

def C(hexstr, alpha=255):
    return (int(hexstr[0:2], 16), int(hexstr[2:4], 16), int(hexstr[4:6], 16), alpha)


def lighten(c, f=0.3):
    return (int(c[0] + (255 - c[0]) * f), int(c[1] + (255 - c[1]) * f),
            int(c[2] + (255 - c[2]) * f), c[3])


def darken(c, f=0.3):
    return (int(c[0] * (1 - f)), int(c[1] * (1 - f)), int(c[2] * (1 - f)), c[3])


OUTLINE = C("14121E")
BLACK = C("1A1826")
WHITE = C("F4F5FA")
SKIN = C("EDB88B")
SKIN_DARK = C("C98F60")
BROWN = C("77502C")
BROWN_DARK = C("4E3218")
STEEL = C("A9B4C8")
STEEL_DARK = C("67738C")
GOLD = C("F4C542")
GOLD_DARK = C("BC8F22")
NAVY = C("263056")
RED = C("D14444")
RED_DARK = C("8E2828")
GREEN = C("4CA852")
GREEN_DARK = C("2F7038")
BONE = C("EAE5D2")
BONE_DARK = C("BBB49A")
PURPLE = C("8459BC")
PURPLE_DARK = C("58397E")
CYAN = C("5FD0EE")
ORANGE = C("EE8A32")
YELLOW = C("F7E15E")
GRAY = C("7B8294")
GRAY_DARK = C("4A4F5F")


# ───────────────────────────────── Canvas ─────────────────────────────────

class Canvas:
    def __init__(self, w, h=None):
        self.w = w
        self.h = h if h is not None else w
        self.px = [[None] * self.w for _ in range(self.h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[int(y)][int(x)] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[int(y)][int(x)]
        return None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.set(x, y, c)

    def row(self, y, x0, x1, c):
        self.rect(x0, y, x1, y, c)

    def col(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def dots(self, points, c):
        for (x, y) in points:
            self.set(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        rx = max(rx, 0.5)
        ry = max(ry, 0.5)
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def tri(self, p0, p1, p2, c):
        xs = [p0[0], p1[0], p2[0]]
        ys = [p0[1], p1[1], p2[1]]

        def sign(ax, ay, bx, by, px, py):
            return (px - bx) * (ay - by) - (ax - bx) * (py - by)

        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                d1 = sign(*p0, *p1, x, y)
                d2 = sign(*p1, *p2, x, y)
                d3 = sign(*p2, *p0, x, y)
                neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
                pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
                if not (neg and pos):
                    self.set(x, y, c)

    def limb(self, x0, y0, x1, y1, w, c):
        """Thick line — used for arms, legs, tails, weapon hafts."""
        steps = max(abs(int(x1 - x0)), abs(int(y1 - y0)), 1)
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i / steps
            y = y0 + (y1 - y0) * i / steps
            half = w / 2
            self.rect(round(x - half), round(y - half),
                      round(x - half) + int(w) - 1, round(y - half) + int(w) - 1, c)

    def dither(self, x0, y0, x1, y1, c, parity=0):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                if (x + y) % 2 == parity and self.get(x, y) is not None:
                    self.set(x, y, c)


# ─────────────────────────────── Post effects ───────────────────────────────

def rim(canvas, light_f=0.32, dark_f=0.28):
    """Top-edge highlight and bottom-edge shadow pixels for simple shading."""
    src = [row[:] for row in canvas.px]
    for y in range(canvas.h):
        for x in range(canvas.w):
            c = src[y][x]
            if c is None or c[3] < 255:
                continue
            above = src[y - 1][x] if y > 0 else None
            below = src[y + 1][x] if y < canvas.h - 1 else None
            if above is None:
                canvas.px[y][x] = lighten(c, light_f)
            elif below is None:
                canvas.px[y][x] = darken(c, dark_f)
    return canvas


def outline(canvas, color=OUTLINE):
    """1px dark outline around every opaque region (drawn outside the shape)."""
    src = [row[:] for row in canvas.px]
    for y in range(canvas.h):
        for x in range(canvas.w):
            if src[y][x] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < canvas.w and 0 <= ny < canvas.h and src[ny][nx] is not None and src[ny][nx][3] == 255:
                    canvas.px[y][x] = color
                    break
    return canvas


def finish(canvas):
    return outline(rim(canvas))


def squash(src, fy, fx=1.0):
    """Squash toward the bottom (ground) — used for hit recoil and defeats."""
    out = Canvas(src.w, src.h)
    gy = src.h - 1
    cx = src.w / 2
    for ty in range(src.h):
        sy = round(gy - (gy - ty) / fy)
        if not (0 <= sy < src.h):
            continue
        for tx in range(src.w):
            sx = round(cx + (tx - cx) / fx)
            if 0 <= sx < src.w and src.px[sy][sx] is not None:
                out.px[ty][tx] = src.px[sy][sx]
    return out


def fade(src, f):
    out = Canvas(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y][x]
            if c is not None:
                out.px[y][x] = (c[0], c[1], c[2], int(c[3] * f))
    return out


def shift(src, dx, dy=0):
    out = Canvas(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            c = src.px[y][x]
            if c is not None:
                out.set(x + dx, y + dy, c)
    return out


# ─────────────────────────────── PNG / imageset ───────────────────────────────

def write_png(path, canvas, scale):
    width = canvas.w * scale
    raw = bytearray()
    for y in range(canvas.h):
        row = bytearray()
        for x in range(canvas.w):
            c = canvas.px[y][x] or (0, 0, 0, 0)
            row.extend(bytes(c) * scale)
        row_bytes = b"\x00" + bytes(row)
        raw.extend(row_bytes * scale)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", width, canvas.h * scale, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        f.write(chunk(b"IEND", b""))


def write_imageset(name, canvas, scale=SPRITE_SCALE):
    directory = os.path.join(ASSETS_DIR, f"{name}.imageset")
    os.makedirs(directory, exist_ok=True)
    write_png(os.path.join(directory, f"{name}.png"), canvas, scale)
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(directory, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


# ═══════════════════════════════ HERO CLASSES ═══════════════════════════════
#
# 64x64 rig facing right. Ground at y=59. Draw order: back arm, back leg,
# torso, front leg, head, front arm, weapon, effects.

HERO = {
    "head": (25, 7, 40, 22),      # x0,y0,x1,y1
    "torso": (25, 23, 38, 40),
    "back_shoulder": (28, 26),
    "front_shoulder": (36, 26),
    "back_hip": (29, 40),
    "front_hip": (34, 40),
    "ground": 56,
}


def hero_frame_params(anim, t):
    """(dy, back_foot_dx, front_foot_dx, back_hand, front_hand, blink)"""
    rest_back = (24, 38)
    rest_front = (41, 38)
    if anim == "walk":
        feet = [(-7, 7), (-3, 3), (7, -7), (3, -3)][t]
        swing = [5, 2, -5, -2][t]
        dy = [0, -1, 0, -1][t]
        return (dy, feet[0], feet[1],
                (24 - swing, 37), (41 + swing, 37), False)
    if anim == "idle":
        dy = [0, 0, 1, 1][t]
        return (dy, -3, 3, rest_back, rest_front, t == 3)
    if anim == "attack":
        hand = [(34, 12), (52, 27), (47, 33)][t]           # windup, strike, recover
        dy = [0, 1, 1][t]
        return (dy, -6, 6, (22, 36), hand, False)
    if anim == "cast":
        lift = [30, 22, 16][t]
        return (0, -3, 3, (21, lift + 2), (44, lift), False)
    return (0, -3, 3, rest_back, rest_front, False)


def draw_hero_body(c, pal, anim, t):
    dy, bdx, fdx, bhand, fhand, blink = hero_frame_params(anim, t)
    hx0, hy0, hx1, hy1 = HERO["head"]
    tx0, ty0, tx1, ty1 = HERO["torso"]
    hy0 += dy; hy1 += dy; ty0 += dy; ty1 += dy
    ground = HERO["ground"]
    skin = pal["skin"]
    torso = pal["torso"]
    torso_dark = darken(torso, 0.25)
    legs = pal["legs"]
    boots = pal["boots"]

    # back arm + back leg (darker for depth)
    bsx, bsy = HERO["back_shoulder"][0], HERO["back_shoulder"][1] + dy
    c.limb(bsx, bsy, bhand[0], bhand[1], 4, darken(pal["sleeve"], 0.25))
    c.rect(bhand[0] - 2, bhand[1] - 2, bhand[0] + 1, bhand[1] + 1, darken(skin, 0.2))
    bhx, bhy = HERO["back_hip"][0], HERO["back_hip"][1] + dy
    c.limb(bhx, bhy, bhx + bdx, ground, 5, darken(legs, 0.25))
    c.rect(bhx + bdx - 2, ground - 1, bhx + bdx + 4, ground + 2, darken(boots, 0.2))

    # torso
    c.rect(tx0, ty0, tx1, ty1, torso)
    c.rect(tx0, ty1 - 2, tx1, ty1, torso_dark)              # belt
    c.rect(tx0 + 1, ty0 + 1, tx0 + 3, ty1 - 3, lighten(torso, 0.18))

    # front leg
    fhx, fhy = HERO["front_hip"][0], HERO["front_hip"][1] + dy
    c.limb(fhx, fhy, fhx + fdx, ground, 5, legs)
    c.rect(fhx + fdx - 2, ground - 1, fhx + fdx + 4, ground + 2, boots)

    # head
    c.rect(hx0, hy0, hx1, hy1, skin)
    c.rect(hx0, hy1 - 3, hx1, hy1, darken(skin, 0.12))      # jaw shading
    if blink:
        c.row(hy0 + 8, hx1 - 6, hx1 - 4, darken(skin, 0.45))
    else:
        c.rect(hx1 - 6, hy0 + 7, hx1 - 5, hy0 + 9, BLACK)   # eye
        c.set(hx1 - 6, hy0 + 7, WHITE)
    c.row(hy0 + 5, hx1 - 8, hx1 - 3, darken(skin, 0.3))     # brow

    # front arm
    fsx, fsy = HERO["front_shoulder"][0], HERO["front_shoulder"][1] + dy
    c.limb(fsx, fsy, fhand[0], fhand[1], 4, pal["sleeve"])
    c.rect(fhand[0] - 2, fhand[1] - 2, fhand[0] + 1, fhand[1] + 1, skin)

    return dy, bhand, fhand


def sword(c, hx, hy, angle, length=17):
    """Blade from the hand outward at angle (radians, 0 = right, -pi/2 = up)."""
    ex = hx + math.cos(angle) * length
    ey = hy + math.sin(angle) * length
    c.limb(hx + math.cos(angle) * 4, hy + math.sin(angle) * 4, ex, ey, 3, STEEL)
    c.limb(hx + math.cos(angle) * 6, hy + math.sin(angle) * 6, ex, ey, 1, lighten(STEEL, 0.45))
    px, py = math.cos(angle + math.pi / 2), math.sin(angle + math.pi / 2)
    gx, gy = hx + math.cos(angle) * 3, hy + math.sin(angle) * 3
    c.limb(gx - px * 4, gy - py * 4, gx + px * 4, gy + py * 4, 2, GOLD)   # crossguard
    c.limb(hx - math.cos(angle) * 2, hy - math.sin(angle) * 2, hx - math.cos(angle) * 4, hy - math.sin(angle) * 4, 3, BROWN)
    c.set(round(hx - math.cos(angle) * 5), round(hy - math.sin(angle) * 5), GOLD)  # pommel


def hero_knight(anim, t):
    c = Canvas(64)
    pal = {"skin": SKIN, "torso": STEEL, "sleeve": STEEL_DARK,
           "legs": NAVY, "boots": darken(STEEL, 0.35)}
    dy, bhand, fhand = draw_hero_body(c, pal, anim, t)
    hx0, hy0, hx1, hy1 = HERO["head"]
    hy0 += dy
    # great helm with visor slit and plume
    c.rect(hx0 - 1, hy0 - 2, hx1 + 1, hy0 + 6, STEEL)
    c.rect(hx0 - 1, hy0 + 4, hx1 + 1, hy0 + 5, darken(STEEL, 0.4))   # visor slit
    c.rect(hx0 + 4, hy0 - 5, hx0 + 7, hy0 - 2, RED)                  # plume
    c.rect(hx0 + 5, hy0 - 9, hx0 + 6, hy0 - 5, RED)
    # tabard stripe + gold trim
    tx0, ty0, tx1, ty1 = HERO["torso"]
    c.rect(tx0 + 5, ty0 + dy, tx0 + 8, ty1 - 3 + dy, NAVY)
    c.row(ty0 + dy, tx0, tx1, GOLD_DARK)
    # kite shield on back arm
    c.tri((bhand[0] - 5, bhand[1] - 6), (bhand[0] + 3, bhand[1] - 6), (bhand[0] - 1, bhand[1] + 8), NAVY)
    c.rect(bhand[0] - 5, bhand[1] - 7, bhand[0] + 3, bhand[1] - 5, GOLD_DARK)
    c.set(bhand[0] - 1, bhand[1] - 2, GOLD)
    # sword
    if anim == "attack":
        angle = [-2.3, -0.15, 0.5][t]
        sword(c, fhand[0], fhand[1], angle)
        if t == 1:  # motion arc
            for i, a in enumerate((-1.4, -1.0, -0.6)):
                c.set(round(fhand[0] + math.cos(a) * 16), round(fhand[1] + math.sin(a) * 16), C("F4C542", 150))
    elif anim == "cast":
        sword(c, fhand[0], fhand[1], -math.pi / 2, 15)
        glow = [C("F4C542", 120), C("F4C542", 180), GOLD][t]
        c.dots([(fhand[0] - 3, fhand[1] - 18), (fhand[0] + 3, fhand[1] - 18), (fhand[0], fhand[1] - 21)], glow)
    else:
        sword(c, fhand[0], fhand[1], -math.pi / 2 + 0.25, 14)
    return c


def hero_ranger(anim, t):
    c = Canvas(64)
    pal = {"skin": SKIN, "torso": GREEN_DARK, "sleeve": darken(GREEN_DARK, 0.15),
           "legs": BROWN, "boots": BROWN_DARK}
    dy, bhand, fhand = draw_hero_body(c, pal, anim, t)
    hx0, hy0, hx1, hy1 = HERO["head"]
    hy0 += dy
    # hood + cloak tail
    c.rect(hx0 - 1, hy0 - 2, hx1 + 1, hy0 + 4, GREEN_DARK)
    c.tri((hx0 - 1, hy0 - 2), (hx0 - 6, hy0 + 10), (hx0 - 1, hy0 + 12), darken(GREEN_DARK, 0.2))
    c.tri((hx1 - 2, hy0 - 2), (hx1 + 4, hy0 - 6), (hx1 + 1, hy0 + 2), GREEN_DARK)  # hood point
    # quiver on back
    c.limb(22, 26 + dy, 18, 36 + dy, 4, BROWN)
    c.dots([(19, 24 + dy), (21, 23 + dy), (17, 25 + dy)], RED)        # fletchings
    # leather strap
    tx0, ty0, tx1, ty1 = HERO["torso"]
    c.limb(tx0 + 1, ty0 + 2 + dy, tx1 - 1, ty1 - 4 + dy, 2, BROWN)
    # bow
    def bow(hx, hy, drawn=False):
        for i in range(-9, 10):
            bulge = math.sqrt(max(0.0, 1 - (i / 9) ** 2)) * 6
            c.set(round(hx + bulge), hy + i, BROWN)
            c.set(round(hx + bulge) + 1, hy + i, BROWN_DARK)
        string_x = hx - (3 if drawn else 0)
        c.col(string_x, hy - 8, hy + 8, C("E4DCC4"))
        if drawn:
            c.limb(string_x, hy, hx + 14, hy, 2, STEEL)               # arrow
            c.tri((hx + 14, hy - 2), (hx + 14, hy + 2), (hx + 17, hy), lighten(STEEL, 0.4))
    if anim == "attack":
        if t == 0:
            bow(fhand[0] + 2, fhand[1], drawn=True)
        elif t == 1:
            bow(fhand[0] + 2, fhand[1], drawn=False)
            for i in range(3):                                        # loosed arrow + speed lines
                c.limb(fhand[0] + 10 + i * 5, fhand[1] - 1, fhand[0] + 13 + i * 5, fhand[1] - 1, 1, C("5FD0EE", 170 - i * 40))
        else:
            bow(fhand[0] + 2, fhand[1])
    elif anim == "cast":
        bow(fhand[0] + 2, fhand[1])
        glow = [C("4CA852", 130), C("4CA852", 190), GREEN][t]
        c.dots([(fhand[0] - 2, fhand[1] - 12), (fhand[0] + 6, fhand[1] - 14), (fhand[0] + 2, fhand[1] - 17)], glow)
    else:
        bow(fhand[0] + 2, fhand[1])
    return c


def hero_mage(anim, t):
    c = Canvas(64)
    pal = {"skin": SKIN, "torso": PURPLE, "sleeve": PURPLE_DARK,
           "legs": PURPLE, "boots": PURPLE_DARK}
    dy, bhand, fhand = draw_hero_body(c, pal, anim, t)
    tx0, ty0, tx1, ty1 = HERO["torso"]
    # robe skirt over the legs
    c.tri((tx0 - 1, ty1 - 2 + dy), (tx1 + 1, ty1 - 2 + dy), (tx1 + 4, HERO["ground"] + 2), PURPLE)
    c.tri((tx0 - 1, ty1 - 2 + dy), (tx0 - 4, HERO["ground"] + 2), (tx1 + 4, HERO["ground"] + 2), PURPLE)
    c.row(HERO["ground"] + 1, tx0 - 3, tx1 + 3, PURPLE_DARK)
    c.dots([(tx0 + 3, ty1 + 6 + dy), (tx1 - 4, ty1 + 9 + dy)], GOLD)  # star spangles
    hx0, hy0, hx1, hy1 = HERO["head"]
    hy0 += dy
    # pointed hat
    c.rect(hx0 - 3, hy0 + 1, hx1 + 3, hy0 + 3, PURPLE_DARK)           # brim
    c.tri((hx0 + 2, hy0 + 1), (hx1 - 2, hy0 + 1), (hx0 + 5, hy0 - 12), PURPLE)
    c.row(hy0 - 1, hx0 + 3, hx1 - 4, GOLD_DARK)                       # hat band
    c.set(hx0 + 5, hy0 - 13, GOLD)                                    # hat tip star
    # staff with orb
    def staff(hx, hy, glow_level):
        c.limb(hx, hy + 16, hx, hy - 12, 3, BROWN)
        c.dots([(hx - 1, hy + 4), (hx + 1, hy - 4)], BROWN_DARK)      # gnarls
        c.ellipse(hx, hy - 16, 3.4, 3.4, CYAN)
        c.set(hx - 1, hy - 17, WHITE)
        if glow_level > 0:
            ring = C("5FD0EE", 90 + glow_level * 50)
            r = 5 + glow_level * 2
            for a in range(0, 360, 45):
                c.set(round(hx + math.cos(math.radians(a)) * r),
                      round(hy - 16 + math.sin(math.radians(a)) * r), ring)
    if anim == "cast":
        staff(fhand[0], fhand[1], t + 1)
        if t == 2:  # floating runes
            c.dots([(fhand[0] - 10, fhand[1] - 22), (fhand[0] + 8, fhand[1] - 26)], GOLD)
    elif anim == "attack":
        staff(fhand[0], fhand[1], 1)
        if t >= 1:  # bolt leaving the orb
            for i in range(3):
                c.ellipse(fhand[0] + 8 + i * 6, fhand[1] - 16, 2 - i * 0.5, 2 - i * 0.5, C("5FD0EE", 220 - i * 60))
    else:
        staff(fhand[0], fhand[1], 0)
    return c


def hero_monk(anim, t):
    c = Canvas(64)
    pal = {"skin": SKIN, "torso": ORANGE, "sleeve": SKIN,
           "legs": darken(ORANGE, 0.3), "boots": BROWN_DARK}
    dy, bhand, fhand = draw_hero_body(c, pal, anim, t)
    hx0, hy0, hx1, hy1 = HERO["head"]
    hy0 += dy
    # headband with trailing ribbon that waves per frame
    c.rect(hx0 - 1, hy0 + 2, hx1 + 1, hy0 + 4, RED)
    wave = [0, -1, 0, 1][t % 4]
    c.limb(hx0 - 1, hy0 + 3, hx0 - 8, hy0 + 6 + wave, 2, RED)
    # sash
    tx0, ty0, tx1, ty1 = HERO["torso"]
    c.limb(tx0, ty0 + 3 + dy, tx1, ty1 - 4 + dy, 3, darken(ORANGE, 0.35))
    # wrapped fists
    c.rect(fhand[0] - 3, fhand[1] - 3, fhand[0] + 2, fhand[1] + 2, WHITE)
    c.rect(bhand[0] - 3, bhand[1] - 3, bhand[0] + 2, bhand[1] + 2, C("D9DAE2"))
    if anim == "attack" and t == 1:
        for i in range(3):                                            # punch speed lines
            c.limb(fhand[0] + 5 + i * 4, fhand[1] - 2 + i * 2, fhand[0] + 9 + i * 4, fhand[1] - 2 + i * 2, 1, C("F7E15E", 180 - i * 50))
    if anim == "cast":
        ring = C("F4C542", 100 + t * 55)
        r = 10 + t * 4
        for a in range(0, 360, 30):
            c.set(round(32 + math.cos(math.radians(a)) * r),
                  round(34 + math.sin(math.radians(a)) * r * 0.7), ring)
    return c


def hero_rogue(anim, t):
    c = Canvas(64)
    pal = {"skin": SKIN, "torso": GRAY_DARK, "sleeve": darken(GRAY_DARK, 0.15),
           "legs": darken(GRAY_DARK, 0.3), "boots": BLACK}
    dy, bhand, fhand = draw_hero_body(c, pal, anim, t)
    hx0, hy0, hx1, hy1 = HERO["head"]
    hy0 += dy
    # deep hood with shadowed face and glinting eye
    c.rect(hx0 - 1, hy0 - 2, hx1 + 1, hy0 + 5, GRAY_DARK)
    c.rect(hx0 + 1, hy0 + 5, hx1 - 1, hy0 + 9, darken(GRAY_DARK, 0.45))
    c.rect(hx1 - 6, hy0 + 7, hx1 - 5, hy0 + 8, YELLOW)
    # purple scarf trailing
    wave = [0, 1, 0, -1][t % 4]
    c.limb(hx0, hy0 + 12, hx0 - 9, hy0 + 15 + wave, 3, PURPLE_DARK)

    def dagger(hx, hy, angle):
        ex = hx + math.cos(angle) * 9
        ey = hy + math.sin(angle) * 9
        c.limb(hx + math.cos(angle) * 2, hy + math.sin(angle) * 2, ex, ey, 2, STEEL)
        c.set(round(ex), round(ey), lighten(STEEL, 0.5))
        c.limb(hx, hy, hx - math.cos(angle) * 2, hy - math.sin(angle) * 2, 2, BROWN_DARK)

    if anim == "attack":
        angles = [(-2.0, -1.2), (-0.2, 0.3), (0.4, 0.9)][t]
        dagger(fhand[0], fhand[1], angles[0])
        dagger(bhand[0], bhand[1], angles[1])
        if t == 1:
            for i in range(3):
                c.set(fhand[0] + 10 + i * 3, fhand[1] - 3 + i, C("8459BC", 170 - i * 45))
    elif anim == "cast":
        dagger(fhand[0], fhand[1], -0.5)
        dagger(bhand[0], bhand[1], math.pi + 0.5)
        ghost = C("58397E", 60 + t * 30)                              # dash afterimages
        c.rect(12 - t * 3, 26, 16 - t * 3, 50, ghost)
    else:
        dagger(fhand[0], fhand[1], -0.7)
        dagger(bhand[0], bhand[1], math.pi + 0.7)
    return c


HERO_BUILDERS = {
    "knight": hero_knight,
    "ranger": hero_ranger,
    "mage": hero_mage,
    "monk": hero_monk,
    "rogue": hero_rogue,
}


# ═══════════════════════════════ MONSTERS ═══════════════════════════════
#
# Each family draws idle (t 0-2) and attack (t 0-1) natively at any canvas
# size; hit and defeat frames are synthesized with squash/fade transforms.
# All face right (the scene flips enemies to face the hero).

def m_slime(pal, s, anim, t):
    c = Canvas(s)
    body, core = pal
    cx, gy = s * 0.5, s - 5
    ry = s * 0.26 * [1.0, 0.9, 0.96][t % 3]
    rx = s * 0.34 * [1.0, 1.06, 1.02][t % 3]
    if anim == "attack":
        cx += s * (0.06 + 0.06 * t)
        rx *= 1.05 + 0.08 * t
        ry *= 0.94
    c.ellipse(cx, gy - ry, rx, ry, body)
    c.rect(cx - rx, gy - ry * 0.4, cx + rx, gy, body)                  # flat base
    c.ellipse(cx, gy - ry * 0.6, rx * 0.55, ry * 0.5, darken(body, 0.18))  # nucleus
    c.ellipse(cx - rx * 0.4, gy - ry * 1.2, rx * 0.22, ry * 0.3, lighten(body, 0.45))  # shine
    ex = cx + rx * 0.25
    c.rect(ex - 1, gy - ry - 1, ex, gy - ry + 2, BLACK)                # eyes
    c.rect(ex + 4, gy - ry - 1, ex + 5, gy - ry + 2, BLACK)
    c.row(gy - ry + 5, ex, ex + 4, darken(body, 0.5))                  # mouth
    c.dots([(cx - rx * 0.9, gy - 1), (cx + rx * 0.95, gy - 2)], core)  # drips
    if anim == "attack" and t == 1:
        c.dots([(cx - rx - 3, gy - 4), (cx - rx - 6, gy - 2)], C(core_hex(core), 140))
    return c


def core_hex(c):
    return f"{c[0]:02X}{c[1]:02X}{c[2]:02X}"


def m_bat(pal, s, anim, t):
    c = Canvas(s)
    body, wing = pal
    cx, cy = s * 0.5, s * 0.5 + [0, 2, 1][t % 3]
    r = s * 0.16
    if anim == "attack":
        cx += s * 0.08 * (t + 1)
        cy += 2
    flap = [-1.0, 0.0, 0.7][t % 3] if anim == "idle" else 0.9
    for side in (-1, 1):
        shoulder = (cx + side * r * 0.8, cy - 1)
        tip = (cx + side * s * 0.36, cy - r - s * 0.14 * flap)
        mid = (cx + side * s * 0.22, cy + r * 0.9 - s * 0.1 * flap)
        c.tri(shoulder, tip, mid, wing)
        c.tri(shoulder, mid, (cx + side * r * 0.6, cy + r), darken(wing, 0.2))
        c.limb(*shoulder, *tip, 2, darken(wing, 0.35))                 # wing bone
    c.ellipse(cx, cy, r * 1.1, r * 1.25, body)
    c.tri((cx - r * 0.7, cy - r), (cx - r * 0.2, cy - r * 1.9), (cx, cy - r * 0.8), body)   # ears
    c.tri((cx + r * 0.7, cy - r), (cx + r * 0.2, cy - r * 1.9), (cx, cy - r * 0.8), body)
    c.dots([(cx - 2, cy - 1), (cx + 2, cy - 1)], RED)
    open_jaw = 1 if anim == "attack" else 0
    c.dots([(cx - 1, cy + 3 + open_jaw), (cx + 1, cy + 3 + open_jaw)], WHITE)  # fangs
    return c


def m_rat(pal, s, anim, t):
    c = Canvas(s)
    fur, belly = pal
    gy = s - 5
    cx = s * 0.46
    bob = [0, 1, 0][t % 3]
    lunge = s * 0.06 * (t + 1) if anim == "attack" else 0
    # tail with wiggle
    wig = [0, 2, -1][t % 3]
    c.limb(cx - s * 0.28, gy - 4, s * 0.06, gy - 8 + wig, 2, darken(fur, 0.15))
    # body
    c.ellipse(cx + lunge, gy - s * 0.13, s * 0.28, s * 0.14 - bob * 0.5, fur)
    c.ellipse(cx + lunge, gy - s * 0.08, s * 0.24, s * 0.08, belly)
    # head
    hx = cx + s * 0.24 + lunge
    hy = gy - s * 0.16 + bob - (2 if anim == "attack" else 0)
    c.tri((hx - 3, hy - 4), (hx - 3, hy + 6), (hx + s * 0.16, hy + 3), fur)
    c.tri((hx - 2, hy - 4), (hx + 2, hy - 9), (hx + 4, hy - 3), fur)   # ear
    c.set(hx + 3, hy - 5, lighten(fur, 0.3))
    c.dots([(hx + 4, hy - 1)], RED)                                    # eye
    c.set(hx + s * 0.16, hy + 3, C("E8A0A8"))                          # nose
    if anim == "attack":
        c.dots([(hx + s * 0.14, hy + 5), (hx + s * 0.14 - 2, hy + 6)], WHITE)  # bared teeth
    for fx in (cx - s * 0.16, cx - s * 0.02, cx + s * 0.14):
        c.rect(fx + lunge, gy - 2, fx + 2 + lunge, gy, darken(fur, 0.3))
    return c


def humanoid(c, s, pal, anim, t, headroom=0.16):
    """Shared bipedal frame for goblins/orcs/skeletons/knights.
    Returns key points dict for decorating hooks."""
    u = s / 64.0
    cx = s * 0.5
    ground = s - 5
    dy = [0, 1, 0][t % 3] if anim == "idle" else 0
    lunge = u * 5 * (t + 1) if anim == "attack" else 0
    skin, torso_c, legs_c = pal["skin"], pal["torso"], pal["legs"]

    head_h = s * headroom
    head_w = s * (headroom + 0.05)
    ty0 = s * 0.34 + dy
    ty1 = s * 0.62 + dy
    tx0 = cx - s * 0.14 + lunge
    tx1 = cx + s * 0.14 + lunge

    back_hand = (tx0 - u * 8, ty0 + s * 0.16)
    if anim == "attack":
        front_hand = [(tx1 + u * 2, ty0 - u * 10), (tx1 + u * 12, ty0 + s * 0.10)][t]
    else:
        front_hand = (tx1 + u * 6, ty0 + s * 0.18)

    # back arm & leg
    c.limb(tx0 + u * 2, ty0 + u * 3, *back_hand, 4 * u, darken(skin, 0.25))
    c.limb(cx - s * 0.07 + lunge, ty1, cx - s * 0.11 + lunge, ground, 5 * u, darken(legs_c, 0.25))
    # torso
    c.rect(tx0, ty0, tx1, ty1, torso_c)
    c.rect(tx0 + 1, ty0 + 1, tx0 + int(u * 3), ty1 - 2, lighten(torso_c, 0.15))
    c.rect(tx0, ty1 - u * 2, tx1, ty1, darken(torso_c, 0.3))
    # front leg
    c.limb(cx + s * 0.07 + lunge, ty1, cx + s * 0.11 + lunge, ground, 5 * u, legs_c)
    for foot_x in (cx - s * 0.11, cx + s * 0.11):
        c.rect(foot_x - u * 2 + lunge, ground - 1, foot_x + u * 3 + lunge, ground + 1, darken(legs_c, 0.4))
    # head
    hx0 = cx - head_w / 2 + lunge + u * 2
    hy0 = ty0 - head_h - u * 2
    c.rect(hx0, hy0, hx0 + head_w, hy0 + head_h, skin)
    # front arm
    c.limb(tx1 - u * 2, ty0 + u * 3, *front_hand, 4 * u, skin)

    return {"u": u, "cx": cx + lunge, "ground": ground, "dy": dy,
            "head": (hx0, hy0, hx0 + head_w, hy0 + head_h),
            "torso": (tx0, ty0, tx1, ty1),
            "front_hand": front_hand, "back_hand": back_hand}


def m_goblin(pal, s, anim, t, warrior=False):
    c = Canvas(s)
    skin = pal[0]
    p = humanoid(c, s, {"skin": skin, "torso": pal[1], "legs": BROWN_DARK}, anim, t)
    hx0, hy0, hx1, hy1 = p["head"]
    u = p["u"]
    # huge ears, hooked nose, toothy grin
    c.tri((hx0, hy0 + u * 4), (hx0 - u * 7, hy0 - u * 2), (hx0, hy0 + u * 8), skin)
    c.tri((hx1, hy0 + u * 4), (hx1 + u * 7, hy0 - u * 2), (hx1, hy0 + u * 8), skin)
    c.dots([(hx1 - u * 4, hy0 + u * 4), (hx1 - u * 8, hy0 + u * 4)], RED)      # eyes
    c.tri((hx1 - u * 2, hy0 + u * 6), (hx1 + u * 2, hy0 + u * 8), (hx1 - u * 2, hy0 + u * 9), darken(skin, 0.25))  # nose
    c.row(hy1 - u * 2, hx0 + u * 3, hx1 - u * 2, BLACK)
    c.dots([(hx0 + u * 4, hy1 - u * 2), (hx0 + u * 8, hy1 - u * 2)], WHITE)     # teeth
    fh = p["front_hand"]
    if warrior:
        c.rect(hx0 - 1, hy0 - u * 3, hx1 + 1, hy0 + u * 2, STEEL_DARK)          # kettle helm
        c.set((hx0 + hx1) / 2, hy0 - u * 4, STEEL)
        # axe
        c.limb(fh[0], fh[1] + u * 6, fh[0] + u * 2, fh[1] - u * 10, 2 * u, BROWN)
        c.tri((fh[0] - u * 2, fh[1] - u * 10), (fh[0] + u * 8, fh[1] - u * 12), (fh[0] + u * 6, fh[1] - u * 2), STEEL)
        # round shield on back hand
        bh = p["back_hand"]
        c.ellipse(bh[0], bh[1], u * 6, u * 6, BROWN)
        c.ellipse(bh[0], bh[1], u * 2, u * 2, STEEL_DARK)
    else:
        c.limb(fh[0], fh[1], fh[0] + u * 7, fh[1] - u * 5, 2, STEEL)            # dagger
        bh = p["back_hand"]
        c.rect(bh[0] - u * 3, bh[1], bh[0] + u * 2, bh[1] + u * 5, BROWN)       # satchel
    return c


def m_skeleton(pal, s, anim, t, armored=False):
    c = Canvas(s)
    bone = pal[0]
    torso = STEEL_DARK if armored else darken(bone, 0.55)
    p = humanoid(c, s, {"skin": bone, "torso": torso, "legs": bone}, anim, t)
    hx0, hy0, hx1, hy1 = p["head"]
    tx0, ty0, tx1, ty1 = p["torso"]
    u = p["u"]
    # skull details
    c.rect(hx0 + u * 3, hy0 + u * 5, hx0 + u * 5, hy0 + u * 8, BLACK)
    c.rect(hx1 - u * 5, hy0 + u * 5, hx1 - u * 3, hy0 + u * 8, BLACK)
    c.set(hx1 - u * 3.5, hy0 + u * 5, RED if armored else C("9FE8FF"))          # eye glow
    c.rect(hx0 + u * 4, hy1 - u * 3, hx1 - u * 4, hy1 - u * 2, bone)            # jaw
    for i in range(3):
        c.col(hx0 + u * (5 + i * 3), hy1 - u * 2, hy1 - u, BLACK)               # teeth gaps
    if armored:
        c.rect(hx0 - 1, hy0 - u * 2, hx1 + 1, hy0 + u * 3, STEEL)               # helm
        c.dots([(tx0 - u * 2, ty0), (tx1 + u * 2, ty0)], STEEL)                 # pauldrons
        c.row(ty0 + u * 4, tx0 + u * 2, tx1 - u * 2, GOLD_DARK)
    else:
        for i in range(3):                                                       # rib arcs
            y = ty0 + u * (4 + i * 5)
            c.row(y, tx0 + u * 2, tx1 - u * 2, bone)
    fh = p["front_hand"]
    if anim == "attack":                                                         # claw swipe arc
        for i, a in enumerate((-0.9, -0.5, -0.1)):
            c.set(round(fh[0] + math.cos(a) * u * 8), round(fh[1] + math.sin(a) * u * 8), C("9FE8FF", 200 - i * 50))
    return c


def m_orc(pal, s, anim, t, brute=False):
    c = Canvas(s)
    skin = pal[0]
    p = humanoid(c, s, {"skin": skin, "torso": pal[1], "legs": BROWN_DARK}, anim, t, headroom=0.18)
    hx0, hy0, hx1, hy1 = p["head"]
    tx0, ty0, tx1, ty1 = p["torso"]
    u = p["u"]
    # widen torso with shoulder wedges
    c.tri((tx0, ty0), (tx0 - u * 5, ty0 + u * 6), (tx0, ty0 + u * 12), skin)
    c.tri((tx1, ty0), (tx1 + u * 5, ty0 + u * 6), (tx1, ty0 + u * 12), skin)
    # face: squint eyes, tusks, topknot
    c.dots([(hx0 + u * 5, hy0 + u * 6), (hx1 - u * 5, hy0 + u * 6)], RED)
    c.row(hy0 + u * 5, hx0 + u * 4, hx1 - u * 4, darken(skin, 0.35))
    c.tri((hx0 + u * 3, hy1), (hx0 + u * 5, hy1 - u * 5), (hx0 + u * 7, hy1), WHITE)
    c.tri((hx1 - u * 3, hy1), (hx1 - u * 5, hy1 - u * 5), (hx1 - u * 7, hy1), WHITE)
    c.rect(hx0 + u * 6, hy0 - u * 3, hx1 - u * 6, hy0, BLACK)                    # topknot
    # chest strap
    c.limb(tx0 + u, ty0 + u * 2, tx1 - u, ty1 - u * 3, 2 * u, BROWN)
    fh = p["front_hand"]
    if brute:
        c.dots([(tx0 - u * 3, ty0 + u * 2), (tx1 + u * 3, ty0 + u * 2)], STEEL_DARK)  # shoulder plate studs
        c.limb(fh[0], fh[1] + u * 4, fh[0] + u * 3, fh[1] - u * 14, 3 * u, BROWN)     # spiked club
        c.ellipse(fh[0] + u * 3, fh[1] - u * 15, u * 5, u * 6, BROWN_DARK)
        for a in range(0, 360, 60):
            c.set(round(fh[0] + u * 3 + math.cos(math.radians(a)) * u * 6),
                  round(fh[1] - u * 15 + math.sin(math.radians(a)) * u * 7), STEEL)
    else:
        c.limb(fh[0], fh[1] + u * 3, fh[0] + u * 2, fh[1] - u * 8, 2 * u, BROWN)      # hand axe
        c.tri((fh[0] - u, fh[1] - u * 8), (fh[0] + u * 7, fh[1] - u * 9), (fh[0] + u * 5, fh[1] - u * 3), STEEL)
    return c


def m_imp(pal, s, anim, t):
    c = Canvas(s)
    skin, accent = pal
    cx, gy = s * 0.5, s - 5
    dy = [0, -2, -1][t % 3]
    lunge = s * 0.06 * (t + 1) if anim == "attack" else 0
    cx += lunge
    # wings
    for side in (-1, 1):
        c.tri((cx + side * s * 0.12, gy - s * 0.36 + dy),
              (cx + side * s * 0.34, gy - s * 0.52 + dy),
              (cx + side * s * 0.2, gy - s * 0.26 + dy), darken(accent, 0.2))
    # tail with spade tip
    c.limb(cx - s * 0.1, gy - s * 0.18, cx - s * 0.3, gy - s * 0.05 + dy, 2, skin)
    c.tri((cx - s * 0.34, gy - s * 0.1 + dy), (cx - s * 0.26, gy - s * 0.06 + dy), (cx - s * 0.3, gy + dy), accent)
    # body + head
    c.ellipse(cx, gy - s * 0.24 + dy, s * 0.14, s * 0.17, skin)
    c.ellipse(cx, gy - s * 0.46 + dy, s * 0.13, s * 0.12, skin)
    c.tri((cx - s * 0.1, gy - s * 0.54 + dy), (cx - s * 0.16, gy - s * 0.66 + dy), (cx - s * 0.04, gy - s * 0.56 + dy), accent)  # horns
    c.tri((cx + s * 0.1, gy - s * 0.54 + dy), (cx + s * 0.16, gy - s * 0.66 + dy), (cx + s * 0.04, gy - s * 0.56 + dy), accent)
    c.dots([(cx - 2, gy - s * 0.47 + dy), (cx + 3, gy - s * 0.47 + dy)], YELLOW)
    c.row(gy - s * 0.42 + dy, cx - 1, cx + 2, BLACK)                              # grin
    # legs
    c.limb(cx - 3, gy - s * 0.1 + dy, cx - 4, gy, 3, darken(skin, 0.25))
    c.limb(cx + 3, gy - s * 0.1 + dy, cx + 4, gy, 3, darken(skin, 0.25))
    if anim == "attack" and t == 1:                                               # hurled ember
        for i in range(3):
            c.ellipse(cx + s * 0.24 + i * 4, gy - s * 0.5, 2 - i * 0.5, 2 - i * 0.5, [YELLOW, ORANGE, C("EE8A32", 120)][i])
    return c


def m_mushroom(pal, s, anim, t):
    c = Canvas(s)
    cap, spot, stem = pal
    cx, gy = s * 0.5, s - 5
    sq = [1.0, 0.92, 0.97][t % 3]
    lean = s * 0.05 * (t + 1) if anim == "attack" else 0
    cap_cy = gy - s * 0.42 * sq
    # stem with grumpy face
    c.rect(cx - s * 0.12, gy - s * 0.34, cx + s * 0.12, gy, stem)
    c.dots([(cx - 3, gy - s * 0.2), (cx + 3, gy - s * 0.2)], BLACK)
    c.row(gy - s * 0.24, cx - 4, cx - 1, darken(stem, 0.4))                       # angry brow
    c.row(gy - s * 0.12, cx - 2, cx + 2, darken(stem, 0.5))                       # frown
    # cap dome
    c.ellipse(cx + lean, cap_cy, s * 0.36, s * 0.2 * sq, cap)
    c.rect(cx - s * 0.36 + lean, cap_cy, cx + s * 0.36 + lean, cap_cy + s * 0.08, cap)
    c.row(cap_cy + s * 0.09, cx - s * 0.3 + lean, cx + s * 0.3 + lean, darken(cap, 0.35))  # gills
    c.dots([(cx - s * 0.18 + lean, cap_cy - 3), (cx + s * 0.1 + lean, cap_cy - s * 0.1),
            (cx + s * 0.24 + lean, cap_cy + 1), (cx - s * 0.02 + lean, cap_cy + 3)], spot)
    if anim == "attack":                                                          # spore puff
        for i in range(4 + t * 2):
            a = i * 1.1 + t
            c.set(round(cx + math.cos(a) * s * (0.2 + 0.05 * i)),
                  round(cap_cy - s * 0.15 - math.sin(a * 0.7) * s * 0.12), C("B98FE0", 200 - i * 22))
    return c


def m_wraith(pal, s, anim, t):
    c = Canvas(s)
    robe, glow = pal
    cx = s * 0.5
    dy = [0, -2, -1][t % 3]
    base = s * 0.86 + dy
    flare = anim == "attack"
    # tapering spectral body with wavy hem
    top = s * 0.24 + dy
    for i, y in enumerate(range(int(top), int(base))):
        prog = i / max(base - top, 1)
        w = s * 0.17 * (1 - prog * 0.55) + math.sin(prog * 9 + t * 2.1) * s * 0.02
        col = robe if prog < 0.75 else C(core_hex(robe), int(255 * (1 - (prog - 0.75) * 3.5)))
        c.row(y, cx - w, cx + w, col)
    # hood
    c.ellipse(cx, top + s * 0.06, s * 0.15, s * 0.12, darken(robe, 0.15))
    c.ellipse(cx + s * 0.03, top + s * 0.08, s * 0.09, s * 0.07, BLACK)           # void face
    eye_y = top + s * 0.07
    c.dots([(cx, eye_y), (cx + s * 0.08, eye_y)], glow)
    if flare:
        c.dots([(cx - 1, eye_y - 1), (cx + s * 0.08 + 1, eye_y - 1)], lighten(glow, 0.4))
    # arms
    reach = -s * 0.1 if not flare else -s * 0.22 - t * 2
    for side in (-1, 1):
        c.limb(cx + side * s * 0.12, top + s * 0.22, cx + side * s * 0.3, top + s * 0.3 + reach * 0.5, 3, robe)
    if flare:                                                                     # aura burst
        r = s * (0.26 + 0.06 * t)
        for a in range(0, 360, 40):
            c.set(round(cx + math.cos(math.radians(a)) * r),
                  round(top + s * 0.2 + math.sin(math.radians(a)) * r * 0.8), C(core_hex(glow), 150))
    return c


def m_golem(pal, s, anim, t, rune=None):
    c = Canvas(s)
    stone = pal[0]
    crack = darken(stone, 0.45)
    cx, gy = s * 0.5, s - 4
    dy = [0, 1, 0][t % 3]
    # legs
    for side in (-1, 1):
        c.rect(cx + side * s * 0.16 - s * 0.06, gy - s * 0.2, cx + side * s * 0.16 + s * 0.06, gy, darken(stone, 0.2))
    # torso: big rounded slab
    ty0 = gy - s * 0.62 + dy
    c.ellipse(cx, ty0 + s * 0.22, s * 0.26, s * 0.24, stone)
    c.rect(cx - s * 0.26, ty0 + s * 0.2, cx + s * 0.26, gy - s * 0.18, stone)
    # arms: boulder shoulders + forearm columns
    raise_arm = anim == "attack"
    for side, is_front in ((-1, False), (1, True)):
        sx = cx + side * s * 0.3
        c.ellipse(sx, ty0 + s * 0.14, s * 0.1, s * 0.1, darken(stone, 0.12) if not is_front else stone)
        if is_front and raise_arm:
            end_y = ty0 - s * 0.12 if t == 0 else ty0 + s * 0.3                  # up, then slammed
            end_x = sx + s * (0.04 if t == 0 else 0.14)
            c.limb(sx, ty0 + s * 0.14, end_x, end_y, s * 0.11, stone)
            c.ellipse(end_x, end_y, s * 0.08, s * 0.07, darken(stone, 0.15))
            if t == 1:
                c.dots([(end_x + s * 0.12, gy - 2), (end_x + s * 0.16, gy - 5), (end_x + s * 0.08, gy - 7)], YELLOW)
        else:
            c.limb(sx, ty0 + s * 0.14, sx + side * s * 0.03, gy - s * 0.06, s * 0.1,
                   darken(stone, 0.12) if not is_front else stone)
            c.ellipse(sx + side * s * 0.03, gy - s * 0.06, s * 0.07, s * 0.06, darken(stone, 0.2))
    # head sunk into shoulders
    c.rect(cx - s * 0.1, ty0 - s * 0.02, cx + s * 0.1, ty0 + s * 0.12, darken(stone, 0.08))
    glow = rune or YELLOW
    c.dots([(cx - s * 0.04, ty0 + s * 0.04), (cx + s * 0.05, ty0 + s * 0.04)], glow)
    # cracks + runes
    c.dots([(cx - s * 0.12, ty0 + s * 0.28), (cx - s * 0.1, ty0 + s * 0.31), (cx - s * 0.08, ty0 + s * 0.34),
            (cx + s * 0.14, ty0 + s * 0.2), (cx + s * 0.16, ty0 + s * 0.24)], crack)
    if rune:
        c.dots([(cx, ty0 + s * 0.26), (cx - s * 0.04, ty0 + s * 0.3), (cx + s * 0.04, ty0 + s * 0.3),
                (cx, ty0 + s * 0.34)], rune)
    return c


def m_dark_knight(pal, s, anim, t):
    c = Canvas(s)
    armor, glow = pal
    p = humanoid(c, s, {"skin": armor, "torso": armor, "legs": darken(armor, 0.15)}, anim, t)
    hx0, hy0, hx1, hy1 = p["head"]
    tx0, ty0, tx1, ty1 = p["torso"]
    u = p["u"]
    # cape
    c.tri((tx0, ty0), (tx0 - u * 9, ty1 + u * 6), (tx0 + u * 2, ty1), RED_DARK)
    # horned helm with glowing visor
    c.rect(hx0 - 1, hy0 - u * 2, hx1 + 1, hy0 + u * 5, darken(armor, 0.1))
    c.tri((hx0, hy0), (hx0 - u * 6, hy0 - u * 8), (hx0 + u * 3, hy0 - u), RED)
    c.tri((hx1, hy0), (hx1 + u * 6, hy0 - u * 8), (hx1 - u * 3, hy0 - u), RED)
    c.row(hy0 + u * 3, hx0 + u * 3, hx1 - u * 3, glow)
    # trim
    c.row(ty0, tx0, tx1, GOLD_DARK)
    fh = p["front_hand"]
    angle = [-2.2, -0.1][t] if anim == "attack" else -math.pi / 2 + 0.3
    sword(c, fh[0], fh[1], angle, 15 * u / 1.0)
    if anim == "attack" and t == 1:
        for i, a in enumerate((-1.3, -0.9, -0.5)):
            c.set(round(fh[0] + math.cos(a) * u * 14), round(fh[1] + math.sin(a) * u * 14), C(core_hex(glow), 190 - i * 50))
    return c


def m_dragon(pal, s, anim, t, elder=False):
    c = Canvas(s)
    scale, belly, wing = pal
    gy = s - 5
    bx, by = s * 0.42, gy - s * 0.2                                    # body center
    breathe = [0, 1, 0][t % 3]
    thrust = anim == "attack"
    # tail with spade
    c.limb(bx - s * 0.2, by, s * 0.08, by + s * 0.12, s * 0.06, scale)
    c.tri((s * 0.03, by + s * 0.08), (s * 0.13, by + s * 0.1), (s * 0.06, by + s * 0.2), darken(scale, 0.2))
    # legs
    for lx in (bx - s * 0.08, bx + s * 0.14):
        c.limb(lx, by + s * 0.1, lx + s * 0.02, gy, s * 0.06, darken(scale, 0.2))
        c.dots([(lx + s * 0.04, gy - 1), (lx + s * 0.06, gy - 1)], WHITE)         # claws
    # body
    c.ellipse(bx, by - breathe * 0.5, s * 0.26, s * 0.15 + breathe * 0.5, scale)
    c.ellipse(bx, by + s * 0.06, s * 0.22, s * 0.08, belly)
    # wing (flaps in idle)
    flap = [-1.0, 0.0, 0.8][t % 3] if anim == "idle" else -0.6
    wx, wy = bx - s * 0.02, by - s * 0.1
    tip = (wx - s * 0.2, wy - s * 0.24 - s * 0.1 * flap)
    c.tri((wx, wy), tip, (wx - s * 0.28, wy + s * 0.02 - s * 0.06 * flap), wing)
    c.limb(wx, wy, *tip, 2, darken(wing, 0.3))
    # neck + head
    hx = bx + s * 0.3 + (s * 0.08 * (t + 1) if thrust else 0)
    hy = by - s * 0.26 + (s * 0.08 if thrust else 0)
    c.limb(bx + s * 0.18, by - s * 0.06, hx - s * 0.04, hy + s * 0.04, s * 0.09, scale)
    c.ellipse(hx, hy, s * 0.11, s * 0.08, scale)
    c.rect(hx + s * 0.06, hy - s * 0.02, hx + s * 0.19, hy + s * 0.03, scale)      # snout
    jaw_drop = s * 0.05 if thrust else 0
    c.rect(hx + s * 0.06, hy + s * 0.04 + jaw_drop, hx + s * 0.16, hy + s * 0.06 + jaw_drop, darken(scale, 0.2))
    c.set(hx + s * 0.08, hy + s * 0.035 + jaw_drop / 2, WHITE)                     # fang
    c.dots([(hx + s * 0.02, hy - s * 0.03)], RED if elder else YELLOW)             # eye
    horn_len = s * (0.12 if elder else 0.08)
    c.tri((hx - s * 0.04, hy - s * 0.06), (hx - s * 0.1, hy - s * 0.06 - horn_len), (hx, hy - s * 0.07), darken(scale, 0.3))
    if elder:
        c.tri((hx + s * 0.01, hy - s * 0.07), (hx - s * 0.03, hy - s * 0.07 - horn_len * 0.7), (hx + s * 0.05, hy - s * 0.08), darken(scale, 0.3))
        for i in range(3):                                                          # back spikes
            spx = bx - s * 0.1 + i * s * 0.12
            c.tri((spx, by - s * 0.13), (spx + s * 0.04, by - s * 0.2), (spx + s * 0.08, by - s * 0.13), darken(scale, 0.25))
    if thrust and t == 1:                                                           # breath
        col = [ORANGE, YELLOW, RED] if elder else [C("9FE8FF"), CYAN, WHITE]
        for i in range(5):
            c.ellipse(hx + s * 0.2 + i * s * 0.05, hy + s * 0.03 + jaw_drop, 2.4 - i * 0.35, 2.0 - i * 0.3, col[i % 3])
    return c


def m_beast(pal, s, anim, t):
    c = Canvas(s)
    fur, mane = pal
    gy = s - 4
    rear = anim == "attack"
    bob = [0, 1, 0][t % 3]
    bx, by = s * 0.42, gy - s * 0.24 + bob
    tilt = -s * 0.08 if rear else 0
    # tail
    c.limb(bx - s * 0.24, by, s * 0.06, by - s * 0.14, 3, fur)
    # back legs
    for lx in (bx - s * 0.18, bx - s * 0.06):
        c.limb(lx, by + s * 0.08, lx - s * 0.02, gy, s * 0.06, darken(fur, 0.25))
    # body slanted up toward chest
    c.ellipse(bx, by, s * 0.28, s * 0.16, fur)
    c.ellipse(bx + s * 0.14, by - s * 0.05 + tilt, s * 0.18, s * 0.15, fur)
    # front legs (rear up when attacking)
    for i, lx in enumerate((bx + s * 0.16, bx + s * 0.26)):
        if rear:
            c.limb(lx, by + tilt, lx + s * 0.1, by - s * 0.1 + tilt + i * 3, s * 0.055, fur)
            c.dots([(lx + s * 0.12, by - s * 0.12 + tilt + i * 3)], WHITE)
        else:
            c.limb(lx, by + s * 0.06, lx + s * 0.01, gy, s * 0.055, fur)
            c.dots([(lx + s * 0.03, gy - 1)], WHITE)                               # claws
    # mane spikes along the back
    for i in range(4):
        mx = bx - s * 0.14 + i * s * 0.11
        my = by - s * 0.14 + tilt * (i / 3)
        c.tri((mx, my), (mx + s * 0.05, my - s * 0.1 - bob), (mx + s * 0.1, my), mane)
    # head with heavy jaw
    hx = bx + s * 0.3
    hy = by - s * 0.16 + tilt
    c.ellipse(hx, hy, s * 0.12, s * 0.1, fur)
    c.rect(hx + s * 0.04, hy, hx + s * 0.2, hy + s * 0.05, fur)                    # muzzle
    jaw = s * 0.06 if rear else s * 0.02
    c.rect(hx + s * 0.04, hy + s * 0.05 + jaw, hx + s * 0.18, hy + s * 0.07 + jaw, darken(fur, 0.25))
    c.dots([(hx + s * 0.07, hy + s * 0.05), (hx + s * 0.13, hy + s * 0.05)], WHITE)  # fangs
    c.dots([(hx + s * 0.02, hy - s * 0.03)], pal[1] if len(pal) > 1 else YELLOW)     # eye
    c.row(hy - s * 0.05, hx - s * 0.02, hx + s * 0.05, darken(fur, 0.4))             # brow
    if rear and t == 1:                                                              # roar marks
        c.dots([(hx + s * 0.24, hy - 2), (hx + s * 0.27, hy + 2), (hx + s * 0.24, hy + 6)], mane)
    return c


# Monster registry: id -> (family fn, palette, canvas size).
# Size tiers must match RPGMonster.displaySize on the Swift side:
# threat <=3 -> 48, threat 4-7 -> 64, threat 8+ -> 80.

MONSTERS = {
    "training_slime":   (m_slime, (C("9BD77A"), C("6FB84E")), 48),
    "tiny_bat":         (m_bat, (GRAY, GRAY_DARK), 48),
    "forest_slime":     (m_slime, (GREEN, GREEN_DARK), 48),
    "cave_bat":         (m_bat, (PURPLE, PURPLE_DARK), 48),
    "goblin_scout":     (lambda p, s, a, t: m_goblin(p, s, a, t), (C("7CB35B"), BROWN), 48),
    "goblin_warrior":   (lambda p, s, a, t: m_goblin(p, s, a, t, warrior=True), (C("6AA34C"), RED_DARK), 64),
    "bone_rat":         (m_rat, (BONE, BONE_DARK), 48),
    "wild_imp":         (m_imp, (C("D96A3A"), BROWN_DARK), 64),
    "skeleton_grunt":   (lambda p, s, a, t: m_skeleton(p, s, a, t), (BONE,), 64),
    "orc_rookie":       (lambda p, s, a, t: m_orc(p, s, a, t), (C("8A9E4A"), BROWN), 64),
    "cursed_mushroom":  (m_mushroom, (PURPLE, C("C9A6E8"), C("E2D6BC")), 64),
    "orc_brute":        (lambda p, s, a, t: m_orc(p, s, a, t, brute=True), (C("5F7A35"), RED_DARK), 64),
    "wraith":           (m_wraith, (C("93A9CC"), CYAN), 64),
    "stone_golem":      (m_golem, (GRAY,), 64),
    "armored_skeleton": (lambda p, s, a, t: m_skeleton(p, s, a, t, armored=True), (BONE,), 64),
    "fire_imp":         (m_imp, (RED, ORANGE), 64),
    "hill_golem":       (lambda p, s, a, t: m_golem(p, s, a, t, rune=GREEN), (C("8F7E58"),), 80),
    "demon_knight":     (m_dark_knight, (C("3A3547"), RED), 80),
    "frost_wraith":     (m_wraith, (C("AEDCEF"), WHITE), 80),
    "dragonling":       (m_dragon, (GREEN, C("D9E8A8"), GREEN_DARK), 80),
    "ancient_golem":    (lambda p, s, a, t: m_golem(p, s, a, t, rune=GOLD), (C("53807E"),), 80),
    "abyss_wraith":     (m_wraith, (PURPLE_DARK, C("E070E0")), 80),
    "elder_dragonling": (lambda p, s, a, t: m_dragon(p, s, a, t, elder=True), (GOLD_DARK, YELLOW, C("8E6A14")), 80),
    "infernal_beast":   (m_beast, (C("3A2C31"), ORANGE), 80),
}


def render_enemy_frames(name, fn, pal, size, frames=MONSTER_FRAMES, prefix="rpg_monster"):
    count = 0
    for t in range(frames["idle"]):
        write_imageset(f"{prefix}_{name}_idle{t}", finish(fn(pal, size, "idle", t % 3)))
        count += 1
    for t in range(frames["attack"]):
        write_imageset(f"{prefix}_{name}_attack{t}", finish(fn(pal, size, "attack", min(t, 1))))
        count += 1
    base = finish(fn(pal, size, "idle", 0))
    for t in range(frames["hit"]):
        write_imageset(f"{prefix}_{name}_hit{t}", shift(squash(base, 0.92), -3))
        count += 1
    n = frames["defeat"]
    for t in range(n):
        prog = (t + 1) / n
        write_imageset(f"{prefix}_{name}_defeat{t}", fade(squash(base, 1 - prog * 0.75), 1 - prog * 0.7))
        count += 1
    return count


# ═══════════════════════════════ BOSSES ═══════════════════════════════
#
# 128x128, built on the family templates with extra regalia so silhouettes
# read as "the big one". idle 4 / attack 4 / defeat 5.

def boss_idle_t(t):
    return [0, 1, 2, 1][t % 4]


def boss_attack_t(t):
    return [0, 0, 1, 1][t % 4]


def boss_goblin_captain(anim, t):
    s = 128
    tt = boss_idle_t(t) if anim == "idle" else boss_attack_t(t)
    c = Canvas(s)
    m_goblin((C("6AA34C"), STEEL_DARK), s, "idle" if anim == "idle" else "attack", tt, warrior=True)
    # redraw at boss scale with extra regalia on top of the warrior template
    base = m_goblin((C("6AA34C"), STEEL_DARK), s, "idle" if anim == "idle" else "attack", tt, warrior=True)
    c.px = base.px
    # commander's banner spear on the back
    c.limb(s * 0.16, s * 0.16, s * 0.13, s * 0.78, 4, BROWN)
    c.tri((s * 0.11, s * 0.16), (s * 0.2, s * 0.16), (s * 0.155, s * 0.06), STEEL)
    c.rect(s * 0.17, s * 0.18, s * 0.3, s * 0.3, RED)
    c.rect(s * 0.17, s * 0.18, s * 0.3, s * 0.2, GOLD_DARK)
    # iron pauldron studs + crown spikes on helm
    c.dots([(s * 0.38, s * 0.14), (s * 0.45, s * 0.11), (s * 0.52, s * 0.14)], GOLD)
    return c


def boss_bone_colossus(anim, t):
    s = 128
    tt = boss_idle_t(t) if anim == "idle" else boss_attack_t(t)
    base = m_skeleton((BONE,), s, "idle" if anim == "idle" else "attack", tt, armored=False)
    # massive shoulder bones + cracked crown
    base.ellipse(s * 0.24, s * 0.36, s * 0.09, s * 0.07, BONE)
    base.ellipse(s * 0.74, s * 0.36, s * 0.09, s * 0.07, BONE)
    base.tri((s * 0.42, s * 0.16), (s * 0.46, s * 0.06), (s * 0.5, s * 0.16), BONE_DARK)
    base.tri((s * 0.52, s * 0.16), (s * 0.56, s * 0.08), (s * 0.6, s * 0.16), BONE_DARK)
    base.dots([(s * 0.47, s * 0.24), (s * 0.5, s * 0.27)], darken(BONE, 0.5))      # skull crack
    return base


def boss_storm_wyvern(anim, t):
    s = 128
    tt = boss_idle_t(t) if anim == "idle" else boss_attack_t(t)
    base = m_dragon((C("4A78C8"), C("A8C8F0"), C("2C4A88")), s, "idle" if anim == "idle" else "attack", tt)
    # crackling storm charge
    positions = [(s * 0.2, s * 0.2), (s * 0.75, s * 0.3), (s * 0.6, s * 0.12), (s * 0.35, s * 0.36)]
    for i, (lx, ly) in enumerate(positions[:2 + (t % 3)]):
        base.limb(lx, ly, lx + 3, ly + 6, 1, YELLOW)
        base.limb(lx + 3, ly + 6, lx + 1, ly + 10, 1, YELLOW)
    return base


def boss_infernal_champion(anim, t):
    s = 128
    tt = boss_idle_t(t) if anim == "idle" else boss_attack_t(t)
    base = m_dark_knight((C("46242F"), ORANGE), s, "idle" if anim == "idle" else "attack", tt)
    # flame wisps rising off the armor, cycling with t
    for i in range(4):
        fx = s * (0.3 + 0.14 * i)
        fy = s * 0.3 - ((t + i) % 4) * 3
        base.set(fx, fy, [ORANGE, YELLOW, RED, ORANGE][(t + i) % 4])
        base.set(fx + 1, fy + 3, C("EE8A32", 150))
    return base


def boss_ancient_dragon(anim, t):
    s = 128
    tt = boss_idle_t(t) if anim == "idle" else boss_attack_t(t)
    base = m_dragon((GOLD_DARK, YELLOW, C("8E6A14")), s, "idle" if anim == "idle" else "attack", tt, elder=True)
    # gilded chest glow + drifting embers
    base.dots([(s * 0.4, s * 0.66), (s * 0.44, s * 0.68), (s * 0.48, s * 0.66)], YELLOW)
    for i in range(3):
        base.set(s * (0.2 + 0.25 * i), s * 0.16 + ((t + i) % 4) * 2, C("F7E15E", 170))
    return base


BOSSES = {
    "iron_goblin_captain": boss_goblin_captain,
    "bone_colossus": boss_bone_colossus,
    "storm_wyvern": boss_storm_wyvern,
    "infernal_champion": boss_infernal_champion,
    "ancient_dragon": boss_ancient_dragon,
}


def render_boss_frames(name, fn):
    count = 0
    for t in range(BOSS_FRAMES["idle"]):
        write_imageset(f"rpg_boss_{name}_idle{t}", finish(fn("idle", t)))
        count += 1
    for t in range(BOSS_FRAMES["attack"]):
        write_imageset(f"rpg_boss_{name}_attack{t}", finish(fn("attack", t)))
        count += 1
    base = finish(fn("idle", 0))
    n = BOSS_FRAMES["defeat"]
    for t in range(n):
        prog = (t + 1) / n
        write_imageset(f"rpg_boss_{name}_defeat{t}", fade(squash(base, 1 - prog * 0.8), 1 - prog * 0.75))
        count += 1
    return count


# ═══════════════════════════════ ICONS (48x48) ═══════════════════════════════

def icon_canvas():
    return Canvas(48)


def icon_sword():
    c = icon_canvas()
    c.limb(24, 6, 24, 27, 5, STEEL)
    c.col(24, 7, 26, lighten(STEEL, 0.45))                              # fuller
    c.tri((21, 5), (27, 5), (24, 2), STEEL)                             # tip
    c.rect(15, 28, 32, 30, GOLD)
    c.dots([(16, 29), (31, 29)], GOLD_DARK)
    c.limb(24, 31, 24, 39, 4, BROWN)
    c.dither(22, 31, 26, 39, BROWN_DARK)
    c.ellipse(24, 42, 3, 3, GOLD)
    return c


def icon_axe():
    c = icon_canvas()
    c.limb(24, 8, 24, 42, 4, BROWN)
    c.dither(22, 10, 26, 40, BROWN_DARK)
    for side in (-1, 1):                                                # dumbbell-plate blades
        c.ellipse(24 + side * 10, 14, 7, 9, STEEL)
        c.ellipse(24 + side * 10, 14, 3, 5, STEEL_DARK)
    c.rect(20, 12, 28, 16, STEEL)
    c.row(43, 21, 27, GOLD_DARK)
    return c


def icon_bow():
    c = icon_canvas()
    for i in range(-15, 16):
        bulge = math.sqrt(max(0.0, 1 - (i / 15) ** 2)) * 10
        c.set(round(16 + bulge), 24 + i, BROWN)
        c.set(round(16 + bulge) + 1, 24 + i, BROWN_DARK)
    c.col(15, 10, 38, C("E4DCC4"))                                      # string
    c.limb(16, 24, 38, 24, 2, STEEL)                                    # arrow
    c.tri((38, 21), (38, 27), (43, 24), lighten(STEEL, 0.4))
    c.dots([(17, 21), (17, 27), (19, 24)], RED)                         # fletching
    return c


def icon_staff():
    c = icon_canvas()
    c.limb(24, 14, 24, 44, 4, BROWN)
    c.dots([(22, 22), (26, 30), (22, 36)], BROWN_DARK)
    c.ellipse(24, 9, 6, 6, CYAN)
    c.ellipse(22, 7, 2, 2, WHITE)
    for a in range(0, 360, 45):
        c.set(round(24 + math.cos(math.radians(a)) * 9),
              round(9 + math.sin(math.radians(a)) * 9), C("5FD0EE", 130))
    return c


def icon_daggers():
    c = icon_canvas()
    for (bx, tilt) in ((16, -0.25), (32, 0.25)):
        ex, ey = bx + tilt * 20, 8
        c.limb(bx, 26, ex, ey, 3, STEEL)
        c.limb(bx, 24, ex, ey + 2, 1, lighten(STEEL, 0.45))
        c.limb(bx - 5, 28, bx + 5, 28, 2, GOLD_DARK)
        c.limb(bx, 29, bx - tilt * 8, 38, 3, BROWN_DARK)
    return c


def icon_armor(main, trim):
    c = icon_canvas()
    c.rect(10, 12, 16, 20, main)                                        # pauldrons
    c.rect(32, 12, 38, 20, main)
    c.rect(14, 10, 34, 40, main)
    c.tri((14, 40), (24, 44), (34, 40), main)
    c.rect(20, 8, 28, 12, darken(main, 0.35))                           # collar
    c.col(24, 14, 40, darken(main, 0.3))                                # center seam
    c.row(26, 15, 33, trim)                                             # belt line
    c.dots([(18, 16), (30, 16)], lighten(main, 0.3))
    c.row(41, 16, 32, trim)
    return c


def icon_vest():
    c = icon_canvas()
    c.rect(13, 10, 35, 42, GRAY_DARK)
    c.rect(19, 8, 29, 16, BLACK)                                        # neck opening
    for (px, py) in ((16, 18), (28, 18), (16, 30), (28, 30)):
        c.rect(px, py, px + 6, py + 8, GRAY)                            # weight pockets
        c.row(py + 1, px + 1, px + 5, lighten(GRAY, 0.25))
    c.col(24, 17, 42, darken(GRAY_DARK, 0.3))                           # zipper
    return c


def icon_robe():
    c = icon_canvas()
    c.rect(18, 6, 30, 14, PURPLE_DARK)                                  # hood
    c.rect(15, 15, 33, 30, PURPLE)
    c.tri((15, 30), (10, 43), (24, 43), PURPLE)
    c.tri((33, 30), (38, 43), (24, 43), PURPLE)
    c.col(24, 15, 42, GOLD_DARK)                                        # trim
    c.row(43, 12, 36, GOLD_DARK)
    c.dots([(19, 22), (29, 34)], GOLD)                                  # stars
    return c


def icon_power_strike():
    c = icon_canvas()
    c.limb(10, 38, 32, 16, 4, STEEL)
    c.limb(12, 36, 30, 18, 1, lighten(STEEL, 0.5))
    c.limb(8, 44, 13, 39, 3, BROWN)
    for r, col in ((10, GOLD), (6, YELLOW)):
        for a in range(0, 360, 45):
            c.set(round(36 + math.cos(math.radians(a)) * r),
                  round(12 + math.sin(math.radians(a)) * r), col)
    c.ellipse(36, 12, 3, 3, WHITE)
    return c


def icon_quick_shot():
    c = icon_canvas()
    for i, off in enumerate((0, 7)):
        y = 18 + off
        c.limb(8, y + 12, 34, y - 4, 2, BROWN if i == 0 else BROWN_DARK)
        c.tri((34, y - 6), (34, y - 1), (39, y - 4), STEEL)
        c.dots([(10, y + 10), (13, y + 12)], RED)
    c.dots([(20, 12), (26, 9), (16, 16)], C("5FD0EE", 170))              # speed lines
    return c


def icon_firebolt():
    c = icon_canvas()
    c.ellipse(24, 30, 10, 12, ORANGE)
    c.tri((16, 26), (24, 4), (32, 26), ORANGE)
    c.ellipse(24, 32, 5, 8, YELLOW)
    c.tri((20, 28), (24, 14), (28, 28), YELLOW)
    c.ellipse(24, 36, 2, 4, WHITE)
    c.dots([(13, 20), (36, 24), (33, 12)], C("EE8A32", 170))             # sparks
    c.row(43, 18, 30, RED)
    return c


def icon_heal_pulse():
    c = icon_canvas()
    c.rect(19, 10, 29, 38, GREEN)
    c.rect(10, 19, 38, 29, GREEN)
    c.rect(21, 12, 23, 36, lighten(GREEN, 0.3))
    c.rect(12, 21, 36, 23, lighten(GREEN, 0.3))
    for a in range(0, 360, 30):
        c.set(round(24 + math.cos(math.radians(a)) * 19),
              round(24 + math.sin(math.radians(a)) * 19), C("4CA852", 140))
    return c


def icon_shadow_dash():
    c = icon_canvas()
    c.tri((24, 10), (24, 38), (42, 24), PURPLE)
    c.tri((27, 15), (27, 33), (38, 24), lighten(PURPLE, 0.2))
    for i, x in enumerate((6, 11, 16)):
        c.rect(x, 18 + i * 2, x + 3, 30 - i * 2, C("58397E", 180 - i * 45))
    return c


def icon_iron_guard():
    c = icon_canvas()
    c.rect(12, 8, 36, 28, STEEL)
    c.tri((12, 28), (24, 42), (36, 28), STEEL)
    c.rect(12, 8, 36, 10, GOLD_DARK)
    c.col(12, 8, 30, GOLD_DARK)
    c.col(36, 8, 30, GOLD_DARK)
    c.rect(22, 12, 26, 32, GOLD)                                        # center stripe
    c.dots([(16, 13), (32, 13)], lighten(STEEL, 0.4))
    return c


def icon_endurance_aura():
    c = icon_canvas()
    for r, col in ((19, GOLD), (14, C("F4C542", 150))):
        for a in range(0, 360, 20):
            c.set(round(24 + math.cos(math.radians(a)) * r),
                  round(24 + math.sin(math.radians(a)) * r), col)
    c.ellipse(24, 24, 7, 7, GREEN)
    c.ellipse(24, 24, 3, 3, YELLOW)
    c.set(22, 21, WHITE)
    return c


def icon_boss_breaker():
    c = icon_canvas()
    c.rect(20, 6, 40, 18, STEEL_DARK)                                   # hammer head
    c.rect(20, 6, 40, 9, STEEL)
    c.rect(18, 8, 20, 16, GOLD_DARK)
    c.limb(22, 20, 8, 40, 4, BROWN)
    c.dither(10, 22, 20, 38, BROWN_DARK)
    for i, (dx, dy) in enumerate(((4, 2), (7, 6), (5, 10))):            # crack burst
        c.limb(40 + dx - 4, 20 + dy - 3, 40 + dx, 20 + dy, 1, GOLD)
    c.dots([(36, 24), (33, 29)], RED)
    return c


ICONS = {
    "rpg_equip_training_sword": icon_sword,
    "rpg_equip_iron_dumbbell_axe": icon_axe,
    "rpg_equip_runners_bow": icon_bow,
    "rpg_equip_focus_staff": icon_staff,
    "rpg_equip_shadow_daggers": icon_daggers,
    "rpg_equip_beginner_armor": lambda: icon_armor(BROWN, GOLD_DARK),
    "rpg_equip_weighted_vest": icon_vest,
    "rpg_equip_heroic_chestplate": lambda: icon_armor(GOLD, STEEL),
    "rpg_equip_mystic_robe": icon_robe,
    "rpg_skill_power_strike": icon_power_strike,
    "rpg_skill_quick_shot": icon_quick_shot,
    "rpg_skill_firebolt": icon_firebolt,
    "rpg_skill_heal_pulse": icon_heal_pulse,
    "rpg_skill_shadow_dash": icon_shadow_dash,
    "rpg_skill_iron_guard": icon_iron_guard,
    "rpg_skill_endurance_aura": icon_endurance_aura,
    "rpg_skill_boss_breaker": icon_boss_breaker,
}


# ═══════════════════════════════ BACKGROUNDS ═══════════════════════════════
#
# 480x270 scenes composed from 32px tile stamps.

TILE = 32


def stamp_cloud(c, x, y, w):
    c.ellipse(x, y, w * 0.5, 5, WHITE)
    c.ellipse(x - w * 0.3, y + 2, w * 0.28, 4, WHITE)
    c.ellipse(x + w * 0.32, y + 2, w * 0.3, 4, lighten(C("D8E8F4"), 0.2))


def stamp_tree(c, x, base_y, scale=1.0, leaf=GREEN_DARK):
    trunk_h = int(14 * scale)
    c.rect(x - 2, base_y - trunk_h, x + 2, base_y, BROWN_DARK)
    c.col(x - 1, base_y - trunk_h, base_y, BROWN)
    c.ellipse(x, base_y - trunk_h - 10 * scale, 13 * scale, 11 * scale, leaf)
    c.ellipse(x - 6 * scale, base_y - trunk_h - 5 * scale, 8 * scale, 7 * scale, leaf)
    c.ellipse(x + 7 * scale, base_y - trunk_h - 6 * scale, 8 * scale, 7 * scale, darken(leaf, 0.12))
    c.ellipse(x - 3 * scale, base_y - trunk_h - 14 * scale, 6 * scale, 5 * scale, lighten(leaf, 0.15))


def background_field():
    w, h = 480, 270
    c = Canvas(w, h)
    # sky gradient bands
    for i, col in enumerate((C("7EBEE8"), C("8EC8EC"), C("9ED2F0"), C("B2DEF4"), C("C6E8F8"))):
        c.rect(0, i * 26, w - 1, i * 26 + 25, col)
    c.rect(0, 130, w - 1, 160, C("D4EEFA"))
    # sun with rays
    c.ellipse(396, 34, 16, 16, GOLD)
    c.ellipse(392, 30, 5, 5, YELLOW)
    for a in range(0, 360, 45):
        c.set(round(396 + math.cos(math.radians(a)) * 21),
              round(34 + math.sin(math.radians(a)) * 21), C("F7E15E", 200))
    stamp_cloud(c, 70, 40, 40)
    stamp_cloud(c, 200, 66, 30)
    stamp_cloud(c, 320, 28, 36)
    stamp_cloud(c, 450, 80, 26)
    # far hills
    for i in range(16):
        top = 140 + int(math.sin(i * 1.1) * 10)
        c.rect(i * TILE, top, i * TILE + TILE - 1, 190, C("6FA86F"))
        c.ellipse(i * TILE + 16, top, 22, 12, C("6FA86F"))
    # near hills, darker
    for i in range(16):
        top = 168 + int(math.sin(i * 0.8 + 2.4) * 8)
        c.rect(i * TILE, top, i * TILE + TILE - 1, 200, C("4E8A4E"))
        c.ellipse(i * TILE + 16, top, 22, 10, C("4E8A4E"))
    c.rect(0, 196, w - 1, 200, C("3A6B3A"))
    # tree line
    stamp_tree(c, 60, 208, 1.2)
    stamp_tree(c, 150, 204, 0.9)
    stamp_tree(c, 290, 207, 1.3)
    stamp_tree(c, 400, 205, 1.0)
    stamp_tree(c, 455, 208, 0.8)
    # grass field with tufts and flowers
    c.rect(0, 200, w - 1, 234, C("58A84E"))
    for x in range(0, w, 7):
        ty = 205 + (x * 13 % 26)
        c.set(x + (x % 3), ty, C("3F8A38"))
        c.set(x + (x % 3), ty - 1, C("6FBE62"))
    for x in range(12, w, 53):
        c.dots([(x, 210 + (x % 17)), (x + 1, 209 + (x % 17))], [GOLD, WHITE, C("E070A0")][x % 3])
    # walking path
    c.rect(0, 234, w - 1, 238, C("3F8A38"))
    c.rect(0, 238, w - 1, h - 1, C("7A5A38"))
    c.rect(0, 238, w - 1, 240, C("8F6C44"))
    for x in range(0, w, 9):
        c.set(x + (x % 5), 244 + (x * 7 % 22), C("5C4228"))
        if x % 27 == 0:
            c.ellipse(x + 4, 252 + (x % 12), 3, 2, C("6B4E30"))          # stones
    return c


def background_boss():
    w, h = 480, 270
    c = Canvas(w, h)
    for i, col in enumerate((C("221838"), C("2A1E42"), C("32244C"), C("3C2C58"), C("463560"))):
        c.rect(0, i * 26, w - 1, i * 26 + 25, col)
    c.rect(0, 130, w - 1, 160, C("523E6A"))
    # moon + stars
    c.ellipse(392, 36, 15, 15, C("E8E2C8"))
    c.ellipse(387, 32, 5, 5, WHITE)
    c.ellipse(398, 42, 3, 3, C("C8C2A8"))
    for (sx, sy) in ((30, 20), (90, 48), (150, 14), (210, 60), (260, 30),
                     (330, 70), (360, 18), (440, 55), (470, 24), (120, 84)):
        c.set(sx, sy, WHITE)
        if sx % 60 == 0:
            c.dots([(sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], C("F4F5FA", 120))
    # jagged obsidian spires, two depths
    for i in range(12):
        bx = i * 40 + 8
        peak = 120 + (i * 29 % 40)
        c.tri((bx, 208), (bx + 34, 208), (bx + 15 + (i % 7), peak), C("3A3244"))
    for i in range(14):
        bx = i * 34
        peak = 158 + (i * 17 % 30)
        c.tri((bx, 212), (bx + 30, 212), (bx + 12 + (i % 9), peak), C("2A2433"))
        c.set(bx + 13, peak + 6, C("E070E0", 160))                       # glowing veins
    c.rect(0, 208, w - 1, 212, C("28222F"))
    # scorched ground
    c.rect(0, 212, w - 1, 236, C("4A3A50"))
    for x in range(0, w, 6):
        c.set(x + (x % 4), 216 + (x * 11 % 18), C("332838"))
    c.rect(0, 236, w - 1, h - 1, C("332838"))
    # glowing cracks
    for x in range(10, w, 44):
        c.limb(x, 244 + (x % 10), x + 9, 248 + (x % 10), 1, C("E070E0", 150))
        c.limb(x + 9, 248 + (x % 10), x + 15, 244 + (x % 10), 1, C("B850B8", 120))
    return c


# ═══════════════════════════════════ MAIN ═══════════════════════════════════

def main():
    # wipe and regenerate everything for consistency
    if os.path.isdir(ASSETS_DIR):
        shutil.rmtree(ASSETS_DIR)
    os.makedirs(ASSETS_DIR)
    with open(os.path.join(ASSETS_DIR, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")

    count = 0
    for cls, builder in HERO_BUILDERS.items():
        for anim, frames in HERO_FRAMES.items():
            for t in range(frames):
                write_imageset(f"rpg_class_{cls}_{anim}{t}", finish(builder(anim, t)))
                count += 1
    for name, (fn, pal, size) in MONSTERS.items():
        count += render_enemy_frames(name, fn, pal, size)
    for name, fn in BOSSES.items():
        count += render_boss_frames(name, fn)
    for name, builder in ICONS.items():
        write_imageset(name, finish(builder()))
        count += 1
    write_imageset("rpg_bg_field", background_field(), scale=BG_SCALE)
    write_imageset("rpg_bg_boss", background_boss(), scale=BG_SCALE)
    count += 2

    print(f"Generated {count} imagesets in {ASSETS_DIR}")


if __name__ == "__main__":
    main()
