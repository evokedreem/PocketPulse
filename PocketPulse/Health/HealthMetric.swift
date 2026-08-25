import Foundation

enum HealthCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case activity
    case heart
    case sleep
    case body
    case respiratory
    case nutrition
    case mobility
    case mindfulness
    case vitals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activity: "Activity"
        case .heart: "Heart"
        case .sleep: "Sleep"
        case .body: "Body Measurements"
        case .respiratory: "Respiratory"
        case .nutrition: "Nutrition"
        case .mobility: "Mobility"
        case .mindfulness: "Mindfulness"
        case .vitals: "Vitals"
        }
    }

    var systemImage: String {
        switch self {
        case .activity: "figure.walk"
        case .heart: "heart.fill"
        case .sleep: "bed.double.fill"
        case .body: "figure.arms.open"
        case .respiratory: "lungs.fill"
        case .nutrition: "drop.fill"
        case .mobility: "figure.walk.motion"
        case .mindfulness: "brain.head.profile"
        case .vitals: "waveform.path.ecg"
        }
    }
}

enum HealthMetric: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case steps
    case activeEnergy = "active-energy"
    case exerciseMinutes = "exercise-minutes"
    case walkingRunningDistance = "walking-running-distance"
    case flightsClimbed = "flights-climbed"
    case heartRate = "heart-rate"
    case restingHeartRate = "resting-heart-rate"
    case walkingHeartRate = "walking-heart-rate"
    case heartRateVariability = "heart-rate-variability"
    case oxygenSaturation = "oxygen-saturation"
    case respiratoryRate = "respiratory-rate"
    case bodyMass = "body-mass"
    case height
    case bodyMassIndex = "body-mass-index"
    case bodyFatPercentage = "body-fat-percentage"
    case leanBodyMass = "lean-body-mass"
    case sleep
    case mindfulMinutes = "mindful-minutes"
    case water
    case dietaryEnergy = "dietary-energy"
    case bloodGlucose = "blood-glucose"
    case systolicBloodPressure = "systolic-blood-pressure"
    case diastolicBloodPressure = "diastolic-blood-pressure"
    case bodyTemperature = "body-temperature"
    case vo2Max = "vo2-max"
    case walkingSpeed = "walking-speed"
    case walkingAsymmetry = "walking-asymmetry"
    case walkingSteadiness = "walking-steadiness"

    var id: String { rawValue }

    static let defaultPinned: [HealthMetric] = [.steps, .heartRate, .sleep, .activeEnergy]

    var title: String {
        switch self {
        case .steps: "Steps"
        case .activeEnergy: "Active Energy"
        case .exerciseMinutes: "Exercise"
        case .walkingRunningDistance: "Walking + Running Distance"
        case .flightsClimbed: "Flights Climbed"
        case .heartRate: "Heart Rate"
        case .restingHeartRate: "Resting Heart Rate"
        case .walkingHeartRate: "Walking Heart Rate Average"
        case .heartRateVariability: "Heart Rate Variability"
        case .oxygenSaturation: "Blood Oxygen"
        case .respiratoryRate: "Respiratory Rate"
        case .bodyMass: "Weight"
        case .height: "Height"
        case .bodyMassIndex: "Body Mass Index"
        case .bodyFatPercentage: "Body Fat Percentage"
        case .leanBodyMass: "Lean Body Mass"
        case .sleep: "Sleep Duration"
        case .mindfulMinutes: "Mindful Minutes"
        case .water: "Water"
        case .dietaryEnergy: "Dietary Energy"
        case .bloodGlucose: "Blood Glucose"
        case .systolicBloodPressure: "Systolic Blood Pressure"
        case .diastolicBloodPressure: "Diastolic Blood Pressure"
        case .bodyTemperature: "Body Temperature"
        case .vo2Max: "Cardio Fitness"
        case .walkingSpeed: "Walking Speed"
        case .walkingAsymmetry: "Walking Asymmetry"
        case .walkingSteadiness: "Walking Steadiness"
        }
    }

    var category: HealthCategory {
        switch self {
        case .steps, .activeEnergy, .exerciseMinutes, .walkingRunningDistance, .flightsClimbed:
            .activity
        case .heartRate, .restingHeartRate, .walkingHeartRate, .heartRateVariability:
            .heart
        case .sleep:
            .sleep
        case .bodyMass, .height, .bodyMassIndex, .bodyFatPercentage, .leanBodyMass:
            .body
        case .oxygenSaturation, .respiratoryRate:
            .respiratory
        case .water, .dietaryEnergy:
            .nutrition
        case .walkingSpeed, .walkingAsymmetry, .walkingSteadiness:
            .mobility
        case .mindfulMinutes:
            .mindfulness
        case .bloodGlucose, .systolicBloodPressure, .diastolicBloodPressure, .bodyTemperature, .vo2Max:
            .vitals
        }
    }

    var systemImage: String {
        switch self {
        case .steps: "shoeprints.fill"
        case .activeEnergy: "flame.fill"
        case .exerciseMinutes: "figure.run"
        case .walkingRunningDistance: "map.fill"
        case .flightsClimbed: "stairs"
        case .heartRate: "heart.fill"
        case .restingHeartRate: "heart.circle.fill"
        case .walkingHeartRate: "figure.walk"
        case .heartRateVariability: "waveform.path.ecg"
        case .oxygenSaturation: "drop.circle.fill"
        case .respiratoryRate: "lungs.fill"
        case .bodyMass: "scalemass.fill"
        case .height: "ruler.fill"
        case .bodyMassIndex: "function"
        case .bodyFatPercentage: "percent"
        case .leanBodyMass: "figure.strengthtraining.traditional"
        case .sleep: "bed.double.fill"
        case .mindfulMinutes: "brain.head.profile"
        case .water: "drop.fill"
        case .dietaryEnergy: "fork.knife"
        case .bloodGlucose: "drop.triangle.fill"
        case .systolicBloodPressure, .diastolicBloodPressure: "gauge.with.dots.needle.67percent"
        case .bodyTemperature: "thermometer.medium"
        case .vo2Max: "lungs.fill"
        case .walkingSpeed: "speedometer"
        case .walkingAsymmetry: "figure.walk.motion"
        case .walkingSteadiness: "figure.walk.circle.fill"
        }
    }

    var isWritable: Bool {
        switch self {
        case .bodyMass, .heartRate, .bloodGlucose, .oxygenSaturation,
             .bodyTemperature, .water, .mindfulMinutes:
            true
        default:
            false
        }
    }

    var manualUnitLabel: String {
        switch self {
        case .bodyMass: "lb"
        case .heartRate: "bpm"
        case .bloodGlucose: "mg/dL"
        case .oxygenSaturation: "%"
        case .bodyTemperature: "°F"
        case .water: "fl oz"
        case .mindfulMinutes: "min"
        default: ""
        }
    }
}

enum PinnedMetricSelection {
    static func normalized(identifiers: [String]) -> [HealthMetric] {
        var seen = Set<HealthMetric>()
        let metrics = identifiers.compactMap(HealthMetric.init(rawValue:)).filter { seen.insert($0).inserted }
        return metrics.isEmpty ? HealthMetric.defaultPinned : metrics
    }
}
