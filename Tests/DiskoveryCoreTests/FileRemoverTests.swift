import XCTest
@testable import DiskoveryCore

final class FileRemoverTests: XCTestCase {
    func testMoveToTrashReportsFailureForMissingURL() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-missing-\(UUID().uuidString)")

        let result = FileRemover.moveToTrash([missing])

        XCTAssertFalse(result.allSucceeded)
        XCTAssertTrue(result.removed.isEmpty)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(result.failures.first?.url, missing)
    }

    func testMoveToTrashThrowsForMissingURL() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-missing-\(UUID().uuidString)")

        XCTAssertThrowsError(try FileRemover.moveToTrash(missing))
    }

    func testDeletePermanentlyRemovesFromDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-perm-\(UUID().uuidString).txt")
        try Data(repeating: 0x41, count: 10).write(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let result = FileRemover.remove([url], permanently: true)

        XCTAssertTrue(result.allSucceeded)
        XCTAssertEqual(result.removed, [url])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRemoveTrashModeKeepsExistingApi() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-trash-\(UUID().uuidString).txt")
        try Data(repeating: 0x41, count: 10).write(to: url)

        let result = FileRemover.remove([url], permanently: false)

        XCTAssertTrue(result.allSucceeded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRemovePermanentlyReportsFailureForMissingURL() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("diskovery-missing-\(UUID().uuidString)")

        let result = FileRemover.remove([missing], permanently: true)

        XCTAssertFalse(result.allSucceeded)
        XCTAssertEqual(result.failures.count, 1)
    }
}
