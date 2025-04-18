// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import Foundation
import ArgumentParser
import HLSAnalyzerCore

@main
struct HLSAnalyzerCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hls-analyzer",
        abstract: "HLS-Analyzer: A tool to fetch and analyze HLS playlist manifests from a URL or local file."
    )
    
    @Argument(
        help: """
        URL or local file path of the HLS playlist (master or media .m3u8).
        Examples:
          1) hls-analyzer https://example.com/playlist.m3u8
          2) hls-analyzer Samples/video.m3u8
        """
    )
    var pathOrURL: String
    
    /// Add a --json flag to allow JSON output (no ANSI color codes in the text).
    @Flag(name: .long, help: "Output the analysis in JSON format instead of color-coded text.")
    var json: Bool = false
    
    func run() throws {
        // Print an intro message in plain text mode
        if !json {
            print("HLS-Analyzer: Starting analysis for \(pathOrURL)")
        }
        
        // Fetch playlist content and determine its source URL (remote or local)
        let (content, bytesCount, sourceURL) = try fetchOrReadContent(pathOrURL: pathOrURL)
        
        if !json {
            print("Download complete. Bytes received: \(bytesCount)")
        }
        
        // Perform playlist analysis, returning a structured object
        // that includes both type info and the textual summary
        let result = analyzePlaylist(content: content, sourceURL: sourceURL)
        
        if json {
            // Encode the analysis result as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(result)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            // Print color-coded text
            print(result.analysisText)
            print("Analysis complete.")
        }
    }
    
    // MARK: - Fetch or Read
    
    /// Fetches the playlist from a remote URL or reads from a local file.
    /// Returns the content, byte count, and the source URL for resolving segment URIs.
    private func fetchOrReadContent(pathOrURL: String) throws -> (String, Int, URL) {
        // Decide if input is an http(s) URL or local file path
        if let remoteURL = URL(string: pathOrURL),
           let scheme = remoteURL.scheme,
           ["http","https"].contains(scheme.lowercased()) {
            
            // Remote download
            if !json {
                print("Detected remote URL. Downloading...")
            }
            let (content, bytesCount) = try fetchRemoteManifest(from: remoteURL)
            // Use playlist directory as base for relative segment URIs
            let baseURL = remoteURL.deletingLastPathComponent()
            return (content, bytesCount, baseURL)
            
        } else {
            // Local file read
            if !json {
                print("Detected local file path. Reading...")
            }
            let (content, bytesCount) = try readLocalManifest(at: pathOrURL)
            // Use file's parent directory as base for relative segment URIs
            let fileURL = URL(fileURLWithPath: pathOrURL)
            let baseURL = fileURL.deletingLastPathComponent()
            return (content, bytesCount, baseURL)
        }
    }
    
    private func fetchRemoteManifest(from url: URL) throws -> (content: String, bytesCount: Int) {
        let semaphore = DispatchSemaphore(value: 0)
        var playlistContent: String?
        var downloadError: Error?
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let err = error {
                downloadError = err
            } else if let data = data {
                playlistContent = String(data: data, encoding: .utf8)
            }
            semaphore.signal()
        }.resume()
        
        semaphore.wait()
        if let err = downloadError {
            throw RuntimeError("Failed to download playlist: \(err.localizedDescription)")
        }
        guard let content = playlistContent else {
            throw RuntimeError("No data received from URL: \(url)")
        }
        return (content, content.utf8.count)
    }
    
    private func readLocalManifest(at path: String) throws -> (content: String, bytesCount: Int) {
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw RuntimeError("Local file does not exist at path: \(path)")
        }
        let data = try Data(contentsOf: fileURL)
        guard let content = String(data: data, encoding: .utf8) else {
            throw RuntimeError("Failed to decode file as UTF-8 text: \(path)")
        }
        return (content, content.utf8.count)
    }
    
    // MARK: - Analyze
    
    /// Returns both a structured result for JSON and a textual summary (with optional ANSI).
    /// Analyze playlist content, using the sourceURL to resolve segment URIs when needed.
    private func analyzePlaylist(content: String, sourceURL: URL) -> AnalysisResult {
        let playlistType = HLSAnalyzerCore.determinePlaylistType(from: content)
        
        // We'll pass `useANSI: !json` to each analyzer, so color codes are only used in normal mode.
        switch playlistType {
        case .master:
            let masterAnalyzer = MasterPlaylistAnalyzer()
            let masterSummary = masterAnalyzer.analyze(content: content, useANSI: !json)
            return AnalysisResult(
                playlistType: "Master",
                analysisText: masterSummary
            )
            
        case .media:
            let mediaAnalyzer = MediaPlaylistAnalyzer()
            // Pass sourceURL so MP4 segments can be parsed
            let mediaSummary = mediaAnalyzer.analyze(content: content, useANSI: !json, baseURL: sourceURL)
            return AnalysisResult(
                playlistType: "Media",
                analysisText: mediaSummary
            )
            
        case .unknown:
            return AnalysisResult(
                playlistType: "Unknown",
                analysisText: "Playlist type detected: Unknown\n"
            )
        }
    }
    
    // MARK: - Data Structures
    
    /// Minimal container for analysis results (for JSON encoding).
    private struct AnalysisResult: Codable {
        let playlistType: String
        let analysisText: String
    }
}

// MARK: - Error Types

struct ValidationError: Error, CustomStringConvertible {
    var description: String
    init(_ message: String) { self.description = message }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    init(_ message: String) { self.description = message }
}
