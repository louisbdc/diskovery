import XCTest
@testable import DiskoveryCore

final class SizeProportionTests: XCTestCase {
    private func entry(_ size: Int64, _ name: String) -> Entry {
        Entry(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            sizeBytes: size,
            isDirectory: false
        )
    }

    // MARK: - fraction(of:max:)

    func testFractionMaxZeroIsZero() {
        XCTAssertEqual(SizeProportion.fraction(of: 0, max: 0), 0)
    }

    func testFractionNominalHalf() {
        XCTAssertEqual(SizeProportion.fraction(of: 50, max: 100), 0.5, accuracy: 1e-9)
    }

    func testFractionFullWhenEqualToMax() {
        XCTAssertEqual(SizeProportion.fraction(of: 100, max: 100), 1.0, accuracy: 1e-9)
    }

    func testFractionEmptyElementIsZero() {
        XCTAssertEqual(SizeProportion.fraction(of: 0, max: 100), 0, accuracy: 1e-9)
    }

    func testFractionClampsAboveMax() {
        XCTAssertEqual(SizeProportion.fraction(of: 150, max: 100), 1.0, accuracy: 1e-9)
    }

    // MARK: - fractions(for:)

    func testFractionsEmptyIsEmpty() {
        XCTAssertTrue(SizeProportion.fractions(for: []).isEmpty)
    }

    func testFractionsRelativeToMax() throws {
        let entries = [entry(200, "a"), entry(100, "b"), entry(50, "c")]
        let result = SizeProportion.fractions(for: entries)

        XCTAssertEqual(try XCTUnwrap(result[entries[0].url]), 1.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(result[entries[1].url]), 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(result[entries[2].url]), 0.25, accuracy: 1e-9)
    }

    func testFractionsAllZeroDoesNotCrash() {
        let entries = [entry(0, "a"), entry(0, "b")]
        let result = SizeProportion.fractions(for: entries)

        XCTAssertEqual(result[entries[0].url], 0)
        XCTAssertEqual(result[entries[1].url], 0)
    }
}
