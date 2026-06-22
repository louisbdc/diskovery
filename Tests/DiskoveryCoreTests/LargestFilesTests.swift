import XCTest
@testable import DiskoveryCore

final class LargestFilesTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-largest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root, FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    @discardableResult
    private func makeFile(_ relativePath: String, bytes: Int) throws -> URL {
        let url = root.appendingPathComponent(relativePath, isDirectory: false)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url
    }

    // Tailles bien séparées (> 1 bloc de 4 Ko d'écart) : `sizeBytes` est la
    // taille allouée sur disque, donc des fichiers de quelques octets
    // tomberaient tous dans le même bloc et seraient indistinguables.
    func testReturnsTopNBySize() async throws {
        try makeFile("a.bin", bytes: 10_000)
        try makeFile("b.bin", bytes: 50_000)
        try makeFile("c.bin", bytes: 30_000)
        try makeFile("d.bin", bytes: 20_000)

        let top = await FileScanner.findLargestFiles(under: root, limit: 2)

        XCTAssertEqual(top.count, 2)
        XCTAssertEqual(top.map(\.name), ["b.bin", "c.bin"])
        let sizes = top.map(\.sizeBytes)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testIsRecursiveAcrossDepth() async throws {
        try makeFile("x/y/deep.bin", bytes: 9000)
        try makeFile("shallow.bin", bytes: 100)

        let top = await FileScanner.findLargestFiles(under: root, limit: 1)
        XCTAssertEqual(top.first?.name, "deep.bin")
    }

    func testExcludesDirectories() async throws {
        try makeFile("bigdir/a.bin", bytes: 20_000)
        try makeFile("bigdir/b.bin", bytes: 20_000)
        try makeFile("lonely.bin", bytes: 30_000)

        let top = await FileScanner.findLargestFiles(under: root, limit: 3)
        XCTAssertTrue(top.allSatisfy { !$0.isDirectory })
        XCTAssertFalse(top.contains { $0.name == "bigdir" })
        XCTAssertEqual(top.first?.name, "lonely.bin")
    }

    func testLimitZeroReturnsEmpty() async throws {
        try makeFile("a.bin", bytes: 1000)
        let r = await FileScanner.findLargestFiles(under: root, limit: 0)
        XCTAssertTrue(r.isEmpty)
    }

    func testLimitLargerThanCountReturnsAllSorted() async throws {
        try makeFile("a.bin", bytes: 10_000)
        try makeFile("b.bin", bytes: 30_000)
        try makeFile("c.bin", bytes: 20_000)

        let r = await FileScanner.findLargestFiles(under: root, limit: 100)
        XCTAssertEqual(r.count, 3)
        let sizes = r.map(\.sizeBytes)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }

    func testPrunesGitDirectory() async throws {
        try makeFile(".git/objects/huge.pack", bytes: 9000)
        try makeFile("app/small.bin", bytes: 100)

        let r = await FileScanner.findLargestFiles(under: root, limit: 5)
        XCTAssertFalse(r.contains { $0.url.path.contains(".git") })
    }

    func testNoDuplicatesAcrossManyDirs() async throws {
        for i in 0..<30 {
            try makeFile("g\(i % 3)/p\(i)/f\(i).bin", bytes: 10_000 * (i + 1))
        }

        let r = await FileScanner.findLargestFiles(under: root, limit: 10)
        XCTAssertEqual(r.count, 10)
        XCTAssertEqual(Set(r.map(\.url)).count, 10, "Aucun doublon attendu")
        // Les 10 plus gros sont i = 20…29 (le partitionnement parallèle ne doit
        // ni en manquer ni en dupliquer) : tous les noms doivent être f20…f29.
        let names = Set(r.map(\.name))
        let expected = Set((20..<30).map { "f\($0).bin" })
        XCTAssertEqual(names, expected)
    }

    func testStreamMatchesNonStream() async throws {
        try makeFile("a.bin", bytes: 1000)
        try makeFile("sub/b.bin", bytes: 5000)
        try makeFile("c.bin", bytes: 3000)

        var last: FileScanner.ScanProgress?
        for await update in FileScanner.findLargestFilesStream(under: root, limit: 2) {
            XCTAssertLessThanOrEqual(update.completed, update.total)
            last = update
        }

        XCTAssertFalse(last?.isDiscovering ?? true, "L'émission finale doit être figée")
        let direct = await FileScanner.findLargestFiles(under: root, limit: 2)
        XCTAssertEqual(Set(last?.entries.map(\.url) ?? []), Set(direct.map(\.url)))
        let sizes = last?.entries.map(\.sizeBytes) ?? []
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }
}
