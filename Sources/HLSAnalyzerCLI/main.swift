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
    
    /// Add a --json flag to allow JSON output
    @Flag(name: .long, help: "Output the analysis in JSON format instead of color-coded text.")
    var json: Bool = false
    
    func run() throws {
        // Intro logging (only shown in plain-text mode)
        if !json {
            print("HLS-Analyzer: Starting analysis for \(pathOrURL)")
        }
        
        let (content, bytesCount) = try fetchOrReadContent(pathOrURL: pathOrURL)
        
        if !json {
            print("Download complete. Bytes received: \(bytesCount)")
        }
        
        // Perform playlist analysis, returning a structured object with type + text summary
        let result = analyzePlaylist(content: content)
        
        if json {
            // 1) Encode the analysis result to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(result)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            // 2) Standard color-coded console output
            print(result.analysisText)
            print("Analysis complete.")
        }
    }
    
    // MARK: - Helper to fetch remote or local
    
    private func fetchOrReadContent(pathOrURL: String) throws -> (String, Int) {
        // Decide if it's remote http(s) or local path
        if let remoteURL = URL(string: pathOrURL),
           let scheme = remoteURL.scheme,
           ["http","https"].contains(scheme.lowercased()) {
            
            // Remote download
            if !json {
                print("Detected remote URL. Downloading...")
            }
            return try fetchRemoteManifest(from: remoteURL)
            
        } else {
            // Local file read
            if !json {
                print("Detected local file path. Reading...")
            }
            return try readLocalManifest(at: pathOrURL)
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
    
    // MARK: - Analyze the Playlist
    
    /// Returns both a structured result for JSON and a textual summary for normal output.
    private func analyzePlaylist(content: String) -> AnalysisResult {
        let playlistType = HLSAnalyzerCore.determinePlaylistType(from: content)
        
        switch playlistType {
        case .master:
            let masterAnalyzer = MasterPlaylistAnalyzer()
            let masterSummary = masterAnalyzer.analyze(content: content)
            return AnalysisResult(
                playlistType: "Master",
                analysisText: masterSummary
            )
            
        case .media:
            let mediaAnalyzer = MediaPlaylistAnalyzer()
            let mediaSummary = mediaAnalyzer.analyze(content: content)
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
    
    // MARK: - Data Structure for JSON Output
    
    /// Minimal container for analysis results
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
