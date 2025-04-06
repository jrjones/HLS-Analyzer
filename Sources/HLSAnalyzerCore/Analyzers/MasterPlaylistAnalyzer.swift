import Foundation

open class MasterPlaylistAnalyzer: Analyzer {
    
    public func analyze(content: String) -> String {
        let master = SimpleHLSParser.parseMasterPlaylist(content)
        
        var summary = "[Master Playlist Summary]\n"
        summary += "Found \(master.variantStreams.count) variant streams.\n\n"
        
        for (i, stream) in master.variantStreams.enumerated() {
            summary += "\(ANSI.white)Variant \(i + 1):\(ANSI.reset)\n"
            if let bw = stream.bandwidth {
                summary += "  \(ANSI.yellow)BANDWIDTH:\(ANSI.reset) \(ANSI.green)\(bw)\(ANSI.reset)\n"
            }
            if let res = stream.resolution {
                summary += "  \(ANSI.yellow)RESOLUTION:\(ANSI.reset) \(ANSI.green)\(res.width)x\(res.height)\(ANSI.reset)\n"
            }
            if let codecs = stream.codecs {
                summary += "  \(ANSI.yellow)CODECS:\(ANSI.reset) \(ANSI.green)\(codecs)\(ANSI.reset)\n"
            }
            if let uri = stream.uri {
                summary += "  \(ANSI.yellow)URI:\(ANSI.reset) \(ANSI.blue)\(uri)\(ANSI.reset)\n"
            }
            summary += "\n"
        }
        
        if !master.renditionGroups.isEmpty {
            summary += "\(ANSI.white)Renditions:\(ANSI.reset)\n"
            for (j, group) in master.renditionGroups.enumerated() {
                summary += "  \(ANSI.white)Rendition \(j + 1):\(ANSI.reset) "
                summary += "\(ANSI.yellow)GROUP-ID\(ANSI.reset)=\(ANSI.green)\(group.groupID)\(ANSI.reset), "
                summary += "\(ANSI.yellow)TYPE\(ANSI.reset)=\(ANSI.green)\(group.type ?? "")\(ANSI.reset), "
                if let uri = group.uri {
                    summary += "\(ANSI.yellow)URI\(ANSI.reset)=\(ANSI.blue)\(uri)\(ANSI.reset)"
                }
                summary += "\n"
            }
        }
        
        return summary
    }
}
