import XCTest
@testable import HLSAnalyzerCore

final class CMAFValidationTests: XCTestCase {

    func testNonCMAFPlaylist() {
        let tsMedia = """
        #EXTM3U
        #EXTINF:8,
        segment1.ts
        """
        let analyzer = MediaPlaylistAnalyzer()
        let output = analyzer.analyze(content: tsMedia)
        // Should NOT contain 'CMAF Validation'
        XCTAssertFalse(output.contains("CMAF Validation"))
    }

    func testMissingMapTagForLikelyCMAF() {
        let missingMap = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXTINF:4.0,
        segment1.m4s
        """
        let analyzer = MediaPlaylistAnalyzer()
        let output = analyzer.analyze(content: missingMap)

        XCTAssertTrue(output.contains("CMAF Validation"))
        XCTAssertTrue(output.contains("❌ Missing #EXT-X-MAP"), "Missing #EXT-X-MAP should produce error")
        XCTAssertTrue(output.contains("⚠️  Missing #EXT-X-INDEPENDENT-SEGMENTS"), "Should warn about no #EXT-X-INDEPENDENT-SEGMENTS")
    }

    func testFullCMAFCompliance() {
        let cmafPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS
        #EXT-X-MAP:URI="init.mp4"
        #EXTINF:3.2,
        segment1.m4s
        #EXTINF:3.2,
        segment2.m4s
        """
        let analyzer = MediaPlaylistAnalyzer()
        let output = analyzer.analyze(content: cmafPlaylist)

        XCTAssertTrue(output.contains("CMAF Validation"))
        XCTAssertTrue(output.contains("✅ #EXT-X-MAP found."))
        XCTAssertTrue(output.contains("✅ #EXT-X-INDEPENDENT-SEGMENTS present."))
        XCTAssertTrue(output.contains("✅ Playlist version appears CMAF-compatible."))
    }

    func testVersionTooLow() {
        let lowVersion = """
        #EXTM3U
        #EXT-X-VERSION:5
        #EXT-X-MAP:URI="init.m4s"
        #EXTINF:2.0,
        seg1.m4s
        """
        let analyzer = MediaPlaylistAnalyzer()
        let output = analyzer.analyze(content: lowVersion)

        XCTAssertTrue(output.contains("CMAF Validation"))
        XCTAssertTrue(output.contains("❌ #EXT-X-VERSION is 5"), "Version < 7 should produce error")
    }

    func testNoVersionTag() {
        let noVersion = """
        #EXTM3U
        #EXT-X-MAP:URI="init.m4s"
        #EXTINF:2.0,
        seg1.m4s
        """
        let analyzer = MediaPlaylistAnalyzer()
        let output = analyzer.analyze(content: noVersion)

        XCTAssertTrue(output.contains("CMAF Validation"))
        XCTAssertTrue(output.contains("⚠️  #EXT-X-VERSION not found. CMAF typically requires version >= 7."))
    }
}
