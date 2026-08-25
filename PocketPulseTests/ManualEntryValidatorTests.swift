import XCTest
@testable import PocketPulse

final class ManualEntryValidatorTests: XCTestCase {
    func testParsesSupportedDisplayValues() throws {
        XCTAssertEqual(try ManualEntryValidator.value("184.2", for: .bodyMass), 184.2)
        XCTAssertEqual(try ManualEntryValidator.value("72", for: .heartRate), 72)
        XCTAssertEqual(try ManualEntryValidator.value("16", for: .water), 16)
        XCTAssertEqual(try ManualEntryValidator.value("10", for: .mindfulMinutes), 10)
    }

    func testConvertsHumanPercentageToHealthKitFraction() throws {
        XCTAssertEqual(
            try ManualEntryValidator.value("98", for: .oxygenSaturation),
            0.98,
            accuracy: 0.000_001
        )
    }

    func testRejectsReadOnlyMetrics() {
        XCTAssertThrowsError(try ManualEntryValidator.value("1000", for: .steps)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .readOnlyMetric)
        }
    }

    func testRejectsBlankAndNonNumericValues() {
        XCTAssertThrowsError(try ManualEntryValidator.value("   ", for: .water)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .emptyValue)
        }
        XCTAssertThrowsError(try ManualEntryValidator.value("abc", for: .water)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .notANumber)
        }
    }

    func testRejectsNonFiniteAndNonPositiveValues() {
        XCTAssertThrowsError(try ManualEntryValidator.value("nan", for: .water)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .notANumber)
        }
        XCTAssertThrowsError(try ManualEntryValidator.value("-1", for: .water)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
        XCTAssertThrowsError(try ManualEntryValidator.value("0", for: .mindfulMinutes)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
    }

    func testRejectsMetricSpecificUnsafeRanges() {
        XCTAssertThrowsError(try ManualEntryValidator.value("301", for: .heartRate)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
        XCTAssertThrowsError(try ManualEntryValidator.value("101", for: .oxygenSaturation)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
        XCTAssertThrowsError(try ManualEntryValidator.value("79", for: .bodyTemperature)) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
    }

    func testValidatesNormalizedEntryAtWriteBoundary() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNoThrow(
            try ManualEntryValidator.validate(
                ManualHealthEntry(metric: .oxygenSaturation, value: 0.98, date: now),
                now: now
            )
        )

        XCTAssertThrowsError(
            try ManualEntryValidator.validate(
                ManualHealthEntry(metric: .oxygenSaturation, value: 98, date: now),
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .outOfRange)
        }
    }

    func testRejectsReadOnlyAndFutureEntriesAtWriteBoundary() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertThrowsError(
            try ManualEntryValidator.validate(
                ManualHealthEntry(metric: .steps, value: 1_000, date: now),
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .readOnlyMetric)
        }

        XCTAssertThrowsError(
            try ManualEntryValidator.validate(
                ManualHealthEntry(metric: .water, value: 12, date: now.addingTimeInterval(1)),
                now: now
            )
        ) { error in
            XCTAssertEqual(error as? ManualEntryValidationError, .futureDate)
        }
    }
}
