import XCTest
@testable import DiskoveryCore

final class FileScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    // MARK: - Helpers

    private func makeDir(_ relativePath: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func makeFile(_ relativePath: String, bytes: Int) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(repeating: 0x41, count: bytes)
        try data.write(to: url)
        return url
    }

    // MARK: - directorySize

    func testDirectorySizeSumsNestedFiles() throws {
        try makeFile("a.txt", bytes: 1000)
        try makeFile("sub/b.txt", bytes: 2000)
        try makeFile("sub/deep/c.txt", bytes: 3000)

        let size = FileScanner.directorySize(of: root)

        // Taille allouée >= taille logique ; au minimum la somme logique.
        XCTAssertGreaterThanOrEqual(size, 6000)
    }

    func testDirectorySizeOfSingleFileReturnsItsSize() throws {
        let file = try makeFile("only.bin", bytes: 4096)
        let size = FileScanner.directorySize(of: file)
        XCTAssertGreaterThanOrEqual(size, 4096)
    }

    func testDirectorySizeOfMissingPathIsZero() {
        let missing = root.appendingPathComponent("does-not-exist", isDirectory: true)
        XCTAssertEqual(FileScanner.directorySize(of: missing), 0)
    }

    // MARK: - directEntries

    func testDirectEntriesListsImmediateChildrenSortedBySize() async throws {
        try makeFile("small.txt", bytes: 100)
        try makeFile("big/inner.txt", bytes: 50_000)
        try makeFile("medium.txt", bytes: 5_000)

        let entries = await FileScanner.directEntries(of: root)

        XCTAssertEqual(entries.count, 3)
        // Trié décroissant : "big" (dossier 50k) en premier.
        XCTAssertEqual(entries.first?.name, "big")
        XCTAssertTrue(entries.first?.isDirectory ?? false)

        // Vérifie tri décroissant strict.
        let sizes = entries.map(\.sizeBytes)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testDirectEntriesMarksDirectoriesAndFiles() async throws {
        try makeFile("file.txt", bytes: 10)
        try makeDir("folder")

        let entries = await FileScanner.directEntries(of: root)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        XCTAssertEqual(byName["file.txt"]?.isDirectory, false)
        XCTAssertEqual(byName["folder"]?.isDirectory, true)
    }

    func testDirectEntriesParallelMatchesSequentialSizes() async throws {
        // Plusieurs sous-dossiers : vérifie que le calcul parallèle donne
        // exactement les mêmes tailles qu'un calcul séquentiel de référence.
        for i in 0..<6 {
            try makeFile("dir\(i)/a.bin", bytes: 1000 * (i + 1))
            try makeFile("dir\(i)/nested/b.bin", bytes: 500 * (i + 1))
        }

        let entries = await FileScanner.directEntries(of: root, useCache: false)
        for entry in entries where entry.isDirectory {
            XCTAssertEqual(
                entry.sizeBytes,
                FileScanner.directorySize(of: entry.url),
                "Taille parallèle ≠ séquentielle pour \(entry.name)"
            )
        }
    }

    func testDirectEntriesCacheReturnsStableResultAndInvalidates() async throws {
        try makeFile("a.txt", bytes: 1000)

        let first = await FileScanner.directEntries(of: root, useCache: true)
        XCTAssertEqual(first.count, 1)

        // Ajout d'un fichier APRÈS le premier scan : le cache doit masquer le changement…
        try makeFile("b.txt", bytes: 2000)
        let cached = await FileScanner.directEntries(of: root, useCache: true)
        XCTAssertEqual(cached.count, 1, "Le cache doit renvoyer le résultat mémorisé")

        // …jusqu'à invalidation explicite.
        await FileScanner.invalidateCache(for: root)
        let refreshed = await FileScanner.directEntries(of: root, useCache: true)
        XCTAssertEqual(refreshed.count, 2, "Après invalidation, le nouveau fichier apparaît")
    }

    func testDirectEntriesStreamReportsProgressAndFinalMatches() async throws {
        try makeFile("a/inner.bin", bytes: 3000)
        try makeFile("b.txt", bytes: 1000)
        try makeDir("c")

        var last: FileScanner.ScanProgress?
        var maxCompleted = 0
        var sawMonotonicTotal = true

        for await update in FileScanner.directEntriesStream(of: root, useCache: false) {
            XCTAssertLessThanOrEqual(update.completed, update.total)
            if let previous = last, previous.total != update.total { sawMonotonicTotal = false }
            maxCompleted = max(maxCompleted, update.completed)
            last = update
        }

        XCTAssertTrue(sawMonotonicTotal, "Le total doit rester stable pendant le scan")
        XCTAssertEqual(last?.total, 3)
        XCTAssertEqual(maxCompleted, 3)
        XCTAssertEqual(last?.entries.count, 3)

        // Mêmes éléments que la version non-stream (l'ordre des ex æquo en taille
        // n'est pas garanti, on compare donc les ensembles), et tri décroissant.
        let direct = await FileScanner.directEntries(of: root, useCache: false)
        XCTAssertEqual(Set(last?.entries.map(\.url) ?? []), Set(direct.map(\.url)))
        let sizes = last?.entries.map(\.sizeBytes) ?? []
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    // MARK: - findNodeModules

    func testFindNodeModulesDetectsAllAndDoesNotDescend() async throws {
        // projectA/node_modules with a nested package that itself has node_modules
        try makeFile("projectA/node_modules/pkg/index.js", bytes: 2000)
        try makeFile("projectA/node_modules/pkg/node_modules/dep/x.js", bytes: 1000)
        // projectB/node_modules separate
        try makeFile("projectB/node_modules/lib/y.js", bytes: 4000)
        // a non-node_modules dir that should be ignored
        try makeFile("projectB/src/main.js", bytes: 500)

        let found = await FileScanner.findNodeModules(under: root)

        // Ne doit PAS descendre dans projectA/node_modules → le nested node_modules
        // ne doit pas apparaître séparément.
        let paths = found.map { $0.url.path }
        XCTAssertEqual(found.count, 2, "Trouvés : \(paths)")

        XCTAssertTrue(paths.contains { $0.hasSuffix("projectA/node_modules") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("projectB/node_modules") })
        XCTAssertFalse(
            paths.contains { $0.contains("pkg/node_modules") },
            "Ne doit pas descendre dans un node_modules trouvé"
        )

        // Tous sont des dossiers, triés décroissant (taille allouée sur disque,
        // donc l'ordre logique n'est pas garanti, mais le tri descendant l'est).
        XCTAssertTrue(found.allSatisfy(\.isDirectory))
        let sizes = found.map(\.sizeBytes)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testEntriesCarryModificationDate() async throws {
        try makeFile("a.txt", bytes: 100)
        let entries = await FileScanner.directEntries(of: root, useCache: false)
        XCTAssertNotNil(entries.first?.modifiedAt, "Une entrée doit porter sa date de modification")
    }

    func testFindNodeModulesStreamMatchesNonStream() async throws {
        try makeFile("projectA/node_modules/pkg/index.js", bytes: 2000)
        try makeFile("projectB/node_modules/lib/y.js", bytes: 4000)

        var last: FileScanner.ScanProgress?
        var maxCompleted = 0
        for await update in FileScanner.findNodeModulesStream(under: root) {
            XCTAssertLessThanOrEqual(update.completed, update.total)
            maxCompleted = max(maxCompleted, update.completed)
            last = update
        }

        XCTAssertEqual(last?.total, 2)
        XCTAssertEqual(maxCompleted, 2)

        let direct = await FileScanner.findNodeModules(under: root)
        XCTAssertEqual(Set(last?.entries.map(\.url) ?? []), Set(direct.map(\.url)))
        // Chaque node_modules trouvé porte une date de modification.
        XCTAssertTrue(last?.entries.allSatisfy { $0.modifiedAt != nil } ?? false)
    }

    func testFindNodeModulesNoDuplicatesAcrossManyProjects() async throws {
        // Plusieurs projets frères + imbriqués : le partitionnement parallèle ne
        // doit ni manquer ni dupliquer de node_modules.
        for i in 0..<12 {
            try makeFile("group\(i % 3)/project\(i)/node_modules/pkg/index.js", bytes: 100 + i)
            try makeFile("group\(i % 3)/project\(i)/src/main.js", bytes: 50)
        }

        let found = await FileScanner.findNodeModules(under: root)
        XCTAssertEqual(found.count, 12)
        XCTAssertEqual(Set(found.map(\.url)).count, 12, "Aucun doublon attendu")
    }

    func testFindNodeModulesPrunesGitDirectory() async throws {
        // Un node_modules à l'intérieur d'un .git ne doit pas être remonté
        // (dossier interne élagué pour accélérer la recherche).
        try makeFile(".git/objects/node_modules/x.js", bytes: 1000)
        try makeFile("app/node_modules/lib/y.js", bytes: 2000)

        let found = await FileScanner.findNodeModules(under: root)
        let paths = found.map(\.url.path)
        XCTAssertEqual(found.count, 1, "Trouvés : \(paths)")
        XCTAssertTrue(paths.contains { $0.hasSuffix("app/node_modules") })
        XCTAssertFalse(paths.contains { $0.contains(".git") })
    }

    func testFindNodeModulesEmptyWhenNonePresent() async throws {
        try makeFile("src/index.js", bytes: 100)
        let found = await FileScanner.findNodeModules(under: root)
        XCTAssertTrue(found.isEmpty)
    }

    func testFindNodeModulesIncludesNestedSizeInParent() async throws {
        try makeFile("p/node_modules/a/x.js", bytes: 2000)
        try makeFile("p/node_modules/a/node_modules/b/y.js", bytes: 1000)

        let found = await FileScanner.findNodeModules(under: root)
        XCTAssertEqual(found.count, 1)
        // La taille du node_modules parent inclut le node_modules imbriqué.
        XCTAssertGreaterThanOrEqual(found.first?.sizeBytes ?? 0, 3000)
    }
}
