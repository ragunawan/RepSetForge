#!/usr/bin/env python3
"""Deprecated RPG art generator.

SetCraft's RPG art is now manually generated/imported chibi art. This file is
kept only so old commands fail with a useful message instead of silently
recreating procedural placeholder assets.

Use:
    python3 scripts/import_rpg_art.py
"""

import sys


def main():
    print("Procedural RPG art generation is disabled.")
    print("Generate finished PNG art manually, save it in ArtSource/RPG/incoming/, then run:")
    print("  python3 scripts/import_rpg_art.py")
    print("See ArtSource/RPG/README.md for exact sizes, counts, filenames, and format rules.")
    sys.exit(1)


if __name__ == "__main__":
    main()
