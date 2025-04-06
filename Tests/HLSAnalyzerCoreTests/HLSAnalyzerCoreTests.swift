import XCTest
@testable import HLSAnalyzerCore

final class HLSAnalyzerCoreTests: XCTestCase {

    func testDetectMasterPlaylist() {
        let masterContent = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        video_640x360.m3u8
        """
        let type = HLSAnalyzerCore.determinePlaylistType(from: masterContent)
        XCTAssertEqual(type, .master)
    }

    func testDetectMediaPlaylist() {
        let mediaContent = """
        #EXTM3U
        #EXTINF:4.0,
        segment1.ts
        #EXTINF:4.0,
        segment2.ts
        #EXT-X-ENDLIST
        """
        let type = HLSAnalyzerCore.determinePlaylistType(from: mediaContent)
        XCTAssertEqual(type, .media)
    }
    
    func testDetectUnknownPlaylist() {
        let weirdContent = """
        #EXTM3U
        #NO_KNOWN_TAGS
        """
        let type = HLSAnalyzerCore.determinePlaylistType(from: weirdContent)
        XCTAssertEqual(type, .unknown)
    }
    
    func testParseMasterPlaylist() {
        let masterContent = """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=123456,RESOLUTION=1920x1080,CODECS=\"avc1.4d401f\"
        high.m3u8
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"aud1\",NAME=\"English\",URI=\"eng.m3u8\"
        """
        
        let master = SimpleHLSParser.parseMasterPlaylist(masterContent)
        XCTAssertEqual(master.variantStreams.count, 1)
        XCTAssertEqual(master.renditionGroups.count, 1)
        
        let variant = master.variantStreams.first!
        XCTAssertEqual(variant.bandwidth, 123456)
        XCTAssertEqual(variant.resolution?.width, 1920)
        XCTAssertEqual(variant.resolution?.height, 1080)
        XCTAssertEqual(variant.codecs, "\"avc1.4d401f\"")
        XCTAssertEqual(variant.uri, "high.m3u8")
        
        let rendition = master.renditionGroups.first!
        XCTAssertEqual(rendition.groupID, "aud1")
        XCTAssertEqual(rendition.type, "AUDIO")
        XCTAssertEqual(rendition.uri, "eng.m3u8")
    }
    
    func testParseMediaPlaylist() {
        let mediaContent = """
        #EXTM3U
        #EXT-X-TARGETDURATION:8
        #EXTINF:7.5,
        segment1.ts
        #EXTINF:7.4,
        segment2.ts
        """
        
        let playlist = SimpleHLSParser.parseMediaPlaylist(mediaContent)
        XCTAssertEqual(playlist.targetDuration, 8)
        XCTAssertEqual(playlist.segments.count, 2)
        
        let firstSegment = playlist.segments[0]
        XCTAssertEqual(firstSegment.duration, 7.5, accuracy: 0.01)
        XCTAssertEqual(firstSegment.uri, "segment1.ts")
        
        let secondSegment = playlist.segments[1]
        XCTAssertEqual(secondSegment.duration, 7.4, accuracy: 0.01)
        XCTAssertEqual(secondSegment.uri, "segment2.ts")
    }
}
