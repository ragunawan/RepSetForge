#!/usr/bin/env python3
"""Import manually generated RPG art into the Xcode asset catalog.

This project no longer uses procedural placeholder art for the RPG layer.
Create finished chibi PNGs, save them flat in ArtSource/RPG/incoming/ with
the exact manifest filenames, then run this script from the repo root:

    python3 scripts/import_rpg_art.py

The script validates filename, dimensions, and PNG format, then writes each
accepted file into SetCraft/Assets.xcassets/RPG/<name>.imageset/.
"""

import json
import os
import struct
import sys

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ASSETS_DIR = os.path.join(REPO_ROOT, "SetCraft", "Assets.xcassets", "RPG")
ART_SOURCE_DIR = os.path.join(REPO_ROOT, "ArtSource", "RPG")
INCOMING_DIR = os.path.join(ART_SOURCE_DIR, "incoming")
HANDMADE_MANIFEST = os.path.join(ART_SOURCE_DIR, "handmade_manifest.json")

SPRITE_SCALE = 4
BG_SCALE = 2

HERO_FRAMES = {"idle": 4, "walk": 4, "attack": 3, "cast": 3, "defend": 2, "sitting": 4}
MONSTER_FRAMES = {"idle": 3, "attack": 2, "hit": 1, "defeat": 3}
BOSS_FRAMES = {"idle": 4, "attack": 4, "defeat": 5}

HERO_CLASSES = ["knight", "ranger", "mage", "monk", "rogue"]

MONSTERS_48 = ["training_slime", "tiny_bat", "forest_slime", "cave_bat", "goblin_scout", "bone_rat"]
MONSTERS_64 = [
    "goblin_warrior", "wild_imp", "skeleton_grunt", "orc_rookie", "cursed_mushroom",
    "orc_brute", "wraith", "stone_golem", "armored_skeleton", "fire_imp",
]
MONSTERS_80 = [
    "hill_golem", "demon_knight", "frost_wraith", "dragonling", "ancient_golem",
    "abyss_wraith", "elder_dragonling", "infernal_beast",
]
MONSTER_SIZES = {name: 48 for name in MONSTERS_48}
MONSTER_SIZES.update({name: 64 for name in MONSTERS_64})
MONSTER_SIZES.update({name: 80 for name in MONSTERS_80})

BOSSES = ["iron_goblin_captain", "bone_colossus", "storm_wyvern", "infernal_champion", "ancient_dragon"]

EQUIPMENT = [
    "training_sword", "iron_dumbbell_axe", "runners_bow", "focus_staff", "shadow_daggers",
    "beginner_armor", "weighted_vest", "heroic_chestplate", "mystic_robe",
]

SKILLS = [
    "power_strike", "quick_shot", "firebolt", "heal_pulse", "shadow_dash",
    "iron_guard", "endurance_aura", "boss_breaker",
]

BACKGROUNDS = [
    "field", "forest", "forest_night", "cave", "mountain_pass",
    "dungeon_corridor", "ruined_castle", "boss", "boss_ruins",
]


def build_manifest():
    """Return name -> expected import spec."""
    manifest = {}

    side = 64 * SPRITE_SCALE
    for cls in HERO_CLASSES:
        for anim, frames in HERO_FRAMES.items():
            for frame in range(frames):
                manifest[f"rpg_class_{cls}_{anim}{frame}"] = {
                    "category": "hero", "width": side, "height": side,
                }

    for monster_id, native_size in MONSTER_SIZES.items():
        side = native_size * SPRITE_SCALE
        for anim, frames in MONSTER_FRAMES.items():
            for frame in range(frames):
                manifest[f"rpg_monster_{monster_id}_{anim}{frame}"] = {
                    "category": "monster", "width": side, "height": side,
                }

    side = 128 * SPRITE_SCALE
    for boss_id in BOSSES:
        for anim, frames in BOSS_FRAMES.items():
            for frame in range(frames):
                manifest[f"rpg_boss_{boss_id}_{anim}{frame}"] = {
                    "category": "boss", "width": side, "height": side,
                }

    side = 48 * SPRITE_SCALE
    for item_id in EQUIPMENT:
        manifest[f"rpg_equip_{item_id}"] = {"category": "equipment", "width": side, "height": side}
    for skill_id in SKILLS:
        manifest[f"rpg_skill_{skill_id}"] = {"category": "skill", "width": side, "height": side}

    for bg_id in BACKGROUNDS:
        manifest[f"rpg_bg_{bg_id}"] = {
            "category": "background", "width": 480 * BG_SCALE, "height": 270 * BG_SCALE,
        }

    return manifest


def load_imported_names():
    if os.path.exists(HANDMADE_MANIFEST):
        with open(HANDMADE_MANIFEST) as f:
            return set(json.load(f))
    return set()


def save_imported_names(names):
    os.makedirs(ART_SOURCE_DIR, exist_ok=True)
    with open(HANDMADE_MANIFEST, "w") as f:
        json.dump(sorted(names), f, indent=2)
        f.write("\n")


def read_png_header(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    if len(data) < 33 or data[12:16] != b"IHDR":
        return None
    width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", data[16:29])
    return width, height, bit_depth, color_type, compression, filter_method, interlace


def write_imageset(name, png_bytes):
    directory = os.path.join(ASSETS_DIR, f"{name}.imageset")
    os.makedirs(directory, exist_ok=True)
    with open(os.path.join(directory, f"{name}.png"), "wb") as f:
        f.write(png_bytes)
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(directory, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")


def existing_imageset_names():
    if not os.path.isdir(ASSETS_DIR):
        return set()
    names = set()
    for entry in os.listdir(ASSETS_DIR):
        if not entry.endswith(".imageset"):
            continue
        name = entry[:-len(".imageset")]
        png_path = os.path.join(ASSETS_DIR, entry, f"{name}.png")
        if os.path.exists(png_path):
            names.add(name)
    return names


def main():
    os.makedirs(INCOMING_DIR, exist_ok=True)
    os.makedirs(ASSETS_DIR, exist_ok=True)
    with open(os.path.join(ASSETS_DIR, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")

    manifest = build_manifest()
    imported_names = load_imported_names()
    imported, errors, unrecognized = [], [], []

    incoming_files = sorted(f for f in os.listdir(INCOMING_DIR) if f.lower().endswith(".png"))
    for filename in incoming_files:
        name = filename[:-4]
        spec = manifest.get(name)
        path = os.path.join(INCOMING_DIR, filename)
        with open(path, "rb") as f:
            data = f.read()

        if spec is None:
            unrecognized.append(filename)
            continue

        header = read_png_header(data)
        if header is None:
            errors.append(f"{filename}: not a valid PNG")
            continue
        width, height, bit_depth, color_type, compression, filter_method, interlace = header
        if (width, height) != (spec["width"], spec["height"]):
            errors.append(f"{filename}: expected {spec['width']}x{spec['height']}px, got {width}x{height}px")
            continue
        if (bit_depth, color_type, compression, filter_method, interlace) != (8, 6, 0, 0, 0):
            errors.append(
                f"{filename}: expected 8-bit RGBA, non-interlaced PNG "
                f"(got bit_depth={bit_depth}, color_type={color_type}, interlace={interlace})"
            )
            continue

        write_imageset(name, data)
        imported_names.add(name)
        imported.append(name)

    save_imported_names(imported_names)

    present = imported_names | existing_imageset_names()
    missing_by_category = {}
    for name, spec in manifest.items():
        if name not in present:
            missing_by_category.setdefault(spec["category"], []).append(name)

    print(f"Imported {len(imported)} PNG(s) into {ASSETS_DIR}.")
    if unrecognized:
        print(f"\nSkipped {len(unrecognized)} unrecognized PNG file(s):")
        for filename in unrecognized:
            print(f"  {filename}")
    if errors:
        print(f"\nRejected {len(errors)} PNG file(s):")
        for error in errors:
            print(f"  {error}")

    missing_total = sum(len(names) for names in missing_by_category.values())
    if missing_total:
        print(f"\n{missing_total} required art asset(s) are still missing:")
        for category, names in sorted(missing_by_category.items()):
            print(f"  {category}: {len(names)} missing")
        print("\nSee ArtSource/RPG/README.md for the exact filename manifest.")
    else:
        print("\nAll required RPG art assets are imported.")

    if errors or unrecognized:
        sys.exit(1)


if __name__ == "__main__":
    main()
