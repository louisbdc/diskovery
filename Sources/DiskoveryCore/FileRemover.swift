import Foundation

/// Suppression de fichiers/dossiers, soit vers la Corbeille (réversible), soit
/// définitivement (irréversible).
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

    /// Supprime définitivement une URL (irréversible). Lance une erreur si échec.
    public static func deletePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Met plusieurs URLs à la Corbeille, en continuant malgré les échecs
    /// individuels. Renvoie le détail des succès et des échecs.
    public static func moveToTrash(_ urls: [URL]) -> RemovalResult {
        remove(urls, permanently: false)
    }

    /// Supprime plusieurs URLs, soit vers la Corbeille (`permanently == false`),
    /// soit définitivement (`permanently == true`), en continuant malgré les
    /// échecs individuels. Renvoie le détail des succès et des échecs.
    public static func remove(_ urls: [URL], permanently: Bool) -> RemovalResult {
        var removed: [URL] = []
        var failures: [(url: URL, message: String)] = []

        for url in urls {
            do {
                if permanently {
                    try deletePermanently(url)
                } else {
                    try moveToTrash(url)
                }
                removed.append(url)
            } catch {
                failures.append((url, error.localizedDescription))
            }
        }

        return RemovalResult(removed: removed, failures: failures)
    }
}
