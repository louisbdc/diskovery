import Foundation

/// Parcours du système de fichiers et calcul des tailles.
/// Toutes les opérations ignorent silencieusement les éléments illisibles (comme `2>/dev/null`).
///
/// Optimisations :
/// - un seul appel `resourceValues` par élément (type + taille en une fois),
/// - calcul des tailles des enfants parallélisé sur tous les cœurs,
/// - cache de session pour rendre la navigation arrière instantanée.
public enum FileScanner {
    private static let cache = ScanCache()
    private static let sizeCache = SizeCache()

    /// Métadonnées d'un élément, lues en un seul `stat`.
    private struct NodeInfo {
        let isDirectory: Bool
        let isSymlink: Bool
        let size: Int64
    }

    private static let infoKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .fileSizeKey,
    ]

    /// Lit type et taille d'une URL en un seul appel système.
    private static func info(for url: URL) -> NodeInfo {
        guard let values = try? url.resourceValues(forKeys: Set(infoKeys)) else {
            return NodeInfo(isDirectory: false, isSymlink: false, size: 0)
        }
        let size: Int64 = Int64(
            values.totalFileAllocatedSize
                ?? values.fileAllocatedSize
                ?? values.fileSize
                ?? 0
        )
        return NodeInfo(
            isDirectory: values.isDirectory ?? false,
            isSymlink: values.isSymbolicLink ?? false,
            size: size
        )
    }

    /// Reproduit `find -type d` / `du` : un lien symbolique n'est jamais traité
    /// comme un dossier, même s'il pointe vers un dossier.
    private static func isRealDirectory(_ url: URL) -> Bool {
        let node = info(for: url)
        return node.isDirectory && !node.isSymlink
    }

    /// Date de dernière modification d'une URL (lue à la demande, hors du chemin
    /// récursif chaud pour ne pas le ralentir).
    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// Taille récursive (octets) d'un sous-arbre de dossier, en sommant les tailles des fichiers.
    /// Ne suit pas les liens symboliques (comportement par défaut de `du`).
    ///
    /// Récursif et **mis en cache** : chaque dossier traversé mémorise sa taille,
    /// si bien qu'entrer ensuite dans un de ces dossiers ne déclenche aucun
    /// nouveau parcours (lecture O(1) du cache).
    public static func directorySize(of url: URL) -> Int64 {
        directorySize(of: url, info: info(for: url))
    }

    private static func directorySize(of url: URL, info node: NodeInfo) -> Int64 {
        guard node.isDirectory && !node.isSymlink else {
            return node.size
        }
        if let cached = sizeCache.get(url) {
            return cached
        }

        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: infoKeys,
            options: []
        )) ?? []

        var total: Int64 = 0
        for child in children {
            let childInfo = info(for: child)
            if childInfo.isDirectory && !childInfo.isSymlink {
                total += directorySize(of: child, info: childInfo)
            } else {
                total += childInfo.size
            }
        }

        sizeCache.set(total, for: url)
        return total
    }

    /// Enfants directs (fichiers + sous-dossiers immédiats) d'un dossier, chacun avec sa taille.
    /// Les dossiers reçoivent leur taille récursive. Trié par taille décroissante.
    ///
    /// - Parameter useCache: réutilise un résultat déjà calculé pour ce dossier si disponible.
    public static func directEntries(of dir: URL, useCache: Bool = true) async -> [Entry] {
        if useCache, let cached = await cache.get(dir) {
            return cached
        }
        let result = await Task.detached(priority: .userInitiated) {
            directEntriesSync(of: dir)
        }.value
        await cache.set(result, for: dir)
        return result
    }

    /// Calcul des enfants directs, parallélisé : la taille de chaque enfant est
    /// calculée sur un cœur distinct via `concurrentPerform`.
    private static func directEntriesSync(of dir: URL) -> [Entry] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: infoKeys,
            options: []
        )) ?? []

        guard !children.isEmpty else { return [] }

        let entries = parallelMap(children) { computeEntry(for: $0) }
        return entries.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Construit l'`Entry` d'un enfant : un seul `stat`, taille récursive (mise en
    /// cache) pour les dossiers. Instantané si ce dossier a déjà été traversé.
    private static func computeEntry(for child: URL) -> Entry {
        let node = info(for: child)
        let isDir = node.isDirectory && !node.isSymlink
        let size = isDir ? directorySize(of: child, info: node) : node.size
        return Entry(
            url: child,
            name: child.lastPathComponent,
            sizeBytes: size,
            isDirectory: isDir,
            modifiedAt: modificationDate(of: child)
        )
    }

    /// Progression d'un scan en flux : les entrées accumulées (triées) et l'avancement.
    public struct ScanProgress: Sendable {
        public let entries: [Entry]
        public let completed: Int
        public let total: Int
        /// Vrai pendant la phase de localisation des dossiers (total encore en
        /// cours d'établissement) ; faux pendant la phase de mesure.
        public let isDiscovering: Bool

        public init(entries: [Entry], completed: Int, total: Int, isDiscovering: Bool = false) {
            self.entries = entries
            self.completed = completed
            self.total = total
            self.isDiscovering = isDiscovering
        }

        /// Fraction d'avancement entre 0 et 1.
        public var fraction: Double {
            total > 0 ? Double(completed) / Double(total) : 0
        }
    }

    /// Variante en flux de `directEntries` : émet une mise à jour à chaque enfant
    /// mesuré, permettant un affichage progressif et une barre de progression.
    /// Les enfants sont mesurés en parallèle ; les entrées sont triées à chaque émission.
    public static func directEntriesStream(of dir: URL, useCache: Bool = true) -> AsyncStream<ScanProgress> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                if useCache, let cached = await cache.get(dir) {
                    continuation.yield(ScanProgress(entries: cached, completed: cached.count, total: cached.count))
                    continuation.finish()
                    return
                }

                let children = (try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: infoKeys,
                    options: []
                )) ?? []

                let total = children.count
                guard total > 0 else {
                    continuation.yield(ScanProgress(entries: [], completed: 0, total: 0))
                    continuation.finish()
                    return
                }

                var collected: [Entry] = []
                collected.reserveCapacity(total)

                await withTaskGroup(of: Entry.self) { group in
                    for child in children {
                        group.addTask { computeEntry(for: child) }
                    }
                    var done = 0
                    for await entry in group {
                        if Task.isCancelled { break }
                        collected.append(entry)
                        done += 1
                        let snapshot = collected.sorted { $0.sizeBytes > $1.sizeBytes }
                        continuation.yield(ScanProgress(entries: snapshot, completed: done, total: total))
                    }
                }

                if !Task.isCancelled {
                    await cache.set(collected.sorted { $0.sizeBytes > $1.sizeBytes }, for: dir)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Tous les dossiers nommés "node_modules" sous `root`, avec leur taille récursive.
    /// Ne descend pas dans un node_modules trouvé. Trié par taille décroissante.
    public static func findNodeModules(under root: URL) async -> [Entry] {
        await Task.detached(priority: .userInitiated) {
            let matches = nodeModuleMatches(under: root) { _ in }
            let found = parallelMap(matches) { nodeModuleEntry(for: $0) }
            return found.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value
    }

    /// Localise (sans mesurer) tous les dossiers `node_modules` sous `root`.
    /// Recherche parallélisée sur tous les cœurs.
    public static func locateNodeModules(under root: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            nodeModuleMatches(under: root) { _ in }
        }.value
    }

    /// Variante en flux. La **recherche** des dossiers est parallélisée sur tous
    /// les cœurs et émet une progression dès qu'un node_modules est trouvé
    /// (`isDiscovering`). Puis la **mesure** des tailles, parallèle elle aussi,
    /// remplit le tableau au fur et à mesure.
    public static func findNodeModulesStream(under root: URL) -> AsyncStream<ScanProgress> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task.detached(priority: .userInitiated) {
                // --- Phase 1 : recherche parallèle, progression en direct ---
                let matches = nodeModuleMatches(under: root) { foundSoFar in
                    if Task.isCancelled { return }
                    continuation.yield(ScanProgress(
                        entries: [],
                        completed: 0,
                        total: foundSoFar,
                        isDiscovering: true
                    ))
                }

                if Task.isCancelled { continuation.finish(); return }

                let total = matches.count
                guard total > 0 else {
                    continuation.yield(ScanProgress(entries: [], completed: 0, total: 0))
                    continuation.finish()
                    return
                }

                // --- Phase 2 : mesure parallèle, remplissage progressif ---
                var collected: [Entry] = []
                collected.reserveCapacity(total)

                await withTaskGroup(of: Entry.self) { group in
                    for match in matches {
                        group.addTask { nodeModuleEntry(for: match) }
                    }
                    var done = 0
                    for await entry in group {
                        if Task.isCancelled { break }
                        collected.append(entry)
                        done += 1
                        let snapshot = collected.sorted { $0.sizeBytes > $1.sizeBytes }
                        continuation.yield(ScanProgress(entries: snapshot, completed: done, total: total))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Localise tous les dossiers `node_modules` sous `root` sans calculer leur taille.
    /// La recherche est **parallélisée** : chaque sous-dossier de premier niveau
    /// est exploré sur un cœur distinct. `onFound` est appelé (depuis plusieurs
    /// threads) à chaque correspondance, avec le nombre total trouvé jusque-là.
    private static func nodeModuleMatches(under root: URL, onFound: @escaping (Int) -> Void) -> [URL] {
        // `find` évalue aussi le chemin de départ : si la racine elle-même est un
        // dossier nommé node_modules, on la renvoie sans descendre (comme `-prune`).
        if isRealDirectory(root), root.lastPathComponent == "node_modules" {
            onFound(1)
            return [root]
        }

        let matches = Locked<[URL]>([])
        let record: (URL) -> Void = { url in
            let count = matches.withLock { list -> Int in
                list.append(url)
                return list.count
            }
            onFound(count)
        }

        // Construit un « front » d'unités de travail indépendantes en descendant
        // de quelques niveaux, pour équilibrer la charge même si un seul dossier
        // de premier niveau domine. L'expansion ne fait que partitionner l'arbre ;
        // l'enregistrement se fait uniquement dans le parcours parallèle ci-dessous,
        // donc chaque node_modules est vu exactement une fois.
        let units = buildSearchFrontier(from: root)

        nonisolated(unsafe) let recordUnsafe = record
        DispatchQueue.concurrentPerform(iterations: units.count) { index in
            walkForNodeModules(units[index], record: recordUnsafe)
        }

        return matches.withLock { $0 }
    }

    /// Partitionne l'arborescence sous `root` en unités de travail indépendantes,
    /// en développant niveau par niveau jusqu'à obtenir au moins `4 × cœurs`
    /// unités. Renvoie les dossiers « normaux » restant à parcourir et les
    /// node_modules terminaux (à enregistrer sans descendre), sous-arbres disjoints.
    private static func buildSearchFrontier(from root: URL) -> [URL] {
        let target = max(ProcessInfo.processInfo.activeProcessorCount * 4, 8)
        var frontier: [URL] = [root]
        var terminals: [URL] = []

        while !frontier.isEmpty && frontier.count + terminals.count < target {
            var next: [URL] = []

            for dir in frontier {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                    options: []
                )) ?? []

                for child in children {
                    let name = child.lastPathComponent
                    if name == "node_modules" {
                        if isRealDirectory(child) { terminals.append(child) }
                    } else if prunedDirectoryNames.contains(name) {
                        continue
                    } else if isRealDirectory(child) {
                        next.append(child)
                    }
                }
            }

            frontier = next
        }

        // Unités à parcourir : dossiers normaux non encore développés + node_modules
        // terminaux (walkForNodeModules se contente de les enregistrer).
        return frontier + terminals
    }

    /// Dossiers internes élagués pendant la recherche de node_modules : ils ne
    /// contiennent jamais de node_modules de projet et peuvent être énormes
    /// (historique git, etc.). Les élaguer accélère fortement le parcours.
    private static let prunedDirectoryNames: Set<String> = [".git", ".hg", ".svn"]

    /// Parcourt séquentiellement une branche, signalant chaque node_modules
    /// rencontré sans y descendre.
    private static func walkForNodeModules(_ url: URL, record: (URL) -> Void) {
        let node = info(for: url)
        guard node.isDirectory && !node.isSymlink else { return }

        if url.lastPathComponent == "node_modules" {
            record(url)
            return
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return
        }

        for case let element as URL in enumerator {
            // Comparaison de nom d'abord (gratuite) : on évite ainsi un `stat`
            // sur les millions de fichiers qui ne s'appellent pas node_modules.
            let name = element.lastPathComponent
            if name == "node_modules" {
                guard isRealDirectory(element) else { continue }
                // Ne pas descendre : la taille du node_modules inclut déjà ses enfants.
                enumerator.skipDescendants()
                record(element)
            } else if prunedDirectoryNames.contains(name) {
                // Élague les dossiers internes volumineux et non pertinents.
                enumerator.skipDescendants()
            }
        }
    }

    /// Construit l'`Entry` d'un node_modules : taille récursive (cachée) + date de modification.
    private static func nodeModuleEntry(for url: URL) -> Entry {
        Entry(
            url: url,
            name: url.lastPathComponent,
            sizeBytes: directorySize(of: url),
            isDirectory: true,
            modifiedAt: modificationDate(of: url)
        )
    }

    // MARK: - Cache

    /// Invalide les caches pour un rafraîchissement.
    ///
    /// Vide la liste mémorisée du dossier ciblé et l'intégralité du cache de
    /// tailles : les tailles d'un sous-arbre peuvent dépendre de n'importe quel
    /// descendant, on repart donc d'une base saine.
    public static func invalidateCache(for dir: URL) async {
        await cache.remove(dir)
        sizeCache.removeAll()
    }

    /// Vide entièrement les caches de session.
    public static func clearCache() async {
        await cache.removeAll()
        sizeCache.removeAll()
    }
}

/// Applique `transform` à chaque élément en parallèle sur tous les cœurs disponibles,
/// en préservant l'ordre d'entrée. Les écritures se font à des indices distincts d'un
/// buffer pré-alloué, donc sans course de données.
private func parallelMap<T, R>(_ items: [T], _ transform: (T) -> R) -> [R] {
    let count = items.count
    let result = UnsafeMutablePointer<R>.allocate(capacity: count)
    defer { result.deallocate() }

    // `concurrentPerform` est synchrone (il rend la main une fois toutes les
    // itérations terminées) et chaque itération écrit à un indice distinct :
    // aucune course de données, d'où `nonisolated(unsafe)`.
    nonisolated(unsafe) let items = items
    nonisolated(unsafe) let transform = transform
    nonisolated(unsafe) let base = result
    DispatchQueue.concurrentPerform(iterations: count) { index in
        (base + index).initialize(to: transform(items[index]))
    }

    let buffer = UnsafeMutableBufferPointer(start: result, count: count)
    defer { buffer.baseAddress?.deinitialize(count: count) }
    return Array(buffer)
}
