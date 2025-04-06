import Foundation

/// A struct to represent an ad marker found in the playlist.
public struct AdMarker {
    public enum MarkerType {
        case discontinuity
        case dateRange
        case cueOut
        case cueIn
    }
    
    public var type: MarkerType
    public var rawLine: String
    public var segmentIndex: Int?  // if we can track which segment it belongs to
    public var attributes: [String: String] = [:]  // for #EXT-X-DATERANGE, etc.
}

/// This analyzer inspects ad markers (SSAI, SGAI, or older style).
open class AdMarkersAnalyzer: Analyzer {
    
    /// Analyze a media playlist's text for ad markers:
    /// - Returns a summary (String) plus an array of detected ad markers
    public func analyzeAdMarkers(in content: String) -> (summary: String, markers: [AdMarker]) {
        var summary = ""
        var markers: [AdMarker] = []
        
        // Split lines
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // We'll track the "current segment index" for #EXTINF lines
        var segmentIndex = -1
        
        for (i, line) in lines.enumerated() {
            if line.hasPrefix("#EXTINF:") {
                segmentIndex += 1
            }
            else if line.hasPrefix("#EXT-X-DISCONTINUITY") {
                // Classic SSAI or content changes
                let marker = AdMarker(type: .discontinuity, rawLine: line, segmentIndex: segmentIndex)
                markers.append(marker)
            }
            else if line.hasPrefix("#EXT-X-CUE-OUT") {
                let marker = AdMarker(type: .cueOut, rawLine: line, segmentIndex: segmentIndex)
                markers.append(marker)
            }
            else if line.hasPrefix("#EXT-X-CUE-IN") {
                let marker = AdMarker(type: .cueIn, rawLine: line, segmentIndex: segmentIndex)
                markers.append(marker)
            }
            else if line.hasPrefix("#EXT-X-DATERANGE:") {
                // SGAI / Interstitial approach
                let attributeString = String(line.dropFirst("#EXT-X-DATERANGE:".count))
                let attrs = parseAttributes(attributeString)
                
                var marker = AdMarker(type: .dateRange, rawLine: line, segmentIndex: segmentIndex)
                marker.attributes = attrs
                markers.append(marker)
            }
        }
        
        if markers.isEmpty {
            // No ad markers found
            return ("", [])
        }
        
        // Summarize the discovered markers
        summary += "\n\(ANSI.white)Ad Marker Detection:\(ANSI.reset)\n"
        var usedDiscontinuity = false
        var usedDateRange = false
        var usedCueOutIn = false
        
        for marker in markers {
            switch marker.type {
            case .discontinuity:
                usedDiscontinuity = true
                summary += "\(ANSI.cyan)Found #EXT-X-DISCONTINUITY at segment index \(marker.segmentIndex ?? -1)\(ANSI.reset)\n"
            case .dateRange:
                usedDateRange = true
                let classAttr = marker.attributes["CLASS"] ?? "(none)"
                summary += "\(ANSI.cyan)Found #EXT-X-DATERANGE at segment index \(marker.segmentIndex ?? -1), CLASS=\(classAttr)\(ANSI.reset)\n"
                if let scte = marker.attributes["SCTE35-OUT"], !scte.isEmpty {
                    summary += "  \(ANSI.yellow)SCTE35-OUT:\(ANSI.reset) \(scte)\n"
                }
            case .cueOut:
                usedCueOutIn = true
                summary += "\(ANSI.cyan)Found #EXT-X-CUE-OUT at segment index \(marker.segmentIndex ?? -1)\(ANSI.reset)\n"
            case .cueIn:
                usedCueOutIn = true
                summary += "\(ANSI.cyan)Found #EXT-X-CUE-IN at segment index \(marker.segmentIndex ?? -1)\(ANSI.reset)\n"
            }
        }
        
        // Summarize type of ad insertion
        summary += "\n\(ANSI.white)Ad Insertion Type Detected:\(ANSI.reset) "
        var types = [String]()
        if usedDiscontinuity { types.append("SSAI (discontinuity-based)") }
        if usedDateRange { types.append("SGAI / Interstitial (#EXT-X-DATERANGE)") }
        if usedCueOutIn { types.append("Cue Out/In Markers") }
        
        if types.isEmpty {
            summary += "\(ANSI.yellow)None\(ANSI.reset)\n"
        } else {
            summary += "\(ANSI.green)\(types.joined(separator: ", "))\(ANSI.reset)\n"
        }
        
        return (summary, markers)
    }
    
    // Simple attribute parser
    private func parseAttributes(_ line: String) -> [String: String] {
        var result: [String : String] = [:]
        let items = line.split(separator: ",")
        for item in items {
            let kv = item.split(separator: "=", maxSplits: 1).map { String($0) }
            if kv.count == 2 {
                let key = kv[0].uppercased().trimmingCharacters(in: .whitespaces)
                let val = kv[1].trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                result[key] = val
            }
        }
        return result
    }
}
