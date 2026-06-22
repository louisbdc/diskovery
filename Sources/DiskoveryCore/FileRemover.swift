import Foundation

/// Suppression de fichiers/dossiers vers la Corbeille (réversible).
public enum FileRemover {
    public struct RemovalResult: Sendable {
        public let removed: [URL]
        public let failures: [(url: URL, message: String)]

        public var allSucceeded: Bool { failures.isEmpty }
    }

    /// Met une URL à la Corbeille. Lance une erreur si l'opération échoue.
    public static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Met plusieurs URLs à la Corbeille, en continuant malgré les échecs
    /// individuels. Renvoie le détail des succès et des échecs.
    public static func moveToTrash(_ urls: [URL]) -> RemovalResult {
        var removed: [URL] = []
        var failures: [(url: URL, message: String)] = []

        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                removed.append(url)
            } catch {
                failures.append((url, error.localizedDescription))
            }
        }

        return RemovalResult(removed: removed, failures: failures)
    }
}
