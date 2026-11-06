import XCTest
@testable import AnimalScroller

final class HeroImageTests: XCTestCase {
    private func image(_ title: String, artwork: Bool = false) -> LicensedImage {
        let url = URL(string: "https://upload.wikimedia.org/\(title).jpg")!
        return LicensedImage(fileTitle: title, url: url, width: 800, height: 1000, caption: nil,
                             attribution: Attribution(title: title, author: "A", license: "CC BY 4.0",
                                                      licenseURL: nil, sourceURL: url),
                             isArtwork: artwork)
    }

    private func content(_ images: [LicensedImage], lead: String?) -> SpeciesContent {
        SpeciesContent(title: "T", tagline: nil, lead: "", pageURL: URL(string: "https://en.wikipedia.org/wiki/T")!,
                       leadImageFileTitle: lead, facts: [], images: images)
    }

    private let living = TreeFixture.species("Fennec fox", "Vulpes zerda")
    private let extinct = TreeFixture.species("Smilodon fatalis", "Smilodon fatalis", .extinct)

    func testPrefersTheLeadImage() {
        let c = content([image("a"), image("b")], lead: "b")
        XCTAssertEqual(HeroImage.pick(from: c, species: living, allowArtwork: true)?.fileTitle, "b")
    }

    func testFallsBackToFirstRealPhoto() {
        let c = content([image("art", artwork: true), image("photo")], lead: nil)
        XCTAssertEqual(HeroImage.pick(from: c, species: extinct, allowArtwork: true)?.fileTitle, "photo")
    }

    func testLivingSpeciesNeverShowArtwork() {
        let c = content([image("art", artwork: true)], lead: "art")
        XCTAssertNil(HeroImage.pick(from: c, species: living, allowArtwork: true))
        XCTAssertEqual(HeroImage.usableImages(c, species: living, allowArtwork: true), [])
    }

    func testExtinctArtworkOnlyWhenAllowed() {
        let c = content([image("art", artwork: true)], lead: "art")
        XCTAssertEqual(HeroImage.pick(from: c, species: extinct, allowArtwork: true)?.fileTitle, "art")
        XCTAssertNil(HeroImage.pick(from: c, species: extinct, allowArtwork: false))
    }
}
