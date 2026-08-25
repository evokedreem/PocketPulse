# PocketPulse HealthKit Companion Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Expand PocketPulse into a polished, private, native SwiftUI health dashboard that reads and writes the user's authorized Apple HealthKit data without copying Apple's proprietary Health app UI or claiming access to unsupported private Health features.

**Architecture:** Keep `com.evokedreem.pocketpulse` so the new IPA updates the installed app. Add a protocol-driven HealthKit service, pure/testable metric models and formatting, a `@MainActor` dashboard model, and SwiftUI Summary, Browse, metric detail, manual-entry, and Privacy/Sharing screens. Health measurements remain in HealthKit; only UI preferences such as pinned metrics remain in `AppStorage`.

**Tech Stack:** Swift 5, SwiftUI, HealthKit, Charts, XCTest, Xcode 16, iOS 17+, GitHub Actions macOS CI, device-locked Ad Hoc distribution.

---

## Product and platform boundaries

- Use HealthKit, Apple's supported shared health-data store, after explicit per-category permission.
- Never claim that successful authorization means every read permission was granted; HealthKit intentionally protects read-denial status.
- Never upload health data to PocketPulse or Hostinger. Refresh from HealthKit on launch, foreground activation, pull-to-refresh, and after manual saves.
- Use a distinct PocketPulse visual system and wording. Do not copy Apple's icons, screenshots, exact layouts, branding, or private implementation.
- Do not attempt to replace or uninstall Apple's Health app.
- Do not imitate unsupported Apple-only functionality: Health Sharing administration, clinical records, medication management, organ donation, emergency Medical ID editing, or private recommendation engines.
- Preserve the one-device Ad Hoc distribution route. A release is blocked until the App ID and provisioning profile include the HealthKit entitlement.

## Acceptance criteria

1. A first-launch disclosure explains that data stays on device and permission is controlled by Apple Health.
2. The app requests read access for supported activity, heart, sleep, body, respiratory, nutrition, mobility, mindfulness, and vital metrics.
3. Safe manual entries can be written for body mass, water, resting/spot heart rate, blood glucose, oxygen saturation, body temperature, and mindful minutes where supported.
4. Summary shows pinned metric cards, latest values, timestamps, data-quality/empty states, and selected highlights.
5. Browse groups and searches the complete supported catalog.
6. Metric detail shows latest value, source/date context, 7/30/90-day range selection, native charts, and manual entry when writable.
7. Privacy/Sharing accurately describes HealthKit access and offers system-settings guidance plus a native summary export; it does not pretend to reproduce Apple Health Sharing.
8. All screens handle HealthKit unavailable, not requested, no data, loading, denied/empty, and query errors without fabricated sample values.
9. VoiceOver labels, Dynamic Type, Reduce Motion, high contrast, and light/dark appearance remain usable.
10. XCTest covers metric catalog behavior, unit formatting, trend/highlight calculation, pinned-metric persistence transformations, dashboard state transitions, and manual-entry validation.
11. Unsigned device build and simulator XCTest pass on macOS CI.
12. The signed IPA contains the HealthKit entitlement, the validated one-device profile authorizes it, public OTA files match the verified IPA checksum, and the target iPhone opens the build and reads authorized data.

---

### Task 1: Add failing domain-model tests

**Objective:** Define metric catalog, formatting, trend, pinning, and entry-validation behavior before production code.

**Files:**
- Create: `PocketPulseTests/HealthMetricTests.swift`
- Create: `PocketPulseTests/HealthPresentationTests.swift`
- Create: `PocketPulseTests/ManualEntryValidatorTests.swift`
- Preserve: `PocketPulseTests/PulseCounterTests.swift`

**Steps:**
1. Write tests against wished-for `HealthMetric`, `HealthValueFormatter`, `HealthTrendAnalyzer`, `PinnedMetricSelection`, and `ManualEntryValidator` APIs.
2. Push the tests alone.
3. Run GitHub Actions and verify compilation fails because those production symbols do not exist.
4. Record the failing run as the RED gate.

Representative assertions:

```swift
XCTAssertEqual(HealthMetric.steps.category, .activity)
XCTAssertEqual(HealthValueFormatter.display(10_234, for: .steps), "10,234")
XCTAssertEqual(HealthTrendAnalyzer.direction(current: 110, baseline: 100), .up)
XCTAssertEqual(PinnedMetricSelection.normalized([.steps, .steps, .sleep]), [.steps, .sleep])
XCTAssertThrowsError(try ManualEntryValidator.value("-1", for: .water))
```

### Task 2: Implement pure health domain models

**Objective:** Make Task 1 tests pass without HealthKit or UI dependencies.

**Files:**
- Create: `PocketPulse/Health/HealthMetric.swift`
- Create: `PocketPulse/Health/HealthModels.swift`
- Create: `PocketPulse/Health/HealthPresentation.swift`

**Steps:**
1. Implement supported categories and stable metric IDs.
2. Add locale-aware display formatting and explicit HealthKit canonical-unit conversion metadata.
3. Add trend direction/percentage calculations with zero/insufficient-data handling.
4. Normalize persisted pinned IDs by deduplicating and dropping unknown IDs.
5. Validate finite, positive, metric-appropriate manual values and convert percentages correctly.
6. Run the focused tests, then the complete suite, and commit only after GREEN.

### Task 3: Define HealthKit service contract and failing dashboard tests

**Objective:** Make synchronization behavior testable without relying on simulator Health data.

**Files:**
- Create: `PocketPulse/Health/HealthDataProviding.swift`
- Create: `PocketPulseTests/HealthDashboardModelTests.swift`

**Steps:**
1. Define async operations for availability, permission request, summary fetch, history fetch, and manual save.
2. Implement a test fake returning deterministic snapshots or errors.
3. Test initial state, successful authorization/refresh, empty data, refresh error with stale-data preservation, and save-then-refresh.
4. Push and verify RED because `HealthDashboardModel` does not exist.

Contract:

```swift
protocol HealthDataProviding: Sendable {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws
    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary
    func fetchHistory(for metric: HealthMetric, range: HealthRange, now: Date) async throws -> MetricHistory
    func save(_ entry: ManualHealthEntry) async throws
}
```

### Task 4: Implement the HealthKit adapter and dashboard model

**Objective:** Query the real shared HealthKit store while keeping presentation state deterministic.

**Files:**
- Create: `PocketPulse/Health/HealthKitStore.swift`
- Create: `PocketPulse/Health/HealthDashboardModel.swift`
- Modify: `PocketPulse/PocketPulseApp.swift`

**Steps:**
1. Map each supported metric to an optional `HKObjectType`, canonical `HKUnit`, aggregation strategy, and read/write role.
2. Request only supported object types, filtering unavailable identifiers safely.
3. Fetch latest samples and daily statistics with continuations that resume exactly once.
4. Preserve source names and timestamps, but do not expose device identifiers.
5. Save only validated writable quantity/category samples.
6. Implement `@MainActor` loading, ready, unavailable, and error states; retain stale data on transient refresh failure.
7. Inject `HealthKitStore` at the app root and refresh when the scene becomes active.
8. Run dashboard tests and full suite to GREEN.

### Task 5: Build the distinct native information architecture

**Objective:** Replace the counter-only surface with a complete, coherent health companion.

**Files:**
- Replace: `PocketPulse/ContentView.swift`
- Create: `PocketPulse/Design/PocketPulseTheme.swift`
- Create: `PocketPulse/Views/RootTabView.swift`
- Create: `PocketPulse/Views/SummaryView.swift`
- Create: `PocketPulse/Views/MetricCard.swift`
- Create: `PocketPulse/Views/HealthPermissionView.swift`
- Create: `PocketPulse/Views/HealthStateViews.swift`

**Steps:**
1. Add Summary, Browse, and Privacy tabs with semantic SF Symbols and distinct PocketPulse colors.
2. Build a first-launch privacy/permission card before HealthKit authorization.
3. Render real values only; show `No Data` rather than seeded/demo measurements.
4. Add pinned cards, highlights, recent source/time context, refresh state, and accessibility values.
5. Keep the original tap-counter concept only as an optional local interaction, not as a fabricated health reading.
6. Verify Dynamic Type and Reduce Motion paths in code and simulator UI.

### Task 6: Build browse, detail, chart, and manual-entry flows

**Objective:** Cover the supported health catalog beyond the summary screen.

**Files:**
- Create: `PocketPulse/Views/BrowseView.swift`
- Create: `PocketPulse/Views/MetricDetailView.swift`
- Create: `PocketPulse/Views/MetricChartView.swift`
- Create: `PocketPulse/Views/ManualEntryView.swift`
- Create: `PocketPulse/Views/MetricPickerView.swift`

**Steps:**
1. Group metrics by health category and support native searchable filtering.
2. Add 7/30/90-day range selection and Swift Charts with accessible chart summaries.
3. Display source/date context and accurate no-data/error states.
4. Allow pin/unpin with normalized persistent IDs.
5. Present manual entry only for writable metrics; validate before save and refresh after success.
6. Avoid unsupported clinical diagnosis or medical advice language.

### Task 7: Build privacy and native export behavior

**Objective:** Give the user auditable data controls without imitating Apple-only sharing.

**Files:**
- Create: `PocketPulse/Views/PrivacyView.swift`
- Create: `PocketPulse/Views/HealthSummaryDocument.swift`
- Create: `PocketPulse/Views/ShareSheet.swift`

**Steps:**
1. Explain that HealthKit owns the measurements and Apple controls permissions.
2. Link to the app's system settings for permission changes.
3. Generate an explicit user-triggered text/CSV summary from currently loaded values.
4. Use the native share sheet only after user action; never upload automatically.
5. Label exported content as informational, not medical advice.

### Task 8: Add HealthKit capability and usage descriptions

**Objective:** Make unsigned builds and signed device builds declare the exact required capability.

**Files:**
- Create: `PocketPulse/PocketPulse.entitlements`
- Modify: `PocketPulse.xcodeproj/project.pbxproj`
- Modify: `.github/workflows/ios.yml`
- Modify: `.github/workflows/adhoc.yml`

**Steps:**
1. Add `com.apple.developer.healthkit = true` to the entitlements plist.
2. Set `CODE_SIGN_ENTITLEMENTS` for Debug and Release.
3. Add clear `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` generated Info.plist keys.
4. Extend CI to verify the effective entitlements path and usage strings.
5. Extend Ad Hoc preflight to require the HealthKit entitlement in both the profile and final signed app.
6. Do not weaken the existing team, bundle, certificate, one-device, architecture, or cleanup checks.

### Task 9: Verify macOS CI and review

**Objective:** Prove the Xcode project builds and tests before touching production signing.

**Files:**
- Update as required by actual compiler/test output.

**Steps:**
1. Run local JSON/XML/plist/static validation and `actionlint`.
2. Commit and push `native-swiftui`.
3. Watch the macOS workflow through unsigned device build and simulator XCTest.
4. Fix compiler/test failures one root cause at a time and rerun.
5. Run a pre-commit code/security review focused on HealthKit privacy, continuation safety, fabricated data, and accessibility.

### Task 10: Regenerate and validate HealthKit-enabled Ad Hoc signing

**Objective:** Produce a release that iOS accepts with HealthKit access.

**Files/Systems:**
- Apple Developer App ID: `com.evokedreem.pocketpulse`
- GitHub secret: `IOS_ADHOC_PROVISIONING_PROFILE_BASE64`
- Workflow: `.github/workflows/adhoc.yml`

**Steps:**
1. Enable HealthKit for the existing explicit App ID in Apple Developer.
2. Regenerate the one-device Ad Hoc provisioning profile using the existing distribution certificate and registered iPhone.
3. Replace only the provisioning-profile secret; never expose the profile or UDID in chat/source/logs.
4. Trigger a release tag and require archive/export plus independent IPA checks.
5. Verify the embedded profile and signed entitlements both contain HealthKit and still authorize exactly the intended device.

### Task 11: Publish and verify the updated private build

**Objective:** Replace the existing OTA package only with a verified HealthKit build and confirm physical-device behavior.

**Files/Systems:**
- Existing unguessable Caddy install route and manifest
- Registered iPhone

**Steps:**
1. Download the verified CI artifact and validate ZIP structure/checksum.
2. Stage the new IPA atomically and update the manifest build version.
3. Verify HTTPS 200 responses, MIME types, byte ranges, TLS, and public checksum.
4. Install over the existing bundle ID without deleting the old app.
5. On iPhone, open PocketPulse, approve selected Health permissions, confirm real Health values appear, add one safe test entry if desired, and verify Apple Health reflects it.
