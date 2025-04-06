// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import Foundation

open class DRMAnalyzer: Analyzer {
    
    public func analyzeDRM(in content: String) -> String {
        let keyLines = content.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("#EXT-X-KEY:") }
        
        guard !keyLines.isEmpty else {
            return ""
        }
        
        var output = "\n\(ANSI.white)DRM Analysis:\(ANSI.reset)\n"
        
        for line in keyLines {
            // Insert the lock emoji
            output += "\(ANSI.green)🔐 #EXT-X-KEY found.\(ANSI.reset)\n"
            // Then parse METHOD, URI, KEYFORMAT, etc. if you want more detail
        }
        
        return output
    }
}
