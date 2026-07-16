# RepSetForge Release Verification

Date: 2026-07-16
Build: v1.0
Tester:
Device:
iOS version:

Use this checklist for the Phase 3, Phase 6, and Phase 8 device gates that cannot be proven in simulator CI.

## Privacy Policy URL

- [ ] Host `Docs/privacy-policy.md` at a public HTTPS URL.
- [ ] Open the URL outside the developer account and confirm it resolves without authentication.
- [ ] Enter the URL in App Store Connect.

URL:

## CloudKit Production

- [ ] Archive a release build signed with the production CloudKit container.
- [ ] Deploy the CloudKit schema to production in CloudKit Console.
- [ ] Install the TestFlight build on a clean device signed into iCloud.
- [ ] Create an exercise, complete a workout, and confirm records sync after relaunch.
- [ ] Run Settings > Delete All Data and confirm app records are removed after relaunch.

Notes:

## HealthKit Device Gate

- [ ] Complete a workout and grant Health permission in context.
- [ ] Confirm the workout appears in Apple Health/Fitness.
- [ ] Edit the session in History and confirm the Apple Health workout is replaced through the existing `healthKitUUID`.
- [ ] Delete the session in History and confirm the Apple Health workout is removed.
- [ ] Repeat the demo path with Health permission denied and confirm RepSetForge remains fully usable.

Notes:

## Live Activity Device Gate

- [ ] Start a rest timer, lock the phone, and confirm the countdown ticks on the lock screen.
- [ ] Tap Skip from the lock screen and confirm the in-app rest state ends.
- [ ] Start another rest timer, background the app, and confirm the Live Activity remains current.
- [ ] Confirm the app remains functional when Live Activities are disabled in Settings.

Notes:

## Accessibility And Polish

- [ ] Run Dynamic Type AX5 on device and confirm set rows remain readable in stacked layout.
- [ ] Audit tap targets in Settings, Library builder, History editor, and CSV controls.
- [ ] Confirm rest timer VoiceOver announcements at 10 seconds remaining and completion.
- [ ] Confirm haptics: light set complete, success PR, warning rest done.
- [ ] Spot-check visual contrast on Home, Focus, Summary, History, Progress, Library, and Settings in light and dark mode.

Notes:

## App Store Screenshots

- [ ] 6.9-inch dark mode set captured.
- [ ] 6.5-inch dark mode set captured.
- [ ] Summary screenshot includes the Apple Health save row if Health integration is mentioned in listing text.

Screenshot filenames:

## Sign-off

All required checks passed:
Release blocker notes:
