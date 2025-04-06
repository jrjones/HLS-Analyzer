// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import Foundation

open class HLSAnalyzerCore: Analyzer {
    
    public enum PlaylistType {
        case master
        case media
        case unknown
    }
    
    /// Determine if the content is Master or Media playlist
    public static func determinePlaylistType(from content: String) -> PlaylistType {
        if content.contains("#EXT-X-STREAM-INF") {
            return .master
        } else if content.contains("#EXTINF") {
            return .media
        } else {
            return .unknown
        }
    }
}
