import XCTest
@testable import DiskoveryCore

final class FindDirectoriesTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-finddirs-\(UUID().uuidString)", isDirectory: true)
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

    func testMatchesMultipleNames() async throws {
        try makeFile("a/node_modules/x.js", bytes: 1000)
        try makeFile("b/target/y.o", bytes: 2000)
        try makeFile("c/.venv/z.py", bytes: 3000)

        let found = await FileScanner.findDirectories(
            matching: ["node_modules", "target", ".venv"],
            under: root
        )
        XCTAssertEqual(found.count, 3)
        XCTAssertEqual(Set(found.map(\.name)), ["node_modules", "target", ".venv"])
    }

    func testPrunesInsideMatch() async throws {
        // Un node_modules à l'intérieur d'un target trouvé ne doit pas remonter
        // séparément ; sa taille est incluse dans target.
        try makeFile("p/target/a.o", bytes: 2000)
        try makeFile("p/target/node_modules/dep/b.js", bytes: 1000)

        let found = await FileScanner.findDirectories(
            matching: ["target", "node_modules"],
            under: root
        )
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.name, "target")
        XCTAssertFalse(found.contains { $0.url.path.contains("target/node_modules") })
    }

    func testEmptyNamesReturnsEmpty() async throws {
        try makeFile("a/node_modules/x.js", bytes: 1000)
        let found = await FileScanner.findDirectories(matching: [], under: root)
        XCTAssertTrue(found.isEmpty)
    }

    func testNoDescentIntoMatch() async throws {
        try makeFile("app/node_modules/pkg/node_modules/dep/x.js", bytes: 1000)
        let found = await FileScanner.findDirectories(matching: ["node_modules"], under: root)
        XCTAssertEqual(found.count, 1)
        XCTAssertFalse(found.contains { $0.url.path.contains("pkg/node_modules") })
    }

    func testSiblingNoDuplicates() async throws {
        for i in 0..<12 {
            try makeFile("proj\(i)/node_modules/x.js", bytes: 100 + i)
            try makeFile("proj\(i)/dist/y.js", bytes: 50 + i)
        }
        let found = await FileScanner.findDirectories(matching: ["node_modules", "dist"], under: root)
        XCTAssertEqual(found.count, 24)
        XCTAssertEqual(Set(found.map(\.url)).count, 24)
    }

    func testPrunesGit() async throws {
        try makeFile(".git/objects/node_modules/x.js", bytes: 1000)
        try makeFile("app/dist/y.js", bytes: 2000)
        let found = await FileScanner.findDirectories(matching: ["node_modules", "dist"], under: root)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.name, "dist")
        XCTAssertFalse(found.contains { $0.url.path.contains(".git") })
    }

    func testStreamMatchesNonStream() async throws {
        try makeFile("a/node_modules/x.js", bytes: 1000)
        try makeFile("b/target/y.o", bytes: 2000)

        var last: FileScanner.ScanProgress?
        var maxCompleted = 0
        for await update in FileScanner.findDirectoriesStream(matching: ["node_modules", "target"], under: root) {
            XCTAssertLessThanOrEqual(update.completed, update.total)
            maxCompleted = max(maxCompleted, update.completed)
            last = update
        }
        XCTAssertEqual(last?.total, 2)
        XCTAssertEqual(maxCompleted, 2)

        let direct = await FileScanner.findDirectories(matching: ["node_modules", "target"], under: root)
        XCTAssertEqual(Set(last?.entries.map(\.url) ?? []), Set(direct.map(\.url)))
        XCTAssertTrue(last?.entries.allSatisfy { $0.modifiedAt != nil } ?? false)
    }

    func testFindNodeModulesStillDelegates() async throws {
        try makeFile("projectA/node_modules/pkg/index.js", bytes: 2000)
        try makeFile("projectB/node_modules/lib/y.js", bytes: 4000)

        let viaNodeModules = await FileScanner.findNodeModules(under: root)
        let viaGeneric = await FileScanner.findDirectories(matching: ["node_modules"], under: root)

        XCTAssertEqual(viaNodeModules.count, 2)
        XCTAssertEqual(Set(viaNodeModules.map(\.url)), Set(viaGeneric.map(\.url)))
    }
}
