# RepSetForge App Store Submission

## Privacy Nutrition Label

Data collected:
- Health & Fitness: workouts, body measurements, heart rate.
- User Content: workout notes and exercise notes.

Data use:
- App functionality only.
- Linked to the user through Apple Health and the user's private CloudKit database.
- Not used for tracking.
- Not sold or shared.

Tracking:
- No tracking.
- No third-party SDKs.

## Privacy Policy

Draft: `Docs/privacy-policy.md`.

Required before submission: host the public privacy policy URL and enter it in App Store Connect.

Policy must state:
- RepSetForge reads heart rate, energy burned, body weight, and body-fat measurements when permission is granted.
- RepSetForge writes completed strength workouts to Apple Health when permission is granted.
- App data syncs through the user's private CloudKit database.
- Health data and CloudKit-backed app data are not sold, shared, or used for tracking.
- Settings > Delete All Data removes app records and app-created Health workouts.

## Usage Strings

Verified in `RepSetForge/Info.plist`:
- `NSHealthUpdateUsageDescription`: "RepSetForge saves your completed strength workouts to Apple Health so they appear in the Fitness app and count toward your rings."
- `NSHealthShareUsageDescription`: "RepSetForge reads your heart rate and energy burned during workouts, and your body weight and body-fat measurements, to display them in your training and body-trend charts."

## App Review Notes

HealthKit permission is requested at first workout completion. The exercise database is intentionally user-populated.

Demo path:
1. Open RepSetForge.
2. Tap the floating add button.
3. Create an exercise.
4. Log 2 sets.
5. Finish the workout.
6. Review the Summary screen and Apple Health save row.

Health-denied path:
1. Deny Health permission when prompted.
2. Confirm the workout still saves in RepSetForge.
3. Confirm Summary shows Health access off messaging.

## Screenshot List

- Home first-run placeholders.
- Focus workout logging with set table.
- Focus workout after first completed set with collapsed chart.
- Progression sheet.
- Summary with Health save row.
- History calendar/list.
- Progress charts locked and unlocked.
- Library routine builder.
- Settings with Health and Delete All Data controls.

## Release Checklist

- Complete `Docs/release-verification.md` and keep the signed-off copy with the release archive.
- CloudKit production schema deployed.
- Privacy policy URL hosted and entered in App Store Connect.
- TestFlight Health-denied path completed.
- On-device Live Activity lock-screen checklist completed.
- On-device Health workout write/edit/delete checklist completed.
