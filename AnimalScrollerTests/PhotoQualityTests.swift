import XCTest
@testable import AnimalScroller

/// Photo ranking and rendition choice (`PhotoQuality`), and how `ContentPolicy.licensedImages`
/// uses them. File names, sizes, assessments and categories below are real Commons values
/// recorded on 2026-11-06 from the Snow leopard, Tiger and Atlantic puffin articles.
final class PhotoQualityTests: XCTestCase {

    // MARK: Fixtures

    private let standard = URL(string: "https://thumb.wikimedia.org/x/1920px-a.jpg")!
    private let large = URL(string: "https://thumb.wikimedia.org/x/3840px-a.jpg")!
    private let original = URL(string: "https://upload.wikimedia.org/x/a.jpg")!

    private func info(_ title: String, _ width: Int, _ height: Int, bytes: Int = 3_000_000,
                      mime: String = "image/jpeg", license: String = "CC BY-SA 4.0",
                      assessments: String = "", categories: String = "") -> WikiClient.ImageInfo {
        let slug = title.replacingOccurrences(of: " ", with: "_")
        return WikiClient.ImageInfo(
            fileTitle: title,
            url: URL(string: "https://thumb.wikimedia.org/thumb/\(slug)/1920px-\(slug)")!,
            largeURL: URL(string: "https://thumb.wikimedia.org/thumb/\(slug)/3840px-\(slug)")!,
            width: width, height: height, bytes: bytes, mime: mime,
            descriptionURL: URL(string: "https://commons.wikimedia.org/wiki/\(slug)")!,
            licenseShortName: license, licenseURL: nil, artistHTML: "Someone", descriptionHTML: nil,
            assessments: assessments, categories: categories)
    }

    private let puffin = ["Fratercula arctica", "Atlantic puffin"]

    // MARK: Rendition

    func testTallPhotosGetTheLargeRenditionSoTheyFillTheScreenHeight() {
        // 3:4 portrait, 3000 wide: 1920 px would be 2560 tall, under the 2868 px screen.
        XCTAssertEqual(PhotoQuality.displayURL(width: 3000, height: 4000, bytes: 4_000_000,
                                               standardURL: standard, largeURL: large), large)
        // Square 3317 px Featured puffin: fills height only from the large rendition.
        XCTAssertEqual(PhotoQuality.displayURL(width: 3317, height: 3317, bytes: 8_488_883,
                                               standardURL: standard, largeURL: large), large)
    }

    func testStandardRenditionIsEnoughForTallNarrowAndWidePhotos() {
        // 2:3 portrait: 1920 wide is 2880 tall, already taller than the screen.
        XCTAssertEqual(PhotoQuality.displayURL(width: 3200, height: 4800, bytes: 4_217_484,
                                               standardURL: standard, largeURL: large), standard)
        // 3:2 landscape is shown whole across the screen, which is only 1320 px wide.
        XCTAssertEqual(PhotoQuality.displayURL(width: 6988, height: 4664, bytes: 20_390_113,
                                               standardURL: standard, largeURL: large), standard)
        // Original no wider than 1920: Commons already serves the original.
        XCTAssertEqual(PhotoQuality.displayURL(width: 1575, height: 1181, bytes: 273_183,
                                               standardURL: original, largeURL: nil), original)
    }

    func testHugeOriginalsAreNeverDownloaded() {
        // 2010 × 2892: the 2x rendition is the original itself. Fine at 3.4 MB, not at 40 MB.
        XCTAssertEqual(PhotoQuality.displayURL(width: 2010, height: 2892, bytes: 3_439_156,
                                               standardURL: standard, largeURL: original), standard,
                       "2:3-ish portraits at 1920 px already reach 90% of the screen height")
        XCTAssertEqual(PhotoQuality.displayURL(width: 2400, height: 2400, bytes: 3_000_000,
                                               standardURL: standard, largeURL: original), original)
        XCTAssertEqual(PhotoQuality.displayURL(width: 2400, height: 2400, bytes: 40_000_000,
                                               standardURL: standard, largeURL: original), standard)
    }

    func testNeededWidth() {
        XCTAssertEqual(PhotoQuality.neededWidth(width: 3000, height: 2000), PhotoQuality.screenPixelWidth)
        XCTAssertEqual(PhotoQuality.neededWidth(width: 1000, height: 1000), PhotoQuality.screenPixelHeight)
        XCTAssertEqual(PhotoQuality.neededWidth(width: 1000, height: 3000), PhotoQuality.screenPixelWidth)
        XCTAssertEqual(PhotoQuality.neededWidth(width: 0, height: 0), PhotoQuality.screenPixelWidth)
    }

    // MARK: Score

    func testCommonsAssessmentsAreParsed() {
        XCTAssertEqual(PhotoQuality.assessments(from: "quality|featured|poty"), ["quality", "featured", "poty"])
        XCTAssertEqual(PhotoQuality.assessments(from: ""), [])
        XCTAssertEqual(PhotoQuality.assessments(from: nil), [])
        XCTAssertEqual(PhotoQuality.categories(from: "A b|C d|"), ["A b", "C d"])
    }

    func testFeaturedBigPortraitBeatsSmallLandscape() {
        let featured = PhotoQuality.score(.init(
            fileTitle: "File:Fratercula arctica in flight, Borgarfjörður eystri, Iceland.jpg",
            width: 1936, height: 2656, assessments: ["quality", "featured", "poty"], subjectNames: puffin))
        let plain = PhotoQuality.score(.init(
            fileTitle: "File:Fratercula arctica001.jpg", width: 1000, height: 783, subjectNames: puffin))
        XCTAssertGreaterThan(featured, plain + 50)
    }

    func testPortraitBeatsPanoramaAtTheSameResolution() {
        let portrait = PhotoQuality.shapeScore(width: 3000, height: 4000)
        let square = PhotoQuality.shapeScore(width: 3000, height: 3000)
        let landscape = PhotoQuality.shapeScore(width: 4500, height: 3000)
        let panorama = PhotoQuality.shapeScore(width: 6000, height: 2500)
        XCTAssertGreaterThan(portrait, square)
        XCTAssertGreaterThan(square, landscape)
        XCTAssertGreaterThan(landscape, panorama)
    }

    func testResolutionScoreRisesWithSize() {
        XCTAssertLessThan(PhotoQuality.resolutionScore(width: 640, height: 480), 0)
        XCTAssertEqual(PhotoQuality.resolutionScore(width: 1200, height: 800), 0, accuracy: 0.001)
        XCTAssertGreaterThan(PhotoQuality.resolutionScore(width: 3000, height: 2000),
                             PhotoQuality.resolutionScore(width: 1600, height: 1067))
        XCTAssertEqual(PhotoQuality.resolutionScore(width: 6000, height: 4000), 30, accuracy: 0.001)
    }

    func testCloseUpsBeatHabitatShotsAndSpecimens() {
        let names = ["Panthera uncia", "Snow leopard"]
        let head = PhotoQuality.score(.init(
            fileTitle: "File:Panthera uncia (33172899150).jpg", width: 4411, height: 3092,
            categories: ["Panthera uncia heads", "Yawning Panthera uncia"], subjectNames: names))
        let skull = PhotoQuality.score(.init(
            fileTitle: "File:Panthera uncia 02 MWNH 355.jpg", width: 4288, height: 2848,
            categories: ["Panthera uncia skulls", "Felidae skulls in left lateral aspect"], subjectNames: names))
        let park = PhotoQuality.score(.init(
            fileTitle: "File:Khunjerab 240625.jpg", width: 1920, height: 1280,
            categories: ["Khunjerab National Park", "Self-published work"], subjectNames: names))
        XCTAssertGreaterThan(head, skull + 30)
        XCTAssertGreaterThan(head, park + 30)
    }

    func testSpeciesOwnNameNeverCountsAgainstIt() {
        let names = ["Callorhinus ursinus", "Northern fur seal"]
        let seal = PhotoQuality.score(.init(fileTitle: "File:Northern fur seal bull.jpg", width: 3000, height: 2000,
                                            categories: ["Callorhinus ursinus"], subjectNames: names))
        let same = PhotoQuality.score(.init(fileTitle: "File:Northern seal bull.jpg", width: 3000, height: 2000,
                                            categories: ["Callorhinus ursinus"], subjectNames: names))
        XCTAssertEqual(seal, same, accuracy: 0.001)
    }

    func testCommonsFlawCategoriesCostPoints() {
        let clean = PhotoQuality.score(.init(fileTitle: "File:A.jpg", width: 3000, height: 2000))
        let flawed = PhotoQuality.score(.init(fileTitle: "File:A.jpg", width: 3000, height: 2000,
                                              categories: ["Images with inappropriate JPEG compression"]))
        XCTAssertLessThan(flawed, clean)
    }

    // MARK: ContentPolicy.licensedImages

    func testLicensedImagesRanksBestFirstAndDropsJunk() {
        let infos = [
            info("File:Fratercula arctica001.jpg", 1000, 783),
            info("File:Fratercula arctica distribution map.svg", 3100, 1600, mime: "image/svg+xml"),
            info("File:Faroe stamp 031 puffin.jpg", 1600, 2200),
            info("File:Puffin (Fratercula arctica).jpg", 3317, 3317, bytes: 8_488_883,
                 assessments: "quality|featured|valued", categories: "Fratercula arctica portraits"),
            info("File:Dunnet Head Puffin.jpg", 3200, 4800),
            info("File:Puffin watching (8958978651).jpg", 1024, 484),
            info("File:Atlantic Puffins, Scotland.jpg", 3120, 1893, license: "CC BY-NC 2.0"),
        ]
        let images = ContentPolicy.licensedImages(from: infos, subjectNames: puffin)
        let titles = images.map(\.fileTitle)
        XCTAssertEqual(titles.first, "File:Puffin (Fratercula arctica).jpg")
        XCTAssertFalse(titles.contains("File:Faroe stamp 031 puffin.jpg"), "stamp")
        XCTAssertFalse(titles.contains("File:Fratercula arctica distribution map.svg"), "map")
        XCTAssertFalse(titles.contains("File:Atlantic Puffins, Scotland.jpg"), "NonCommercial")
        XCTAssertFalse(titles.contains("File:Puffin watching (8958978651).jpg"), "strip, too small")
        // Two sharp photos exist, so the soft 1000 px one is dropped.
        XCTAssertFalse(titles.contains("File:Fratercula arctica001.jpg"))
        // The square Featured photo loads at 3840 px to fill the screen height.
        XCTAssertTrue(images.first?.url.absoluteString.contains("3840px-") == true)
        // Width and height are the original's, not the requested thumbnail width.
        XCTAssertEqual(images.first?.width, 3317)
    }

    func testSoftPhotosStayWhenASpeciesHasFewSharpOnes() {
        let infos = [info("File:Rare beetle 1.jpg", 1000, 750), info("File:Rare beetle 2.jpg", 2000, 1500)]
        XCTAssertEqual(ContentPolicy.licensedImages(from: infos).count, 2)
        XCTAssertEqual(ContentPolicy.licensedImages(from: infos).first?.fileTitle, "File:Rare beetle 2.jpg")
    }

    func testTinyOriginalsAreDroppedEvenWhenCommonsReportsTheThumbnailWidth() {
        // Commons answered 1920 for this 599 × 381 woodcut's `thumbwidth`; the original size rules.
        let infos = [info("File:Ounce1.jpg", 599, 381, license: "CC0")]
        XCTAssertTrue(ContentPolicy.licensedImages(from: infos).isEmpty)
    }

    func testLeadImageGetsABoostButAFeaturedPhotoCanStillOutrankIt() {
        let infos = [info("File:Lead.jpg", 2000, 1500), info("File:Other.jpg", 2000, 1500)]
        XCTAssertEqual(ContentPolicy.licensedImages(from: infos, leadFileTitle: "File:Other.jpg").first?.fileTitle,
                       "File:Other.jpg")
        let featured = [info("File:Lead.jpg", 2000, 1500), info("File:Best.jpg", 3000, 4000, assessments: "featured|quality")]
        XCTAssertEqual(ContentPolicy.licensedImages(from: featured, leadFileTitle: "File:Lead.jpg").first?.fileTitle,
                       "File:Best.jpg")
    }

    func testArtworkCategoriesLabelArtwork() {
        XCTAssertTrue(ContentPolicy.isArtwork(fileTitle: "File:Ounce1.jpg", description: nil,
                                              categories: ["Woodcuts of animals", "17th-century illustrations of snow leopards"]))
        // "template" contains "plate", but categories match whole words only.
        XCTAssertFalse(ContentPolicy.isArtwork(fileTitle: "File:Irbis4.JPG", description: nil,
                                               categories: ["Media missing infobox template", "Standing Panthera uncia"]))
    }

    func testJunkMatchesWholeWordsOnly() {
        XCTAssertFalse(ContentPolicy.isJunk(fileTitle: "File:Orange-bellied parrot.jpg"))
        XCTAssertFalse(ContentPolicy.isJunk(fileTitle: "File:Mountain gorilla photograph.jpg"))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:Snow leopard range.png"))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:Status_iucn3.1_VU.svg"))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:SnowLeopard10000KZT.jpg",
                                           categories: ["Blue banknotes", "Snow leopards on banknotes"]))
        XCTAssertTrue(ContentPolicy.isJunk(fileTitle: "File:Two cladograms for Panthera.svg"))
    }
}
