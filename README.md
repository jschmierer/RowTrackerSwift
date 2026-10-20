# RowTrackerSwift

A SwiftUI iPhone app for logging rowing workouts, viewing them in a history
list, and seeing progress over time.

Four tabs:

- **Dashboard** — total meters, this-week meters, workout count, best 2k.
- **Log** — pick workout type (timed or distance), choose number of intervals,
  then per-interval enter any two of time / distance / split; the third is
  derived.
- **History** — workouts newest-first, swipe to delete.
- **Progress** — Swift Charts line chart of average split over time (y-axis
  flipped so up means faster) and a bar chart of weekly meters.

On first launch with an empty database the app seeds about 15 sample workouts
so the charts aren't empty. Workouts persist in a local SQLite database via
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
