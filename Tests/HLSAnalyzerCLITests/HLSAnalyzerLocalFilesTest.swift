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

            // Basic check: ensure we mention "Analysis complete."
            XCTAssertTrue(
                output.contains("Analysis complete."),
                "Output for \(filename) should have 'Analysis complete.'"
            )

            // Optional: check specific strings
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
                // Expect 🔐 if your DRM code is in place
                XCTAssertTrue(
                    output.contains("🔐"),
                    "Should emit a lock emoji for DRM detection in sample-drm-aes128"
                )
            case "sample-ad-discontinuity.m3u8":
                // Expect 🕺 for discontinuities
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

    /// Helper to run `swift run hls-analyzer <file>` on top-level `Samples/`
    private func runAnalyzerOnLocalFile(_ filename: String) throws -> String {
        let fm = FileManager.default
        let currentDir = fm.currentDirectoryPath

        // Step up from 'Tests/HLSAnalyzerCLITests' to 'Tests', and again to project root
        let rootDirURL = URL(fileURLWithPath: currentDir)
            .deletingLastPathComponent()  // up from HLSAnalyzerCLITests
            .deletingLastPathComponent()  // up from Tests

        let fileURL = rootDirURL.appendingPathComponent("Samples").appendingPathComponent(filename)

        guard fm.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "File not found: \(fileURL.path)"])
        }

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

        // Non-zero exit => fail
        if process.terminationStatus != 0 {
            throw NSError(domain: "HLSAnalyzerLocalFilesTest",
                          code: Int(process.terminationStatus),
                          userInfo: [
                            NSLocalizedDescriptionKey:
                              "CLI exited with code \(process.terminationStatus). Stderr:\n\(errorStr)"
                          ])
        }

        return outputStr
    }
}
