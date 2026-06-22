import Foundation

/// Formatage des tailles d'octets en chaînes lisibles (Ko / Mo / Go…).
public enum SizeFormatter {
    /// Convertit un nombre d'octets en chaîne lisible, ex. "1,2 Go".
    /// Une nouvelle instance est créée à chaque appel pour rester concurrency-safe ;
    /// `ByteCountFormatter` n'étant pas `Sendable`, on évite tout état partagé.
    public static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: bytes)
    }
}
