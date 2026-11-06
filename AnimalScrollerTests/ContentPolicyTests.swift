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
        // Real Commons case: a Meganeura reconstruction described only in Spanish.
        XCTAssertTrue(ContentPolicy.isArtwork(fileTitle: "File:Meganeura monyi.png",
                                              description: "Reconstrucción del insecto meganisóptero Meganeura monyi."))
        XCTAssertTrue(ContentPolicy.isArtwork(fileTitle: "File:Archaeopteryx Lebendrekonstruktion.jpg", description: nil))
        XCTAssertFalse(ContentPolicy.isArtwork(fileTitle: "File:Meganeura monyi fossil.jpg",
                                               description: "Fossil wing in the Muséum de Toulouse"))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:Panthera uncia distribution map.png"))
    }

    func testStripsHTMLFromCommonsMetadata() {
        XCTAssertEqual(HTMLText.plain("<a href=\"x\">Jane &amp; Joe</a>\n Smith"), "Jane & Joe Smith")
    }

    func testDropsSmallAndStripImages() {
        XCTAssertTrue(ContentPolicy.isSharpEnough(width: 1080, height: 720))
        XCTAssertTrue(ContentPolicy.isSharpEnough(width: 1080, height: 1440))
        XCTAssertTrue(ContentPolicy.isSharpEnough(width: nil, height: nil))
        XCTAssertFalse(ContentPolicy.isSharpEnough(width: 320, height: 240))   // tiny original
        XCTAssertFalse(ContentPolicy.isSharpEnough(width: 1080, height: 300))  // panorama strip
        XCTAssertFalse(ContentPolicy.isSharpEnough(width: 700, height: 2000))  // tall strip
    }

    private func image(_ title: String) -> LicensedImage {
        LicensedImage(fileTitle: title, url: URL(string: "https://example.org/x.jpg")!,
                      width: 1080, height: 720, caption: nil,
                      attribution: Attribution(title: title, author: nil, license: "CC BY 4.0",
                                               licenseURL: nil, sourceURL: URL(string: "https://example.org")!),
                      isArtwork: false)
    }

    func testDropsCropsAndReencodesButKeepsTheLead() {
        let images = ["File:Snow leopard.jpg", "File:Snow leopard (cropped).jpg", "File:Snow_leopard.png",
                      "File:Snow leopard 2.jpg", "File:Snow leopard cub.jpg"].map(image)
        let kept = ContentPolicy.distinctImages(images, preferring: "File:Snow leopard (cropped).jpg").map(\.fileTitle)
        XCTAssertEqual(kept, ["File:Snow leopard (cropped).jpg", "File:Snow leopard 2.jpg", "File:Snow leopard cub.jpg"])
        let noLead = ContentPolicy.distinctImages(images, preferring: nil).map(\.fileTitle)
        XCTAssertEqual(noLead, ["File:Snow leopard.jpg", "File:Snow leopard 2.jpg", "File:Snow leopard cub.jpg"])
    }
}
