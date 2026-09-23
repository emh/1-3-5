# Exercise Snacks — iOS Implementation Plan

Based on [the PRD](prd.md) and [the supplied mocks](mocks.png). Prepared September 22, 2026.

## 1. Build approach

Build a small SwiftUI iPhone app with one history screen, a snack preview sheet, a full-screen timer, and a short settings flow. Keep exercise definitions as text and completed snacks as immutable snapshots. Use local JSON persistence, native system file interfaces, and no third-party dependencies.

The repository currently contains only the PRD and mocks. There is no existing app, project configuration, or test suite to preserve. The local toolchain reports Xcode 26.6 and the iPhoneOS 26.5 SDK.

Recommended deployment target: **iOS 26.0+**, portrait, iPhone only for MVP. This is a proposed interpretation of “current iOS versions,” not a requirement stated in the PRD. Use Swift 6 and Observation, with an ordinary checked-in Xcode project and a shared build scheme.

**Confirmed timer behavior:** locking the phone or switching apps does not pause a running snack. Reconcile elapsed time when the app returns. A manually paused snack stays paused.

## 2. What to preserve from the mocks

The composite shows eight states, read left to right across each row:

| Mock | Implementation |
| --- | --- |
| Top 1: history | Fixed title/settings header; date-grouped text log; aligned time, duration, and exercise columns; bottom `1 / 3 / 5` controls. |
| Top 2: preview | `YOUR SNACK`, exercise count, numbered rows, individual rerolls, close, and a wide green `Go` button. |
| Top 3: reroll feedback | Brief, low-opacity green highlight on the changed row. |
| Top 4: settled reroll | The new exercise stays in the same position; other rows do not change. |
| Bottom 1: active | Close and position at top, exercise name above a large green timer, Pause and Skip below. |
| Bottom 2: paused | Muted `PAUSED` replaces the timer; exactly one Resume control at the bottom. |
| Bottom 3: next exercise | Position and name advance; each new minute starts at `01:00`. |
| Bottom 4: completion | Return to history, scroll to the new entry, briefly highlight it, then remove the highlight. |

Use a near-black background, slightly lighter sheet/control surfaces, off-white text, muted secondary text, and restrained green accents. Use system monospaced fonts, thin separators, generous spacing, circular icon controls, and solid fills. Establish reusable color, spacing, and typography tokens before building screens; tune them against simulator screenshots rather than copying the composite's pixel dimensions.

Resolve these mock ambiguities as follows:

- The mock's `00:60` is a display error; the PRD's `01:00` wins.
- The highlighted `3` does not add a selection step. Every size button immediately generates its preview. Initially emphasize `3` to match the reference, then emphasize the most recently chosen size; this is transient styling.
- Preserve the preview's dark rounded surface with native sheet presentation. Do not reproduce the extra stacked silhouettes in the composite as additional views. Allow a taller sheet and scrolling for five exercises or large text.
- Render solid colors rather than the image's apparent texture/glow. Keep native presentation behavior without adding decorative glass effects.
- Settings, library editing, empty history, errors, and confirmation dialogs have no mocks. Extend the same typography and spacing with sparse native controls.

Keep touch targets at least 44 points. Support Dynamic Type, VoiceOver labels, sufficient contrast, Reduce Motion, and long exercise names. At accessibility sizes, allow the log columns to reflow and the timer screen to scroll rather than clipping controls. Dark appearance is the MVP default; a separate light palette is outside this plan.

## 3. Navigation and ownership

```text
History
  ├─ 1 / 3 / 5 → Preview sheet → Go → Active snack → History
  └─ Settings → Exercise Library
              → Export share sheet
              → Import document picker → Replace confirmation
              → Reset confirmation
```

Use one `NavigationStack` for History → Settings → Exercise Library, an item-driven `.sheet` for preview, and a `.fullScreenCover` for the active snack. Coordinate preview dismissal before presenting the timer. Begin the countdown when the active screen is ready, so presentation time does not consume the first exercise. Guard repeated Go taps. No tab bar is needed.

Keep the structure small:

| Component | Responsibility |
| --- | --- |
| `AppStore` (`@MainActor @Observable`) | Own loaded app data, loading/error state, and serialized user mutations; publish successful commits. |
| `LocalDataStore` (actor) | Decode, validate, and atomically save snapshots off the main actor. |
| `LibraryParser` | Turn raw text into ordered, unique exercise names. |
| `SnackGenerator` | Initial selection and individual rerolls, with injectable randomness for tests. |
| `SnackSession` (`@MainActor @Observable`) | Timer state machine, pause/resume/skip/cancel, and one-time completion. |
| Feature views | Layout and local interaction state; no file I/O or timer arithmetic in view bodies. |

The app root owns shared objects through `@State`. Inject shared storage through the environment and pass session/draft state explicitly to the views that need it. Use value types for navigation destinations and preview drafts. Keep timer observation scoped to the active screen so a countdown tick cannot rebuild the history list.

Suggested organization, with types combined when splitting would add no clarity:

```text
ExerciseSnacks.xcodeproj
ExerciseSnacks/
  App/                 # App entry, root navigation, theme
  Models/              # Snack, stored data, export payload, session checkpoint
  Data/                # Atomic JSON storage, validation, seed library
  Features/
    History/           # Date sections and aligned log rows
    Snack/             # Parser/generator, preview, session engine, timer views
    Settings/          # Settings, text editor, import/export
  Resources/           # Assets and app icon
ExerciseSnacksTests/
ExerciseSnacksUITests/
```

## 4. Data and persistence

Keep the PRD's `Snack` fields: `id: UUID`, `completedAt: Date`, and `exercises: [String]`. Capture names when the snack is generated, so later library edits cannot rewrite history. Derive the displayed duration from exercise count; a three-exercise snack is logged as `3m` even if exercises were skipped. Do not introduce an elapsed-duration metric.

Persist one versioned JSON snapshot in Application Support:

- `version`
- `libraryText` — the editable source of truth
- `exercisePreferences` — mute/boost flags keyed by normalized exercise name
- `snacks` — completed snack snapshots
- `activeSession` — optional internal recovery checkpoint, described below

Use one serialized mutation path and atomic replacement of the file. Prevent an older asynchronous save from overwriting a later edit or an import/reset. Publish import/reset results only after the replacement succeeds. Write on meaningful changes, never every timer tick.

Seed the owner's 28 default exercises (updated September 23, 2026) on first launch and explicit reset. An intentionally empty library remains empty. If an existing file cannot be decoded, preserve it and show a minimal native recovery error with retry and an explicitly confirmed reset path; never silently replace it with seed data. On a write failure, retain pending changes in memory, report the failure, and allow retry.

For MVP, load the compact history once, sort newest first, and render it lazily. Cache date sections and refresh them when history, the local day, or the time zone changes. Use `TODAY`, `YESTERDAY`, and an unambiguous date for older entries. Use local completion time in the compact 24-hour style shown in the mock. Stable snack IDs preserve list identity.

“Infinite” means all stored history remains scrollable, with no retention cap. JSON still loads and rewrites the full dataset; lazy UI rendering is not disk pagination. Verify performance with 10,000 generated entries. If that exposes unacceptable launch/save/scroll behavior, replace the storage implementation with a paged database before release, without changing the UI or export contract.

### Library parsing and editing

- Accept ordinary newline variants, trim leading/trailing whitespace, ignore blank lines, and preserve order.
- Deduplicate case-insensitively after Unicode normalization, keeping the first spelling and capitalization. This is a proposed refinement of the PRD's duplicate rule.
- Preserve raw editor text during editing; parse for selection and export. Do not rewrite the text while the user is typing.
- Use a monospaced native text view with autocapitalization and autocorrection disabled. A keyboard accessory reveals Mute/Unmute and Boost 2×/Unboost only when complete exercise names are highlighted. A cursor or any partially selected exercise hides both actions; Done remains available. Muted text is struck through and boosted text is bold. Persist preferences separately from raw text.
- Autosave after a short debounce and flush pending edits on navigation away or backgrounding. Retain edits and expose retry if saving fails; no routine Save button.
- Disable snack sizes larger than the unmuted unique count. With an empty library, all sizes are disabled and one compact `Add exercises` action opens the library editor. If all entries are muted, offer `Manage exercises`.

### Selection and rerolls

Draw exactly 1, 3, or 5 unique, unmuted exercises without replacement. Boosted exercises have selection weight 2; others have weight 1. A reroll uses the same weights and excludes every exercise currently visible, including the row being replaced. Replace only that row.

When the library has exactly as many exercises as the snack, disable reroll buttons because no valid alternative exists. Never repeat the same exercise as a fake reroll. Keep accessibility labels specific, such as `Reroll pushups`; explain unavailable controls through accessibility hints rather than permanent helper copy.

## 5. Timer and lifecycle behavior

Implement and test the session engine independently of SwiftUI. The core states are `running`, `paused`, `finishing`, `completed`, and `cancelled`; a preview is a separate draft with no timer.

| Event | Result |
| --- | --- |
| Go | Create a session ID and start exercise 1 with exactly 60 seconds. |
| Foreground update | Derive remaining time from the clock and deadline, rather than decrementing an integer. |
| Deadline reached | Advance once, emit a subtle foreground haptic, and set the next deadline relative to the previous deadline. |
| Pause | First reconcile elapsed time, then freeze the precise remaining interval. |
| Resume | Set a new deadline from the frozen interval. |
| Skip while running | Advance immediately; the next exercise gets a fresh 60 seconds. |
| Skip while paused | Advance to a fresh 60 seconds and remain paused. This is the proposed default for an unspecified PRD case. |
| Final deadline or final Skip | Persist exactly one snack, clear the session, and return to History without a completion screen. |
| Close before Go | Dismiss the preview without confirmation or a log entry. |
| Close after Go | Show native `End snack?` confirmation. Temporarily freeze the timer while deciding; keeping the snack restores its prior running/paused state. Confirming discards it. |

Use `ContinuousClock` for in-process elapsed time so display ticks and changes to the wall clock cannot lengthen a minute. Continuous clock instants are local to the running process, so do not encode them for later launches. [Apple: ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)

The display rounds positive remaining seconds upward and formats them as `mm:ss`, with monospaced digits. The scheduler may be late; each update must reconcile all elapsed deadlines, not just one. For example, returning 130 seconds into an uninterrupted three-exercise snack shows exercise 3 with `00:50` remaining. Returning after 180 seconds records completion once.

On backgrounding, stop unnecessary display updates but retain the logical deadline. Reconcile when active again. Haptics are foreground-only; do not replay several missed haptics on return. iOS can suspend ordinary background apps, so elapsed-time reconciliation must not depend on receiving background timer callbacks. No background audio, notifications, or Live Activities are required. [Apple: background execution](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time)

Persist a small session checkpoint on start, pause/resume, skip, exercise transitions, and backgrounding. Include session ID, exercise snapshots, current index, running/paused state, and either a wall-clock deadline or frozen remaining interval. After process termination, reconstruct from that checkpoint on launch; a manually paused session restores paused. Wall-clock changes across process death are an acknowledged limitation of this fallback; normal in-process timing stays monotonic.

Completion must atomically append the snack and clear the checkpoint in the same snapshot. Reuse the session ID as the snack ID, making recovery/retries idempotent. When catching up, log the reconstructed completion time rather than the later time the app was reopened. On a save failure, keep a non-interactive finishing state and offer retry without discarding the completed session.

Serialize timer and button events. Associate actions with the current exercise/state generation so an expired timer callback or rapid duplicate tap cannot advance twice or create two log entries. Disable idle sleep only while actively displaying a running timer, and restore normal behavior on pause, exit, or backgrounding. Manual lock still follows the confirmed keep-counting behavior.

## 6. Settings, export, import, and reset

Settings has exactly the four PRD rows: Exercise Library, Export Data, Import Data, and Reset All Data. Use system back navigation and native alerts. No additional preferences screen is needed.

**Export:** generate the PRD's public version-1 JSON contract: `version`, parsed `library: [String]`, `exercisePreferences` with mute/boost flags, and `snacks` with UUIDs, ISO-8601 timestamps, and exercise arrays. Include muted library entries; exclude the internal active-session checkpoint. Use a dated `.json` filename and a native share sheet, backed by a temporary file whose lifetime extends through sharing. The export preserves all meaningful library/history data; editor-only blank lines and duplicate lines are normalized.

**Import:** use SwiftUI's native document picker restricted to JSON, read the selected file, then release security-scoped access. This access lifecycle is required by the picker API. [Apple: fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:oncompletion:))

Validate the complete file before changing local data:

- Supported version and required field types.
- Non-empty trimmed exercise names; reject names containing embedded newlines.
- Valid, unique snack UUIDs and parseable ISO-8601 dates, accepting timestamps with or without fractional seconds.
- Snack sizes of 1, 3, or 5, without duplicate exercises within a snack.
- An empty library or empty history is valid. Historical names do not have to exist in the current library.
- Normalize duplicate library names through the same parser; preserve historical exercise names. Ignore unknown fields for forward-compatible additions, but reject unknown schema versions.

Show a minimal replacement confirmation with the validated exercise/snack counts. Cancel leaves all data unchanged. On confirmation, join the imported library with newlines and replace the complete snapshot atomically; do not merge or partially import. Malformed, unreadable, or unsupported files produce a concise native error. A failed replacement preserves the previous data.

**Reset:** require destructive confirmation, then atomically clear history/session data and restore the default library. The confirmation should say that history is deleted and the starter library restored. Cancelling changes nothing.

## 7. Implementation milestones

Complete these in order. Each milestone should leave a building app and a concrete behavior to verify.

| Milestone | Work | Exit check |
| --- | --- | --- |
| 1. App shell and visual foundation | Create Xcode project, shared scheme, Swift 6 target, test targets, assets, dark theme, root navigation, fixture-backed history and timer previews. | Builds and launches on an iPhone simulator; typography, safe areas, header, log alignment, and bottom controls resemble the mocks. |
| 2. Local data and library | Models, seed data, atomic serialized storage, parser, library editor, date grouping, empty/error states, session-checkpoint schema. | Library/history survive relaunch; editing and disabled-size rules work; storage failures cannot silently erase data. |
| 3. Snack preview | Size selection, unique random picks, row rerolls, exhausted-pool behavior, preview dismissal, feedback highlight, coordinated Go transition. | Every valid size opens the right count; one reroll changes one row; dismissal creates no history. |
| 4. Complete snack flow | Clock-driven engine, timer screen, pause/resume, skip, cancel, haptics, lifecycle reconciliation, recovery, one-time completion persistence. | A snack can run end to end and return to the newly added log entry; backgrounding and recovery pass deterministic tests. |
| 5. Data portability and reset | Settings actions, JSON export/share, validated import/replace, reset, native errors and confirmations. | Export → reset → import restores equivalent library/history; cancellation or invalid input leaves existing data intact. |
| 6. Accessibility and release verification | Screenshot comparison, small/large iPhone layouts, large text, VoiceOver, Reduce Motion, performance fixture, app icon, release build and device checks. | All PRD acceptance criteria pass; no clipped controls, timer drift, duplicate completions, or persistence regressions. |

Milestones 1–4 produce the core usable app. Milestones 5–6 complete the stated MVP; import/export and reset are not deferred extras.

## 8. Verification plan

Use Swift Testing for domain/storage tests and XCTest UI tests for a small number of complete user flows. Inject a controllable clock, random generator, and temporary storage URL so tests are deterministic and do not require waiting through real minutes.

**Focused automated coverage:**

- Parsing whitespace, blank lines, newline variants, case duplicates, Unicode, and stable ordering.
- Selection uniqueness for 1/3/5, insufficient libraries, individual rerolls, and no-alternative rerolls.
- Timing at 60/180/300 seconds, rounding near boundaries, delayed callbacks, pause/resume precision, paused/running skips, cancel/keep, and foreground catch-up across several exercises.
- Races between Skip and expiry, repeated Go/completion actions, recovery of paused/running sessions, and retrying a completion without duplicate history.
- Persistence round trips, first-launch seeding versus a deliberately empty library, corrupted-file handling, write failures, and mutation ordering.
- Import/export round trips, invalid schema/date/UUID/count, duplicate IDs, unsupported versions, cancelled replacement, and failed replacement retaining old data.
- Date sections across midnight, time-zone changes, and daylight-saving boundaries.

**UI and device checks:**

1. Choose each snack size, preview, reroll, Go, pause, resume, skip, complete, and verify the newest log row.
2. Cancel preview and active snacks; verify that neither creates history.
3. Edit the library down to 0, 1, 2, 3, and 5 unique entries; verify size and reroll availability.
4. Exercise native Files import and share-sheet export, including cancel/error paths; reset and restore a real export.
5. Match the eight mock states with deterministic screenshot fixtures; cover five-row previews and long names too.
6. On a physical iPhone, verify haptics, idle sleep restoration, manual lock, app switching, and resumed/cold-launch catch-up. Simulator tests alone are insufficient for these behaviors.
7. Verify large text and VoiceOver, including readable exercise position and remaining time without announcing every second.
8. Load 10,000 history records and inspect launch, save, memory, and scrolling. Profile only if those checks expose a problem.

Acceptance mapping: PRD criteria 1 and 10 → history/storage; 2–4 → preview; 5–9 → session engine; 11 → library editor; 12–14 → export/import/reset. Run the full acceptance walkthrough after the final release build.

## 9. Boundaries and delivery

Keep all PRD non-goals out of the build: accounts, network services, analytics, cloud sync, HealthKit, Watch, statistics, categories, configurable durations, exercise instruction media, recommendations, notifications, and social features. Also omit the optional Copy Library action for MVP.

The build deliverable is a runnable Xcode project with meaningful automated tests, screenshot fixtures, a short README covering build/run and data format, and a completed acceptance checklist. Device signing needs the owner's development team; App Store/TestFlight distribution is a separate delivery step. Confirm the final bundle identifier and icon during app setup, without blocking simulator development.

Remaining proposed defaults are explicitly recorded above: iOS 26 minimum, case-insensitive deduplication, paused Skip staying paused, cancellation temporarily freezing time, last-used size emphasis, and recovery after process termination. The confirmed background policy is keep counting and catch up on return.
