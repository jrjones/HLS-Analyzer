// File: Tests/HLSAnalyzerCLITests/HLSAnalyzerLocalFilesTest.swift

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

    /// A single test method that iterates through each sample file.
    /// You could also split them into separate methods if you prefer.
    func testLocalSampleFiles() throws {
        for filename in sampleFilenames {
            let output = try runAnalyzerOnLocalFile(filename)
            
            // Basic check: ensure we mention "Analysis complete."
            XCTAssertTrue(
                output.contains("Analysis complete."),
                "Output for \(filename) should end with 'Analysis complete.'"
            )
            
            // Optional: Check specific strings
            switch filename {
            case "sample-master.m3u8":
                XCTAssertTrue(
                    output.contains("Found 2 variant streams"),
                    "Should find 2 variants in sample-master"
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
                // We'll check for "🔐" after we add that code below
                // Meanwhile we can check "METHOD=AES-128" or "KEYFORMAT" if the DRM analyzer is active
                break
            case "sample-ad-discontinuity.m3u8":
                // We'll check for "🕺" after code changes, or look for "Found #EXT-X-DISCONTINUITY"
                break
            case "sample-ad-daterange.m3u8":
                // We'll check for #EXT-X-DATERANGE or "SGAI / Interstitial"
                break
            default:
                break
            }
        }
    }

    // Helper to run the CLI and capture output
    private func runAnalyzerOnLocalFile(_ filename: String) throws -> String {
        // 1) Build the full path
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath  // Typically the package root when `swift test` runs
        let fileURL = URL(fileURLWithPath: currentDir)
            .appendingPathComponent("Samples")
            .appendingPathComponent(filename)
        
        // 2) Check existence
        guard fm.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "File not found: \(fileURL.path)"])
        }

        // 3) Run `swift run hls-analyzer <filepath>`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "run", "hls-analyzer", fileURL.path]

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

        // If non-zero exit, fail
        if process.terminationStatus != 0 {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: Int(process.terminationStatus),
                          userInfo: [
                            NSLocalizedDescriptionKey:
                              "CLI exited with code \(process.terminationStatus). Stderr: \(errorStr)"
                          ])
        }

        // Return the CLI's combined output
        return outputStr
    }
}
