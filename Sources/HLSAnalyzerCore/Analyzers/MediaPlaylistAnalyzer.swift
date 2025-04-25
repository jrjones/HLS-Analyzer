// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import Foundation
import Dispatch

open class MediaPlaylistAnalyzer: Analyzer {
    
    public func analyze(content: String, useANSI: Bool = true) -> String {
        let playlist = SimpleHLSParser.parseMediaPlaylist(content)
        
        let Y = useANSI ? ANSI.yellow : ""
        let G = useANSI ? ANSI.green : ""
        let B = useANSI ? ANSI.blue : ""
        let R = useANSI ? ANSI.red : ""
        let W = useANSI ? ANSI.white : ""
        let Reset = useANSI ? ANSI.reset : ""
        
        var summary = "\(W)[Media Playlist Summary]\(Reset)\n"
        
        if let targetDuration = playlist.targetDuration {
            summary += "\(Y)Target Duration:\(Reset) \(G)\(targetDuration)\(Reset)\n"
        }
        // Compute total of all EXTINF durations
        let totalDuration = playlist.segments.reduce(0.0) { sum, seg in sum + seg.duration }
        summary += "\(Y)Total Duration:\(Reset) \(G)\(String(format: "%.3f", totalDuration))\(Reset)\n"
        summary += "Segments: \(playlist.segments.count)\n\n"
        
        for (i, seg) in playlist.segments.enumerated() {
            summary += "\(W)Segment \(i + 1):\(Reset) "
            summary += "\(Y)duration=\(Reset)\(G)\(seg.duration)\(Reset)"
            if let uri = seg.uri {
                summary += ", \(Y)uri=\(Reset)\(B)\(uri)\(Reset)"
            }
            summary += "\n"
        }
        
        // CMAF checks
        summary += validateCMAF(content: content, useANSI: useANSI)
        
        // AD markers
        let adAnalyzer = AdMarkersAnalyzer()
        let (adSummary, _) = adAnalyzer.analyzeAdMarkers(in: content, useANSI: useANSI)
        summary += adSummary
        
        // If not a LIVE or EVENT, check #EXT-X-ENDLIST
        if !content.contains("#EXT-X-PLAYLIST-TYPE:LIVE") && !content.contains("#EXT-X-PLAYLIST-TYPE:EVENT") {
            if !content.contains("#EXT-X-ENDLIST") {
                summary += "\(R)❌ Warning: Missing #EXT-X-ENDLIST (might be VOD missing end tag)\(Reset)\n"
            }
        }
        
        return summary
    }
    
    /// Overload to include MP4 segment parsing for fMP4 segments using the playlist's base URL.
    public func analyze(content: String, useANSI: Bool = true, baseURL: URL?) -> String {
        // Base analysis (CMAF, ad markers, etc.)
        let baseSummary = analyze(content: content, useANSI: useANSI)
        // Only proceed if we have a base URL to resolve segments
        guard let baseURL = baseURL else { return baseSummary }
        // Parse playlist to collect fMP4 segment URLs
        let playlist = SimpleHLSParser.parseMediaPlaylist(content)
        var tasks: [(index: Int, uri: String, url: URL)] = []
        for (i, seg) in playlist.segments.enumerated() {
            guard let uri = seg.uri,
                  let rel = URL(string: uri, relativeTo: baseURL),
                  rel.path.lowercased().hasSuffix(".m4s") || rel.path.lowercased().hasSuffix(".mp4")
            else { continue }
            tasks.append((i, uri, rel.absoluteURL))
        }
        // If no fragmented-MP4 segments, return base summary
        guard !tasks.isEmpty else { return baseSummary }
        // Concurrently analyze each fMP4 segment
        let mp4Analyzer = MP4SegmentAnalyzer()
        var results: [(index: Int, uri: String, info: SegmentInfo)] = []
        let group = DispatchGroup()
        let syncQ = DispatchQueue(label: "mp4ResultsSync")
        for task in tasks {
            group.enter()
            DispatchQueue.global().async {
                let info = mp4Analyzer.analyzeSegment(url: task.url)
                syncQ.sync { results.append((task.index, task.uri, info)) }
                group.leave()
            }
        }
        group.wait()
        // Sort results by segment index
        results.sort { $0.index < $1.index }
        // Build fMP4 details
        var fMP4Details = ""
        let header = "[Segment-by-Segment fMP4 Analysis]"
        let H = useANSI ? ANSI.white : ""
        let R = useANSI ? ANSI.reset : ""
        let Y = useANSI ? ANSI.yellow : ""
        fMP4Details += "\n\(H)\(header)\(R)\n"
        for (idx, uri, info) in results {
            let B = useANSI ? ANSI.blue : ""
            let Y = useANSI ? ANSI.yellow : ""
            let G = useANSI ? ANSI.green : ""
            let RD = useANSI ? ANSI.red : ""
            fMP4Details += "\(B)Segment \(idx + 1) (\(uri)):\(R)\n"
            fMP4Details += "  \(Y)Size:\(R) \(info.sizeBytes) bytes\n"
            if info.issues.isEmpty {
                fMP4Details += "  \(G)No MP4 parse issues.\(R)\n"
            } else {
                for issue in info.issues {
                    fMP4Details += "  \(RD)❌ \(issue)\(R)\n"
                }
            }
            // Additional segment info: audio channels, sample rate, resolution, HDR box
            if let audio = info.audioTrack {
                fMP4Details += "  \(Y)Channels:\(R) \(G)\(audio.channels.map(String.init) ?? "N/A")\(R)\n"
                fMP4Details += "  \(Y)Sample Rate:\(R) \(G)\(audio.sampleRate.map { String($0) + " Hz" } ?? "N/A")\(R)\n"
            }
            if let video = info.videoTrack {
                if let res = video.resolution {
                    fMP4Details += "  \(Y)Resolution:\(R) \(G)\(res.width)x\(res.height)\(R)\n"
                }
                fMP4Details += "  \(Y)HDR Box:\(R) \(G)\(video.hdrType ?? "None")\(R)\n"
            }
            fMP4Details += "\n"
        }
        // Add an aggregated summary for video engineers
        let segmentCount = results.count
        let totalSize = results.reduce(0) { $0 + $1.info.sizeBytes }
        let avgSize = segmentCount > 0 ? totalSize / segmentCount : 0
        // Determine audio/video track characteristics from first segment with data
        let firstAudio = results.first { $0.info.audioTrack != nil }?.info.audioTrack
        let firstVideo = results.first { $0.info.videoTrack != nil }?.info.videoTrack
        // Encryption flags
        let audioEncrypted = results.contains { $0.info.audioTrack?.encrypted == true }
        let videoEncrypted = results.contains { $0.info.videoTrack?.encrypted == true }
        // Build summary text
        fMP4Details += "\(H)[Analysis Summary]\(R)\n"
        fMP4Details += "  \(Y)Segments:\(R) \(segmentCount)\n"
        fMP4Details += "  \(Y)Total Size:\(R) \(totalSize) bytes\n"
        fMP4Details += "  \(Y)Avg Segment Size:\(R) \(avgSize) bytes\n"
        if let td = playlist.targetDuration {
            fMP4Details += "  \(Y)Playlist Target Duration:\(R) \(td) seconds\n"
        }
        // Total duration from playlist EXTINF tags
        let extTotal = playlist.segments.reduce(0.0) { sum, seg in sum + seg.duration }
        let formattedExtTotal = String(format: "%.3f", extTotal)
        fMP4Details += "  \(Y)Total Playlist Duration (EXTINF):\(R) \(formattedExtTotal) seconds\n"
        if let audio = firstAudio {
            fMP4Details += "\n  \(Y)Audio Track Summary:\(R)\n"
            fMP4Details += "    Channels: \(audio.channels.map(String.init) ?? "N/A")\n"
            fMP4Details += "    Sample Rate: \(audio.sampleRate.map { String($0) + " Hz" } ?? "N/A")\n"
            fMP4Details += "    Encrypted: \(audioEncrypted ? "Yes" : "No")\n"
        }
        if let video = firstVideo {
            fMP4Details += "\n  \(Y)Video Track Summary:\(R)\n"
            if let res = video.resolution {
                fMP4Details += "    Resolution: \(res.width)x\(res.height)\n"
            }
            fMP4Details += "    HDR Box: \(video.hdrType ?? "None")\n"
            fMP4Details += "    Encrypted: \(videoEncrypted ? "Yes" : "No")\n"
        }
        // Combine and return
        return baseSummary + fMP4Details
    }
    
    private func validateCMAF(content: String, useANSI: Bool) -> String {
        let Y = useANSI ? ANSI.yellow : ""
        let G = useANSI ? ANSI.green : ""
        let R = useANSI ? ANSI.red : ""
        let Reset = useANSI ? ANSI.reset : ""
        
        var cmafSummary = ""
        
        let isLikelyCMAF = content.contains(".m4s") || content.contains(".mp4") || content.contains("#EXT-X-MAP")
        guard isLikelyCMAF else { return cmafSummary }
        
        cmafSummary += "\n\(Y)CMAF Validation:\(Reset)\n"
        
        if !content.contains("#EXT-X-MAP") {
            cmafSummary += "\(R)❌ Missing #EXT-X-MAP tag (required for CMAF fMP4)\(Reset)\n"
        } else {
            cmafSummary += "\(G)✅ #EXT-X-MAP found.\(Reset)\n"
        }
        
        if !content.contains("#EXT-X-INDEPENDENT-SEGMENTS") {
            cmafSummary += "\(Y)⚠️ Missing #EXT-X-INDEPENDENT-SEGMENTS (recommended for CMAF)\(Reset)\n"
        } else {
            cmafSummary += "\(G)✅ #EXT-X-INDEPENDENT-SEGMENTS present.\(Reset)\n"
        }
        
        let versionPrefix = "#EXT-X-VERSION:"
        if let versionLine = content.components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix(versionPrefix) }) {
            
            let verStr = versionLine.dropFirst(versionPrefix.count).trimmingCharacters(in: .whitespaces)
            if let verInt = Int(verStr), verInt < 7 {
                cmafSummary += "\(R)❌ #EXT-X-VERSION is \(verInt), CMAF typically requires >= 7.\(Reset)\n"
            } else {
                cmafSummary += "\(G)✅ Playlist version appears CMAF-compatible.\(Reset)\n"
            }
        } else {
            cmafSummary += "\(Y)⚠️ #EXT-X-VERSION not found. CMAF typically requires version >= 7.\(Reset)\n"
        }
        
        return cmafSummary
    }
}
// MARK: - PlaylistAnalyzer Conformance
extension MediaPlaylistAnalyzer: PlaylistAnalyzer {
    public func analyze(content: String, useANSI: Bool, sourceURL: URL?) -> String {
        // Use baseURL (sourceURL) to enable segment resolution if provided
        return analyze(content: content, useANSI: useANSI, baseURL: sourceURL)
    }
}
