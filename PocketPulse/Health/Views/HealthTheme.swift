import SwiftUI

struct HealthPalette {
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.16)
    static let muted = Color.secondary
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let accent = Color(red: 0.31, green: 0.25, blue: 0.94)
    static let accentSecondary = Color(red: 0.02, green: 0.67, blue: 0.78)
    static let success = Color(red: 0.08, green: 0.65, blue: 0.38)
}

extension HealthCategory {
    var tint: Color {
        switch self {
        case .activity: Color(red: 1.00, green: 0.38, blue: 0.20)
        case .heart: Color(red: 0.96, green: 0.20, blue: 0.36)
        case .sleep: Color(red: 0.40, green: 0.32, blue: 0.93)
        case .body: Color(red: 0.10, green: 0.58, blue: 0.96)
        case .respiratory: Color(red: 0.03, green: 0.68, blue: 0.72)
        case .nutrition: Color(red: 0.06, green: 0.65, blue: 0.38)
        case .mobility: Color(red: 0.96, green: 0.60, blue: 0.12)
        case .mindfulness: Color(red: 0.46, green: 0.32, blue: 0.87)
        case .vitals: Color(red: 0.86, green: 0.24, blue: 0.58)
        }
    }
}

extension HealthMetric {
    var tint: Color { category.tint }
}

struct HealthCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(HealthPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.primary.opacity(0.055), lineWidth: 1)
            }
    }
}

extension View {
    func healthCard() -> some View {
        modifier(HealthCardModifier())
    }
}
