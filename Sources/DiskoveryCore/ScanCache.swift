import Foundation

/// Cache de session des résultats de scan, indexé par chemin de dossier.
///
/// Acteur isolé : sûr en concurrence. Permet une navigation arrière instantanée
/// (revenir au dossier parent ne recalcule rien) tant que l'utilisateur ne
/// demande pas explicitement un rafraîchissement.
actor ScanCache {
    private var store: [String: [Entry]] = [:]

    private func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    func get(_ url: URL) -> [Entry]? {
        store[key(for: url)]
    }

    func set(_ entries: [Entry], for url: URL) {
        store[key(for: url)] = entries
    }

    func remove(_ url: URL) {
        store[key(for: url)] = nil
    }

    func removeAll() {
        store.removeAll()
    }
}
