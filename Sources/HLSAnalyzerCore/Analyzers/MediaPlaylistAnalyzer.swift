open class MediaPlaylistAnalyzer: Analyzer {
    public func analyze(content: String) -> String {
        let playlist = SimpleHLSParser.parseMediaPlaylist(content)
        
        var summary = "\(ANSI.white)[Media Playlist Summary]\(ANSI.reset)\n"
        
        if let targetDuration = playlist.targetDuration {
            summary += "\(ANSI.yellow)Target Duration:\(ANSI.reset) \(ANSI.green)\(targetDuration)\(ANSI.reset)\n"
        }
        summary += "Segments: \(playlist.segments.count)\n\n"
        
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
        
        // AD markers
        let adAnalyzer = AdMarkersAnalyzer()
        let (adSummary, _) = adAnalyzer.analyzeAdMarkers(in: content)
        summary += adSummary
        
        // ** NEW: check for #EXT-X-ENDLIST if not live/event
        if !content.contains("#EXT-X-PLAYLIST-TYPE:LIVE") && !content.contains("#EXT-X-PLAYLIST-TYPE:EVENT") {
            if !content.contains("#EXT-X-ENDLIST") {
                summary += "\(ANSI.red)❌ Warning: Missing #EXT-X-ENDLIST. This might be a VOD missing the end tag.\(ANSI.reset)\n"
            }
        }
        
        return summary
    }
    
    // ... existing validateCMAF function ...
}
