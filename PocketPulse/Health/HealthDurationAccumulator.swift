import Foundation

enum HealthDurationAccumulator {
    static func totalSeconds(
        in intervals: [DateInterval],
        clippedTo window: DateInterval
    ) -> TimeInterval {
        merged(intervals, clippedTo: window)
            .reduce(0) { $0 + $1.duration }
    }

    static func secondsByDay(
        in intervals: [DateInterval],
        clippedTo window: DateInterval,
        calendar: Calendar
    ) -> [Date: TimeInterval] {
        var totals: [Date: TimeInterval] = [:]
        for interval in merged(intervals, clippedTo: window) {
            var cursor = interval.start
            while cursor < interval.end {
                let day = calendar.startOfDay(for: cursor)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
                let segmentEnd = min(nextDay, interval.end)
                totals[day, default: 0] += segmentEnd.timeIntervalSince(cursor)
                cursor = segmentEnd
            }
        }
        return totals
    }

    private static func merged(
        _ intervals: [DateInterval],
        clippedTo window: DateInterval
    ) -> [DateInterval] {
        let clipped = intervals.compactMap { interval -> DateInterval? in
            let start = max(interval.start, window.start)
            let end = min(interval.end, window.end)
            guard start < end else { return nil }
            return DateInterval(start: start, end: end)
        }
        .sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }

        var merged: [DateInterval] = []
        for interval in clipped {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}
