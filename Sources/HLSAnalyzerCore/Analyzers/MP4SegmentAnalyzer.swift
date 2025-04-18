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
        segmentInfo.issues.append(contentsOf: result.issues)

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
}
