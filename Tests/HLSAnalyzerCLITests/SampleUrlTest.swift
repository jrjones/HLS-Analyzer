import XCTest
import Foundation

final class SampleUrlTest: XCTestCase {
    
    func testSampleUrls() throws {
        let fm = FileManager.default
        let currentPath = fm.currentDirectoryPath
        
        // Look for 'Samples/urls.txt'
        let urlsFileURL = URL(fileURLWithPath: currentPath).appendingPathComponent("Samples/urls.txt")
        guard fm.fileExists(atPath: urlsFileURL.path) else {
            XCTFail("Could not find Samples/urls.txt at \(urlsFileURL.path)")
            return
        }
        
        let fileContent = try String(contentsOf: urlsFileURL, encoding: .utf8)
        let lines = fileContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else {
            XCTFail("Samples/urls.txt is empty.")
            return
        }
        
        // The results file in the home directory
        let homeDirURL = fm.homeDirectoryForCurrentUser
        let resultsFileURL = homeDirURL.appendingPathComponent("hls-analyzer-results.txt")
        
        for urlString in lines {
            let (output, errorOut) = try runHlsAnalyzer(urlString: urlString)
            
            // Prepend new entry to results
            let timestamp = ISO8601DateFormatter().string(from: Date())
            var newEntry = "[\(timestamp)] URL: \(urlString)\n"
            newEntry += output
            newEntry += "\n---\n"
            
            if let oldContents = try? String(contentsOf: resultsFileURL, encoding: .utf8) {
                newEntry += oldContents
            }
            
            try newEntry.write(to: resultsFileURL, atomically: true, encoding: .utf8)
            
            // Fail if there's any stderr output
            if !errorOut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                XCTFail("CLI wrote to stderr:\n\(errorOut)")
            }
        }
        
        // If we reach here, we pass
        XCTAssertTrue(true, "Sample URLs tested with no CLI errors.")
    }
    
    private func runHlsAnalyzer(urlString: String) throws -> (String, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "hls-analyzer", urlString]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputStr = String(data: outputData, encoding: .utf8) ?? ""
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorStr = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "SampleUrlTest",
                          code: Int(process.terminationStatus),
                          userInfo: [
                            NSLocalizedDescriptionKey: 
                              "hls-analyzer exited with code \(process.terminationStatus). stderr: \(errorStr)"
                          ])
        }
        
        return (outputStr, errorStr)
    }
}
