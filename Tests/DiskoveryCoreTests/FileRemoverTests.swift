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
}
