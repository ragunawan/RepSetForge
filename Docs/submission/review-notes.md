# RepSetForge — App Review notes (v1.0)

RepSetForge is a strength-training tracker. All user data is stored in
SwiftData with iCloud (CloudKit private database) sync. No account, no
third-party services, no analytics SDKs.

## HealthKit usage
- **Write**: completed strength workouts are saved as `HKWorkout`
  (traditionalStrengthTraining) so they appear in Fitness and count toward
  rings. Permission is requested at the user's **first workout completion**,
  never at launch.
- **Read**: heart rate + active energy (displayed during/after workouts),
  body mass and body-fat percentage (Home "Body" trend chart).
- Editing a logged workout **updates** the same HKWorkout (tracked via its
  UUID); deleting a workout deletes it from Health. "Delete All Data" in
  Settings also purges all app-written HKWorkouts.
- The app is fully functional with Health permission denied — export lines
  and Health-sourced charts simply don't populate.

## Live Activities
A workout Live Activity shows elapsed time / current exercise / rest
countdown with a Skip button (LiveActivityIntent, in-process). All timer
rendering uses OS-driven `Text(timerInterval:)`. The app is fully
functional with Live Activities disabled.

## How to test quickly
1. Launch → Library tab → create a routine (create an exercise inline —
   the database ships empty by design).
2. Home → Start → log sets with the ✓ button (values inherit as ghost
   text; two taps logs an unchanged set).
3. Finish → summary appears; grant Health permission → workout visible in
   Fitness app.
4. History → edit or delete the session → Health entry updates/disappears
   and records recompute.

## Privacy label (App Store Connect)
- Health & Fitness data: **linked to user? No. Tracking? No.** Used for
  App Functionality only.
- No data collected by the developer — everything stays on device/in the
  user's private iCloud.

Privacy policy URL: https://gnwn.dev/repsetforge/privacy
