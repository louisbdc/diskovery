import Foundation

/// Modèle immuable représentant un fichier ou un dossier dans les résultats d'un scan.
public struct Entry: Identifiable, Hashable, Sendable {
    public let url: URL
    public let name: String
    public let sizeBytes: Int64
    public let isDirectory: Bool
    /// Date de dernière modification, si disponible. Sert notamment à repérer
    /// les node_modules anciens.
    public let modifiedAt: Date?

    public var id: URL { url }

    public init(
        url: URL,
        name: String,
        sizeBytes: Int64,
        isDirectory: Bool,
        modifiedAt: Date? = nil
    ) {
        self.url = url
        self.name = name
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
        self.modifiedAt = modifiedAt
    }
}
