import Foundation

/// Min-heap borné conservant les `capacity` plus grandes `Entry` rencontrées,
/// sans jamais trier la totalité du flux. À chaque candidat : une comparaison
/// O(1) au plus petit retenu ; s'il n'est pas plus grand, rejet immédiat (cas
/// très fréquent quand on scanne des millions de fichiers). Mémoire O(capacity).
///
/// Accédé depuis plusieurs threads (`concurrentPerform`), d'où le `NSLock`.
/// `@unchecked Sendable` : sûreté garantie manuellement par le verrou.
final class BoundedTopHeap: @unchecked Sendable {
    private let lock = NSLock()
    private let capacity: Int
    private var heap: [Entry] = []

    init(capacity: Int) {
        self.capacity = max(0, capacity)
        heap.reserveCapacity(self.capacity)
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return heap.count
    }

    /// Propose une entrée. Retenue si le heap n'est pas plein, ou si elle est
    /// plus grande que la plus petite retenue (qui est alors éjectée).
    @discardableResult
    func offer(_ entry: Entry) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard capacity > 0 else { return false }

        if heap.count < capacity {
            heap.append(entry)
            siftUp(heap.count - 1)
            return true
        }
        // Racine = plus petite retenue. On remplace seulement si le candidat la surpasse.
        if ranksBelow(heap[0], entry) {
            heap[0] = entry
            siftDown(0)
            return true
        }
        return false
    }

    /// Copie triée par taille décroissante (ne vide pas le heap).
    func sortedSnapshot() -> [Entry] {
        lock.lock(); defer { lock.unlock() }
        return heap.sorted { ranksBelow($1, $0) }
    }

    // MARK: - Ordre

    /// `true` si `a` est classée plus bas que `b` (donc éjectée en premier) :
    /// taille plus petite, ou taille égale et chemin lexicographiquement plus grand
    /// (départage stable pour rendre l'ordre des ex æquo déterministe).
    private func ranksBelow(_ a: Entry, _ b: Entry) -> Bool {
        if a.sizeBytes != b.sizeBytes { return a.sizeBytes < b.sizeBytes }
        return a.url.path > b.url.path
    }

    private func siftUp(_ index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            guard ranksBelow(heap[i], heap[parent]) else { break }
            heap.swapAt(i, parent)
            i = parent
        }
    }

    private func siftDown(_ index: Int) {
        var i = index
        let n = heap.count
        while true {
            let left = 2 * i + 1
            let right = 2 * i + 2
            var lowest = i
            if left < n, ranksBelow(heap[left], heap[lowest]) { lowest = left }
            if right < n, ranksBelow(heap[right], heap[lowest]) { lowest = right }
            if lowest == i { break }
            heap.swapAt(i, lowest)
            i = lowest
        }
    }
}
