import Foundation

open class MasterPlaylistAnalyzer: Analyzer {

    public func analyze(content: String, useANSI: Bool = true) -> String {
        // Example color references if useANSI is true
        let Y = useANSI ? ANSI.yellow : ""
        let G = useANSI ? ANSI.green : ""
        let B = useANSI ? ANSI.blue : ""
        let R = useANSI ? ANSI.red : ""
        let W = useANSI ? ANSI.white : ""
        let Reset = useANSI ? ANSI.reset : ""
        
        let master = SimpleHLSParser.parseMasterPlaylist(content)

        var summary = "\(W)[Master Playlist Summary]\(Reset)\n"
        summary += "Found \(master.variantStreams.count) variant streams.\n\n"
        
        for (i, stream) in master.variantStreams.enumerated() {
            summary += "\(W)Variant \(i + 1):\(Reset)\n"
            
            if let bw = stream.bandwidth {
                summary += "  \(Y)BANDWIDTH:\(Reset) \(G)\(bw)\(Reset)\n"
            } else {
                summary += "  \(R)❌ Missing BANDWIDTH\(Reset)\n"
            }
            
            if let res = stream.resolution {
                summary += "  \(Y)RESOLUTION:\(Reset) \(G)\(res.width)x\(res.height)\(Reset)\n"
            } else {
                summary += "  \(R)❌ Missing RESOLUTION\(Reset)\n"
            }
            
            if let codecs = stream.codecs {
                summary += "  \(Y)CODECS:\(Reset) \(G)\(codecs)\(Reset)\n"
            } else {
                summary += "  \(R)❌ Missing CODECS\(Reset)\n"
            }
            
            if let uri = stream.uri {
                summary += "  \(Y)URI:\(Reset) \(B)\(uri)\(Reset)\n"
            }
            summary += "\n"
        }
        
        summary += validateVariants(master.variantStreams, useANSI: useANSI)
        
        if !master.renditionGroups.isEmpty {
            summary += "\(W)Renditions:\(Reset)\n"
            for (j, group) in master.renditionGroups.enumerated() {
                summary += "  \(W)Rendition \(j + 1):\(Reset) "
                summary += "GROUP-ID=\(G)\(group.groupID)\(Reset), "
                summary += "TYPE=\(G)\(group.type ?? "")\(Reset), "
                if let uri = group.uri {
                    summary += "URI=\(B)\(uri)\(Reset)"
                }
                summary += "\n"
            }
        }
        
        return summary
    }
    
    private func validateVariants(_ variants: [VariantStream], useANSI: Bool) -> String {
        let Y = useANSI ? ANSI.yellow : ""
        let G = useANSI ? ANSI.green : ""
        let W = useANSI ? ANSI.white : ""
        let Reset = useANSI ? ANSI.reset : ""
        
        var warnings = ""
        
        let nonNilVariants = variants.filter { $0.resolution != nil }
        let groupedByRes = Dictionary(grouping: nonNilVariants, by: { $0.resolution! })
        
        for (res, streams) in groupedByRes {
            if streams.count > 1 {
                let bws = streams.compactMap { $0.bandwidth }.sorted()
                if bws.count > 1 {
                    let minBW = bws.first!
                    let maxBW = bws.last!
                    if maxBW - minBW < 50000 {
                        warnings += "\(Y)⚠️ Variants with resolution \(res.width)x\(res.height) have nearly identical bandwidth. Possibly redundant.\(Reset)\n"
                    }
                }
            }
        }
        
        if !warnings.isEmpty {
            warnings = "\n\(W)Variant Validation Warnings:\(Reset)\n" + warnings
        }
        
        return warnings
    }
}
