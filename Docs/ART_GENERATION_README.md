# RepSetForge RPG Art Import Pipeline

RepSetForge's RPG art pipeline is manual chibi-art import only. Procedural
placeholder generation is disabled.

Source of truth for required files:

```text
ArtSource/RPG/README.md
```

Import script:

```bash
python3 scripts/import_rpg_art.py
```

Deprecated script:

```bash
python3 scripts/generate_pixel_assets.py
```

That command now exits with a message and does not generate art.

## 1. Art Style Rules

Create polished chibi fantasy RPG art, matching the supplied reference style:

- Oversized heads, compact bodies, readable poses.
- Clean hand-rendered fantasy icon look, not flat procedural blocks.
- Rich highlights and shadows with strong silhouettes.
- Transparent backgrounds for characters, monsters, bosses, equipment, and skills.
- Backgrounds are full scene art.
- No blurry exports, white matte backgrounds, watermarks, text labels, or sprite-sheet files.

## 2. Orientation Rules

- Hero/class sprites face right.
- Monster and boss sprites face left, toward the hero.
- Runtime rendering does not mirror monster or boss art.
- Do not author duplicate mirrored frames.
- Each animation frame is a separate PNG and becomes one flat `.imageset`.

## 3. Required Sizes

| Category | Exported PNG Size |
|---|---:|
| Hero/class sprite | 256x256 |
| Small monster | 192x192 |
| Medium monster | 256x256 |
| Large monster | 320x320 |
| Boss | 512x512 |
| Equipment icon | 192x192 |
| Skill icon | 192x192 |
| Background | 960x540 |

Every PNG must be 8-bit RGBA, color type 6, non-interlaced.

## 4. Required Files

The complete required manifest is documented in
`ArtSource/RPG/README.md`. Current total: 407 PNG files.

Summary:

| Category | Required PNGs |
|---|---:|
| Hero/class frames | 100 |
| Monster frames | 216 |
| Boss frames | 65 |
| Equipment icons | 9 |
| Skill icons | 8 |
| Backgrounds | 9 |

## 5. Folder Structure

Generated source art must be dropped flat into:

```text
ArtSource/RPG/incoming/
```

The importer writes accepted art into:

```text
RepSetForge/Assets.xcassets/RPG/
  rpg_class_<class>_<anim><frame>.imageset/
  rpg_monster_<id>_<anim><frame>.imageset/
  rpg_boss_<id>_<anim><frame>.imageset/
  rpg_equip_<id>.imageset/
  rpg_skill_<id>.imageset/
  rpg_bg_<id>.imageset/
```

Do not create nested asset folders. Swift runtime lookup expects flat asset
names.

## 6. Naming Convention

| Category | Filename pattern |
|---|---|
| Hero class | `rpg_class_{class}_{anim}{frame}.png` |
| Monster | `rpg_monster_{id}_{anim}{frame}.png` |
| Boss | `rpg_boss_{id}_{anim}{frame}.png` |
| Equipment icon | `rpg_equip_{id}.png` |
| Skill icon | `rpg_skill_{id}.png` |
| Background | `rpg_bg_{id}.png` |

The IDs and animation counts are listed in `ArtSource/RPG/README.md`.

## 7. Import Workflow

1. Generate finished chibi PNGs according to `ArtSource/RPG/README.md`.
2. Save them directly into `ArtSource/RPG/incoming/`.
3. Run:

   ```bash
   python3 scripts/import_rpg_art.py
   ```

4. Read the output. If any files are rejected, fix only those files and rerun.
5. Continue until the importer reports:

   ```text
   All required RPG art assets are imported.
   ```

6. Rebuild the app.

The importer validates and copies art. It does not resize, rename, generate,
or synthesize missing frames.

## 8. Project Files To Update When Content Changes

Update Swift registries when adding or removing content IDs:

| File | Responsibility |
|---|---|
| `RepSetForge/Models/RPGClass.swift` | Hero class enum and frame lookup |
| `RepSetForge/Models/RPGMonster.swift` | Monster asset-name lookup |
| `RepSetForge/Models/RPGBoss.swift` | Boss asset-name lookup |
| `RepSetForge/Services/RPGMonsterRegistry.swift` | Monster ids and level bands |
| `RepSetForge/Services/RPGBossRegistry.swift` | Boss ids and backgrounds |
| `RepSetForge/Services/RPGEquipmentRegistry.swift` | Equipment icon ids |
| `RepSetForge/Services/RPGSkillRegistry.swift` | Skill icon ids |
| `RepSetForge/Services/MonsterSpawnService.swift` | Level background selection |
| `ArtSource/RPG/README.md` | Required file manifest |
| `scripts/import_rpg_art.py` | Import manifest validation |

Keep the Swift IDs, importer manifest, and art README in sync.

## 9. Acceptance Criteria

- `python3 scripts/import_rpg_art.py` accepts every submitted PNG with 0 rejected files.
- The importer reports all required RPG art assets are imported.
- Every imported imageset contains exactly one PNG and one `Contents.json`.
- All runtime-referenced RPG asset names exist in `RepSetForge/Assets.xcassets/RPG/`.
- The app builds and RPG scenes show finished chibi art, not procedural placeholders.
