import Foundation

/// Calcul (pur, testable) de la proportion d'une taille rapportée à la plus
/// grande d'un lot — sert à dimensionner les barres de proportion des tableaux.
///
/// L'échelle est linéaire et rapportée au **maximum visible** (pas au total) :
/// le plus gros élément remplit la barre, les autres se situent relativement à lui.
public enum SizeProportion {
    /// Fraction de `value` rapportée à `max`, bornée dans 0…1.
    /// Renvoie 0 si `max <= 0` (garde anti-division par zéro).
    public static func fraction(of value: Int64, max: Int64) -> Double {
        guard max > 0 else { return 0 }
        let raw = Double(value) / Double(max)
        return Swift.min(1, Swift.max(0, raw))
    }

    /// Dictionnaire `url → fraction` pour un lot d'entrées.
    /// Le maximum est calculé une seule fois (O(n)) ; chaque cellule n'a plus
    /// qu'à lire sa fraction (O(1)), sans aucun calcul de max au rendu.
    public static func fractions(for entries: [Entry]) -> [URL: Double] {
        let maxSize = entries.map(\.sizeBytes).max() ?? 0
        return entries.reduce(into: [:]) { result, entry in
            result[entry.url] = fraction(of: entry.sizeBytes, max: maxSize)
        }
    }
}
