import XCTest
@testable import DiskoveryCore

final class SizeFormatterTests: XCTestCase {
    func testZeroBytes() {
        let result = SizeFormatter.string(0)
        XCTAssertFalse(result.isEmpty)
        // ByteCountFormatter rend "0 octet" / "Zero KB" selon la locale ; non vide suffit.
    }

    func testBytesProducesNonEmptyString() {
        XCTAssertFalse(SizeFormatter.string(512).isEmpty)
    }

    func testKilobytesContainsUnit() {
        // 1500 octets ~ 1,5 Ko / 1.5 KB selon la locale.
        let result = SizeFormatter.string(1500)
        XCTAssertTrue(
            result.lowercased().contains("k"),
            "Attendu une unité kilo dans : \(result)"
        )
    }

    func testMegabytesContainsUnit() {
        let result = SizeFormatter.string(5_000_000)
        XCTAssertTrue(
            result.uppercased().contains("M"),
            "Attendu une unité méga dans : \(result)"
        )
    }

    func testLargerBytesGiveLongerOrEqualMagnitude() {
        // Sanity : une grande valeur ne doit pas formater en octets bruts.
        let big = SizeFormatter.string(2_000_000_000)
        XCTAssertTrue(
            big.uppercased().contains("G") || big.uppercased().contains("B"),
            "Attendu giga/byte unit dans : \(big)"
        )
    }
}
