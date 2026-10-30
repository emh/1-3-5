# MVP verification

Simulator verification used Xcode 26.6 and iOS 26.5 on iPhone 17 Pro and iPhone 17e. Device deployment environments and verification results are recorded below. TestFlight/App Store distribution signing is not configured.

## Monochrome widget marker fix — October 29, 2026

- The device screenshot exposed that the apparent hollow marker used an opaque background-colored fill, which tinted/clear Home Screen rendering recolored. The completed marker also blended into the arc. Apple's [accented-rendering guidance](https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass) confirms that these modes replace colors while retaining opacity.
- Replaced the fill with a true hollow stroke and masked the ring underneath both markers. The completed marker is larger and separated from the arc by a transparent halo. Separate cutout masks preserve transparency when markers overlap; exact alignment remains a bullseye.
- The widget reads its rendering mode. In monochrome, behind pace uses a dashed arc and ahead uses a solid arc; full-color appearances retain red/green. Interior snack dots and the absence of visible labels are preserved.
- Simulator and Release device builds passed. Reviewed actual SwiftUI chart renders for behind/aligned/ahead at 15 of 30, plus zero, one, and above-target counts. Alpha assertions verified expected-center and completed-halo opacity of 0, and expected-outline and completed-center opacity of 1. Preview: `build/widget-pace-preview/monochrome-preview.png` (ignored). These are chart renders, not device Home Screen captures.

- Installed the fix in place on the iPhone 18 Pro using the existing signing identity and profiles. Signing and required-OCSP checks passed. Retried transient device-connection failures; final launch and process checks confirmed the new app and widget running. All 20 saved sets were preserved and `data.json` was byte-for-byte unchanged. Records: `build/widget-mono-*`.

## Dot-filled widget deployment — October 29, 2026

- Built and installed the Release app and embedded widget as an in-place update on the connected iPhone 18 Pro. The app launched without test arguments or a debugger; subsequent process inspection confirmed both app and widget running from the new installation.
- Reused existing certificate `3D27727A9E8E7F86DDAD63A68A6EC336055A8DC8` and the existing app/widget provisioning profiles. No provisioning-update flag or certificate creation/revocation was used. Deep signature verification, entitlement/profile checks, and certificate verification with required OCSP response passed at deployment time. Both profiles expire November 4, 2026.
- Backed up saved data before installation and compared it after launch: `data.json` was byte-for-byte unchanged, retaining all 19 saved sets. The existing bundle identifiers and App Group remain unchanged.
- Signed products: `build/WidgetDotsDevice`. Build, backup, install, launch, process, and data-verification records: `build/widget-dots-*` (ignored). Home Screen appearance was not directly captured from the device.

## Signing follow-up — October 29, 2026

- The user reported that the exported identity was marked revoked on the other Mac and confirmed that the account still uses a free Personal Team.
- A fresh Apple revocation check confirmed certificate `3772B871FC09A8454FF51350702D1D04E2F794F4` revoked with reason 4, superseded. The response does not identify the Mac or action responsible. Yesterday's successful launches and trust checks did not establish lasting validity.
- Certificate `3D27727A9E8E7F86DDAD63A68A6EC336055A8DC8`, selected for Timer Blocks yesterday, still passed code-signing trust verification with revocation checking. The imported identity did not remain the sole identity used across both apps. Automatic provisioning was allowed during yesterday's builds; the available logs do not establish which action revoked the imported certificate.
- This follow-up made no certificate, provisioning, or device-install changes. Diagnostic records are under `build/signing-followup-*`. Reimporting the revoked `.p12` cannot restore it; further recovery needs an identity that remains valid and coordination between the Macs before automatic signing changes.

## Signing recovery — October 28, 2026

- Exercise Snacks and Timer Blocks (`dev.emh.ExerciseTimer`, from the sibling `3-2-1` project) stopped during launch. Both previously used certificate `BD0937264F9E324710DA75A612843340FC6BD5B2`; Apple's revocation response marked it revoked with reason 4, superseded. Their provisioning profiles had not expired. The response did not identify the Mac or action responsible for the revocation.
- After the user imported a signing identity from the other Mac, the Exercise Snacks Release build used certificate `3772B871FC09A8454FF51350702D1D04E2F794F4`. Xcode selected a separate available certificate, `3D27727A9E8E7F86DDAD63A68A6EC336055A8DC8`, for the Timer Blocks Release build. Both certificates passed code-signing trust verification with revocation checking; both app signatures and provisioning entitlements were verified.
- Both apps were updated in place on the iPhone 18 Pro running iOS 27.0.1 and launched without a debugger or test arguments. Subsequent process checks confirmed both remained running. The team and bundle identifiers were preserved.
- App files were backed up locally before installation. Exercise Snacks' `data.json` was byte-for-byte unchanged afterward. Timer Blocks had no saved `Application Support/ExerciseTimer` directory before the update; its existing Library files were backed up, and the app was not uninstalled or reset.
- Both renewed development profiles expire November 4, 2026 (America/Vancouver). Build, signing, installation, launch, and data-comparison records are under the ignored `build/redeploy-*` paths. No application source changes were needed for this recovery.

## New iPhone deployment — October 27, 2026

- Release build succeeded with Xcode 27.1 for the connected iPhone 18 Pro running iOS 27.0.1. The phone is paired and Developer Mode is enabled.
- Renewed automatic provisioning includes the new device. Code-signature verification passed, and the app’s signed entitlements match its provisioning profile and existing bundle identifier `local.ExerciseSnacks`.
- Installed version 1.0 (build 1) successfully without uninstalling or resetting data. Initial launch was rejected by iOS with a security/trust error. After the user trusted the developer account, the app launched without test arguments or a debugger; a subsequent process check confirmed it remained running.
- The profile expires November 3, 2026 (America/Vancouver). Build, signing, installation, and launch records are stored locally under `build/deploy-new-phone-*`.

## iPhone deployment — September 23, 2026

- Release build succeeded for a physical iPhone 16 Pro Max running iOS 26.6.2. Code-signature verification passed using the configured development team `FMA5NVPU24` and its provisioning profile for `local.ExerciseSnacks`.
- Installed version 1.0 (build 1) as an update to the existing app without uninstalling it, then launched it without test arguments or a debugger. A subsequent process check confirmed it remained running.
- The development profile includes the connected iPhone and expires September 30, 2026 at 14:30 UTC. This is a direct development deployment; TestFlight/App Store distribution is not configured.
- The development team is also saved in `project.yml` so project regeneration preserves signing. Build/install/launch logs and structured results are under `build/deploy-*`; the signed app is under `build/DeviceDeployment/Build/Products/Release-iphoneos/`.

## Theme and icon appearances — September 23, 2026

- Debug build passes with Light, Dark, and System settings. System is the default; UI-test preferences use a separate UserDefaults suite.
- All 43 selected regression tests pass: 41 domain/storage tests plus the preview → pause → skip → completion → relaunch flow and the library toolbar at the largest accessibility text size.
- Simulator checks on iPhone 17 Pro, iOS 26.5 confirm immediate selection changes, a saved Dark choice after process relaunch, return from Dark to System, and a Light override while the device is dark.
- Changing device appearance with System selected updates the native library editor, selected text, and keyboard accessory colors live, without losing the selection. The simulator’s original light appearance was restored after verification.
- Light-mode foreground, secondary, accent, and destructive text each exceed 4.5:1 contrast against the background, surface, and control colors.
- Light and dark header icons render with their corresponding themes. Asset-catalog inspection confirms both 1024 × 1024 Home Screen icon variants and both header variants are compiled, with the original artwork retained for Dark. The light icon is opaque.
- Screenshots are saved locally under `build/theme-verification/`; light icon generation details are in [icon preparation](icon-preparation.md).

## Timer and log refinements — September 23, 2026

- The updated Debug build passes all 52 tests (41 domain/storage and 11 UI tests) on iPhone 17 Pro, iOS 26.5. The 16 session tests also pass after the final cue adjustment for resuming a fresh minute.
- Preparation lasts 10 seconds before the first full 60-second exercise. Tests cover pausing, skipping preparation without skipping an exercise, cancellation, checkpoint round trips, background catch-up, exact completion dates, and compatibility with existing running/paused checkpoints.
- Cue tests verify one short beep trigger at each 3, 2, and 1, and one longer beep trigger at each minute start, without replaying missed countdown seconds. Runtime logs show no timer-audio errors; physical-device audibility and volume remain a hardware check.
- Simulator recording confirms three separate full-screen pulses at `00:03`, `00:02`, and `00:01`. The screen respects Dim Flashing Lights.
- Screenshots and UI assertions verify the centered timer, upcoming exercise below it, final-exercise label, accessible controls at the largest text size, and log rows containing only time and exercise names.
- The updated Debug app is left paused in Simulator with fixture data for review.

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

- Verify timer sounds, haptics, and idle-sleep behavior on a physical iPhone, including playback volume, manual lock, and calls/interruptions.
- Perform a full VoiceOver walkthrough and check Reduce Motion on hardware.
- Verify the minimum supported iOS 26.0 runtime; the available simulator runtime used here is 26.5.
- Configure the owner's bundle identifier/signing team and prepare a signed archive.
- Prepare distribution metadata.

The app makes no claim to deliver haptics while suspended and requests no background execution modes, notifications, or networking entitlements.

## Widget deployment — October 28, 2026

- Release app and embedded Snack rhythm widget built with automatic provisioning and passed deep code-signature verification.
- Installed as an update on the connected iPhone 18 Pro and successfully launched `local.ExerciseSnacks`.
- Saved `data.json` was backed up before installation and confirmed byte-for-byte unchanged afterward.
- Build/install/launch records are under ignored `build/widget-*`; signed products are under `build/WidgetDeviceDeployment`.
- Direct inspection of the shared widget snapshot was blocked by the device file-transfer service because it resides at the App Group root. Home Screen rendering and shared-data display remain a manual check.

### Charts-only widget and per-exercise counts

- Removed visible widget text and resting icon; expanded the ring/pie to fill the small widget.
- Snapshot generation counts each exercise in a completed set, including existing history. Regression coverage verifies four sets of five equal 20, mixed set sizes, previous-day exclusion, and countdown reset.
- Widget tests passed; Release build and signature verification passed. Installed and launched the update on the iPhone 18 Pro. Saved data remained byte-for-byte unchanged.
- Records: ignored `build/widget-revision-*`.

### Four-stage elapsed clock

- Replaced countdown/overdue pie with four growing concentric stages, each taking one configured interval. Each stage fills clockwise from noon; completed inner circles remain filled. First stage is green, subsequent stages red.
- Clock begins empty after a completed set, at local midnight, or at the snacking window start; it clears outside the window and caps at four filled stages.
- Widget regression tests and signed Release build passed. Installed and launched on the iPhone 18 Pro; saved history was byte-for-byte unchanged. Records are under ignored `build/widget-stages-*`.

### Expected-pace widget — October 29, 2026

- Removed the interval setting and replaced the elapsed clock with daily expected progress: target × elapsed active time ÷ total active time. Completed and expected counts use the same local day. Legacy saved/exported schedules containing an interval still load.
- The ring always displays a solid completed marker and an outlined expected marker. The thicker connecting arc is red behind pace and green ahead; aligned markers form a bullseye. Counts and the pace label remain readable in light and dark appearances. The ring stays full after reaching the goal.
- Simulator Debug build and launch passed. Confirmed Settings contains the daily target and start/end times, with no interval control.
- All eight widget regression tests passed, covering fractional pace, completed exercise counts, goal overflow, future records, midnight, overnight windows, daylight-saving transitions, and data compatibility. The other 41 unit tests passed in the full suite run. The daylight-saving fixture uses a zone that observes both 2026 transitions.
- Rendered and visually reviewed the actual SwiftUI chart at small-widget dimensions in light/dark appearances, plus morning, end-of-window, and above-target states. Preview: `build/widget-pace-preview/preview.png` (ignored). Device installation and Home Screen delivery were not part of this change.

### Dot-filled widget revision — October 29, 2026

- Replaced the visible count, target, expected count, and footer with one interior dot per completed snack. The cluster grows within the ring and scales down for counts beyond the daily goal; it never caps the number of dots. Numeric progress and pace remain available to VoiceOver.
- Preserved the solid/outlined ring markers and red-behind/green-ahead connecting arc. Removing the footer lets the ring occupy the full chart area.
- Simulator Debug build passed. Rendered the actual SwiftUI chart and visually reviewed light/dark states, zero and one snack, the daily goal, overflow, and dense counts up to 300. Preview: `build/widget-pace-preview/dots-preview.png` (ignored).
