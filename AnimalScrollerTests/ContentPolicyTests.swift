import XCTest
@testable import AnimalScroller

final class ContentPolicyTests: XCTestCase {
    func testAllowsFreeLicences() {
        for name in ["CC BY-SA 4.0", "CC BY 2.0", "CC BY 2.0 fr (France)", "CC BY-SA 3.0", "CC0", "Public domain", "PD-USGov"] {
            XCTAssertTrue(ContentPolicy.isAllowedLicense(name), name)
        }
    }

    func testRejectsRestrictedOrUnknownLicences() {
        for name in ["CC BY-NC 2.0", "CC BY-NC-SA 4.0", "CC BY-ND 4.0", "Fair use", "", "GFDL", nil] as [String?] {
            XCTAssertFalse(ContentPolicy.isAllowedLicense(name), name ?? "nil")
        }
    }

    func testFlagsArtworkAndJunk() {
        XCTAssertTrue(ContentPolicy.isArtwork(fileTitle: "File:Tyrannosaurus life restoration.jpg", description: nil))
        XCTAssertFalse(ContentPolicy.isArtwork(fileTitle: "File:Tyrannosaurus Rex Holotype.jpg", description: "Mounted skeleton at the Carnegie Museum"))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:Panthera uncia distribution map.png"))
    }

    func testStripsHTMLFromCommonsMetadata() {
        XCTAssertEqual(HTMLText.plain("<a href=\"x\">Jane &amp; Joe</a>\n Smith"), "Jane & Joe Smith")
    }
}
