import Foundation
import Observation
import DiskoveryCore

/// Recherche des dossiers de cache/artefacts de build (node_modules, target,
/// dist, .gradle…) selon les écosystèmes activés, avec affichage progressif et
/// suppression vers la Corbeille.
@Observable
@MainActor
final class BuildCachesViewModel {
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
    var enabledEcosystems: Set<Ecosystem> = Set(Ecosystem.allCases) {
        didSet { if enabledEcosystems != oldValue, rootURL != nil { scan() } }
    }

    private var rootURL: URL?
    private var scopedRoot: URL?
    private var scanTask: Task<Void, Never>?

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

    func ecosystem(for entry: Entry) -> Ecosystem? {
        Ecosystem.first(forDirectoryNamed: entry.name)
    }

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
        let names = Ecosystem.ruleNames(for: enabledEcosystems)

        scanTask?.cancel()
        state = .scanning
        entries = []
        scanCompleted = 0
        scanTotal = 0
        isDiscovering = true

        scanTask = Task { [weak self] in
            for await update in FileScanner.findDirectoriesStream(matching: names, under: root) {
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

    /// Supprime les dossiers cochés (vers la Corbeille ou définitivement).
    func deleteSelected(_ urls: Set<URL>, permanently: Bool) {
        let targets = entries.filter { urls.contains($0.url) }
        guard !targets.isEmpty else { return }

        withScope {
            let result = FileRemover.remove(targets.map(\.url), permanently: permanently)
            let removed = Set(result.removed)
            entries = entries.filter { !removed.contains($0.url) }

            let freed = targets
                .filter { removed.contains($0.url) }
                .reduce(0) { $0 + $1.sizeBytes }

            statusMessage = removalMessage(result, freed: freed, permanently: permanently)
        }
    }

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
