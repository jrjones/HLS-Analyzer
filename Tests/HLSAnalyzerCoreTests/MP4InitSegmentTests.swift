import XCTest
@testable import HLSAnalyzerCore

// Helpers to encode integers to big-endian byte arrays
private extension UInt32 {
    var bigEndianBytes: [UInt8] {
        let be = self.bigEndian
        return [
            UInt8((be >> 24) & 0xFF),
            UInt8((be >> 16) & 0xFF),
            UInt8((be >> 8) & 0xFF),
            UInt8(be & 0xFF)
        ]
    }
}

final class MP4InitSegmentTests: XCTestCase {
    /// Test parsing of mvhd in an init segment (version 0) for timescale and duration
    func testParseMvhdVersion0() {
        // Construct mvhd payload: version=0, flags=0, creation & modification times=0
        let version: UInt8 = 0
        let flags: [UInt8] = [0, 0, 0]
        let creationAndMod: [UInt8] = [0, 0, 0, 0,  0, 0, 0, 0]
        let timescale: UInt32 = 1000
        let duration: UInt32 = 2000
        var payload = Data([version] + flags + creationAndMod)
        payload.append(contentsOf: timescale.bigEndianBytes)
        payload.append(contentsOf: duration.bigEndianBytes)
        // Ensure payload length is correct
        XCTAssertEqual(payload.count, 20, "mvhd payload should be 20 bytes for version 0.")

        // Create mp4 atoms manually
        let mvhdAtom = MP4Atom(type: "mvhd", size: UInt64(payload.count + 8), children: [], payload: payload)
        let moovAtom = MP4Atom(type: "moov", size: mvhdAtom.size + 8, children: [mvhdAtom], payload: nil)

        // Run parser
        var segmentInfo = SegmentInfo(sizeBytes: 0)
        let analyzer = MP4SegmentAnalyzer()
        analyzer.parseInitSegment(moovAtom, into: &segmentInfo)

        // Check computed duration (seconds)
        XCTAssertNotNil(segmentInfo.segmentDuration)
        XCTAssertEqual(segmentInfo.segmentDuration!, Double(duration) / Double(timescale), accuracy: 1e-6)
        // Verify that an issue entry mentions timescale and duration
        let issueLines = segmentInfo.issues.filter { $0.contains("timescale=") && $0.contains("duration=") }
        XCTAssertFalse(issueLines.isEmpty, "Expected mvhd parse issue with timescale and duration details.")
    }
}