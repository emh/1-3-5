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

Direct iPhone deployment uses automatic signing with development team `FMA5NVPU24` and the existing bundle identifier `local.ExerciseSnacks`; both the Xcode project and `project.yml` preserve that configuration. Select the connected iPhone in Xcode and Run using the team's Apple development identity. Keep the bundle identifier unchanged to update the existing installation and retain its data. TestFlight/App Store distribution is not configured.

The October 28, 2026 Release deployment was installed and launched on an iPhone 18 Pro running iOS 27.0.1 using an identity imported from another Mac. On October 29, Apple reported that imported certificate revoked as superseded, which required a newly signed deployment even though its provisioning profile expires November 4, 2026. The October 29 dot-filled widget update was subsequently signed with the existing valid identity, installed in place, and launched successfully; saved data was unchanged. See the signing follow-up in [the verification record](docs/verification.md).

For development on multiple Macs, transfer the existing signing identity as a password-protected `.p12` containing both the certificate and its private key. Signing in to the same Apple account alone does not transfer that private key. Importing an identity does not ensure automatic signing selects it for every project or prevent later revocation. Check the actual signing certificate and its current status; do not use certificate reset/revocation as a routine repair for a missing private key. A certificate revocation can stop an installed development app from opening even before its provisioning profile expires; rebuild and update the app with a valid identity, keeping its bundle identifier unchanged.

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

- Settings offers **Light**, **Dark**, and **System** themes. System is the default and follows the device’s appearance. The choice applies immediately and is saved on this device separately from library/history imports, exports, and resets.
- The header icon follows the app theme. Light and dark Home Screen icon variants are also included; iOS chooses those using the Home Screen’s icon appearance setting.
- Snacks begin with a 10-second preparation countdown, followed by 60 seconds per exercise. The centered timer shows the next exercise underneath. Preparation can be paused or bypassed with **Start now**.
- At 3, 2, and 1 seconds, the screen pulses and a short beep plays. A longer beep starts each exercise minute. Sounds mix with other audio and use the device's playback volume; screen pulses respect **Dim Flashing Lights**. These cues play while the app is active.
- The timer keeps counting when locked or backgrounded and catches up when the app returns. Paused sessions remain paused, including after relaunch.
- Skipping counts toward the completed snack's planned duration. Log rows show the completion time and exercise names, without a separate duration column.
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

### Home Screen widget

Add **Snack rhythm** from the Home Screen widget gallery (small size). Tap it to open the app. Settings → Snack rhythm controls the daily target (default 30) and daily window (default 7am–7pm). There is no interval setting. Overnight windows are supported; start and end must differ.

The green ring and solid dot track completed snacks toward the daily goal. An outlined marker shows expected progress: daily target × elapsed window time ÷ total window duration. For example, a target of 30 expects 15 snacks at 1pm in the default window. A thicker red arc shows the distance to catch up; a brighter green arc shows your lead. In monochrome Home Screen appearances, a dashed arc means behind and a solid arc means ahead. Transparent cutouts separate the solid completed marker from the arc and preserve the hollow expected marker; neither relies on background-colored fills. The interior fills with one dot per completed snack, arranged in a growing circular cluster. There are no visible counts or pace labels; VoiceOver still announces the counts and pace. Dot positions stay stable up to the daily goal, then scale down to fit additional snacks. Reaching the goal keeps the ring full, including when you exceed the target. Each one-minute exercise counts as a snack: four completed sets of five count as 20.

Expected progress stays at zero before Start and at the full target after End. Both completed and expected progress reset at local midnight. Overnight schedules spread the daily target across that calendar day's morning and evening active portions, holding steady between them. Window duration uses elapsed time, including daylight-saving changes.

The app publishes an atomic snapshot to App Group `group.local.ExerciseSnacks` after successful saves and requests a widget reload. The widget includes five-minute timeline steps and exact midnight/window transitions; iOS controls actual delivery. Schedule settings round-trip through export/import, with defaults for older files; legacy interval fields are ignored. Device signing requires the App Group capability on both app and widget provisioning profiles. Simulator builds do not verify device provisioning.
