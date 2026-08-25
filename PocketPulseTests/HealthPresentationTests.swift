import XCTest
@testable import PocketPulse

final class HealthPresentationTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")

    func testCountFormattingUsesGroupingSeparators() {
        XCTAssertEqual(
            HealthValueFormatter.display(10_234, for: .steps, locale: locale),
            "10,234"
        )
    }

    func testHeartRateIncludesBeatsPerMinute() {
        XCTAssertEqual(
            HealthValueFormatter.display(72, for: .heartRate, locale: locale),
            "72 bpm"
        )
    }

    func testSleepFormatsFractionalHoursAsHoursAndMinutes() {
        XCTAssertEqual(
            HealthValueFormatter.display(7.5, for: .sleep, locale: locale),
            "7 hr 30 min"
        )
    }

    func testPercentagesConvertHealthKitFractionToHumanPercentage() {
        XCTAssertEqual(
            HealthValueFormatter.display(0.975, for: .oxygenSaturation, locale: locale),
            "97.5%"
        )
    }

    func testMassAndTemperatureUseExplicitAppDisplayUnits() {
        XCTAssertEqual(
            HealthValueFormatter.display(184.2, for: .bodyMass, locale: locale),
            "184.2 lb"
        )
        XCTAssertEqual(
            HealthValueFormatter.display(98.6, for: .bodyTemperature, locale: locale),
            "98.6°F"
        )
    }

    func testTrendDirectionUsesTwoPercentNoiseTolerance() {
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: 103, baseline: 100), .up)
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: 97, baseline: 100), .down)
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: 101, baseline: 100), .stable)
    }

    func testTrendIsInsufficientForMissingNonFiniteOrZeroBaseline() {
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: nil, baseline: 100), .insufficient)
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: 100, baseline: nil), .insufficient)
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: .infinity, baseline: 100), .insufficient)
        XCTAssertEqual(HealthTrendAnalyzer.direction(current: 100, baseline: 0), .insufficient)
        XCTAssertNil(HealthTrendAnalyzer.percentageChange(current: 100, baseline: 0))
    }

    func testPercentageChangeIsSignedAndRoundedToOneDecimalPlace() {
        XCTAssertEqual(
            HealthTrendAnalyzer.percentageChange(current: 112.34, baseline: 100),
            12.3
        )
        XCTAssertEqual(
            HealthTrendAnalyzer.percentageChange(current: 90, baseline: 100),
            -10.0
        )
    }
}
