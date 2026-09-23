# Exercise Snacks

A minimal, local-first iPhone app for randomized 1, 3, or 5 minute movement sessions. Built with Swift 6 and SwiftUI for iOS 26+, with no third-party packages, account, backend, analytics, or network requests.

## Build and run

Open `ExerciseSnacks.xcodeproj`, select the **ExerciseSnacks** scheme and an iPhone simulator, then Run. The project is checked in; XcodeGen is only needed when changing the project configuration or adding source files.

```sh
xcodegen generate
xcodebuild -project ExerciseSnacks.xcodeproj \
  -scheme ExerciseSnacks \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData build
```

For a physical iPhone, choose your development team in Signing & Capabilities and replace the development bundle identifier `local.ExerciseSnacks` with your own. Distribution signing and TestFlight/App Store setup are not configured.

## Test

```sh
xcodebuild -project ExerciseSnacks.xcodeproj \
  -scheme ExerciseSnacks \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build/DerivedData \
  -parallel-testing-enabled NO test
```

Domain tests use an explicitly supplied clock and controlled storage; they cover timer deadlines, background catch-up, recovery, parsing, rerolls, import validation, and failed/ordered writes. UI tests cover the real snack flow and use a separate data file so they cannot modify ordinary app data. Screenshots are attached to the UI test results.

Debug launch arguments:

- `--fixture-history`: show an in-memory sample history for visual inspection. Changes in this mode are discarded when the app exits.
- `--ui-testing`: use a separate persistent UI-test data file.
- `--reset-test-data`: reset that test file on launch; only effective with `--ui-testing`.
- `--empty-library`: seed a new UI-test file with an empty library.

All fixture/test arguments are excluded from Release builds. SwiftUI previews cover both populated and empty history.

## Behavior and data

- Each exercise has 60 seconds. The timer keeps counting when locked or backgrounded and catches up when the app returns. Paused sessions remain paused, including after relaunch.
- Skipping counts toward the completed snack's planned duration. A three-exercise snack is always logged as `3m`.
- Skip while paused moves to the next exercise and remains paused. Cancellation temporarily freezes the timer while the native confirmation is open.
- The plain-text library autosaves. Parsing trims lines, ignores blanks, and removes case-insensitive duplicates while preserving the first spelling/order.
- Highlight one or more complete exercise names to show **Mute** and **Boost 2×** above the keyboard. A cursor, partial word, or incomplete multiword name keeps these buttons hidden. Every exercise touched by a multi-line selection must be fully highlighted; surrounding whitespace is optional. **Mute** strikes through the selected exercises and removes them from rotation; **Boost 2×** bolds them and doubles their selection weight. Tap **Unmute** or **Unboost** to reverse either setting.
- Boost is a relative weight for each draw, not a guarantee of twice the inclusion probability for a whole snack. Muting takes precedence; an exercise can retain its boost while muted. New snacks and rerolls both use weighted sampling without duplicates.
- Preferences follow single-line renames and matching exercise names when lines move. New lines start normally; duplicate names share preferences. A multi-line mixed selection applies the setting to all selected exercises; selecting all already-muted/boosted lines clears that setting.
- Snack sizes require enough unique, unmuted exercises. Reroll is disabled when the library contains no eligible alternatives.
- Session completion and checkpoint removal are saved together; recovery/retry reuses the session UUID to avoid duplicate records.

Storage is a versioned JSON file at `Application Support/ExerciseSnacks/data.json` inside the app sandbox. It contains raw `libraryText`, `exercisePreferences` keyed by normalized exercise name, completed `snacks`, and an optional recovery checkpoint. Writes are serialized and atomic. An unreadable file is preserved and produces an error instead of being silently reset.

The shipping version-1 JSON contains `version`, `library: [String]`, `exercisePreferences: {name: {isMuted, isBoosted}}`, and `snacks: [{id, completedAt, exercises}]`. Preferences are optional and default to normal, unmuted exercises. Dates are ISO-8601; imports accept fractional and whole-second timestamps. Export normalizes blank/duplicate library lines, includes muted exercises and their preferences, and excludes an in-progress session. Import validates the whole file and replaces data only after confirmation. Reset restores the 28 starter exercises, clears all mute/boost preferences, and clears history.

Elapsed time uses a monotonic clock while the process lives. Recovery after process termination uses a saved wall-clock deadline, so changing the system clock between termination and relaunch can affect that recovery. iOS background suspension prevents guaranteed background haptics; the app emits transition haptics in the foreground only.

## Project guide

- `ExerciseSnacks/App`: app entry, navigation, observable store, theme, debug fixtures.
- `ExerciseSnacks/Models` and `Data`: versioned persistence, import/export validation, and seed data.
- `ExerciseSnacks/Features`: history, preview/timer, and settings/library views.
- `ExerciseSnacksTests` / `ExerciseSnacksUITests`: domain and end-to-end tests.
- `project.yml`: XcodeGen project definition.
- `docs/icon.png`: supplied icon artwork; [preparation notes](docs/icon-preparation.md) describe the production asset.
- [PRD](docs/prd.md), [mocks](docs/mocks.png), [implementation plan](docs/implementation-plan.md), and [verification record](docs/verification.md).

History has no retention cap. The MVP loads/writes one compact JSON snapshot and renders rows lazily; it does not use disk pagination. A 10,000-record persistence/grouping round trip is included in the tests.
