import Foundation

/// Seuil d'ancienneté au-delà duquel un node_modules est mis en avant comme « ancien ».
enum AgeThreshold: String, CaseIterable, Identifiable {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneWeek: "1 semaine"
        case .oneMonth: "1 mois"
        case .threeMonths: "3 mois"
        case .sixMonths: "6 mois"
        case .oneYear: "1 an"
        }
    }

    /// Durée correspondante, en secondes.
    var interval: TimeInterval {
        let day: TimeInterval = 24 * 3600
        switch self {
        case .oneWeek: return 7 * day
        case .oneMonth: return 30 * day
        case .threeMonths: return 90 * day
        case .sixMonths: return 180 * day
        case .oneYear: return 365 * day
        }
    }

    /// Indique si `date` est plus ancienne que le seuil par rapport à `reference`.
    func isOld(_ date: Date?, reference: Date) -> Bool {
        guard let date else { return false }
        return reference.timeIntervalSince(date) > interval
    }
}
