# RowTrackerSwift

A SwiftUI iPhone app for logging rowing workouts, viewing them in a history
list, and seeing progress over time.

Four tabs:

- **Dashboard** — total meters, this-week meters, workout count, best 2k.
- **Log** — date, workout type (Time, Distance, or Custom), optional
  intervals (shared or variable per-interval values) with optional rest
  between them (one shared value or one per interval; never counted in
  totals), then the time or distance plus one of split / the other
  quantity / watts; the others are derived. Optional stroke rate, workout
  heart rate (average and max), effort 0–10, and notes. Custom workouts
  are a title and free-text details. "Share workout" saves and opens the
  share sheet.
- **History** — workouts newest-first, swipe to delete. Tapping a workout
  (here or on the Dashboard) opens the detail screen: generated title
  ("3x500m"), header, a Split | Watts toggle, overall stats, intervals,
  and a comparison with the previous and best of the same workout plus a
  graph.
- **Progress** — Swift Charts line chart of average split over time (y-axis
  flipped so up means faster) and a bar chart of weekly meters.

Debug builds seed about 15 sample workouts into an empty database so the
charts aren't empty (Release builds start empty). UI tests launch with
`-uiTesting`, which uses a fresh in-memory database. Workouts persist in a local SQLite database via
GRDB.

## Relationship to the Python original

This is a SwiftUI port of the Python console app at
[github.com/jschmierer/RowTracker](https://github.com/jschmierer/RowTracker).
`RowingMath` and the `Workout` / `Interval` models were translated from the
Python `Workout`, `TimedWorkout`, and `DistancedWorkout` classes.
`StatsDash` maps onto the Dashboard / History / Progress tabs. The Python
`User` class was not ported — accounts are out of scope.

## Build and test

Requires Xcode 15.4+ (iOS 17 SDK or newer) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
cd ios
xcodegen generate
xcrun simctl list devices available   # pick an available iPhone
xcodebuild \
  -project RowTracker.xcodeproj \
  -scheme RowTracker \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  test
```

Swap `iPhone 17` for whichever simulator the previous command listed. The
`.xcodeproj` is gitignored and regenerated from `ios/project.yml`.

To install and launch after a successful build:

```sh
xcrun simctl boot "iPhone 17"
open -a Simulator
xcrun simctl install booted ios/build/Build/Products/Debug-iphonesimulator/RowTracker.app
xcrun simctl launch booted com.jschmierer.rowtracker
```

## Test vectors

`tests/vectors/*.json` are copied from the Python repo and drive the Swift
`RowingMathTests` so both targets agree on parsing and formatting math. Each
vector carries `python_actual` (what Python does today) and, where that
behavior is wrong, `expected` with `suspected_bug: true` beside it.

If the vectors change in the Python repo, copy the updated files back into
this repo and re-run the tests. They are the single source of truth; this
repo does not run the Python oracle.

## Continuous integration

The author develops on Windows, so building and testing the iOS app happens
on GitHub Actions. `.github/workflows/ios.yml` runs on every push and PR,
regenerates the Xcode project with XcodeGen, and runs the Swift Testing
target on a `macos-latest` runner.
