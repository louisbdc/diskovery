import Foundation
import Observation
import DiskoveryCore

/// Navigateur d'espace disque : on choisit un dossier racine, puis on plonge
/// dans les sous-dossiers (double-clic / fil d'Ariane) pour voir, à chaque
/// niveau, ce qui occupe le plus de place.
///
/// La portée de sécurité (security-scoped) est maintenue sur le dossier racine
/// pendant toute la session de navigation : les descendants en héritent.
@Observable
@MainActor
final class FolderNavigatorViewModel {
    enum State: Equatable {
        case idle
        case scanning
        case loaded
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var entries: [Entry] = []
    private(set) var rootURL: URL?
    private(set) var currentURL: URL?
    private(set) var scanCompleted: Int = 0
    private(set) var scanTotal: Int = 0
    private(set) var statusMessage: String?
    var searchText: String = ""

    /// Fraction d'avancement du scan en cours (0…1).
    var scanFraction: Double {
        scanTotal > 0 ? Double(scanCompleted) / Double(scanTotal) : 0
    }

    private var history: [URL] = []
    private var scopedRoot: URL?
    private var scanTask: Task<Void, Never>?

    var canGoBack: Bool { !history.isEmpty }

    /// Segments du fil d'Ariane, de la racine au dossier courant.
    var breadcrumb: [BreadcrumbItem] {
        guard let root = rootURL, let current = currentURL else { return [] }
        let rootComponents = root.standardizedFileURL.pathComponents
        let currentComponents = current.standardizedFileURL.pathComponents
        guard currentComponents.count >= rootComponents.count else {
            return [BreadcrumbItem(name: root.lastPathComponent, url: root)]
        }

        var items: [BreadcrumbItem] = [BreadcrumbItem(name: root.lastPathComponent, url: root)]
        var url = root.standardizedFileURL
        for component in currentComponents[rootComponents.count...] {
            url = url.appendingPathComponent(component)
            items.append(BreadcrumbItem(name: component, url: url))
        }
        return items
    }

    var filteredEntries: [Entry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter { $0.name.lowercased().contains(query) }
    }

    var currentTotalSize: Int64 {
        entries.reduce(0) { $0 + $1.sizeBytes }
    }

    // MARK: - Sélection de la racine

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
        history = []
        navigate(to: root)
    }

    // MARK: - Navigation

    /// Double-clic sur une ligne : entre dans un dossier, sinon révèle le fichier.
    func activate(_ entry: Entry) {
        if entry.isDirectory {
            if let current = currentURL {
                history.append(current)
            }
            navigate(to: entry.url)
        } else {
            FinderReveal.reveal(entry.url)
        }
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        navigate(to: previous)
    }

    /// Saut direct via le fil d'Ariane.
    func navigateViaBreadcrumb(to url: URL) {
        guard let current = currentURL, url != current else { return }
        if let index = history.lastIndex(of: url) {
            history.removeSubrange(index...)
        } else if let current = currentURL {
            history.append(current)
        }
        navigate(to: url)
    }

    /// Met un élément (fichier ou dossier) à la Corbeille, puis le retire de la
    /// liste. Les caches de tailles sont invalidés en arrière-plan car les
    /// tailles des dossiers ancêtres changent.
    func delete(_ entry: Entry) {
        do {
            try FileRemover.moveToTrash(entry.url)
            entries = entries.filter { $0.url != entry.url }
            statusMessage = "« \(entry.name) » mis à la corbeille."
            Task {
                if let current = currentURL {
                    await FileScanner.invalidateCache(for: current)
                }
            }
        } catch {
            statusMessage = "Échec de la suppression : \(error.localizedDescription)"
        }
    }

    func refreshCurrent() {
        guard let current = currentURL else { return }
        Task {
            await FileScanner.invalidateCache(for: current)
            navigate(to: current, useCache: false)
        }
    }

    private func navigate(to url: URL, useCache: Bool = true) {
        scanTask?.cancel()
        currentURL = url
        state = .scanning
        entries = []
        scanCompleted = 0
        scanTotal = 0

        scanTask = Task { [weak self] in
            for await update in FileScanner.directEntriesStream(of: url, useCache: useCache) {
                guard !Task.isCancelled, let self else { return }
                self.entries = update.entries
                self.scanCompleted = update.completed
                self.scanTotal = update.total
            }
            guard !Task.isCancelled, let self else { return }
            self.state = .loaded
        }
    }

    private func releaseScope() {
        if let scoped = scopedRoot {
            scoped.stopAccessingSecurityScopedResource()
            scopedRoot = nil
        }
    }
}
