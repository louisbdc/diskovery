import Foundation
import Observation
import DiskoveryCore

/// Recherche de tous les dossiers `node_modules`, avec affichage progressif,
/// mise en avant des dossiers anciens et suppression (vers la Corbeille).
///
/// La portée de sécurité est maintenue sur le dossier racine pendant toute la
/// session, pour permettre les suppressions après le scan.
@Observable
@MainActor
final class NodeModulesViewModel {
    enum State: Equatable {
        case idle
        case scanning
        case loaded
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var entries: [Entry] = []
    private(set) var scanCompleted: Int = 0
    private(set) var scanTotal: Int = 0
    private(set) var isDiscovering: Bool = false
    private(set) var statusMessage: String?

    var searchText: String = ""
    var threshold: AgeThreshold = .oneMonth

    private var rootURL: URL?
    private var scopedRoot: URL?
    private var scanTask: Task<Void, Never>?

    /// Recalculé à chaque accès pour refléter l'heure courante.
    private var now: Date { Date() }

    var scanFraction: Double {
        scanTotal > 0 ? Double(scanCompleted) / Double(scanTotal) : 0
    }

    var filteredEntries: [Entry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter { $0.url.path.lowercased().contains(query) }
    }

    var totalSize: Int64 {
        entries.reduce(0) { $0 + $1.sizeBytes }
    }

    func isOld(_ entry: Entry) -> Bool {
        threshold.isOld(entry.modifiedAt, reference: now)
    }

    /// node_modules dépassant le seuil d'ancienneté.
    var oldEntries: [Entry] {
        let reference = now
        return entries.filter { threshold.isOld($0.modifiedAt, reference: reference) }
    }

    var oldCount: Int { oldEntries.count }
    var oldTotalSize: Int64 { oldEntries.reduce(0) { $0 + $1.sizeBytes } }

    // MARK: - Scan

    func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                state = .error("Aucun dossier sélectionné.")
                return
            }
            open(root: url)
        case .failure(let error):
            state = .error("Sélection impossible : \(error.localizedDescription)")
        }
    }

    private func open(root: URL) {
        releaseScope()
        scopedRoot = root.startAccessingSecurityScopedResource() ? root : nil
        rootURL = root
        statusMessage = nil
        scan()
    }

    private func scan() {
        guard let root = rootURL else { return }
        scanTask?.cancel()
        state = .scanning
        entries = []
        scanCompleted = 0
        scanTotal = 0
        isDiscovering = true

        scanTask = Task { [weak self] in
            for await update in FileScanner.findNodeModulesStream(under: root) {
                guard !Task.isCancelled, let self else { return }
                self.entries = update.entries
                self.scanCompleted = update.completed
                self.scanTotal = update.total
                self.isDiscovering = update.isDiscovering
            }
            guard !Task.isCancelled, let self else { return }
            self.isDiscovering = false
            self.state = .loaded
        }
    }

    // MARK: - Suppression

    /// Met un node_modules à la Corbeille.
    func delete(_ entry: Entry) {
        withScope {
            do {
                try FileRemover.moveToTrash(entry.url)
                entries = entries.filter { $0.url != entry.url }
                statusMessage = "« \(entry.url.path) » mis à la corbeille."
            } catch {
                statusMessage = "Échec de la suppression : \(error.localizedDescription)"
            }
        }
    }

    /// Met à la Corbeille tous les node_modules dépassant le seuil d'ancienneté.
    func deleteOld() {
        let targets = oldEntries
        guard !targets.isEmpty else { return }

        withScope {
            let result = FileRemover.moveToTrash(targets.map(\.url))
            let removedURLs = Set(result.removed)
            entries = entries.filter { !removedURLs.contains($0.url) }

            let freed = targets
                .filter { removedURLs.contains($0.url) }
                .reduce(0) { $0 + $1.sizeBytes }

            if result.allSucceeded {
                statusMessage = "\(result.removed.count) node_modules (\(SizeFormatter.string(freed))) mis à la corbeille."
            } else {
                statusMessage = "\(result.removed.count) supprimés, \(result.failures.count) en échec."
            }
        }
    }

    /// Exécute une opération sur le système de fichiers en s'assurant que la
    /// portée de sécurité du dossier racine est active.
    private func withScope(_ operation: () -> Void) {
        let needsScope = scopedRoot == nil
        let active = needsScope ? (rootURL?.startAccessingSecurityScopedResource() ?? false) : true
        defer { if needsScope && active { rootURL?.stopAccessingSecurityScopedResource() } }
        operation()
    }

    private func releaseScope() {
        if let scoped = scopedRoot {
            scoped.stopAccessingSecurityScopedResource()
            scopedRoot = nil
        }
    }
}
