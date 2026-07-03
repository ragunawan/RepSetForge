# Manual RPG Art Import Manifest

This folder is the source drop zone for manually generated SetCraft RPG art.
Do not use procedural placeholder art. Create finished chibi RPG PNGs, save
them flat into:

```text
ArtSource/RPG/incoming/
```

Then run this from the repo root:

```bash
python3 scripts/import_rpg_art.py
```

The importer validates exact filename, exact dimensions, and PNG format. It
does not resize, rename, synthesize, or draw missing frames.

## Required PNG Format

Every submitted file must be:

- PNG
- 8-bit RGBA, color type 6
- Non-interlaced
- Transparent background for characters, monsters, bosses, equipment, and skill icons
- Exact exported pixel dimensions listed below
- Saved directly in `ArtSource/RPG/incoming/`, with no subfolders

Style target: polished chibi fantasy RPG icons like the project reference
sheet: oversized heads, compact bodies, readable silhouettes, clean linework,
rich highlights, and hand-rendered charm. Avoid flat procedural block sprites.

Orientation rule:

- Hero/class frames face right.
- Monster and boss frames face left, toward the hero.
- Runtime rendering does not mirror monsters or bosses.
- Do not submit duplicate mirrored files.

## Size Summary

| Category | Native Design Size | Exported PNG Size |
|---|---:|---:|
| Hero/class sprite | 64x64 | 256x256 |
| Small monster | 48x48 | 192x192 |
| Medium monster | 64x64 | 256x256 |
| Large monster | 80x80 | 320x320 |
| Boss | 128x128 | 512x512 |
| Equipment icon | 48x48 | 192x192 |
| Skill icon | 48x48 | 192x192 |
| Background | 480x270 | 960x540 |

## Hero Classes

Each hero class requires 20 files at 256x256.

Animations per class:

| Animation | Frames | Filename pattern |
|---|---:|---|
| idle | 4 | `rpg_class_{class}_idle0.png` through `idle3.png` |
| walk | 4 | `rpg_class_{class}_walk0.png` through `walk3.png` |
| attack | 3 | `rpg_class_{class}_attack0.png` through `attack2.png` |
| cast | 3 | `rpg_class_{class}_cast0.png` through `cast2.png` |
| defend | 2 | `rpg_class_{class}_defend0.png` through `defend1.png` |
| sitting | 4 | `rpg_class_{class}_sitting0.png` through `sitting3.png` |

Classes:

| Class id | Subject direction |
|---|---|
| `knight` | Steel-armored chibi knight, sword, navy kite shield, gold trim, red helm plume |
| `ranger` | Green/brown hooded chibi ranger, bow, quiver |
| `mage` | Purple chibi mage, pointed hat, staff, cyan magic accents |
| `monk` | Orange chibi monk, headband, wrapped fists |
| `rogue` | Gray hooded chibi rogue, dual daggers, shadow accents |

Full hero filename set for each class id:

```text
rpg_class_{class}_idle0.png
rpg_class_{class}_idle1.png
rpg_class_{class}_idle2.png
rpg_class_{class}_idle3.png
rpg_class_{class}_walk0.png
rpg_class_{class}_walk1.png
rpg_class_{class}_walk2.png
rpg_class_{class}_walk3.png
rpg_class_{class}_attack0.png
rpg_class_{class}_attack1.png
rpg_class_{class}_attack2.png
rpg_class_{class}_cast0.png
rpg_class_{class}_cast1.png
rpg_class_{class}_cast2.png
rpg_class_{class}_defend0.png
rpg_class_{class}_defend1.png
rpg_class_{class}_sitting0.png
rpg_class_{class}_sitting1.png
rpg_class_{class}_sitting2.png
rpg_class_{class}_sitting3.png
```

Total hero files: 5 classes x 20 = 100 PNGs.

## Monsters

Every monster frame is required. The importer no longer synthesizes hit or
defeat frames.

Animations per monster:

| Animation | Frames | Filename pattern |
|---|---:|---|
| idle | 3 | `rpg_monster_{id}_idle0.png` through `idle2.png` |
| attack | 2 | `rpg_monster_{id}_attack0.png` through `attack1.png` |
| hit | 1 | `rpg_monster_{id}_hit0.png` |
| defeat | 3 | `rpg_monster_{id}_defeat0.png` through `defeat2.png` |

Small monsters, 192x192 PNGs:

```text
training_slime
tiny_bat
forest_slime
cave_bat
goblin_scout
bone_rat
```

Medium monsters, 256x256 PNGs:

```text
goblin_warrior
wild_imp
skeleton_grunt
orc_rookie
cursed_mushroom
orc_brute
wraith
stone_golem
armored_skeleton
fire_imp
```

Large monsters, 320x320 PNGs:

```text
hill_golem
demon_knight
frost_wraith
dragonling
ancient_golem
abyss_wraith
elder_dragonling
infernal_beast
```

Full monster filename set for each monster id:

```text
rpg_monster_{id}_idle0.png
rpg_monster_{id}_idle1.png
rpg_monster_{id}_idle2.png
rpg_monster_{id}_attack0.png
rpg_monster_{id}_attack1.png
rpg_monster_{id}_hit0.png
rpg_monster_{id}_defeat0.png
rpg_monster_{id}_defeat1.png
rpg_monster_{id}_defeat2.png
```

Total monster files: 24 monsters x 9 = 216 PNGs.

## Bosses

Each boss requires 13 files at 512x512.

Animations per boss:

| Animation | Frames | Filename pattern |
|---|---:|---|
| idle | 4 | `rpg_boss_{id}_idle0.png` through `idle3.png` |
| attack | 4 | `rpg_boss_{id}_attack0.png` through `attack3.png` |
| defeat | 5 | `rpg_boss_{id}_defeat0.png` through `defeat4.png` |

Boss ids:

```text
iron_goblin_captain
bone_colossus
storm_wyvern
infernal_champion
ancient_dragon
```

Full boss filename set for each boss id:

```text
rpg_boss_{id}_idle0.png
rpg_boss_{id}_idle1.png
rpg_boss_{id}_idle2.png
rpg_boss_{id}_idle3.png
rpg_boss_{id}_attack0.png
rpg_boss_{id}_attack1.png
rpg_boss_{id}_attack2.png
rpg_boss_{id}_attack3.png
rpg_boss_{id}_defeat0.png
rpg_boss_{id}_defeat1.png
rpg_boss_{id}_defeat2.png
rpg_boss_{id}_defeat3.png
rpg_boss_{id}_defeat4.png
```

Total boss files: 5 bosses x 13 = 65 PNGs.

## Equipment Items

Each equipment item requires one 192x192 PNG.

Filename pattern:

```text
rpg_equip_{id}.png
```

Equipment ids:

```text
training_sword
iron_dumbbell_axe
runners_bow
focus_staff
shadow_daggers
beginner_armor
weighted_vest
heroic_chestplate
mystic_robe
```

Total equipment files: 9 PNGs.

## Skill Icons

Each skill requires one 192x192 PNG.

Filename pattern:

```text
rpg_skill_{id}.png
```

Skill ids:

```text
power_strike
quick_shot
firebolt
heal_pulse
shadow_dash
iron_guard
endurance_aura
boss_breaker
```

Total skill files: 8 PNGs.

## Backgrounds

Each background requires one 960x540 PNG.

Filename pattern:

```text
rpg_bg_{id}.png
```

Background ids:

```text
field
forest
forest_night
cave
mountain_pass
dungeon_corridor
ruined_castle
boss
boss_ruins
```

Total background files: 9 PNGs.

## Full Catalog Count

| Category | Count |
|---|---:|
| Hero/class frames | 100 |
| Monster frames | 216 |
| Boss frames | 65 |
| Equipment icons | 9 |
| Skill icons | 8 |
| Backgrounds | 9 |
| Total required PNGs | 407 |

## Art Catalog Progress

This section is the source of truth for asset completion. Mark an entry
complete only after the PNGs have been generated, saved in
`ArtSource/RPG/incoming/`, imported with `python3 scripts/import_rpg_art.py`,
and accepted into `SetCraft/Assets.xcassets/RPG/`.

Current import status: 407 / 407 required assets imported.

### Characters

Each character requires 20 frames: idle0-3, walk0-3, attack0-2, cast0-2,
defend0-1, sitting0-3.

- [x] `knight` — 20 / 20 frames imported
- [x] `ranger` — 20 / 20 frames imported
- [x] `mage` — 20 / 20 frames imported
- [x] `monk` — 20 / 20 frames imported
- [x] `rogue` — 20 / 20 frames imported

### Monsters

Each monster requires 9 frames: idle0-2, attack0-1, hit0, defeat0-2.

- [x] `training_slime` — 9 / 9 frames imported
- [x] `tiny_bat` — 9 / 9 frames imported
- [x] `forest_slime` — 9 / 9 frames imported
- [x] `cave_bat` — 9 / 9 frames imported
- [x] `goblin_scout` — 9 / 9 frames imported
- [x] `bone_rat` — 9 / 9 frames imported
- [x] `goblin_warrior` — 9 / 9 frames imported
- [x] `wild_imp` — 9 / 9 frames imported
- [x] `skeleton_grunt` — 9 / 9 frames imported
- [x] `orc_rookie` — 9 / 9 frames imported
- [x] `cursed_mushroom` — 9 / 9 frames imported
- [x] `orc_brute` — 9 / 9 frames imported
- [x] `wraith` — 9 / 9 frames imported
- [x] `stone_golem` — 9 / 9 frames imported
- [x] `armored_skeleton` — 9 / 9 frames imported
- [x] `fire_imp` — 9 / 9 frames imported
- [x] `hill_golem` — 9 / 9 frames imported
- [x] `demon_knight` — 9 / 9 frames imported
- [x] `frost_wraith` — 9 / 9 frames imported
- [x] `dragonling` — 9 / 9 frames imported
- [x] `ancient_golem` — 9 / 9 frames imported
- [x] `abyss_wraith` — 9 / 9 frames imported
- [x] `elder_dragonling` — 9 / 9 frames imported
- [x] `infernal_beast` — 9 / 9 frames imported

### Bosses

Each boss requires 13 frames: idle0-3, attack0-3, defeat0-4.

- [x] `iron_goblin_captain` — 13 / 13 frames imported
- [x] `bone_colossus` — 13 / 13 frames imported
- [x] `storm_wyvern` — 13 / 13 frames imported
- [x] `infernal_champion` — 13 / 13 frames imported
- [x] `ancient_dragon` — 13 / 13 frames imported

### Equipment

Each equipment item requires 1 icon.

- [x] `training_sword` — imported
- [x] `iron_dumbbell_axe` — imported
- [x] `runners_bow` — imported
- [x] `focus_staff` — imported
- [x] `shadow_daggers` — imported
- [x] `beginner_armor` — imported
- [x] `weighted_vest` — imported
- [x] `heroic_chestplate` — imported
- [x] `mystic_robe` — imported

### Skills

Each skill requires 1 icon.

- [x] `power_strike` — imported
- [x] `quick_shot` — imported
- [x] `firebolt` — imported
- [x] `heal_pulse` — imported
- [x] `shadow_dash` — imported
- [x] `iron_guard` — imported
- [x] `endurance_aura` — imported
- [x] `boss_breaker` — imported

### Backgrounds

Each background requires 1 scene image.

- [x] `field` — imported
- [x] `forest` — imported
- [x] `forest_night` — imported
- [x] `cave` — imported
- [x] `mountain_pass` — imported
- [x] `dungeon_corridor` — imported
- [x] `ruined_castle` — imported
- [x] `boss` — imported
- [x] `boss_ruins` — imported

## Adding New Art

Use this checklist when adding a new character, monster, boss, equipment
item, skill, or background. This README and `scripts/import_rpg_art.py` must
stay in sync.

### New Character

1. Add the character id to the app registry/model that references class art.
2. Add the id to `HERO_CLASSES` in `scripts/import_rpg_art.py`.
3. Add the id and subject direction to the `Hero Classes` table above.
4. Add a checkbox under `Characters` with `0 / 20 frames imported`.
5. Generate 20 right-facing PNGs at 256x256 using the hero filename pattern.
6. Run `python3 scripts/import_rpg_art.py`.
7. Mark the character complete only after all 20 frames import.

### New Monster

1. Add the monster id to the Swift monster registry.
2. Add the id to the correct size tier in `scripts/import_rpg_art.py`:
   `MONSTERS_48`, `MONSTERS_64`, or `MONSTERS_80`.
3. Add the id to the matching size list above.
4. Add a checkbox under `Monsters` with `0 / 9 frames imported`.
5. Generate 9 left-facing PNGs at the tier's exported size.
6. Run `python3 scripts/import_rpg_art.py`.
7. Mark the monster complete only after all 9 frames import.

### New Skill

1. Add the skill id to the Swift skill registry.
2. Add the id to `SKILLS` in `scripts/import_rpg_art.py`.
3. Add the id to the `Skill ids` list above.
4. Add a checkbox under `Skills` marked not imported.
5. Generate `rpg_skill_{id}.png` at 192x192.
6. Run `python3 scripts/import_rpg_art.py`.
7. Mark the skill complete only after the icon imports.

### New Equipment Item

1. Add the equipment id to the Swift equipment registry.
2. Add the id to `EQUIPMENT` in `scripts/import_rpg_art.py`.
3. Add the id to the `Equipment ids` list above.
4. Add a checkbox under `Equipment` marked not imported.
5. Generate `rpg_equip_{id}.png` at 192x192.
6. Run `python3 scripts/import_rpg_art.py`.
7. Mark the item complete only after the icon imports.

### New Background

1. Add the background id anywhere the app should select it.
2. Add the id to `BACKGROUNDS` in `scripts/import_rpg_art.py`.
3. Add the id to the `Background ids` list above.
4. Add a checkbox under `Backgrounds` marked not imported.
5. Generate `rpg_bg_{id}.png` at 960x540.
6. Run `python3 scripts/import_rpg_art.py`.
7. Mark the background complete only after the scene imports.

## Import Workflow

1. Generate finished chibi art using the manifest above.
2. Export each file as exact-size 8-bit RGBA, non-interlaced PNG.
3. Save files directly in `ArtSource/RPG/incoming/`.
4. Run `python3 scripts/import_rpg_art.py`.
5. Fix any rejected files and rerun the importer.
6. When the importer reports `All required RPG art assets are imported.`,
   rebuild the app.
