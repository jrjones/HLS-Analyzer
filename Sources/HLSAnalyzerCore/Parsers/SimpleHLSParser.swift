import Foundation

public enum SimpleHLSParser {
    
    public static func parseMasterPlaylist(_ content: String) -> MasterPlaylist {
        var master = MasterPlaylist()
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                let attributes = String(line.dropFirst("#EXT-X-STREAM-INF:".count))
                let parsedAttrs = parseAttributes(from: attributes)
                
                // Next line typically the URI
                let nextIndex = index + 1
                var uriLine: String? = nil
                if nextIndex < lines.count, !lines[nextIndex].hasPrefix("#") {
                    uriLine = lines[nextIndex]
                }
                
                var variant = VariantStream()
                variant.bandwidth = intValue(parsedAttrs["BANDWIDTH"])
                variant.codecs = parsedAttrs["CODECS"]
                if let resString = parsedAttrs["RESOLUTION"] {
                    let comps = resString.split(separator: "x")
                    if comps.count == 2,
                       let w = Int(comps[0]),
                       let h = Int(comps[1]) {
                        variant.resolution = (w, h)
                    }
                }
                variant.uri = uriLine
                master.variantStreams.append(variant)
            }
            else if line.hasPrefix("#EXT-X-MEDIA:") {
                let attributes = String(line.dropFirst("#EXT-X-MEDIA:".count))
                let attrs = parseAttributes(from: attributes)
                
                guard let groupID = attrs["GROUP-ID"]?.replacingOccurrences(of: "\"", with: "") else { continue }
                var rendition = RenditionGroup(groupID: groupID)
                rendition.type = attrs["TYPE"]?.replacingOccurrences(of: "\"", with: "")
                rendition.name = attrs["NAME"]?.replacingOccurrences(of: "\"", with: "")
                rendition.uri = attrs["URI"]?.replacingOccurrences(of: "\"", with: "")
                
                master.renditionGroups.append(rendition)
            }
        }
        
        return master
    }
    
    public static func parseMediaPlaylist(_ content: String) -> MediaPlaylist {
        var playlist = MediaPlaylist()
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                let value = line.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                playlist.targetDuration = Int(value)
            }
            else if line.hasPrefix("#EXTINF:") {
                let extinfPart = String(line.dropFirst("#EXTINF:".count))
                let durationStr = extinfPart.split(separator: ",").first.map(String.init) ?? "0"
                
                let nextIndex = index + 1
                var segmentURI: String? = nil
                if nextIndex < lines.count, !lines[nextIndex].hasPrefix("#") {
                    segmentURI = lines[nextIndex]
                }
                
                let duration = Double(durationStr) ?? 0.0
                let seg = MediaSegment(duration: duration, uri: segmentURI)
                playlist.segments.append(seg)
            }
        }
        
        return playlist
    }
    
    private static func parseAttributes(from attributeString: String) -> [String: String] {
        var attributes: [String: String] = [:]
        let parts = attributeString.split(separator: ",").map(String.init)
        
        for part in parts {
            let kv = part.split(separator: "=")
            guard kv.count == 2 else { continue }
            let key = kv[0].uppercased().trimmingCharacters(in: .whitespaces)
            let val = kv[1].trimmingCharacters(in: .whitespaces)
            attributes[key] = val
        }
        
        return attributes
    }
    
    private static func intValue(_ str: String?) -> Int? {
        guard let s = str else { return nil }
        return Int(s.replacingOccurrences(of: "\"", with: ""))
    }
}
