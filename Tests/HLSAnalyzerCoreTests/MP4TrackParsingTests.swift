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
private extension UInt16 {
    var bigEndianBytes: [UInt8] {
        let be = self.bigEndian
        return [
            UInt8((be >> 8) & 0xFF),
            UInt8(be & 0xFF)
        ]
    }
}

final class MP4TrackParsingTests: XCTestCase {
    func testParseAudioSampleEntry() {
        // Build a minimal tkhd payload: version=0, flags=0, filler up to trackID
        var tkhdPayload = Data(count: 12)
        let trackID: UInt32 = 3
        tkhdPayload.append(contentsOf: trackID.bigEndianBytes) // at bytes 12..15
        let tkhdAtom = MP4Atom(type: "tkhd", size: UInt64(tkhdPayload.count + 8), children: [], payload: tkhdPayload)

        // Build hdlr atom payload: version+flags (4), pre-defined (4), handlerType (4)
        var hdlrPayload = Data([0,0,0,0])
        hdlrPayload.append(contentsOf: [0,0,0,0])
        hdlrPayload.append(contentsOf: Array("soun".utf8))
        let hdlrAtom = MP4Atom(type: "hdlr", size: UInt64(hdlrPayload.count + 8), children: [], payload: hdlrPayload)

        // Build stsd payload: version+flags (4), entryCount=1 (4)
        var stsdPayload = Data([0,0,0,0])
        stsdPayload.append(contentsOf: UInt32(1).bigEndianBytes)
        // One entry: entrySize, entryType
        let audioEntryDataSize = 28
        let audioEntrySize = UInt32(8 + audioEntryDataSize)
        stsdPayload.append(contentsOf: audioEntrySize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("mp4a".utf8))
        // entryData: zeros up to channel/sampleRate positions
        var entryData = Data(count: audioEntryDataSize)
        // Set channelcount @ offset 16 (UInt16)
        let channels: UInt16 = 2
        entryData.replaceSubrange(16..<18, with: channels.bigEndianBytes)
        // Set sampleRate @ offset 24 (UInt32 fixed 16.16)
        let sampleRate: UInt32 = 48000
        let srFixed = sampleRate << 16
        entryData.replaceSubrange(24..<28, with: srFixed.bigEndianBytes)
        stsdPayload.append(entryData)
        let stsdAtom = MP4Atom(type: "stsd", size: UInt64(stsdPayload.count + 8), children: [], payload: stsdPayload)

        // Wrap into stbl, minf, mdia
        let stblAtom = MP4Atom(type: "stbl", size: stsdAtom.size + 8, children: [stsdAtom], payload: nil)
        let minfAtom = MP4Atom(type: "minf", size: stblAtom.size + 8, children: [stblAtom], payload: nil)
        let mdiaAtom = MP4Atom(type: "mdia", size: hdlrAtom.size + minfAtom.size + 8, children: [hdlrAtom, minfAtom], payload: nil)

        // Combine into trak and moov
        let trakAtom = MP4Atom(type: "trak", size: tkhdAtom.size + mdiaAtom.size + 8, children: [tkhdAtom, mdiaAtom], payload: nil)
        let moovAtom = MP4Atom(type: "moov", size: trakAtom.size + 8, children: [trakAtom], payload: nil)

        var segmentInfo = SegmentInfo(sizeBytes: 0)
        let analyzer = MP4SegmentAnalyzer()
        analyzer.parseInitSegment(moovAtom, into: &segmentInfo)

        // Validate audio track fields
        XCTAssertNil(segmentInfo.videoTrack)
        XCTAssertNotNil(segmentInfo.audioTrack)
        let audio = segmentInfo.audioTrack!
        XCTAssertEqual(audio.trackID, trackID)
        XCTAssertEqual(audio.codec, "mp4a")
        XCTAssertEqual(audio.channels, Int(channels))
        XCTAssertEqual(audio.sampleRate, Int(sampleRate))
    }

    func testParseVideoSampleEntry() {
        // Minimal tkhd
        var tkhdPayload = Data(count: 12)
        let trackID: UInt32 = 5
        tkhdPayload.append(contentsOf: trackID.bigEndianBytes)
        let tkhdAtom = MP4Atom(type: "tkhd", size: UInt64(tkhdPayload.count + 8), children: [], payload: tkhdPayload)

        // Video hdlr
        var hdlrPayload = Data([0,0,0,0])
        hdlrPayload.append(contentsOf: [0,0,0,0])
        hdlrPayload.append(contentsOf: Array("vide".utf8))
        let hdlrAtom = MP4Atom(type: "hdlr", size: UInt64(hdlrPayload.count + 8), children: [], payload: hdlrPayload)

        // Build stsd with nested avcC
        var stsdPayload = Data([0,0,0,0])
        stsdPayload.append(contentsOf: UInt32(1).bigEndianBytes)
        // entry: entrySize = 8 + dataSize
        let videoEntryDataSize = 9
        let videoEntrySize = UInt32(8 + videoEntryDataSize)
        stsdPayload.append(contentsOf: videoEntrySize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("avc1".utf8))
        // entryData: nested atom of size 9, type avcC, 1 byte padding
        var entryData = Data()
        entryData.append(contentsOf: UInt32(9).bigEndianBytes)         // nestedSize
        entryData.append(contentsOf: Array("avcC".utf8))             // nestedType
        entryData.append(0)                                            // padding
        stsdPayload.append(entryData)
        let stsdAtom = MP4Atom(type: "stsd", size: UInt64(stsdPayload.count + 8), children: [], payload: stsdPayload)

        // Wrap
        let stblAtom = MP4Atom(type: "stbl", size: stsdAtom.size + 8, children: [stsdAtom], payload: nil)
        let minfAtom = MP4Atom(type: "minf", size: stblAtom.size + 8, children: [stblAtom], payload: nil)
        let mdiaAtom = MP4Atom(type: "mdia", size: hdlrAtom.size + minfAtom.size + 8, children: [hdlrAtom, minfAtom], payload: nil)
        let trakAtom = MP4Atom(type: "trak", size: tkhdAtom.size + mdiaAtom.size + 8, children: [tkhdAtom, mdiaAtom], payload: nil)
        let moovAtom = MP4Atom(type: "moov", size: trakAtom.size + 8, children: [trakAtom], payload: nil)

        var segmentInfo = SegmentInfo(sizeBytes: 0)
        let analyzer = MP4SegmentAnalyzer()
        analyzer.parseInitSegment(moovAtom, into: &segmentInfo)

        // Validate video track fields
        XCTAssertNil(segmentInfo.audioTrack)
        XCTAssertNotNil(segmentInfo.videoTrack)
        let video = segmentInfo.videoTrack!
        XCTAssertEqual(video.trackID, trackID)
        XCTAssertEqual(video.codec, "avc1")
        XCTAssertEqual(video.hdrType, "avcC")
        XCTAssertNotNil(video.resolution)
    }

    func testParseEncryptedAudioSampleEntry() {
        // Build a minimal tkhd payload
        var tkhdPayload = Data(count: 12)
        let trackID: UInt32 = 7
        tkhdPayload.append(contentsOf: trackID.bigEndianBytes)
        let tkhdAtom = MP4Atom(type: "tkhd", size: UInt64(tkhdPayload.count + 8), children: [], payload: tkhdPayload)

        // Audio handler
        var hdlrPayload = Data([0,0,0,0, 0,0,0,0])
        hdlrPayload.append(contentsOf: Array("soun".utf8))
        let hdlrAtom = MP4Atom(type: "hdlr", size: UInt64(hdlrPayload.count + 8), children: [], payload: hdlrPayload)

        // Build stsd entry with sinf
        var stsdPayload = Data([0,0,0,0])
        stsdPayload.append(contentsOf: UInt32(1).bigEndianBytes)
        // One entry header
        let entryDataSize = 28 + 8
        let entrySize = UInt32(8 + entryDataSize)
        stsdPayload.append(contentsOf: entrySize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("mp4a".utf8))
        var entryData = Data(count: 28)
        // pad channels/sampleRate
        entryData.replaceSubrange(16..<18, with: UInt16(1).bigEndianBytes)
        let srFixed = UInt32(44100) << 16
        entryData.replaceSubrange(24..<28, with: srFixed.bigEndianBytes)
        // append a sinf atom: size=8, type="sinf"
        entryData.append(contentsOf: UInt32(8).bigEndianBytes)
        entryData.append(contentsOf: Array("sinf".utf8))
        stsdPayload.append(entryData)
        let stsdAtom = MP4Atom(type: "stsd", size: UInt64(stsdPayload.count + 8), children: [], payload: stsdPayload)

        let stblAtom = MP4Atom(type: "stbl", size: stsdAtom.size + 8, children: [stsdAtom], payload: nil)
        let minfAtom = MP4Atom(type: "minf", size: stblAtom.size + 8, children: [stblAtom], payload: nil)
        let mdiaAtom = MP4Atom(type: "mdia", size: hdlrAtom.size + minfAtom.size + 8, children: [hdlrAtom, minfAtom], payload: nil)
        let trakAtom = MP4Atom(type: "trak", size: tkhdAtom.size + mdiaAtom.size + 8, children: [tkhdAtom, mdiaAtom], payload: nil)
        let moovAtom = MP4Atom(type: "moov", size: trakAtom.size + 8, children: [trakAtom], payload: nil)

        var segmentInfo = SegmentInfo(sizeBytes: 0)
        let analyzer = MP4SegmentAnalyzer()
        analyzer.parseInitSegment(moovAtom, into: &segmentInfo)

        // Encrypted flag should be true
        XCTAssertNotNil(segmentInfo.audioTrack)
        XCTAssertTrue(segmentInfo.audioTrack!.encrypted, "Audio track should be marked encrypted due to sinf atom.")
    }
    
    func testParseEncryptedVideoSampleEntry() {
        // Minimal tkhd
        var tkhdPayload = Data(count: 12)
        let trackID: UInt32 = 9
        tkhdPayload.append(contentsOf: trackID.bigEndianBytes)
        let tkhdAtom = MP4Atom(type: "tkhd", size: UInt64(tkhdPayload.count + 8), children: [], payload: tkhdPayload)

        // Video handler
        var hdlrPayload = Data([0,0,0,0, 0,0,0,0])
        hdlrPayload.append(contentsOf: Array("vide".utf8))
        let hdlrAtom = MP4Atom(type: "hdlr", size: UInt64(hdlrPayload.count + 8), children: [], payload: hdlrPayload)

        // Build stsd payload with nested avcC and sinf atoms
        var stsdPayload = Data([0,0,0,0])
        stsdPayload.append(contentsOf: UInt32(1).bigEndianBytes) // entryCount
        // Entry size = header(8) + data
        let nestedAvcCSize: UInt32 = 9
        let sinfSize: UInt32 = 8
        let entryDataSize = Int(nestedAvcCSize) + Int(sinfSize)
        let entrySize = UInt32(8 + entryDataSize)
        stsdPayload.append(contentsOf: entrySize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("avc1".utf8))
        // Nested avcC atom: size=9, type avcC, 1 byte padding
        stsdPayload.append(contentsOf: nestedAvcCSize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("avcC".utf8))
        stsdPayload.append(0)
        // Nested sinf atom: size=8, type sinf
        stsdPayload.append(contentsOf: sinfSize.bigEndianBytes)
        stsdPayload.append(contentsOf: Array("sinf".utf8))
        let stsdAtom = MP4Atom(type: "stsd", size: UInt64(stsdPayload.count + 8), children: [], payload: stsdPayload)

        let stblAtom = MP4Atom(type: "stbl", size: stsdAtom.size + 8, children: [stsdAtom], payload: nil)
        let minfAtom = MP4Atom(type: "minf", size: stblAtom.size + 8, children: [stblAtom], payload: nil)
        let mdiaAtom = MP4Atom(type: "mdia", size: hdlrAtom.size + minfAtom.size + 8, children: [hdlrAtom, minfAtom], payload: nil)
        let trakAtom = MP4Atom(type: "trak", size: tkhdAtom.size + mdiaAtom.size + 8, children: [tkhdAtom, mdiaAtom], payload: nil)
        let moovAtom = MP4Atom(type: "moov", size: trakAtom.size + 8, children: [trakAtom], payload: nil)

        var segmentInfo = SegmentInfo(sizeBytes: 0)
        let analyzer = MP4SegmentAnalyzer()
        analyzer.parseInitSegment(moovAtom, into: &segmentInfo)

        // Encrypted flag should be true for video
        XCTAssertNotNil(segmentInfo.videoTrack)
        XCTAssertTrue(segmentInfo.videoTrack!.encrypted, "Video track should be marked encrypted due to sinf atom.")
    }
    }
}