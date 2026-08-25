import Foundation

enum HealthValueFormatter {
    static func display(
        _ value: Double,
        for metric: HealthMetric,
        locale: Locale = .current
    ) -> String {
        guard value.isFinite else { return "No Data" }

        switch metric {
        case .steps, .flightsClimbed:
            return number(value, locale: locale, maximumFractionDigits: 0)
        case .activeEnergy, .dietaryEnergy:
            return "\(number(value, locale: locale, maximumFractionDigits: 0)) kcal"
        case .exerciseMinutes, .mindfulMinutes:
            return "\(number(value, locale: locale, maximumFractionDigits: 0)) min"
        case .walkingRunningDistance:
            return "\(number(value, locale: locale, maximumFractionDigits: 2)) mi"
        case .heartRate, .restingHeartRate, .walkingHeartRate:
            return "\(number(value, locale: locale, maximumFractionDigits: 0)) bpm"
        case .heartRateVariability:
            return "\(number(value, locale: locale, maximumFractionDigits: 1)) ms"
        case .oxygenSaturation, .bodyFatPercentage, .walkingAsymmetry, .walkingSteadiness:
            return "\(number(value * 100, locale: locale, maximumFractionDigits: 1))%"
        case .respiratoryRate:
            return "\(number(value, locale: locale, maximumFractionDigits: 1)) br/min"
        case .bodyMass, .leanBodyMass:
            return "\(number(value, locale: locale, minimumFractionDigits: 1, maximumFractionDigits: 1)) lb"
        case .height:
            let totalInches = max(0, Int(value.rounded()))
            return "\(totalInches / 12) ft \(totalInches % 12) in"
        case .bodyMassIndex:
            return number(value, locale: locale, maximumFractionDigits: 1)
        case .sleep:
            let totalMinutes = max(0, Int((value * 60).rounded()))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours == 0 { return "\(minutes) min" }
            if minutes == 0 { return "\(hours) hr" }
            return "\(hours) hr \(minutes) min"
        case .water:
            return "\(number(value, locale: locale, maximumFractionDigits: 1)) fl oz"
        case .bloodGlucose:
            return "\(number(value, locale: locale, maximumFractionDigits: 0)) mg/dL"
        case .systolicBloodPressure, .diastolicBloodPressure:
            return "\(number(value, locale: locale, maximumFractionDigits: 0)) mmHg"
        case .bodyTemperature:
            return "\(number(value, locale: locale, minimumFractionDigits: 1, maximumFractionDigits: 1))°F"
        case .vo2Max:
            return "\(number(value, locale: locale, maximumFractionDigits: 1)) mL/kg/min"
        case .walkingSpeed:
            return "\(number(value, locale: locale, maximumFractionDigits: 1)) mph"
        }
    }

    private static func number(
        _ value: Double,
        locale: Locale,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? "—"
    }
}

enum HealthTrendDirection: Equatable, Sendable {
    case up
    case down
    case stable
    case insufficient
}

enum HealthTrendAnalyzer {
    static func direction(
        current: Double?,
        baseline: Double?,
        tolerance: Double = 0.02
    ) -> HealthTrendDirection {
        guard let change = rawChange(current: current, baseline: baseline) else {
            return .insufficient
        }
        if change > tolerance { return .up }
        if change < -tolerance { return .down }
        return .stable
    }

    static func percentageChange(current: Double?, baseline: Double?) -> Double? {
        guard let change = rawChange(current: current, baseline: baseline) else { return nil }
        return (change * 1_000).rounded() / 10
    }

    private static func rawChange(current: Double?, baseline: Double?) -> Double? {
        guard let current, let baseline,
              current.isFinite, baseline.isFinite,
              baseline != 0 else { return nil }
        return (current - baseline) / abs(baseline)
    }
}

enum ManualEntryValidationError: Error, Equatable, LocalizedError {
    case readOnlyMetric
    case emptyValue
    case notANumber
    case outOfRange

    var errorDescription: String? {
        switch self {
        case .readOnlyMetric: "This metric can only be read from Apple Health."
        case .emptyValue: "Enter a value."
        case .notANumber: "Enter a valid number."
        case .outOfRange: "Enter a realistic positive value."
        }
    }
}

enum ManualEntryValidator {
    static func value(_ text: String, for metric: HealthMetric) throws -> Double {
        guard metric.isWritable else { throw ManualEntryValidationError.readOnlyMetric }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ManualEntryValidationError.emptyValue }
        guard let parsed = Double(trimmed), parsed.isFinite else {
            throw ManualEntryValidationError.notANumber
        }

        let range: ClosedRange<Double>
        switch metric {
        case .bodyMass: range = 20...1_000
        case .heartRate: range = 20...300
        case .bloodGlucose: range = 20...1_000
        case .oxygenSaturation: range = 50...100
        case .bodyTemperature: range = 80...115
        case .water: range = 0.1...1_000
        case .mindfulMinutes: range = 1...720
        default: throw ManualEntryValidationError.readOnlyMetric
        }

        guard range.contains(parsed) else { throw ManualEntryValidationError.outOfRange }
        return metric == .oxygenSaturation ? parsed / 100 : parsed
    }
}
