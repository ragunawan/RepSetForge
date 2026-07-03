#!/usr/bin/env python3
"""Generates a pixel-art placeholder AppIcon.png for RepSetForge.

TODO: replace with a real hand-drawn pixel art icon before shipping.
This script only exists to produce a checked-in placeholder asset.
"""

import struct
import zlib
import os

GRID = 16       # logical pixel-art grid size
SCALE = 64      # upscale factor -> 1024x1024 output
SIZE = GRID * SCALE

NAVY   = (0x12, 0x12, 0x1F)
GOLD   = (0xFF, 0xD1, 0x3C)
SILVER = (0xE8, 0xEC, 0xF1)
BROWN  = (0x5B, 0x3A, 0x1E)
GREEN  = (0x3D, 0xD9, 0x6B)

def build_grid():
    grid = [[NAVY for _ in range(GRID)] for _ in range(GRID)]

    # Outer pixel border
    for i in range(GRID):
        grid[0][i] = GOLD
        grid[GRID - 1][i] = GOLD
        grid[i][0] = GOLD
        grid[i][GRID - 1] = GOLD

    # Inner accent border (green), one pixel in
    for i in range(2, GRID - 2):
        grid[1][i] = GREEN
        grid[GRID - 2][i] = GREEN
        grid[i][1] = GREEN
        grid[i][GRID - 2] = GREEN

    # Sword blade (silver), vertical, rows 2-9, col 7-8
    for r in range(2, 10):
        grid[r][7] = SILVER
        grid[r][8] = SILVER

    # Crossguard (gold), row 10, col 4-11
    for c in range(4, 12):
        grid[10][c] = GOLD

    # Grip (brown), rows 11-13, col 7-8
    for r in range(11, 14):
        grid[r][7] = BROWN
        grid[r][8] = BROWN

    # Pommel (gold), row 14, col 6-9
    for c in range(6, 10):
        grid[14][c] = GOLD

    return grid


def upscale(grid):
    rows = []
    for r in range(GRID):
        row_pixels = []
        for c in range(GRID):
            row_pixels.extend([grid[r][c]] * SCALE)
        rows.extend([row_pixels] * SCALE)
    return rows


def write_png(path, rows):
    width = len(rows[0])
    height = len(rows)

    raw = bytearray()
    for row in rows:
        raw.append(0)  # filter type: None
        for (r, g, b) in row:
            raw.extend((r, g, b))

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)

    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    grid = build_grid()
    rows = upscale(grid)
    out = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "..", "RepSetForge", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png",
    )
    out = os.path.normpath(out)
    write_png(out, rows)
    print(f"Generated: {out} ({SIZE}x{SIZE})")
