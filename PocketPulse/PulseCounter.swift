import Foundation

struct PulseCounter: Equatable {
    private(set) var count: Int

    init(count: Int = 0) {
        self.count = max(0, count)
    }

    mutating func recordPulse() {
        count += 1
    }

    mutating func reset() {
        count = 0
    }

    var message: String {
        switch count {
        case 0:
            return "Ready when you are"
        case 1..<5:
            return "Nice start"
        case 5..<10:
            return "Keep the rhythm going"
        default:
            return "PocketPulse is working"
        }
    }
}
