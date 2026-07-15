# RepSetForge — Developer Implementation Spec

**Locked decisions:** Free app, no IAP/paywall in v1 (monetization deferred entirely — no gating scaffolding built). Sync = **CloudKit + SwiftData** (`ModelConfiguration(cloudKitDatabase:)`, private database; free, zero backend; accepted tradeoff: forecloses Android/web without later migration). Exercise database ships **empty** — users create their own exercises; the dedup/canonical-name system (§2) matters more, not less, since every name is user-typed. The picker's first-run state leads with 'Create your first exercise' and the create flow is one screen: name + muscle groups + equipment.

Companion to `repsetforge-hifi.html` (screens/states) and `gymchalk-tokens.json` (values). Target: SwiftUI, iOS 17+, WidgetKit/ActivityKit for Live Activities.

---

## 1. App architecture & navigation

```
RootView
├── TabView (Home · History · Progress · Library)   ← FAB overlays as ZStack layer
├── StartWorkoutSheet (.sheet, medium detent)        ← from FAB
├── ActiveWorkoutSheet (.fullScreenCover)            ← focused app state
│     └── minimizes to ActiveWorkoutPill (bottom overlay above tab bar)
└── SettingsSheet (from Home profile button)
```

**Active workout state rules**
- `WorkoutSession` is a singleton observable persisted to disk on every mutation (autosave draft).
- **Restore UX (resolved):** on launch with an unfinished session — if it's **< 4 h old, silently resume**: Home shows the normal resume banner, elapsed continues from wall-clock start, no modal (a crash should feel like nothing happened). If **≥ 4 h old**, show a sheet: "Unfinished workout — Push Day A, started 9:02, 14 sets logged" with three actions: *Resume* (elapsed keeps wall-clock truth), *Finish as-is* (commits with `endedAt` = last set's `completedAt`, runs the normal summary/Health path), *Discard* (destructive confirm). Never silently delete logged sets. A session that crosses midnight or exceeds 12 h auto-suggests Finish-as-is with the last-set timestamp — prevents accidental 9-hour "workouts" polluting Health and analytics.
- `interactiveDismissDisabled(true)` on the full-screen cover; swipe-down triggers *minimize*, never dismiss.
- Finish requires: Finish button → confirmation sheet with mini-summary → commit. Cancel workout lives behind the ⋯ overflow with a destructive confirmation.
- Only one active session at a time; FAB while active routes to Resume.

## 2. Data model (Core Data / SwiftData)

```
Exercise        id, name, muscleGroups[], secondaryMuscles[], equipment, isFavorite,
                isCustom, notes(pinned), createdAt, canonicalNameKey (dedup)
Routine         id, name, orderedItems[RoutineItem], archivedAt?, lastPerformedAt
RoutineItem     exerciseRef, order, groupID? (superset/circuit), targetSets,
                targetRepsLow/High, targetRPE?, restSeconds, note, progressionRule?
ProgressionRule type(.ladder), repRangeLow, repRangeHigh, maxQualifyingRPE, qualifyingSetsRequired, incrementKg
WorkoutSession  id, name, routineRef?, startedAt, endedAt?, notes, status(.active/.completed)
SessionExercise sessionRef, exerciseRef, order, groupID?, note
SetEntry        id, sessionExerciseRef, index, type(.warmup/.working/.drop/.failure/.bodyweight),
                weightKg?, reps?, rpe?, completedAt?, isPR:Bool (denormalized)
PRRecord        exerciseRef, kind(.bestWeight/.bestE1RM/.bestVolume/.repsAtWeight),
                value, setRef, achievedAt
BodyMetric      date, bodyweightKg
```

- Weights stored in kg as `Decimal`; unit conversion is presentation-only.
- e1RM: Epley `w × (1 + r/30)`, computed property, capped at reps ≤ 12 for validity.
- `canonicalNameKey` = lowercased, punctuation-stripped name; on custom-exercise creation, fuzzy-match (Levenshtein ≤ 2 or token subset) against existing keys → show "Similar exists" row before allowing create.

## 3. Active Workout screen (priority build)

**One logging surface (v1.4):**
- **Exercise Focus view** — one exercise per page in a horizontal `TabView(.page)` carousel (screen 2b). The only place sets are logged.
- **Exercise Index sheet** — **read-only** overview replacing the former list view: opened by tapping the pager count, it shows each exercise with completion state (`3/4 sets`), volume, and PR badges, plus drag-reorder and jump-to-page. No set entry, no input fields — it is navigation and orientation only, which removes the burden of keeping two full logging surfaces consistent across every set-type/superset/PR case. (Screen 2 in the mockup is retained as this sheet's visual reference.)

Exercise Focus anatomy, top to bottom (**full-bleed, no cards**: content runs edge-to-edge, sections separated by hairline dividers only; screen gutter applies to content padding, not containers):
1. **Telemetry header** — monospaced rows, label left / value right:
   `SESSION:  00:52:18` — total elapsed
   `WORK: 00:40:10        REST: 00:12:08` — one shared line: **WORK** = cumulative time under work (session − rest), **REST** = cumulative rest (sum of completed rest intervals). Both derive from the same rest ledger so they always sum to SESSION. The *current* rest countdown lives exclusively in the bottom pill — the header holds only cumulative values, so a ticking countdown never sits beside cumulative labels.
   `58% · 118 BPM · 328 KCAL          SET 6/14`
   HR/kcal rows are **hidden in v1.0** (they require the Watch session — see §4c); the header shows ELAPSED, REST, % done, and SET count only. Slim session progress bar beneath (completed/planned sets).
2. **Exercise identity row**: muscle thumbnail, name, muscle-detail line ("Chest · Sternal head · Triceps"), overflow menu.
3. **In-context chart** (full-bleed): bars = per-session volume, line = e1RM trend, dashed warning-color horizontal = %1RM target. Toggles: metric, 3M range, %1RM overlay. Below: 1RM chip + PR chip. **Collapse-on-first-set**: once the first set on this exercise is completed, the chart animates closed (200ms height fade) to a single collapsed row — `CHART · 1RM 128 · PR 102.5×8` — reclaiming the space for sets; tap the row (or the CHART pill tab) to re-expand. State is per-exercise-per-session; a new page always starts expanded so the pre-lift context (trend, %1RM target) is visible exactly when it's useful and gone when it isn't.
4. **Coaching prompt banner** (replaces the small chip in this view): plain-language trigger + explicit monospaced target — `Same as last session. Target: ≥ 105 kg × 8 @ 8 RPE (+2.5%)`. Tap applies to pending sets.
5. **Set table**: `# / Weight / Reps / RPE / Rest / ✓` — RPE is a first-class narrow column (hidden app-wide when RPE is off in Settings, freeing width for the others), and the per-set Rest field drives that set's auto-timer. Previous-session values are conveyed purely through ghost text inside the input fields — no sub-lines under rows; the coaching prompt above the table already carries the last-session context.
6. **Bottom pill**: ✕ minimize · **PROG** (progression panel) · ‹ 1/3 › pager · share. Page-swipe also navigates exercises. Rest countdown replaces the pager while a timer runs. Tapping the count opens the read-only Exercise Index sheet (jump/reorder).

**Progression panel (screen 2c)** — opened from PROG in the bottom pill; a full-height sheet over the focus view, same full-bleed layout. Two sections:
- *Progression rule* — editable rows binding directly to `ProgressionRule` (extended: repRangeLow/High, maxQualifyingRPE, qualifyingSetsRequired, incrementKg): Rep range `8–12`, RPE `≤ 9`, Sets per session `≥ 2`, Weight increment `+2.5 kg`.
- *Ladder* — the generated level sequence from current weight through the rep range, then the level-up weight jump. Each level row: `weight × reps` (mono) + computed e1RM with % delta vs. previous level; per-session qualifying checkmarks stacked at right (n = qualifyingSetsRequired) with completion dates. Completed levels dim to 55%; current level gets a signal-dim background; the level-up row is annotated. Engine: a level completes when the user logs ≥ qualifyingSetsRequired sets at that weight×reps with RPE ≤ max, within one session; completing the top rep-range level advances weight by incrementKg and regenerates the ladder. The coaching prompt on the focus view always targets the current ladder level — one source of truth.
- *Methodology scope*: the ladder implements **double progression** (fill the rep range, then add weight). This is one methodology among several lifters use — **5/3/1** (percentage-of-training-max waves with AMRAP sets), **percentage/wave periodization** (prescribed %1RM per session), and **RIR-based autoregulation** (targets derived from reps-in-reserve rather than fixed loads) are the notable others. v1.0 ships double progression only, but `ProgressionRule.type` is an enum precisely so these land as additional cases in **v1.1** without data-model changes; the rule editor's row list is driven by the selected type. The UI copy says "progression rule", never implying the ladder is the only model.
- Pill tabs within the panel: PROG · CHART · LOG · NOTES (chart = the focus-view chart expanded; LOG = full set history; NOTES = pinned + session notes).

Chart data loads lazily per page and is cached; never block set entry on chart render.

**Supersets in the paged view (resolved):** a superset group occupies **one page**. Members render as stacked full-bleed sections on that page (hairline-divided, each with its own set table); the pager counts the group as one position (`2/3` where page 2 = "Superset A"). Rest semantics: completing a set in member A starts **no** timer and auto-scrolls to member B's matching set row (intra-superset transition is immediate by definition); completing the round's final member starts the group's rest timer (the group's `restSeconds`, set in the builder). The prompt banner shows per-member targets stacked. The chart region shows the first member's chart with member chips to switch. Circuits (3+ members) use the same model. Edge case: if a member is replaced mid-workout, it stays in the group; if removed, the group dissolves to a plain exercise when one member remains.

**Set row = single SwiftUI view, no modals for ordinary logging.**

Row anatomy (44pt height): `[type badge 28] [prev ghost 56] [weight field 64] [reps field 48] [rpe field 40] [check 52×44]`

Behavior contract:
1. New row inherits values from row above (or previous session if first row). Inherited values render as ghost text (`textTertiary`) until touched or completed.
2. Tapping weight/reps → inline numpad accessory (system keyboard, `.decimalPad`) with ±increment steppers (increment = plate step from settings, default 2.5 kg). Long-press weight → plate calculator popover.
3. Tapping ✓: commit ghost values as real, set `completedAt`, run PR check, start rest timer (duration = routine item's rest or default), append next row if this was the last, fire `.light` haptic, play 250ms spring on the check (skip under Reduce Motion).
4. PR check on commit: compare against `PRRecord` per kind; on hit, insert inline gold `PR` badge row beneath the set + `.success` haptic. No modal.
5. RPE field: tap → horizontal chip row (6–10, half steps) appears inline below the set; last-used value pre-highlighted.
6. Set type: tap the index badge → menu (Warm-up, Working, Drop, Failure, Bodyweight). Subscript numbering per type (W₁, W₂, D₁). Warm-ups excluded from volume & PR calcs; bodyweight uses `BodyMetric` latest for volume.
7. Swipe-left on row: Delete. Drag handle in edit mode for reorder.
8. Exercise ⋯ menu: Reorder, Replace (picker filtered to same primary muscle; completed sets preserved, pending remapped), Superset with…, Remove.

**Progression chip:** shown above set table when the exercise's `ProgressionRule` condition was met last session. Copy format: `⬆ +2.5 kg — you hit 8/8/8 @ RPE 8`. Dismiss stores a per-exercise-per-session suppression. Tapping applies the increment to all pending working sets.

## 4. Rest timer & Live Activity

- `RestTimerManager`: start(duration), extend(+30), skip. Backed by wall-clock `Date` math, not a running timer — survives backgrounding.
- UI: pill above tab-bar region, progress bar + monospaced countdown. Overtime state: warning color, counts up (`+0:12`).
- **ActivityKit Live Activity** — started with the workout, ended at Finish/Discard. Full surface spec (mockup frame *2e · Live Activity & Dynamic Island*):

  **Attributes/state** (`ActivityAttributes`): static = workout name, start `Date`; `ContentState` = current exercise name, set index/total, session set count/total, rest phase (`.working` or `.resting(end: Date, total: TimeInterval)`), volume kg. State pushed via `Activity.update()` on set completion, rest start/extend/skip, and page change — 5–10 updates per workout, well under ActivityKit budgets; **all ticking is OS-driven** (`Text(timerInterval:)` for countdowns, `Text(_:style: .timer)` for elapsed) so no per-second updates are ever sent.

  **Lock screen / banner** (also the CarPlay/StandBy source): mono type throughout, dark material. Working phase — `PUSH DAY A · 00:52:18` header row, `BENCH PRESS · SET 2/4` body, session progress bar. Resting — countdown becomes the hero (`1:34` large, signal color), progress bar shows rest fraction, exercise line demotes. One `Button(intent:)` on the right: **Skip** while resting (LiveActivityIntent, runs in-process, no app launch); none while working (completing sets from the lock screen without seeing the table invites mis-logs).

  **Dynamic Island**:
  - *Compact* (both sides of the notch): leading = signal-colored dumbbell glyph or rest ring; trailing = the one number that matters — rest countdown while resting, elapsed while working. Mono, tabular.
  - *Minimal* (another app's activity is present): rest ring with countdown inside, or the glyph alone while working.
  - *Expanded* (long-press): leading region = exercise name + `SET 2/4`; trailing = elapsed + volume; center = rest countdown with progress ring when resting, else session progress bar; bottom = Skip / +30s intent buttons (resting only).
  - Tap anywhere → deep-link to the Focus view at the current exercise (`widgetURL`).

  **Overtime state**: countdown flips to warning color and counts up (`+0:12`) — same semantics as the in-app pill; ring shows full.
  **Dismissal rules**: Finish → `activity.end(dismissalPolicy: .after(.now + 4))` showing the final summary line (`58 MIN · 18 SETS · 2 PR`); Discard → `.immediate`. Stale sessions (the ≥12 h case in §1's restore rules) end their activity when the restore sheet resolves.
  **Reliability**: activity start can fail (user disabled Live Activities) — the app never depends on it; the in-app pill is the source of truth. Re-assert the activity on app foreground if `Activity.activities` is empty but a session is live (covers OS eviction).
- Local notification at rest completion (time-sensitive interruption level) if app backgrounded.

## 4b. Apple Health / Fitness export (auto-save workouts)

Completed workouts are written to HealthKit so they appear in the Fitness app automatically and credit the user's rings.

**Write path**
- On session commit, build an `HKWorkout` via `HKWorkoutBuilder`: `activityType = .traditionalStrengthTraining`, start/end from session timestamps.
- Attach `HKWorkoutActivity` segments per exercise (iOS 16+) so Fitness shows the breakdown.
- Energy: if a Watch workout session ran concurrently, the Watch is the source of truth for active energy and HR samples — the phone writes **no** energy sample (prevents double-counting). Phone-only sessions estimate kcal (MET 5.0 × bodyweight × duration) and write `HKQuantitySample(.activeEnergyBurned)` attached to the workout.
- Metadata: `HKMetadataKeyWorkoutBrandName = "RepSetForge"` + custom keys for total volume kg and set count.

**Watch coordination & duplicate guard**
- If the Watch app is running the mirrored `HKWorkoutSession`, the Watch calls `finishWorkout` and owns the HKWorkout; the phone attaches metadata to that workout instead of creating a second one.
- Store the saved `HKWorkout.uuid` on `WorkoutSession.healthKitUUID`. Edits update rather than insert; deleting a session deletes its HKWorkout via `HKHealthStore.delete`. (This is the exact duplicate-write bug class Strongsplit shipped multiple fixes for — design it out up front.)
- Third-party wearable users (Garmin etc.) get a Settings toggle **Auto-save to Apple Health** (default on) plus a manual "Save to Health" action on the Summary when off.

**Permissions & UX**
- Request share authorization (workouts, active energy) and read (heart rate, energy) at first workout completion, not onboarding — in-context asks convert better and avoid the App Review rejection vector of requesting Health access with no visible feature.
- Summary shows "Saved to Apple Health" confirmation row; when denied: "Health access off — enable in Settings › Health".
- Required: `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` strings naming the concrete purpose, HealthKit entitlement, graceful degradation.

## 4c. Apple Watch companion app (heart-rate source) — **v1.1**

Deferred from v1.0 to control solo-developer scope: session mirroring's edge cases (reconnection, sample backfill) are weeks of work orthogonal to the core logging product. **v1.0 ships without the Watch app**: the telemetry header hides its HR/kcal row, and Health export uses the phone-only path in §4b (estimated energy) — fully functional, no dangling UI. Everything below is the v1.1 build target; the design is finalized now so v1.0's session model doesn't need rework to accommodate it.

**Session architecture (iOS 17+ workout mirroring)**
- Phone starts the workout → calls `HKHealthStore.startWatchApp(with:)` to launch the Watch app with an `HKWorkoutConfiguration` (`.traditionalStrengthTraining`, `.indoor`).
- Watch runs `HKWorkoutSession` + `HKLiveWorkoutBuilder`; the session is **mirrored** to the phone (`workoutSessionMirroringStartHandler`), so both devices share one session state — pause/resume/end from either side stays in sync.
- HR and active-energy stream to the phone through the mirrored session's data channel (`sendToRemoteWorkoutSession`); the phone's telemetry header (`118 BPM · 328 KCAL`) binds to this stream with a 5s staleness timeout — values hide, never freeze, when the Watch drops.
- Fallback for watchOS 9 / no mirroring: `WCSession` message channel with the same payload schema.

**Watch UI (three pages, Digital Crown scrolls, page dots)**
Typography: all numerals in SF Mono / `.monospacedDigit()` — timers, HR, kcal, set counts, weights — so values never jitter horizontally as they tick; labels in SF Mono caps at 9–11pt with wide tracking, values right-aligned in label/value rows (Vitals page mirrors the phone telemetry layout).
1. *Now*: exercise name (caps label), `SET 2/4` (mono), target `105kg × 8` as the hero numeral (~27pt mono semibold), `@8 RPE · PREV 100×8` context line, giant ✓ Complete button — completes the set on the phone too (phone's `WorkoutSession` is the single source of truth; Watch sends intents, phone confirms).
2. *Rest*: 40pt mono countdown in signal color, `OF 2:30 · NEXT SET 3/4` context line, progress bar, +30s / Skip; `.notification` haptic at 0.
3. *Vitals*: mono label/value table — HEART, ENERGY, ELAPSED, SETS, VOLUME.
- Water-lock friendly layout, always-on-display dimmed state showing only rest countdown or elapsed.

**Ownership & Health handoff (extends §4b)**
- Watch owns `finishWorkout()` → its HKWorkout carries genuine HR/energy samples; phone attaches metadata (brand, volume, sets) to that workout. Phone-only path in §4b applies when no Watch session ran.
- Reconnection: if the Watch app dies mid-workout, phone continues logging; on relaunch the Watch rejoins the mirrored session and backfills its samples into the same builder.

**Complication/Smart Stack**: rest countdown + current set as a Live Activity-equivalent widget on watchOS 11 Smart Stack.



## 5. Screen-by-screen notes

- **Home (v1.7 — four modules):** (1) resume-workout banner when a session is active (name, elapsed, sets done, Resume); (2) week-at-a-glance strip — sessions vs. target, volume, sets, PRs, streak, mini volume sparkline; (3) recommended next session (least-recently-performed routine, tie-broken by lowest muscle-group weekly set count) with a Start action; (4) **Body module** — a single dual-axis chart overlaying weight (solid, signal, left y-axis) and body-fat % (dashed, secondary grey, right y-axis) with a `W / M / Y` segmented range control and horizontal paging into previous periods (swipe the charts or tap ‹ ›; period label shows the date span, e.g. `‹ JUL 6–12`). A header row carries both current values with period deltas; a legend line maps line style to axis. Body-fat % reads from HealthKit `bodyFatPercentage` (smart scales write it) with manual entry as fallback in Settings › Bodyweight; unlike BMI it is independent of weight, so the overlay shows genuinely divergent trends (weight flat + BF% falling = recomposition — the story lifters actually care about). Sparse-sample handling: BF% is logged less often than weight, so interpolate gaps up to 14 days and render nothing beyond that rather than fabricating a line; if the period has no BF% samples, show the weight line alone with a dimmed 'No body-fat data' right-axis label. `BodyMetric` gains `bodyFatPct?`. Charts read from the `BodyMetric` series aggregated per period (daily points for W, weekly means for M, monthly means for Y); insufficient-data periods render the locked state with an entry shortcut ("Log today's weight").
- **First-run placeholder modules (resolved):** with an empty database, every Home module renders as a placeholder card in its final position — same layout skeleton, dimmed, each stating its unlock condition: Week strip → "Your weekly summary appears after your first workout"; Recommended next → "Build a routine to get session recommendations" (+ New routine action); Body → "Log a bodyweight to start tracking" (+ Log weight action); resume banner simply absent. Modules swap from placeholder to live individually as their data arrives — the screen never reorganizes, it fills in. Same pattern for Progress (each chart card shows its own unlock threshold) and History (empty month grid with "Your first session will appear here"). Placeholders use `textTertiary` content on `surfaceRaised` with a dashed hairline border — visually distinct from live cards, consistent with the routine-library empty state. Everything else stays out — recent workouts live in History, PRs in Progress; Home's job is "what now," not "what happened."
- **Exercise picker:** `.searchable` with 150ms debounce; sections Recents (last 10) → Favorites → All (filtered). Chips for muscle + equipment are AND-combined. Row tap expands inline history preview (best, e1RM, 6-session sparkline) — expansion does not select; explicit "Add to workout" button does.
- **Summary:** deltas computed vs. most recent completed session sharing the same `routineRef` (fallback: same name). Share = rendered `ImageRenderer` card.
- **History:** month grid from completed sessions; planned = future-dated routine schedule (dashed outline); filters compose predicates.
- **Historical edit invalidation chain (resolved):** editing or deleting a past session triggers, in order: (1) **PR recompute** for each touched exercise — `PRRecord`s are derived data, so rebuild them from the full `SetEntry` history for that exercise (cheap: single-exercise scan), and cascade: any *later* set that becomes/stops being a PR gets its denormalized `isPR` flag updated; (2) **ladder recompute** — the exercise's ladder position is re-derived from qualifying-set history; if the edit invalidates a completed level, the ladder regresses and the next session's prompt reflects it (no silent grandfathering); (3) **weekly rollup invalidation** for the affected week(s) — Progress charts recompute those buckets only; (4) **Health re-write** — update the linked `HKWorkout` via `healthKitUUID` (delete + re-save with same-session metadata; deletion of the session deletes the HKWorkout). All four run in one background transaction; UI shows a transient "Recalculating records…" toast only if it exceeds 300 ms. Rule: derived data (PRs, ladders, rollups) is never edited directly and always rebuildable from `SetEntry` — this is what makes the chain safe.
- **Progress:** every chart card = `ChartCard(title, chart, insightSentence)`. Insight sentences are generated from the same query as the chart (e.g., linear regression over e1RM series → "up +7.5 kg over 8 weeks"). Insufficient data (<4 points) → locked state with concrete unlock condition.
- **Routine builder:** `List` with `.onMove`; superset grouping = shared `groupID`, rendered as one card with signal left border. Save validates non-empty name + ≥1 exercise.
- **Post-workout routine update:** diff session vs. template (weights, added/removed exercises, set counts). If diff non-empty → sheet with per-change toggles, default on for weight changes, off for structural changes.

## 6. Settings

Units (kg/lb), default rest (stepper 0:30–5:00), RPE visibility (hides column app-wide), plate calc config (bar weight, available plates), bodyweight entry, CSV import/export (schema: `date,exercise,set_type,weight_kg,reps,rpe`), iCloud sync status, theme (light/dark/system), Delete all data (double confirm + typed word).

## 7a. Dynamic Type strategy & the AX stacked set row

The six-column set table (`# / Weight / Reps / RPE / Rest / ✓`) is the layout most at risk under large text. Three tiers, driven by `@Environment(\.dynamicTypeSize)`:

**Tier 1 — default through xxxLarge (last non-AX size):** full six-column grid; field text scales, column widths flex proportionally (Weight gets first claim on extra width).

**Tier 2 — AX1:** the grid survives by shedding, in order: (a) Rest collapses into the set-type badge row as a suffix chip (still editable via tap-through), (b) Prev ghost text shortens to weight-only. RPE stays if enabled — a 1–2 char field is cheap.

**Tier 3 — AX2+: the stacked set row** (mockup frame *C1 · AX Stacked Set Row*):

```
SET 2 · WORKING            PREV 100×8    caps label row, mono values
[ WEIGHT          ] [ REPS           ]   two half-width fields, ≥48pt tall
[ 102.5 kg        ] [ 8              ]
RPE 8 · REST 2:30                        secondary line, tap-through
[            ✓ Complete             ]    full-width button, ≥52pt
```

Rules: one set per hairline-separated card; Weight and Reps are the only always-visible fields; RPE/Rest demote to a tappable secondary line; the completion control becomes a full-width labeled button (a 26pt checkbox beside AX3 text is a proportion absurdity). Completed cards collapse to a single dimmed summary line `✓ 102.5 kg × 8 · RPE 8` — no field chrome. VoiceOver order: label row → weight → reps → secondary → complete.

**Enforcement:** the tier switch is one modifier on `SetTableView`, snapshot-tested at `large`, `xxxLarge`, `AX1`, `AX3` in both modes. Any new set-row feature must land in all three tiers or it doesn't merge.

## 7. Accessibility (ship-blocking checklist)

- [ ] Dynamic Type to AX5; set table switches to stacked vertical layout at ≥ AX2 (`@Environment(\.dynamicTypeSize)`)
- [ ] All targets ≥ 44×44; check control 52×44
- [ ] Completed = check icon + 55% row dim (never color alone); failure = `!` icon + warning color
- [ ] VoiceOver set row label: "Bench press, set 2 of 4, previous 100 kilograms for 8 reps. Weight, 102.5. Reps, 8. Not completed." Custom action: "Complete set"
- [ ] Rest timer announces at 10s remaining and completion
- [ ] Reduce Motion: springs → fades; no parallax
- [ ] Contrast ≥ 4.5:1 verified both modes (light-mode signal is #1FA968, not #30E585)
- [ ] Haptics: `.light` set complete, `.success` PR, `.warning` rest done

## 8. Performance & reliability contracts

- Set completion tap → visual response < 50ms (optimistic UI; persistence async).
- Session draft persisted within 500ms of any mutation.
- History and Progress queries paginated/aggregated in background; charts render from pre-aggregated weekly rollups (recomputed on session commit).
- Offline-first: everything works with no network; sync reconciles last-write-wins per entity with `updatedAt`.

## 8b. App Store submission package

- **Privacy nutrition label** (App Store Connect): declares *Health & Fitness* data (workouts, body measurements, heart rate) and *User Content* (notes) — all "linked to you" via CloudKit, **not** used for tracking; no third-party SDKs means no tracking section at all. Keep it true by keeping analytics out of v1.
- **Privacy policy URL** — mandatory with HealthKit. Must name: what Health data is read/written, that it never leaves HealthKit/CloudKit private DB, no sale/sharing, deletion path (Delete All Data in Settings removes CloudKit records and app-created HKWorkouts). Host before submission; App Review checks the link resolves.
- **Usage strings** (Info.plist), concrete not generic: `NSHealthUpdateUsageDescription` = "RepSetForge saves your completed strength workouts to Apple Health so they appear in the Fitness app and count toward your rings." `NSHealthShareUsageDescription` = "RepSetForge reads your heart rate and energy burned during workouts, and your body weight and body-fat measurements, to display them in your training and body-trend charts." Vague strings ("to improve your experience") are a top HealthKit rejection cause.
- **App Review notes**: state that HealthKit permission is requested at first workout completion (so the reviewer knows to complete a workout to see it), that the exercise database is intentionally user-populated, and include a 60-second demo path: create exercise → start workout → log 2 sets → finish → see Health save row.
- **Screenshots**: must show the Health integration if the listing mentions it (summary screen with the "Saved to Apple Health" row). 6.9" and 6.5" sets minimum; dark mode as primary matches the product.
- **Review-rejection tripwires already designed out**: permission-in-context (§4b), no Health data used for ads/analytics, account deletion not applicable (no accounts — CloudKit uses the Apple ID silently), and the app is fully functional when Health permission is denied.
- **Pre-submission checklist**: TestFlight external beta round (Health flows behave differently on device vs. simulator — HealthKit is simulator-limited), test the CloudKit production container (dev and prod containers are separate; schema must be deployed to production in CloudKit Console before release), verify Delete All Data against production CloudKit, and run the app with Health permission denied end-to-end.

## 9. Build order

**v1.0 (App Store submission)**
1. Data model + session persistence/restore
2. Exercise Focus view + set row (the product lives or dies here) + read-only Index sheet
3. Rest timer + Live Activity + Dynamic Island (all presentations, §4)
4. Exercise picker + dedup + create-exercise flow (DB ships empty — this flow is v1-critical)
5. Home, Summary, routine-update prompt, HealthKit export (phone-only path, §4b)
6. Routine builder + library + double-progression ladder
7. History, Progress, PR engine backfill
8. Settings, CSV, first-run placeholder modules, light mode pass, accessibility audit (incl. AX stacked set row, §7a)
9. App Store package (§8b): privacy label, policy URL, usage strings, review notes, screenshots, CloudKit prod schema deploy

**v1.1**
10. Watch companion app (§4c): mirrored HKWorkoutSession, live HR/kcal telemetry row, Watch-owned Health writes
11. Additional progression methodologies as `ProgressionRule.type` cases: 5/3/1, percentage waves, RIR autoregulation
