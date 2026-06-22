import Foundation

/// Cache thread-safe des tailles de dossiers déjà calculées, indexé par chemin.
///
/// Rempli pendant le parcours récursif : chaque dossier traversé y dépose sa
/// taille. Ainsi, entrer dans un sous-dossier déjà parcouru ne recalcule rien
/// (lecture O(1) au lieu d'un nouveau parcours du sous-arbre).
///
/// Accédé depuis plusieurs threads (`concurrentPerform`), d'où le verrou.
/// `@unchecked Sendable` : la sûreté est assurée manuellement par le `NSLock`.
final class SizeCache: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Int64] = [:]

    private func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    func get(_ url: URL) -> Int64? {
        let k = key(for: url)
        lock.lock()
        defer { lock.unlock() }
        return store[k]
    }

    func set(_ size: Int64, for url: URL) {
        let k = key(for: url)
        lock.lock()
        defer { lock.unlock() }
        store[k] = size
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
    }
}
