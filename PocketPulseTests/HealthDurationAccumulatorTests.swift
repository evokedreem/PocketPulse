import XCTest
@testable import PocketPulse

final class HealthDurationAccumulatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    func testTotalClipsIntervalsToWindowAndMergesOverlap() {
        let window = DateInterval(start: base, duration: 3_600)
        let intervals = [
            DateInterval(start: base.addingTimeInterval(-600), duration: 1_800),
            DateInterval(start: base.addingTimeInterval(600), duration: 1_800),
            DateInterval(start: base.addingTimeInterval(3_000), duration: 1_200)
        ]

        XCTAssertEqual(
            HealthDurationAccumulator.totalSeconds(in: intervals, clippedTo: window),
            3_000,
            accuracy: 0.001
        )
    }

    func testTotalsByDaySplitMergedIntervalsWithoutDoubleCounting() {
        let startOfDay = calendar.startOfDay(for: base)
        let window = DateInterval(start: startOfDay, duration: 2 * 86_400)
        let first = DateInterval(
            start: startOfDay.addingTimeInterval(23 * 3_600),
            duration: 2 * 3_600
        )
        let overlapping = DateInterval(
            start: startOfDay.addingTimeInterval(23.5 * 3_600),
            duration: 30 * 60
        )

        let totals = HealthDurationAccumulator.secondsByDay(
            in: [first, overlapping],
            clippedTo: window,
            calendar: calendar
        )

        XCTAssertEqual(totals[startOfDay, default: -1], 3_600, accuracy: 0.001)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        XCTAssertEqual(totals[nextDay, default: -1], 3_600, accuracy: 0.001)
    }
}
