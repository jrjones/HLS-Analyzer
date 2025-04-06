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
    
    func run() throws {
        print("HLS-Analyzer: Starting analysis for \(pathOrURL)")
        
        // Determine if it's a remote URL or local file
        if let remoteURL = URL(string: pathOrURL),
           let scheme = remoteURL.scheme,
           ["http","https"].contains(scheme.lowercased()) {
            
            print("Detected remote URL. Downloading...")
            let (content, bytesCount) = try fetchRemoteManifest(from: remoteURL)
            print("Download complete. Bytes received: \(bytesCount)")
            
            analyzePlaylist(content: content)
        } else {
            print("Detected local file path. Reading...")
            let (content, bytesCount) = try readLocalManifest(at: pathOrURL)
            print("File read complete. Bytes read: \(bytesCount)")
            
            analyzePlaylist(content: content)
        }
    }
    
    // MARK: - Analyze
    
    private func analyzePlaylist(content: String) {
        let playlistType = HLSAnalyzerCore.determinePlaylistType(from: content)
        switch playlistType {
        case .master:
            print("Playlist type detected: Master (Multivariant)")
            let masterAnalyzer = MasterPlaylistAnalyzer()
            let masterSummary = masterAnalyzer.analyze(content: content)
            print(masterSummary)
            
        case .media:
            print("Playlist type detected: Media (Variant)")
            let mediaAnalyzer = MediaPlaylistAnalyzer()
            let mediaSummary = mediaAnalyzer.analyze(content: content)
            print(mediaSummary)
            
        case .unknown:
            print("Playlist type detected: Unknown")
        }
        
        print("Analysis complete.")
    }
    
    // MARK: - Fetching / Reading
    
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
