// HLS Analyzer: Analyzer protocol to unify playlist analyzers
import Foundation

/// Protocol for analyzing playlist content into textual summaries.
public protocol PlaylistAnalyzer {
    /// Analyze the given playlist content.
    /// - Parameters:
    ///   - content: The raw playlist text.
    ///   - useANSI: Whether to include ANSI color codes and emojis.
    ///   - sourceURL: Optional base URL for resolving relative segment URIs.
    /// - Returns: A textual summary of the analysis.
    func analyze(content: String, useANSI: Bool, sourceURL: URL?) -> String
}