# Exercise Snacks — Product Requirements Document

## Overview

Exercise Snacks is a deliberately minimal native iOS app for doing very short randomized movement sessions throughout the day.

The app has only three core concepts:

1. **Exercise library** — a plain-text list, one exercise per line.
2. **Snack** — a randomly selected set of 1, 3, or 5 exercises.
3. **Log** — a chronological record of completed snacks.

Each exercise gets exactly **60 seconds**. There are no prescribed work/rest intervals. The user decides how to use that minute.

The app should feel closer to a clean terminal interface than a conventional fitness app: monospaced typography, sparse layout, minimal decoration, and almost no explanatory UI.

Reference screenshots will be placed in the project folder. Treat them as the primary visual reference.

---

## Platform

- Native iOS app
- Swift + SwiftUI
- iPhone-first
- Support current iOS versions
- Portrait orientation is sufficient for MVP
- Local-first; no account, backend, analytics, or networking required

---

## Main Screen

The main screen is primarily an infinite chronological activity log.

### Header

Top navigation contains:

- App title: `EXERCISE SNACKS`
- Settings button

Use monospaced typography.

### Log

Show completed snacks newest first.

Group entries by date.

Example:

```text
TODAY

18:31   3m   pushups
              dead hang
              hip airplanes

14:12   1m   kettlebell swings

09:06   5m   lunges
              pushups
              cossack squats
              hollow hold
              dead hang

YESTERDAY

16:44   3m   air squats
              side plank
              bird dog
```

Each entry contains:

- completion time
- duration (`1m`, `3m`, or `5m`)
- exercises performed

No cards or large containers are required. Prefer text, spacing, and thin separators.

The list should scroll indefinitely through stored history.

### Snack Controls

A fixed bottom control contains three buttons:

```text
1     3     5
```

These correspond to number of exercises/minutes.

Do **not** use bracket notation.

Use simple circular or minimal native-style controls consistent with the screenshots.

Tapping one generates a random snack but does **not** start immediately.

---

## Snack Preview

After selecting `1`, `3`, or `5`, present a modal/sheet showing the randomly selected exercises.

Example:

```text
YOUR SNACK

3 exercises · 1 min each

1   pushups             ↻
2   dead hang           ↻
3   hollow hold         ↻

            Go
```

### Behaviour

- Exercises are selected randomly from the exercise library.
- Do not select the same exercise twice within one snack.
- Each exercise row has an individual reroll button.
- Reroll replaces only that exercise.
- A replacement must not duplicate another exercise currently in the snack.
- There is **no "reroll all" control**.
- Closing the modal cancels the snack.
- `Go` starts the timer.

If the library contains fewer exercises than requested, disable unavailable snack sizes or handle gracefully.

Example:

- 2 exercises in library → `3` and `5` disabled.

---

## Active Snack Screen

Show one exercise at a time.

Example:

```text
×                                  1 / 3


                 PUSHUPS


                 00:45



          ⏸                 ⏭
        Pause              Skip
```

### Layout

Top:

- close/cancel button
- current position: `1 / 3`

Center:

- current exercise name
- large countdown timer

Bottom:

- Pause
- Skip

Do not show gesture instructions, help text, or descriptive copy.

### Timer

Each exercise starts at:

```text
01:00
```

and counts down to zero.

At zero:

- provide a subtle haptic
- automatically move to the next exercise
- reset timer to `01:00`

At the end of the final exercise:

- log the completed snack
- return immediately to the main screen
- newly completed snack appears at the top

No completion/celebration screen.

---

## Pause State

Pausing freezes the timer.

Example:

```text
×                                  1 / 3


                 PUSHUPS


                 PAUSED



          ▶                 ⏭
        Resume              Skip
```

There should be exactly one resume/play control: the bottom `Resume` button.

Do not place an additional play button in the center.

No help text.

---

## Skip

`Skip` immediately advances to the next exercise.

For MVP, treat a skipped exercise as part of the snack and include it in the logged exercise list.

If the final exercise is skipped, the snack completes normally.

---

## Cancel

The `×` control ends the current snack.

For MVP:

- ask for confirmation only if a timer has already started
- cancelled snacks are not logged

Keep the confirmation native and minimal.

---

## Exercise Library

Settings → Exercise Library

The library is conceptually and visually a plain text file.

Example:

```text
pushups
air squats
deep squat
dead hang
cossack squats
hollow hold
kettlebell swings
bird dog
hip airplanes
ATG split squat
lunges
calf raises
plank
side plank
mountain climbers
burpees
```

### Editing

Use a multiline text editor.

Rules:

- one non-empty line = one exercise
- trim leading/trailing whitespace
- ignore blank lines
- preserve ordering
- duplicate lines should ideally be removed or prevented during parsing
- save automatically when leaving the screen

Do not introduce:

- exercise IDs in the UI
- tags
- categories
- equipment fields
- intensity
- modality
- forms
- reorder controls

Keep exercise names as simple text. Store mute and boost preferences separately, keyed by normalized exercise name.

### Rotation controls (September 23, 2026)

- Highlight one or more complete exercise names to reveal **Mute** and **Boost 2×** above the keyboard. A cursor or partial exercise selection keeps these buttons hidden; **Done** remains available. Every exercise touched by a selection must be fully highlighted, including all words of multiword names. Surrounding whitespace is optional.
- Muted lines appear struck through and do not enter new snacks or rerolls. **Unmute** returns them to rotation.
- Boosted lines appear bold and receive weight 2 rather than the normal weight 1. **Unboost** restores normal weight. Muting takes precedence and retains the boost for later.
- A mixed selection applies the chosen setting to every selected exercise. If all selected exercises already have it, the action removes it.
- Blank lines have no controls. Preferences save automatically, survive a single-line rename, and travel with matching names when reordered. Duplicate names share preferences.
- Import/export includes these preferences. Reset clears them.

---

## Settings

Settings screen contains only:

```text
Exercise Library      >
Export Data            >
Import Data            >

Reset All Data         >
```

Keep the screen sparse.

---

## Import / Export

Support exporting all local app data to a single JSON file.

Suggested format:

```json
{
  "version": 1,
  "library": [
    "pushups",
    "dead hang",
    "bird dog"
  ],
  "exercisePreferences": {
    "pushups": {"isMuted": false, "isBoosted": true},
    "dead hang": {"isMuted": true, "isBoosted": false}
  },
  "snacks": [
    {
      "id": "UUID",
      "completedAt": "2026-09-22T18:45:00Z",
      "exercises": [
        "pushups",
        "bird dog",
        "hollow hold"
      ]
    }
  ]
}
```

Export using the native iOS share sheet.

Import using the native document picker.

On import:

- validate structure
- replace existing data only after confirmation
- reject malformed files cleanly

Optionally expose `Copy Library as Text`, but this is not required for MVP.

---

## Reset

`Reset All Data` deletes:

- exercise library
- snack history

Require explicit confirmation.

After reset, restore a small default exercise library rather than leaving the app unusable.

---

## Data Model

Keep the persistence model intentionally small.

Suggested model:

```swift
struct Snack: Identifiable, Codable {
    let id: UUID
    let completedAt: Date
    let exercises: [String]
}
```

Library names are persisted as raw text, with the two rotation preferences stored separately:

```swift
var libraryText: String
var exercisePreferences: [String: ExercisePreferences]
```

Parse into exercises only when needed:

```swift
func parsedExercises(from text: String) -> [String]
```

This is preferable to creating a rich `Exercise` model because the product concept is explicitly that the exercise library behaves like a text file.

Persistence can use:

- SwiftData
- simple JSON/file storage
- UserDefaults for the library plus file storage for history

Prefer the simplest robust implementation.

---

## Random Selection

When generating a snack:

1. parse valid exercises
2. deduplicate
3. exclude muted exercises
4. draw the requested count without replacement, with weight 2 for boosted exercises and weight 1 otherwise

For individual reroll:

1. exclude all exercises currently visible
2. exclude muted exercises and use the same weights to select from the remaining library exercises
3. replace only the selected row

Avoid immediately returning the same exercise being rerolled.

Only the explicit Boost setting affects weight. No recommendation logic is required.

---

## Visual Design

The UI should match the supplied screenshots closely.

### Aesthetic

- dark mode first
- near-black background
- white / light gray text
- muted green accent
- monospaced typography
- minimal borders
- minimal rounded containers
- generous whitespace
- thin separators
- almost no decorative elements

### Typography

Prefer:

- `SF Mono`
- system monospaced fonts where appropriate

Exercise names can use uppercase on timer screens.

### Controls

Prefer native controls styled minimally.

Avoid:

- gradients
- cards everywhere
- large illustrations
- progress rings
- charts
- streaks
- badges
- motivational text
- onboarding
- tutorial copy
- unnecessary animation

### Motion

Keep animation subtle:

- sheet presentation
- timer transitions
- row replacement on reroll
- screen transition between exercises

Haptics:

- light haptic at exercise transition
- optional stronger haptic when snack completes

---

## Default Exercise Library

Ship with these 28 exercises in this order (updated September 23, 2026):

```text
pushups
air squats
split squats
cossack squats
situps
plank
side plank
dead hang
rope flow
indian club circles
steel club mills
kb swings
kb goblet squats
kb snatches
kb clean & presses
kb around the worlds
kb halos
rolling getups
underswitches
jump rope
kick throughs
horse stance
iso lunge
iso calf raise
deep squat
kb rows
glute bridges
suitcase carries
```

The default list is only seed data and can be completely replaced by the user.

---

## Non-Goals

Do not build these for MVP:

- accounts
- cloud sync
- HealthKit
- Apple Watch
- workout statistics
- exercise categories
- exercise metadata beyond mute and boost preferences
- custom durations
- work/rest configuration
- streaks
- achievements
- calories
- heart rate
- videos
- exercise instructions
- AI recommendations
- notifications
- social features

---

## MVP Acceptance Criteria

The build is complete when the user can:

1. open the app and see their snack history
2. tap `1`, `3`, or `5`
3. preview the randomly selected exercises
4. reroll any single exercise
5. tap `Go`
6. perform each exercise against a 60-second timer
7. pause/resume
8. skip
9. finish the snack
10. see it immediately added to the log
11. edit the exercise library as plain multiline text
12. export all data
13. import previously exported data
14. reset all data

The finished app should remain visibly simpler than a conventional fitness app. When deciding whether to add UI or functionality, default to leaving it out.
