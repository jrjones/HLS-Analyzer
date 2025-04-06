import XCTest
@testable import HLSAnalyzerCore

final class AdMarkersTests: XCTestCase {
    
    func testDiscontinuityAndCueOut() {
        let playlist = """
        #EXTM3U
        #EXTINF:5.0,
        seg0.ts
        #EXT-X-DISCONTINUITY
        #EXTINF:5.0,
        ad1.ts
        #EXT-X-CUE-OUT:DURATION=10
        #EXTINF:5.0,
        ad2.ts
        """
        
        let adAnalyzer = AdMarkersAnalyzer()
        let (summary, markers) = adAnalyzer.analyzeAdMarkers(in: playlist)
        
        XCTAssertFalse(markers.isEmpty)
        XCTAssertTrue(summary.contains("Found #EXT-X-DISCONTINUITY"))
        XCTAssertTrue(summary.contains("Found #EXT-X-CUE-OUT"))
        XCTAssertTrue(summary.contains("SSAI (discontinuity-based)"))
        XCTAssertTrue(summary.contains("Cue Out/In Markers"))
    }
}
