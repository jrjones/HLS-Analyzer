// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license
// Sources/HLSAnalyzerCLI/main.swift

import Foundation

public struct SegmentInfo: Codable {
    public var videoTrack: VideoTrackInfo?
    public var audioTrack: AudioTrackInfo?
    public var segmentDuration: Double?
    public var sizeBytes: Int
    public var issues: [String]
    
    // New: to hold MP4 structure if present
    public var mp4Structure: [MP4AtomSummary]?
    
    public init(sizeBytes: Int) {
        self.sizeBytes = sizeBytes
        self.issues = []
    }
}


public struct VideoTrackInfo: Codable {
    public let trackID: UInt32
    public let codec: String
    public let hdrType: String?
    public let resolution: Resolution?  // changed from tuple
    public let encrypted: Bool
}

public struct AudioTrackInfo: Codable {
    public let trackID: UInt32
    public let codec: String
    public let channels: Int?
    public let sampleRate: Int?
    public let dolbyAtmos: Bool
    public let encrypted: Bool
    // etc...
}

public struct MP4AtomSummary: Codable {
    public let type: String
    public let size: UInt64
    public let children: [MP4AtomSummary]
}
