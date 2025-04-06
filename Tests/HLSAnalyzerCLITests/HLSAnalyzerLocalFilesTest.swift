import XCTest
import Foundation

final class HLSAnalyzerLocalFilesTest: XCTestCase {
    
    let sampleFilenames = [
        "sample-master.m3u8",
        "sample-media.m3u8",
        "sample-cmaf.m3u8",
        "sample-drm-aes128.m3u8",
        "sample-ad-discontinuity.m3u8",
        "sample-ad-daterange.m3u8"
    ]

    func testLocalSampleFiles() throws {
        for filename in sampleFilenames {
            let output = try runAnalyzerOnLocalFile(filename)
            
            // Basic check: ensure it prints "Analysis complete."
            XCTAssertTrue(
                output.contains("Analysis complete."),
                "Output for \(filename) should have 'Analysis complete.'"
            )
            
            // Optional content checks
            switch filename {
            case "sample-master.m3u8":
                XCTAssertTrue(
                    output.contains("Found 2 variant streams") || output.contains("variant streams"),
                    "Should find variants in sample-master"
                )
            case "sample-media.m3u8":
                XCTAssertTrue(
                    output.contains("Segments: 3"),
                    "Should list 3 segments in sample-media"
                )
            case "sample-cmaf.m3u8":
                XCTAssertTrue(
                    output.contains("CMAF Validation"),
                    "Should do CMAF checks for sample-cmaf"
                )
            case "sample-drm-aes128.m3u8":
                // Expect a lock emoji if DRM checks are in place
                XCTAssertTrue(
                    output.contains("🔐"),
                    "Should emit a lock emoji for DRM detection in sample-drm-aes128"
                )
            case "sample-ad-discontinuity.m3u8":
                // Expect a dancing emoji for discontinuities
                XCTAssertTrue(
                    output.contains("🕺"),
                    "Should emit a dancing emoji for discontinuities in sample-ad-discontinuity"
                )
            case "sample-ad-daterange.m3u8":
                XCTAssertTrue(
                    output.contains("EXT-X-DATERANGE") || output.contains("com.apple.hls.interstitial"),
                    "Should detect SGAI date range in sample-ad-daterange"
                )
            default:
                break
            }
        }
    }

    /// Runs the compiled CLI binary `.build/debug/hls-analyzer <file>`
    /// with a 15-second timeout to avoid any potential hanging.
    private func runAnalyzerOnLocalFile(_ filename: String) throws -> String {
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath
        
        // Step up two directories from 'Tests/HLSAnalyzerCLITests' to get project root
        let rootDirURL = URL(fileURLWithPath: currentDir)
            .deletingLastPathComponent()  // up from HLSAnalyzerCLITests
            .deletingLastPathComponent()  // up from Tests
        
        // Path to compiled CLI: .build/debug/hls-analyzer
        let analyzerExeURL = rootDirURL.appendingPathComponent(".build/debug/hls-analyzer")
        guard fm.fileExists(atPath: analyzerExeURL.path) else {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: 1,
                          userInfo: [
                            NSLocalizedDescriptionKey: "Compiled binary not found at \(analyzerExeURL.path)"
                          ])
        }

        // Locate the sample file
        let fileURL = rootDirURL
            .appendingPathComponent("Samples")
            .appendingPathComponent(filename)
        guard fm.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "File not found: \(fileURL.path)"])
        }

        // Setup the Process
        let process = Process()
        process.executableURL = analyzerExeURL
        process.arguments = [fileURL.path]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Launch in background queue so we can implement a timeout
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            do {
                try process.run()
            } catch {
                // If process.run() fails, pass the error along
            }
            process.waitUntilExit()
            semaphore.signal()
        }
        
        // Wait up to 15 seconds
        let timeout: DispatchTime = .now() + 15
        if semaphore.wait(timeout: timeout) == .timedOut {
            // Timed out => kill the process to avoid hanging test
            process.terminate()
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: 3,
                          userInfo: [
                            NSLocalizedDescriptionKey: "CLI hung; forcibly terminated after 15s"
                          ])
        }
        
        // Collect output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let outputStr = String(data: outputData, encoding: .utf8) ?? ""
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorStr = String(data: errorData, encoding: .utf8) ?? ""

        // If CLI returned non-zero, fail
        if process.terminationStatus != 0 {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: Int(process.terminationStatus),
                          userInfo: [
                            NSLocalizedDescriptionKey:
                              "hls-analyzer exited with code \(process.terminationStatus). Stderr:\n\(errorStr)"
                          ])
        }

        return outputStr
    }
}
