# RepSetForge

A serious strength-training logger for iOS. Build routines, log sets/reps/weight/RPE fast, track PRs, follow a double-progression ladder per exercise, and export completed workouts to Apple Health.

This is a from-scratch rebuild (July 2026). RepSetForge previously shipped as an RPG-themed quest/XP fitness app; that concept has been fully retired in favor of a dense, data-forward lifting log in the spirit of apps like Strongsplit.

## Status

Early: the SwiftData model layer, CloudKit-ready persistence, exercise-name dedup, design tokens, and a minimal tab shell exist. The core logging screen and everything past it is still being built — see [`TODO.md`](TODO.md).

## Stack

- SwiftUI + SwiftData, iOS 17+, Swift 6
- CloudKit-backed private sync with automatic local fallback
- WidgetKit/ActivityKit for Live Activities (planned)
- watchOS companion app (planned, v1.1)

## Documentation

- [`Docs/repsetforge-dev-spec.md`](Docs/repsetforge-dev-spec.md) — the canonical developer spec: architecture, data model, screen-by-screen behavior contracts, accessibility, performance/reliability rules, App Store submission checklist, and build order.
- [`Docs/repsetforge-hifi.html`](Docs/repsetforge-hifi.html) — hi-fi screen mockups and component states (open in a browser).
- [`CLAUDE.md`](CLAUDE.md) — quick-reference guidance for working in this codebase.
- [`TODO.md`](TODO.md) — the prioritized backlog.

## Quick start

```bash
# Generate the Xcode project file
python3 generate_project.py

# Open in Xcode
open RepSetForge.xcodeproj

# Or build/test from the command line (requires macOS + Xcode)
xcodebuild build -project RepSetForge.xcodeproj -scheme RepSetForge \
  -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project RepSetForge.xcodeproj -scheme RepSetForge \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## License

Private project, not currently licensed for redistribution.
