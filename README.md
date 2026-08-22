# PocketPulse

PocketPulse is a tiny native iPhone app for testing a clean SwiftUI project from end to end. Tap the main button to log a pulse and verify animation, haptic feedback, persistence, accessibility labels, and state changes.

## What it includes

- Native SwiftUI interface for iPhone
- Animated pulse counter with haptic feedback
- Persistent count using `@AppStorage`
- Reduce Motion and VoiceOver-friendly behavior
- XCTest unit coverage for counter logic
- GitHub Actions build and test workflow
- No third-party dependencies

## Run it

1. Clone this repository on a Mac.
2. Open `PocketPulse.xcodeproj` in Xcode 16 or later.
3. Choose an iPhone simulator.
4. Press **Run** (`⌘R`).

The app targets iOS 17 and later. No developer account is required to run it in the simulator.

## Test it

In Xcode, press **Test** (`⌘U`), or run:

```sh
xcodebuild \
  -project PocketPulse.xcodeproj \
  -scheme PocketPulse \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

`project.yml` is included as the XcodeGen source of truth if you want to regenerate the project.
