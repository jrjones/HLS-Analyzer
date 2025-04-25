// HLS Analyzer: Robust attribute parser for HLS tags
// Parses comma-separated key=value pairs, values may be quoted and contain commas
import Foundation

public struct AttributeParser {
    /// Parse an attribute string like 'BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401f"'
    /// Values retain surrounding quotes if present.
    /// Splits on commas not enclosed in quotes.
    public static func parse(_ input: String) -> [String: String] {
        var result: [String: String] = [:]
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        for char in input {
            if char == "\"" { // toggle on quote
                inQuotes.toggle()
                current.append(char)
            } else if char == "," && !inQuotes {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            parts.append(current)
        }
        for part in parts {
            let kv = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces).uppercased()
            let val = kv[1].trimmingCharacters(in: .whitespaces)
            result[key] = val
        }
        return result
    }
}