// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested

import Foundation

public class MP4SegmentAnalyzer {
    private let parser: MP4Parser

    // Basic struct to hold track fragment data during parsing
    private struct TrackFragmentData {
        var trackID: UInt32?
        var decodeTime: UInt64?
        var sampleCount: UInt32 = 0
    }

    public init() {
        self.parser = MP4Parser()
    }

    /// Download segment and parse for CMAF structure.
    /// Return SegmentInfo capturing relevant details.
    /// TODO - should pass an init segment or HLS context.
    public func analyzeSegment(url: URL) -> SegmentInfo {
        guard let data = try? Data(contentsOf: url) else {
            var si = SegmentInfo(sizeBytes: 0)
            si.issues.append("Failed to download \(url)")
            return si
        }
        var segmentInfo = SegmentInfo(sizeBytes: data.count)
        let result = parser.parseMP4(data: data)
        // Record any parse issues
        segmentInfo.issues.append(contentsOf: result.issues)
        // Export raw MP4 box hierarchy for debugging
        segmentInfo.mp4Structure = result.atoms.map { summarize(atom: $0) }
        // Detect and parse init segment (moov) if present
        if let moovAtom = result.atoms.first(where: { $0.type == "moov" }) {
            parseInitSegment(moovAtom, into: &segmentInfo)
        }

        // If top-level atoms are empty, just record an issue.
        if result.atoms.isEmpty {
            segmentInfo.issues.append("No recognizable MP4 atoms found.")
            return segmentInfo
        }

        // We look for moof atoms and parse track fragments.
        // For CMAF typically see moof + mdat.
        var foundMoof = false
        for atom in result.atoms {
            if atom.type == "moof" {
                foundMoof = true
                parseMoof(atom, into: &segmentInfo)
            }
        }
        if !foundMoof {
            // It's possible this segment is an init segment with moov.
            // For now, note that no moof was found.
            segmentInfo.issues.append("No moof atom in segment (maybe init segment?)")
        }

        return segmentInfo
    }

    private func parseMoof(_ moofAtom: MP4Atom, into segmentInfo: inout SegmentInfo) {
        // We expect children: mfhd, traf, etc.
        for child in moofAtom.children {
            switch child.type {
            case "traf":
                parseTraf(child, into: &segmentInfo)
            default:
                break
            }
        }
    }

    private func parseTraf(_ trafAtom: MP4Atom, into segmentInfo: inout SegmentInfo) {
        var trackFrag = TrackFragmentData()
        for child in trafAtom.children {
            switch child.type {
            case "tfhd":
                parseTfhd(child, into: &trackFrag, &segmentInfo)
            case "tfdt":
                parseTfdt(child, into: &trackFrag, &segmentInfo)
            case "trun":
                parseTrun(child, into: &trackFrag, &segmentInfo)
            default:
                break
            }
        }

        guard let trackID = trackFrag.trackID else {
            segmentInfo.issues.append("No trackID found in tfhd.")
            return
        }
        // Simple happy path for first working version - if track ID is 1 => video, track ID is 2 => audio
        // TODO: identify track type from init or from HLS CODECS.
        switch trackID {
        case 1:
            // minimal example
            segmentInfo.videoTrack = VideoTrackInfo(
                trackID: trackID,
                codec: "hvc1", // placeholder, or read from init
                hdrType: nil,
                resolution: nil,
                encrypted: false
            )
        case 2:
            segmentInfo.audioTrack = AudioTrackInfo(
                trackID: trackID,
                codec: "ec-3", // placeholder
                channels: nil,
                sampleRate: nil,
                dolbyAtmos: false,
                encrypted: false
            )
        default:
            // skip other trackIDs for now
            segmentInfo.issues.append("Track ID = \(trackID) encountered but not mapped to video/audio.")
        }
    }

    private func parseTfhd(_ tfhdAtom: MP4Atom, into trackFrag: inout TrackFragmentData, _ segmentInfo: inout SegmentInfo) {
        guard let payload = tfhdAtom.payload, payload.count >= 8 else {
            segmentInfo.issues.append("tfhd atom too small or missing payload.")
            return
        }
        // First 4 bytes are flags, next 4 are trackID.
        let trackID = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        trackFrag.trackID = UInt32(bigEndian: trackID)
    }

    private func parseTfdt(_ tfdtAtom: MP4Atom, into trackFrag: inout TrackFragmentData, _ segmentInfo: inout SegmentInfo) {
        guard let payload = tfdtAtom.payload, payload.count >= 4 else {
            segmentInfo.issues.append("tfdt atom too small.")
            return
        }
        let version = payload[0]
        if version == 1 {
            if payload.count >= 12 {
                let decodeTime = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt64.self) }
                trackFrag.decodeTime = UInt64(bigEndian: decodeTime)
            } else {
                segmentInfo.issues.append("tfdt version=1 but not enough bytes.")
            }
        } else {
            if payload.count >= 8 {
                let decodeTime32 = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
                trackFrag.decodeTime = UInt64(UInt32(bigEndian: decodeTime32))
            } else {
                segmentInfo.issues.append("tfdt version=0 but not enough bytes.")
            }
        }
    }

    private func parseTrun(_ trunAtom: MP4Atom, into trackFrag: inout TrackFragmentData, _ segmentInfo: inout SegmentInfo) {
        guard let payload = trunAtom.payload, payload.count >= 8 else {
            segmentInfo.issues.append("trun atom too small.")
            return
        }
        let sampleCount = payload.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self) }
        let sc = UInt32(bigEndian: sampleCount)
        trackFrag.sampleCount = sc
    }

    // Recursively summarize an MP4Atom into a lightweight summary for debugging
    private func summarize(atom: MP4Atom) -> MP4AtomSummary {
        return MP4AtomSummary(
            type: atom.type,
            size: atom.size,
            children: atom.children.map { summarize(atom: $0) }
        )
    }

    // Parse init segment (moov) metadata: movie header and track info
    func parseInitSegment(_ moov: MP4Atom, into segmentInfo: inout SegmentInfo) {
        // Parse mvhd for movie header and each trak for track metadata
        for atom in moov.children {
            switch atom.type {
            case "mvhd":
                parseMvhd(atom, into: &segmentInfo)
            case "trak":
                parseInitTrak(atom, into: &segmentInfo)
            default:
                continue
            }
        }
    }

    // Parse movie header box (mvhd) to extract timescale and duration
    private func parseMvhd(_ mvhd: MP4Atom, into segmentInfo: inout SegmentInfo) {
        guard let data = mvhd.payload else {
            segmentInfo.issues.append("mvhd atom missing payload.")
            return
        }
        if data.count < 12 {
            segmentInfo.issues.append("mvhd atom too small.")
            return
        }
        let version = data[0]
        var timescale: UInt32 = 0
        var duration: UInt64 = 0
        if version == 1 {
            let headerSize = 4 + 8 + 8
            if data.count >= headerSize + 12 {
                timescale = data[headerSize..<headerSize+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                duration = data[headerSize+4..<headerSize+12].withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
            } else {
                segmentInfo.issues.append("mvhd atom version=1 too small for timescale and duration.")
                return
            }
        } else {
            let headerSize = 4 + 4 + 4
            if data.count >= headerSize + 8 {
                timescale = data[headerSize..<headerSize+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                let dur32 = data[headerSize+4..<headerSize+8].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                duration = UInt64(dur32)
            } else {
                segmentInfo.issues.append("mvhd atom version=0 too small for timescale and duration.")
                return
            }
        }
        if timescale > 0 {
            let seconds = Double(duration) / Double(timescale)
            segmentInfo.segmentDuration = seconds
            segmentInfo.issues.append("Movie header: timescale=\(timescale), duration=\(duration) (~\(String(format: "%.3f", seconds))s)")
        } else {
            segmentInfo.issues.append("mvhd has zero timescale.")
        }
    }

    // Parse a single trak box for track header and media info, including channels and sample rate
    private func parseInitTrak(_ trak: MP4Atom, into segmentInfo: inout SegmentInfo) {
        var trackID: UInt32?
        var width: Int?
        var height: Int?
        var handlerType: String?
        var codecStr: String?
        var hdrType: String?
        var encrypted: Bool = false
        var channels: Int?
        var sampleRateValue: Int?
        
        // Walk through child atoms of trak
        for child in trak.children {
            if child.type == "tkhd" {
                if let (tid, w, h) = parseTkhd(child) {
                    trackID = tid
                    width = w
                    height = h
                }
            } else if child.type == "mdia" {
                // Within mdia, find handler and sample descriptions
                for mdiaChild in child.children {
                    if mdiaChild.type == "hdlr", let payload = mdiaChild.payload, payload.count >= 12 {
                        let typeBytes = payload[8..<12]
                        handlerType = String(data: typeBytes, encoding: .ascii)
                    } else if mdiaChild.type == "minf" {
                        for minfChild in mdiaChild.children {
                            if minfChild.type == "stbl" {
                                for stblChild in minfChild.children {
                                    if stblChild.type == "stsd", let payload = stblChild.payload {
                                        // Parse stsd payload to get entryCount and sample entries
                                        var reader = MP4ByteReader(data: payload)
                                        do {
                                            // Skip version (1 byte) + flags (3 bytes)
                                            try reader.skipBytes(4)
                                            let entryCount = try reader.readUInt32()
                                            for _ in 0..<entryCount {
                                                let entrySize = try reader.readUInt32()
                                                let entryType = try reader.readAtomType()
                                                codecStr = entryType
                                                let dataSize = Int(entrySize) - 8
                                                if dataSize > 0 {
                                                    let entryData = try reader.subdata(count: dataSize)
                                                    // Detect encryption via 'sinf' atom in sample entry
                                                    var sinfReader = MP4ByteReader(data: entryData)
                                                    while sinfReader.bytesLeft > 8 {
                                                        let nSize = try sinfReader.readUInt32()
                                                        let nType = try sinfReader.readAtomType()
                                                        if nType == "sinf" {
                                                            encrypted = true
                                                        }
                                                        let skipLen = Int(nSize) - 8
                                                        if skipLen > 0 {
                                                            try sinfReader.skipBytes(skipLen)
                                                        }
                                                    }
                                                    if handlerType == "soun" {
                                                    // AudioSampleEntry: channelcount @ offset 16, samplerate @ offset 24 (16.16 fixed)
                                                    if entryData.count >= 28 {
                                                        let ch = entryData[16..<18].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                                                        channels = Int(ch)
                                                        let srFixed = entryData[24..<28].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                                                        sampleRateValue = Int(srFixed >> 16)
                                                    }
                                                } else if handlerType == "vide" {
                                                    // VideoSampleEntry: look for avcC or hvcC atom for codec details
                                                    var nestedReader = MP4ByteReader(data: entryData)
                                                    while nestedReader.bytesLeft > 8 {
                                                        let nestedSize = try nestedReader.readUInt32()
                                                        let nestedType = try nestedReader.readAtomType()
                                                        if nestedType == "avcC" {
                                                            hdrType = "avcC"
                                                        } else if nestedType == "hvcC" {
                                                            hdrType = "hvcC"
                                                        }
                                                        let skip = Int(nestedSize) - 8
                                                        if skip > 0 {
                                                            try nestedReader.skipBytes(skip)
                                                        }
                                                    }
                                                }
                                                }
                                                break // only first entry
                                            }
                                        } catch {
                                            segmentInfo.issues.append("Error parsing stsd: \(error)")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        guard let tid = trackID, let handler = handlerType else {
            segmentInfo.issues.append("Track missing header (tkhd) or handler (hdlr).")
            return
        }
        // Assign track info based on handler type
        if handler == "vide" {
            let res = (width != nil && height != nil) ? Resolution(width: width!, height: height!) : nil
            segmentInfo.videoTrack = VideoTrackInfo(trackID: tid,
                                                   codec: codecStr ?? "unknown",
                                                   hdrType: hdrType,
                                                   resolution: res,
                                                   encrypted: encrypted)
        } else if handler == "soun" {
            segmentInfo.audioTrack = AudioTrackInfo(trackID: tid,
                                                   codec: codecStr ?? "unknown",
                                                   channels: channels,
                                                   sampleRate: sampleRateValue,
                                                   dolbyAtmos: false,
                                                   encrypted: encrypted)
        }
    }

    // Parse track header atom (tkhd) to extract trackID, width, and height
    private func parseTkhd(_ tkhd: MP4Atom) -> (UInt32, Int?, Int?)? {
        guard let data = tkhd.payload, data.count >= 8 else {
            return nil
        }
        let version = data[0]
        let base = 4
        var tid: UInt32?
        if version == 1 {
            let offset = base + 8 + 8
            if data.count >= offset + 4 {
                tid = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            }
        } else {
            let offset = base + 4 + 4
            if data.count >= offset + 4 {
                tid = data[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            }
        }
        // width and height are fixed-point 16.16 at end of box
        if data.count >= 8 {
            let wFixed = data[data.count-8..<data.count-4].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let hFixed = data[data.count-4..<data.count].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let w = Int(wFixed >> 16)
            let h = Int(hFixed >> 16)
            if let trackID = tid {
                return (trackID, w, h)
            }
        } else if let trackID = tid {
            return (trackID, nil, nil)
        }
        return nil
    }

    // Parse mdia atom to extract handler type (vide/soun) and codec from stsd
    private func parseMdia(_ mdia: MP4Atom) -> (String?, String?) {
        var handler: String?
        var codec: String?
        for child in mdia.children {
            if child.type == "hdlr", let payload = child.payload, payload.count >= 12 {
                let typeBytes = payload[8..<12]
                handler = String(data: typeBytes, encoding: .ascii)
            } else if child.type == "minf" {
                for minfChild in child.children {
                    if minfChild.type == "stbl" {
                        for stblChild in minfChild.children {
                            if stblChild.type == "stsd", let payload = stblChild.payload, payload.count >= 8 {
                                let entryCount = payload[4..<8].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
                                var cursor = 8
                                for _ in 0..<entryCount {
                                    if payload.count >= cursor + 8 {
                                        let typeData = payload[cursor+4..<cursor+8]
                                        codec = String(data: typeData, encoding: .ascii)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return (handler, codec)
    }
}
