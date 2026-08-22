import XCTest
@testable import PocketPulse

final class PulseCounterTests: XCTestCase {
    func testCounterStartsAtZero() {
        XCTAssertEqual(PulseCounter().count, 0)
        XCTAssertEqual(PulseCounter().message, "Ready when you are")
    }

    func testCounterRejectsNegativeStartingValues() {
        XCTAssertEqual(PulseCounter(count: -4).count, 0)
    }

    func testRecordPulseIncrementsCount() {
        var counter = PulseCounter()
        counter.recordPulse()
        counter.recordPulse()
        XCTAssertEqual(counter.count, 2)
        XCTAssertEqual(counter.message, "Nice start")
    }

    func testMilestoneMessages() {
        XCTAssertEqual(PulseCounter(count: 5).message, "Keep the rhythm going")
        XCTAssertEqual(PulseCounter(count: 10).message, "PocketPulse is working")
    }

    func testResetReturnsCounterToZero() {
        var counter = PulseCounter(count: 12)
        counter.reset()
        XCTAssertEqual(counter.count, 0)
    }
}
