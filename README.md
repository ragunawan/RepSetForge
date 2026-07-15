# RepSetForge

RepSetForge is a native SwiftUI iOS workout logger based on `docs/repsetforge-dev-spec.md` and `docs/repsetforge-hifi.html`.

The current rebuild is a fresh v1.0 implementation after the previous repository contents were intentionally removed. It focuses on the production app shell, workout logging surface, exercise library, routine builder, history, progress, settings, local persistence, and testable service contracts for HealthKit, CloudKit, notifications, and Live Activities.

## Build

```bash
python3 generate_project.py
xcodebuild build -project RepSetForge.xcodeproj -scheme RepSetForge -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Test

```bash
xcodebuild test -project RepSetForge.xcodeproj -scheme RepSetForge -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Design Sources

- `docs/repsetforge-dev-spec.md`
- `docs/repsetforge-hifi.html`
- `docs/implementation-plan.md`

## Launch Arguments

- `--demo-data`: seeds local demo exercises, routines, sessions, and body metrics for screenshots/testing.
- `--reset-demo-data`: clears local app state before optional demo seeding.

