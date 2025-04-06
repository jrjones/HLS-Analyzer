import Foundation

open class MediaPlaylistAnalyzer: Analyzer {
    
public func analyze(content: String) -> String {
        let playlist = SimpleHLSParser.parseMediaPlaylist(content)
        
        var summary = "\(ANSI.white)[Media Playlist Summary]\(ANSI.reset)\n"
        
        if let targetDuration = playlist.targetDuration {
            summary += "\(ANSI.yellow)Target Duration:\(ANSI.reset) \(ANSI.green)\(targetDuration)\(ANSI.reset)\n"
        }
        summary += "Segments: \(playlist.segments.count)\n\n"
        
        // List segments, etc.
        for (i, seg) in playlist.segments.enumerated() {
            summary += "\(ANSI.white)Segment \(i + 1):\(ANSI.reset) "
            summary += "\(ANSI.yellow)duration=\(ANSI.reset)\(ANSI.green)\(seg.duration)\(ANSI.reset)"
            if let uri = seg.uri {
                summary += ", \(ANSI.yellow)uri=\(ANSI.reset)\(ANSI.blue)\(uri)\(ANSI.reset)"
            }
            summary += "\n"
        }
        
        // CMAF checks
        summary += validateCMAF(content: content)
        
        // AD MARKER checks
        let adAnalyzer = AdMarkersAnalyzer()
        let (adSummary, _) = adAnalyzer.analyzeAdMarkers(in: content)
        summary += adSummary
        
        // Return combined result
        return summary
    }    
    // MARK: - CMAF Validation
    
    public func validateCMAF(content: String) -> String {
        var cmafSummary = ""
        
        // Decide if segments appear to be CMAF/fMP4
        let isLikelyCMAF = content.contains(".m4s") || content.contains(".mp4") || content.contains("#EXT-X-MAP")
        guard isLikelyCMAF else { return cmafSummary }
        
        cmafSummary += "\n\(ANSI.white)CMAF Validation:\(ANSI.reset)\n"
        
        // #EXT-X-MAP required
        if !content.contains("#EXT-X-MAP") {
            cmafSummary += "\(ANSI.red)❌ Missing #EXT-X-MAP tag (required for CMAF fMP4)\(ANSI.reset)\n"
        } else {
            cmafSummary += "\(ANSI.green)✅ #EXT-X-MAP found.\(ANSI.reset)\n"
        }
        
        // #EXT-X-INDEPENDENT-SEGMENTS recommended
        if !content.contains("#EXT-X-INDEPENDENT-SEGMENTS") {
            cmafSummary += "\(ANSI.yellow)⚠️  Missing #EXT-X-INDEPENDENT-SEGMENTS (recommended for CMAF)\(ANSI.reset)\n"
        } else {
            cmafSummary += "\(ANSI.green)✅ #EXT-X-INDEPENDENT-SEGMENTS present.\(ANSI.reset)\n"
        }
        
        // #EXT-X-VERSION >= 7 for CMAF
        let versionPrefix = "#EXT-X-VERSION:"
        if let versionLine = content.components(separatedBy: .newlines)
            .first(where: { $0.hasPrefix(versionPrefix) }) {
            
            let ver = versionLine.dropFirst(versionPrefix.count).trimmingCharacters(in: .whitespaces)
            if let verInt = Int(ver), verInt < 7 {
                cmafSummary += "\(ANSI.red)❌ #EXT-X-VERSION is \(verInt), CMAF typically requires >= 7.\(ANSI.reset)\n"
            } else {
                cmafSummary += "\(ANSI.green)✅ Playlist version appears CMAF-compatible.\(ANSI.reset)\n"
            }
        } else {
            cmafSummary += "\(ANSI.yellow)⚠️  #EXT-X-VERSION not found. CMAF typically requires version >= 7.\(ANSI.reset)\n"
        }
        
        return cmafSummary
    }
}
