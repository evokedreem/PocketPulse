# PocketPulse — Native SwiftUI

PocketPulse is a **pure native iPhone app** written in Swift and SwiftUI. This branch has no Expo, Expo Go, EAS, React Native, JavaScript runtime, Metro server, or third-party packages.

Tap the main button to log a pulse and verify animation, native haptic feedback, persistence, accessibility labels, and state changes.

## What it includes

- Native SwiftUI interface for iPhone
- Animated pulse counter with UIKit haptic feedback
- Persistent count using `@AppStorage`
- Reduce Motion and VoiceOver-friendly behavior
- XCTest unit coverage for counter logic
- GitHub Actions build and test workflow on macOS
- No third-party dependencies

## Install directly on Garrette's iPhone

The Apple Developer app on the iPhone manages enrollment and membership. It does **not** compile Swift or install Xcode projects. Direct installation is performed by Xcode on a Mac.

1. On a Mac, install Xcode 16 or later from the Mac App Store.
2. Clone the native branch:

   ```sh
   git clone --branch native-swiftui --single-branch https://github.com/evokedreem/PocketPulse.git
   cd PocketPulse
   open PocketPulse.xcodeproj
   ```

3. In Xcode, open **Xcode → Settings → Accounts**, add the Apple Account that owns the paid developer membership, and confirm the developer team appears.
4. Connect the iPhone to the Mac by USB, unlock it, tap **Trust**, and enable **Settings → Privacy & Security → Developer Mode** if iOS requests it.
5. In Xcode, select the **PocketPulse** project, then **PocketPulse → Signing & Capabilities**.
6. Turn on **Automatically manage signing** and select Garrette's developer team. The bundle identifier is `com.evokedreem.pocketpulse`.
7. Select Garrette's iPhone as the run destination at the top of Xcode.
8. Press **Run** (`⌘R`). Xcode builds, signs, installs, and opens PocketPulse directly on the iPhone.

After the first USB pairing, Xcode can enable **Connect via network** in **Window → Devices and Simulators** for later wireless installs.

This route does not use Expo, TestFlight, or the App Store. A paid-team development profile normally lasts up to one year; rebuild after the profile or membership renews.

## Run in the simulator

1. Open `PocketPulse.xcodeproj` in Xcode 16 or later.
2. Choose an iPhone simulator.
3. Press **Run** (`⌘R`).

The app targets iOS 17 and later.

## Test it

In Xcode, press **Test** (`⌘U`), or run:

```sh
xcodebuild \
  -project PocketPulse.xcodeproj \
  -scheme PocketPulse \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The `native-swiftui` branch runs its actual Xcode project through an unsigned Release build for the iPhone device SDK and Debug unit tests in an iPhone simulator on a macOS GitHub Actions runner. CI also reads the effective device/simulator Xcode build settings and verifies that Expo/React Native artifacts have not entered this branch.

## Branches

- `native-swiftui`: pure native SwiftUI development and direct Xcode installation
- `main`: preserved Expo/React Native experiment
