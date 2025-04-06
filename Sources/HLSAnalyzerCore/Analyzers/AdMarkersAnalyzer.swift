import Foundation

public struct AdMarker {
    public enum MarkerType {
        case discontinuity
        case dateRange
        case cueOut
        case cueIn
    }
    
    public var type: MarkerType
    public var rawLine: String
    public var segmentIndex: Int?
    public var attributes: [String: String] = [:]
}

open class AdMarkersAnalyzer: Analyzer {
    
    public func analyzeAdMarkers(in content: String, useANSI: Bool = true) -> (summary: String, markers: [AdMarker]) {
        // Removed R entirely, or do `_ = useANSI ? ANSI.red : ""`
        let C = useANSI ? ANSI.cyan : ""
        let Y = useANSI ? ANSI.yellow : ""
        let G = useANSI ? ANSI.green : ""
        let W = useANSI ? ANSI.white : ""
        let Reset = useANSI ? ANSI.reset : ""
        
        var summary = ""
        var markers: [AdMarker] = []
        
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        var segmentIndex = -1
        
        // If we don't use (i, line), do (_, line)
        for (_, line) in lines.enumerated() {
            if line.hasPrefix("#EXTINF:") {
                segmentIndex += 1
            }
            else if line.hasPrefix("#EXT-X-DISCONTINUITY") {
                markers.append(AdMarker(type: .discontinuity, rawLine: line, segmentIndex: segmentIndex))
            }
            else if line.hasPrefix("#EXT-X-CUE-OUT") {
                markers.append(AdMarker(type: .cueOut, rawLine: line, segmentIndex: segmentIndex))
            }
            else if line.hasPrefix("#EXT-X-CUE-IN") {
                markers.append(AdMarker(type: .cueIn, rawLine: line, segmentIndex: segmentIndex))
            }
            else if line.hasPrefix("#EXT-X-DATERANGE:") {
                let attrString = String(line.dropFirst("#EXT-X-DATERANGE:".count))
                let attrs = parseAttributes(attrString)
                var marker = AdMarker(type: .dateRange, rawLine: line, segmentIndex: segmentIndex)
                marker.attributes = attrs
                markers.append(marker)
            }
        }
        
        if markers.isEmpty {
            return ("", [])
        }
        
        summary += "\n\(W)Ad Marker Detection:\(Reset)\n"
        
        var usedDiscontinuity = false
        var usedDateRange = false
        var usedCueOutIn = false
        
        for marker in markers {
            switch marker.type {
            case .discontinuity:
                usedDiscontinuity = true
                summary += "\(C)🕺 #EXT-X-DISCONTINUITY at segment index \(marker.segmentIndex ?? -1)\(Reset)\n"
            case .dateRange:
                usedDateRange = true
                let classAttr = marker.attributes["CLASS"] ?? "(none)"
                summary += "\(C)Found #EXT-X-DATERANGE at segment index \(marker.segmentIndex ?? -1), CLASS=\(classAttr)\(Reset)\n"
            case .cueOut:
                usedCueOutIn = true
                summary += "\(C)Found #EXT-X-CUE-OUT at segment index \(marker.segmentIndex ?? -1)\(Reset)\n"
            case .cueIn:
                usedCueOutIn = true
                summary += "\(C)Found #EXT-X-CUE-IN at segment index \(marker.segmentIndex ?? -1)\(Reset)\n"
            }
        }
        
        summary += "\n\(W)Ad Insertion Type Detected:\(Reset) "
        var types = [String]()
        if usedDiscontinuity { types.append("SSAI (discontinuity-based)") }
        if usedDateRange { types.append("SGAI / Interstitial (#EXT-X-DATERANGE)") }
        if usedCueOutIn { types.append("Cue Out/In Markers") }
        
        if types.isEmpty {
            summary += "\(Y)None\(Reset)\n"
        } else {
            summary += "\(G)\(types.joined(separator: ", "))\(Reset)\n"
        }
        
        return (summary, markers)
    }
    
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
