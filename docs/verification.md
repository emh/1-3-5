# MVP verification

Environment: Xcode 26.6, iOS 26.5 Simulator, iPhone 17 Pro and iPhone 17e. Debug tests and the final Release build pass. The Release app is installed and running in Simulator; distribution signing is not configured.

## PRD acceptance criteria

| Criterion | Implementation and evidence |
| --- | --- |
| 1. Open history | Local JSON loads on launch; date-grouped rows are newest first. Relaunch UI test passes. |
| 2. Select 1/3/5 | Fixed bottom controls; insufficient sizes disabled. Parser/selection tests and library UI test pass. |
| 3. Preview exercises | Native dark sheet; verified visually and by UI tests. |
| 4. Individual reroll | Only the selected row changes, without duplicates; unit/UI tests pass. |
| 5. Go | Sheet dismisses before the active screen starts; UI test passes. |
| 6. 60-second exercises | Exact-deadline tests cover 1/3/5 minutes. A real three-minute simulator snack completed and logged. |
| 7. Pause/resume | Fractional time is preserved; UI and cold-launch paused recovery tests pass. |
| 8. Skip | Running/paused/final Skip and stale-action races are covered by unit/UI tests. |
| 9. Finish | Atomic, idempotent completion; failed-save retry tested. |
| 10. New log entry | Immediate return with one new row; persists across relaunch. |
| 11. Edit library | Multiline text, debounce and exit/background flush; empty-library editing UI test passes. |
| 12. Export | Native share sheet → Save to Files verified in Simulator. |
| 13. Import | Native picker → validation → confirmation → replacement verified with the exported file. Malformed/version/date/ID/count rules are tested. |
| 14. Reset | Native confirmation verified; history clears and starter library is restored. Export → reset → import restored the generated history. |

## Additional checks

- 34 domain/storage tests and ten UI tests have passed across targeted runs. The initial mute/boost change was verified with 33 domain/storage tests and four library UI tests (37 checks); the stricter highlight requirement was checked with nine library tests and four library UI flows.
- Mute/Boost are hidden for a cursor, a partial exercise name, or a selection touching an incomplete boundary exercise. UI tests verify extending a partial-word highlight across a complete multiword name, showing the controls, applying a change, and hiding them again when the highlight is replaced. Complete names remain selectable at the largest text size; surrounding whitespace need not be selected.
- Library UI tests cover muting, boosting, single-line renaming, relaunch persistence, disabled snack sizes, multi-line selection, reversing both settings, and toolbar reachability at the largest text size. Screenshots verify bold and strikethrough styling.
- Deterministic sampling tests verify that muted entries never enter generation or rerolls, boosted entries receive 2:1 relative weight, and multi-exercise snacks stay unique. Storage/export tests preserve preferences and reject invalid preference keys or values.
- The largest accessibility text size was tested through a five-exercise preview and the pause/skip controls on both simulator sizes. The controls remain reachable; final screenshots verify that preview row numbers and exercise names have separate space.
- The 10,000-entry JSON save/load/grouping test completed in 0.178 seconds in this environment; this is a development measurement, not a performance guarantee.
- Corrupt files are preserved. Save failures retain the pending in-memory state and allow retry. Failed replacement does not publish the replacement.
- Background catch-up across multiple exercise boundaries and recovery with a new monotonic-clock origin are covered by deterministic tests. A UI test also backgrounds the running app through the Home screen and verifies that the timer continued counting on return.
- Initial simulator screenshots were compared with the supplied history, preview, and timer mocks. The PRD's `01:00` corrects the mock's `00:60`.
- The supplied `docs/icon.png` was prepared as an opaque 1024 × 1024 app icon and compiles in the final Release asset catalog; see [preparation notes](icon-preparation.md).
- The main header uses the supplied icon beside `exercise snacks`, with no repeated numeric title. A Release build and simulator screenshot verify the layout.

## Before distribution

- Verify haptics and idle-sleep behavior on a physical iPhone, including manual lock and calls/interruptions.
- Perform a full VoiceOver walkthrough and check Reduce Motion on hardware.
- Verify the minimum supported iOS 26.0 runtime; the available simulator runtime used here is 26.5.
- Configure the owner's bundle identifier/signing team and prepare a signed archive.
- Prepare distribution metadata.

The app makes no claim to deliver haptics while suspended and requests no background execution modes, notifications, or networking entitlements.
