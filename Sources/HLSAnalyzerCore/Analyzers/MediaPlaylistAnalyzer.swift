// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import Foundation

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
