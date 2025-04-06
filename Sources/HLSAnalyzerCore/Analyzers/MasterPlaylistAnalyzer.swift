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
            } else {
                summary += "  \(ANSI.red)❌ Missing BANDWIDTH\(ANSI.reset)\n"
            }
            if let res = stream.resolution {
                summary += "  \(ANSI.yellow)RESOLUTION:\(ANSI.reset) \(ANSI.green)\(res.width)x\(res.height)\(ANSI.reset)\n"
            }
            if let codecs = stream.codecs {
                summary += "  \(ANSI.yellow)CODECS:\(ANSI.reset) \(ANSI.green)\(codecs)\(ANSI.reset)\n"
            } else {
                summary += "  \(ANSI.red)❌ Missing CODECS\(ANSI.reset)\n"
            }
            if let uri = stream.uri {
                summary += "  \(ANSI.yellow)URI:\(ANSI.reset) \(ANSI.blue)\(uri)\(ANSI.reset)\n"
            }
            summary += "\n"
        }
        
        // Check for conflicts (for example, do multiple variants have the same resolution but very different bandwidth?)
        summary += validateVariants(master.variantStreams)
        
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
    
    // MARK: - Variant Validation
    
    private func validateVariants(_ variants: [VariantStream]) -> String {
        var warnings = ""
        
        // Simple logic: if multiple variants share the same resolution but have extremely close or identical bandwidth, issue a warning.
        // Or if one is drastically higher bandwidth than another of the same resolution, also warn.
        
        // Group by resolution to compare
        let groupedByRes = Dictionary(grouping: variants) { $0.resolution }
        
        for (res, streams) in groupedByRes {
            guard res != nil, streams.count > 1 else { continue }
            // Compare bandwidth across these streams
            var bandwidths = streams.compactMap { $0.bandwidth }.sorted()
            if bandwidths.count <= 1 { continue }
            
            let minBW = bandwidths.first!
            let maxBW = bandwidths.last!
            // If min and max are too close or identical, might be pointless variants
            if maxBW - minBW < 50000 { // e.g. less than 50K difference
                warnings += "\(ANSI.yellow)⚠️ Variants with resolution \(res!.0)x\(res!.1) have nearly identical bandwidths. Possibly redundant.\(ANSI.reset)\n"
            }
        }
        
        if !warnings.isEmpty {
            warnings = "\n\(ANSI.white)Variant Validation Warnings:\(ANSI.reset)\n" + warnings
        }
        return warnings
    }
}
