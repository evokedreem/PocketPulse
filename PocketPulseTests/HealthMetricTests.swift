import XCTest
@testable import PocketPulse

final class HealthMetricTests: XCTestCase {
    func testCatalogUsesStableUniqueIdentifiers() {
        let identifiers = HealthMetric.allCases.map(\.id)

        XCTAssertFalse(identifiers.isEmpty)
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertEqual(HealthMetric.steps.id, "steps")
        XCTAssertEqual(HealthMetric.sleep.id, "sleep")
    }

    func testMetricsAreGroupedIntoExpectedCategories() {
        XCTAssertEqual(HealthMetric.steps.category, .activity)
        XCTAssertEqual(HealthMetric.heartRate.category, .heart)
        XCTAssertEqual(HealthMetric.sleep.category, .sleep)
        XCTAssertEqual(HealthMetric.bodyMass.category, .body)
        XCTAssertEqual(HealthMetric.respiratoryRate.category, .respiratory)
        XCTAssertEqual(HealthMetric.water.category, .nutrition)
        XCTAssertEqual(HealthMetric.walkingSpeed.category, .mobility)
        XCTAssertEqual(HealthMetric.mindfulMinutes.category, .mindfulness)
        XCTAssertEqual(HealthMetric.bloodGlucose.category, .vitals)
    }

    func testOnlySafeManualMetricsAreWritable() {
        let writable = Set(HealthMetric.allCases.filter(\.isWritable))

        XCTAssertEqual(
            writable,
            Set([
                .bodyMass,
                .heartRate,
                .bloodGlucose,
                .oxygenSaturation,
                .bodyTemperature,
                .water,
                .mindfulMinutes
            ])
        )
        XCTAssertFalse(HealthMetric.steps.isWritable)
        XCTAssertFalse(HealthMetric.sleep.isWritable)
    }

    func testDefaultPinnedMetricsAreUsefulAndDeduplicated() {
        XCTAssertEqual(
            HealthMetric.defaultPinned,
            [.steps, .heartRate, .sleep, .activeEnergy]
        )
        XCTAssertEqual(Set(HealthMetric.defaultPinned).count, HealthMetric.defaultPinned.count)
    }

    func testPinnedSelectionDropsUnknownAndDuplicateIdentifiers() {
        let selection = PinnedMetricSelection.normalized(
            identifiers: ["steps", "unknown", "steps", "sleep", "heart-rate"]
        )

        XCTAssertEqual(selection, [.steps, .sleep, .heartRate])
    }

    func testEmptyPinnedSelectionFallsBackToDefaults() {
        XCTAssertEqual(
            PinnedMetricSelection.normalized(identifiers: []),
            HealthMetric.defaultPinned
        )
    }
}
