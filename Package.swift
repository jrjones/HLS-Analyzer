// swift-tools-version: 6.1
// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested 

import PackageDescription

let package = Package(
    name: "HLSAnalyzerCLI",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "HLSAnalyzerCore",
            targets: ["HLSAnalyzerCore"]
        ),
        .executable(
            name: "hls-analyzer",
            targets: ["HLSAnalyzerCLI"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.2.2"
        )
    ],
    targets: [
        // Core library
        .target(
            name: "HLSAnalyzerCore",
            dependencies: []
        ),
        
        // CLI executable
        .executableTarget(
            name: "HLSAnalyzerCLI",
            dependencies: [
                "HLSAnalyzerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        
        // Tests for core logic
        .testTarget(
            name: "HLSAnalyzerCoreTests",
            dependencies: ["HLSAnalyzerCore"],
            path: "Tests/HLSAnalyzerCoreTests"
        ),
        
        // CLI-related tests (SampleUrlTest, etc.)
        .testTarget(
            name: "HLSAnalyzerCLITests",
            dependencies: [],
            path: "Tests/HLSAnalyzerCLITests"
        )
    ]
)
