import Foundation
import HealthKit

final class HealthKitStore: HealthDataProviding, @unchecked Sendable {
    private let store: HKHealthStore
    private let calendar: Calendar

    init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { throw HealthKitStoreError.unavailable }

        let readTypes = Set(HealthMetric.allCases.compactMap(\.healthKitSampleType))
        let writeTypes = Set(
            HealthMetric.allCases
                .filter(\.isWritable)
                .compactMap(\.healthKitSampleType)
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitStoreError.authorizationNotCompleted)
                }
            }
        }
    }

    func fetchSummary(for metrics: [HealthMetric], now: Date) async throws -> HealthSummary {
        guard isHealthDataAvailable else { throw HealthKitStoreError.unavailable }

        var values: [HealthMetric: HealthMetricValue] = [:]
        for metric in metrics {
            if let value = try await fetchSummaryValue(for: metric, now: now) {
                values[metric] = value
            }
        }
        return HealthSummary(generatedAt: now, values: values)
    }

    func fetchHistory(
        for metric: HealthMetric,
        range: HealthRange,
        now: Date
    ) async throws -> MetricHistory {
        guard isHealthDataAvailable else { throw HealthKitStoreError.unavailable }
        guard metric.healthKitSampleType != nil else {
            throw HealthKitStoreError.unsupportedMetric(metric.title)
        }

        let start = historyStart(for: range, now: now)
        let points: [MetricDataPoint]
        switch metric.aggregation {
        case .cumulative, .average:
            guard let quantityType = metric.healthKitSampleType as? HKQuantityType else {
                throw HealthKitStoreError.unsupportedMetric(metric.title)
            }
            points = try await quantityHistory(
                type: quantityType,
                metric: metric,
                start: start,
                end: now
            )
        case .duration:
            guard let categoryType = metric.healthKitSampleType as? HKCategoryType else {
                throw HealthKitStoreError.unsupportedMetric(metric.title)
            }
            points = try await durationHistory(
                type: categoryType,
                metric: metric,
                start: start,
                end: now
            )
        case .latest:
            guard let quantityType = metric.healthKitSampleType as? HKQuantityType else {
                throw HealthKitStoreError.unsupportedMetric(metric.title)
            }
            points = try await latestQuantityHistory(
                type: quantityType,
                metric: metric,
                start: start,
                end: now
            )
        }

        return MetricHistory(
            metric: metric,
            range: range,
            points: points,
            latest: try await fetchSummaryValue(for: metric, now: now)
        )
    }

    func save(_ entry: ManualHealthEntry) async throws {
        guard isHealthDataAvailable else { throw HealthKitStoreError.unavailable }
        guard entry.metric.isWritable else { throw HealthKitStoreError.readOnlyMetric }
        guard let sampleType = entry.metric.healthKitSampleType else {
            throw HealthKitStoreError.unsupportedMetric(entry.metric.title)
        }

        let metadata: [String: Any] = [HKMetadataKeyWasUserEntered: true]
        let sample: HKSample

        if entry.metric == .mindfulMinutes {
            guard let categoryType = sampleType as? HKCategoryType else {
                throw HealthKitStoreError.unsupportedMetric(entry.metric.title)
            }
            let endDate = entry.date.addingTimeInterval(entry.value * 60)
            sample = HKCategorySample(
                type: categoryType,
                value: HKCategoryValue.notApplicable.rawValue,
                start: entry.date,
                end: endDate,
                metadata: metadata
            )
        } else {
            guard let quantityType = sampleType as? HKQuantityType,
                  let unit = entry.metric.healthKitUnit else {
                throw HealthKitStoreError.unsupportedMetric(entry.metric.title)
            }
            let quantity = HKQuantity(unit: unit, doubleValue: entry.value)
            sample = HKQuantitySample(
                type: quantityType,
                quantity: quantity,
                start: entry.date,
                end: entry.date,
                metadata: metadata
            )
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthKitStoreError.saveNotCompleted)
                }
            }
        }
    }

    private func fetchSummaryValue(
        for metric: HealthMetric,
        now: Date
    ) async throws -> HealthMetricValue? {
        guard let sampleType = metric.healthKitSampleType else { return nil }

        switch metric.aggregation {
        case .cumulative:
            guard let quantityType = sampleType as? HKQuantityType,
                  let unit = metric.healthKitUnit else { return nil }
            let start = calendar.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(
                withStart: start,
                end: now,
                options: .strictStartDate
            )
            let statistic = try await statistics(
                type: quantityType,
                predicate: predicate,
                options: .cumulativeSum
            )
            guard let quantity = statistic?.sumQuantity() else { return nil }
            return HealthMetricValue(
                metric: metric,
                value: quantity.doubleValue(for: unit),
                date: now,
                sourceName: nil
            )
        case .duration:
            guard let categoryType = sampleType as? HKCategoryType else { return nil }
            let start: Date
            if metric == .sleep {
                start = calendar.date(byAdding: .hour, value: -36, to: now) ?? calendar.startOfDay(for: now)
            } else {
                start = calendar.startOfDay(for: now)
            }
            let samples = try await categorySamples(type: categoryType, start: start, end: now)
            let relevant = samples.filter { metric.includes(categorySample: $0) }
            guard !relevant.isEmpty else { return nil }
            let seconds = relevant.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            let divisor = metric == .sleep ? 3_600.0 : 60.0
            return HealthMetricValue(
                metric: metric,
                value: seconds / divisor,
                date: relevant.map(\.endDate).max() ?? now,
                sourceName: relevant.last?.sourceRevision.source.name
            )
        case .average, .latest:
            guard let quantityType = sampleType as? HKQuantityType,
                  let unit = metric.healthKitUnit,
                  let sample = try await latestQuantitySample(type: quantityType, end: now) else {
                return nil
            }
            return HealthMetricValue(
                metric: metric,
                value: sample.quantity.doubleValue(for: unit),
                date: sample.endDate,
                sourceName: sample.sourceRevision.source.name
            )
        }
    }

    private func quantityHistory(
        type: HKQuantityType,
        metric: HealthMetric,
        start: Date,
        end: Date
    ) async throws -> [MetricDataPoint] {
        guard let unit = metric.healthKitUnit else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let options: HKStatisticsOptions = metric.aggregation == .cumulative
            ? .cumulativeSum
            : .discreteAverage
        let anchor = calendar.startOfDay(for: start)
        let collection = try await statisticsCollection(
            type: type,
            predicate: predicate,
            options: options,
            anchor: anchor
        )

        var points: [MetricDataPoint] = []
        collection.enumerateStatistics(from: anchor, to: end) { statistics, _ in
            let quantity = metric.aggregation == .cumulative
                ? statistics.sumQuantity()
                : statistics.averageQuantity()
            guard let quantity else { return }
            points.append(
                MetricDataPoint(
                    date: statistics.startDate,
                    value: quantity.doubleValue(for: unit)
                )
            )
        }
        return points
    }

    private func latestQuantityHistory(
        type: HKQuantityType,
        metric: HealthMetric,
        start: Date,
        end: Date
    ) async throws -> [MetricDataPoint] {
        guard let unit = metric.healthKitUnit else { return [] }
        let samples = try await quantitySamples(type: type, start: start, end: end)
        var lastByDay: [Date: HKQuantitySample] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.endDate)
            if let existing = lastByDay[day], existing.endDate >= sample.endDate { continue }
            lastByDay[day] = sample
        }
        return lastByDay
            .map { day, sample in
                MetricDataPoint(date: day, value: sample.quantity.doubleValue(for: unit))
            }
            .sorted { $0.date < $1.date }
    }

    private func durationHistory(
        type: HKCategoryType,
        metric: HealthMetric,
        start: Date,
        end: Date
    ) async throws -> [MetricDataPoint] {
        let samples = try await categorySamples(type: type, start: start, end: end)
            .filter { metric.includes(categorySample: $0) }
        var secondsByDay: [Date: TimeInterval] = [:]

        for sample in samples {
            var cursor = max(sample.startDate, start)
            let sampleEnd = min(sample.endDate, end)
            while cursor < sampleEnd {
                let day = calendar.startOfDay(for: cursor)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? sampleEnd
                let segmentEnd = min(nextDay, sampleEnd)
                secondsByDay[day, default: 0] += segmentEnd.timeIntervalSince(cursor)
                cursor = segmentEnd
            }
        }

        let divisor = metric == .sleep ? 3_600.0 : 60.0
        return secondsByDay
            .map { MetricDataPoint(date: $0.key, value: $0.value / divisor) }
            .sorted { $0.date < $1.date }
    }

    private func statistics(
        type: HKQuantityType,
        predicate: NSPredicate,
        options: HKStatisticsOptions
    ) async throws -> HKStatistics? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
            store.execute(query)
        }
    }

    private func statisticsCollection(
        type: HKQuantityType,
        predicate: NSPredicate,
        options: HKStatisticsOptions,
        anchor: Date
    ) async throws -> HKStatisticsCollection {
        try await withCheckedThrowingContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchor,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let results {
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(throwing: HealthKitStoreError.queryReturnedNoResult)
                }
            }
            store.execute(query)
        }
    }

    private func latestQuantitySample(
        type: HKQuantityType,
        end: Date
    ) async throws -> HKQuantitySample? {
        let start = calendar.date(byAdding: .year, value: -5, to: end)
        return try await quantitySamples(type: type, start: start, end: end, limit: 1).first
    }

    private func quantitySamples(
        type: HKQuantityType,
        start: Date?,
        end: Date,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictEndDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func categorySamples(
        type: HKCategoryType,
        start: Date,
        end: Date
    ) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: []
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func historyStart(for range: HealthRange, now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today) ?? today
    }
}

private enum HealthAggregation {
    case cumulative
    case average
    case latest
    case duration
}

private extension HealthMetric {
    var aggregation: HealthAggregation {
        switch self {
        case .steps, .activeEnergy, .exerciseMinutes, .walkingRunningDistance,
             .flightsClimbed, .water, .dietaryEnergy:
            .cumulative
        case .sleep, .mindfulMinutes:
            .duration
        case .heartRate, .restingHeartRate, .walkingHeartRate,
             .heartRateVariability, .respiratoryRate:
            .average
        default:
            .latest
        }
    }

    var healthKitSampleType: HKSampleType? {
        switch self {
        case .steps: HKObjectType.quantityType(forIdentifier: .stepCount)
        case .activeEnergy: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .exerciseMinutes: HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        case .walkingRunningDistance: HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .flightsClimbed: HKObjectType.quantityType(forIdentifier: .flightsClimbed)
        case .heartRate: HKObjectType.quantityType(forIdentifier: .heartRate)
        case .restingHeartRate: HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        case .walkingHeartRate: HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage)
        case .heartRateVariability: HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
        case .oxygenSaturation: HKObjectType.quantityType(forIdentifier: .oxygenSaturation)
        case .respiratoryRate: HKObjectType.quantityType(forIdentifier: .respiratoryRate)
        case .bodyMass: HKObjectType.quantityType(forIdentifier: .bodyMass)
        case .height: HKObjectType.quantityType(forIdentifier: .height)
        case .bodyMassIndex: HKObjectType.quantityType(forIdentifier: .bodyMassIndex)
        case .bodyFatPercentage: HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)
        case .leanBodyMass: HKObjectType.quantityType(forIdentifier: .leanBodyMass)
        case .sleep: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .mindfulMinutes: HKObjectType.categoryType(forIdentifier: .mindfulSession)
        case .water: HKObjectType.quantityType(forIdentifier: .dietaryWater)
        case .dietaryEnergy: HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)
        case .bloodGlucose: HKObjectType.quantityType(forIdentifier: .bloodGlucose)
        case .systolicBloodPressure: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)
        case .diastolicBloodPressure: HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
        case .bodyTemperature: HKObjectType.quantityType(forIdentifier: .bodyTemperature)
        case .vo2Max: HKObjectType.quantityType(forIdentifier: .vo2Max)
        case .walkingSpeed: HKObjectType.quantityType(forIdentifier: .walkingSpeed)
        case .walkingAsymmetry: HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage)
        case .walkingSteadiness: HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness)
        }
    }

    var healthKitUnit: HKUnit? {
        switch self {
        case .steps, .flightsClimbed, .bodyMassIndex:
            .count()
        case .activeEnergy, .dietaryEnergy:
            .kilocalorie()
        case .exerciseMinutes, .mindfulMinutes:
            .minute()
        case .walkingRunningDistance:
            .mile()
        case .heartRate, .restingHeartRate, .walkingHeartRate, .respiratoryRate:
            .count().unitDivided(by: .minute())
        case .heartRateVariability:
            .secondUnit(with: .milli)
        case .oxygenSaturation, .bodyFatPercentage, .walkingAsymmetry, .walkingSteadiness:
            .percent()
        case .bodyMass, .leanBodyMass:
            .pound()
        case .height:
            .inch()
        case .water:
            .fluidOunceUS()
        case .bloodGlucose:
            HKUnit(from: "mg/dL")
        case .systolicBloodPressure, .diastolicBloodPressure:
            .millimeterOfMercury()
        case .bodyTemperature:
            .degreeFahrenheit()
        case .vo2Max:
            HKUnit(from: "ml/kg*min")
        case .walkingSpeed:
            .mile().unitDivided(by: .hour())
        case .sleep:
            nil
        }
    }

    func includes(categorySample sample: HKCategorySample) -> Bool {
        guard self == .sleep else { return true }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        return asleepValues.contains(sample.value)
    }
}

enum HealthKitStoreError: Error, LocalizedError {
    case unavailable
    case authorizationNotCompleted
    case unsupportedMetric(String)
    case readOnlyMetric
    case saveNotCompleted
    case queryReturnedNoResult

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health data is unavailable on this device."
        case .authorizationNotCompleted:
            "Apple Health access was not completed."
        case .unsupportedMetric(let metric):
            "\(metric) is not supported on this device."
        case .readOnlyMetric:
            "This metric can only be read from Apple Health."
        case .saveNotCompleted:
            "Apple Health did not save this entry."
        case .queryReturnedNoResult:
            "Apple Health returned no result for this query."
        }
    }
}
