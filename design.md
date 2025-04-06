# HLS-Analyzer: Design Document

## 1) Overview

**HLS-Analyzer** is a Swift CLI tool for analyzing HTTP Live Streaming 
(HLS) playlists. The project is structured as a **Swift Package** with 
a library (for core parsing and analysis) and a command-line executable 
(for user interaction). Key features:

 - **Master Playlist Analysis**: Summarizes variant streams, including 
   bandwidth, resolution, codecs, and URI.

 - **Media Playlist Analysis**: Checks target duration, segments, 
   CMAF compliance, ad markers, DRM tags, etc.

 - **Color-Coded Output**: In normal runs, color-coded lines draw 
   attention to warnings, errors, and key data.

 - **JSON Mode**: With a --json flag, it outputs a structured JSON 
   summary (no ANSI codes), allowing external tooling to parse results.

 - **Optional CMAF Checks**: Ensures #EXT-X-MAP, #EXT-X-INDEPENDENT-SEGMENTS, 
   and HLS version compliance for CMAF.

 - **DRM Detection**: Looks for #EXT-X-KEY tags, logs encryption method 
   (AES-128, etc.) with a lock emoji.

 - **Ad Marker Detection**: Recognizes #EXT-X-DISCONTINUITY (SSAI), 
   #EXT-X-DATERANGE (SGAI), #EXT-X-CUE-OUT/IN (cue markers). Prints a dancing emoji for discontinuities.

 - **Simple Unit Tests** for each analyzer, plus CLI tests running against 
   local or remote sample URLs.


## 2) Project Layout

The **Swift Package** (named HLSAnalyzerCLI) has two main products:

1. **Library**: HLSAnalyzerCore

2. **Executable**: hls-analyzer
    
```    
    HLS-Analyzer/
    ├── Package.swift
    ├── Sources/
    │   ├── HLSAnalyzerCLI/          (The CLI executable target)
    │   │   └── main.swift           (ArgumentParser-based entry point)
    │   └── HLSAnalyzerCore/         (The library target)
    │       ├── HLSAnalyzerCore.swift
    │       ├── HLSManifest.swift    (Data models for Master/Media playlists, etc.)
    │       ├── Analyzers/
    │       │   ├── MasterPlaylistAnalyzer.swift
    │       │   ├── MediaPlaylistAnalyzer.swift
    │       │   ├── AdMarkersAnalyzer.swift
    │       │   └── DRMAnalyzer.swift (optional)
    │       └── Parsers/
    │           └── SimpleHLSParser.swift (Minimal parser for M3U8 tags)
    └── Tests/
        ├── HLSAnalyzerCoreTests/     (Unit tests for the core library)
        └── HLSAnalyzerCLITests/      (Tests for the CLI, local file tests, etc.)
```

### 2.1 Swift Package Manifest

 - **Package.swift** declares:

 - **products**: .library(name: "HLSAnalyzerCore"), .executable(name: 
   "hls-analyzer").

 - **targets**: HLSAnalyzerCore (a library target) and HLSAnalyzerCLI (an 
   executable target), plus test targets.

 - Dependencies: ArgumentParser for CLI arguments, etc.

## 3) Core Components

### 3.1 HLSAnalyzerCore.swift

Defines the HLSAnalyzerCore class, primarily with:

 - An **enum** PlaylistType (.master, .media, .unknown)

 - A **static** method determinePlaylistType(from content: String) -> 
   PlaylistType, which checks for #EXT-X-STREAM-INF or #EXTINF lines to guess Master vs. Media.

### 3.2 Data Models (HLSManifest.swift)

Houses simple structs:

 - **MasterPlaylist**: has an array of VariantStream and an array of RenditionGroup.

 - **MediaPlaylist**: has optional targetDuration and a list of MediaSegment.

 - **VariantStream**: with bandwidth, resolution, codecs, etc.

 - **Resolution**: a Hashable struct storing width and height.

 - **MediaSegment**: each segment has a duration and a uri.


### 3.3 SimpleHLSParser.swift

A minimal line-by-line parser that:

 - **parseMasterPlaylist(_:) -> MasterPlaylist*

     - Looks for #EXT-X-STREAM-INF: lines, extracts attributes (BANDWIDTH=, RESOLUTION=, etc.).

     - The next line is typically the stream URI.

     - Also parses #EXT-X-MEDIA: lines for renditions.

 - **parseMediaPlaylist(_:) -> MediaPlaylist**

     - Finds #EXT-X-TARGETDURATION, #EXTINF, builds up segments.

This parser is easily replaceable by a third-party library (e.g. Comcast's Mamba) in the future.

### 3.4 Analyzers

#### 3.4.1 MasterPlaylistAnalyzer.swift

 -  **analyze(content:useANSI:)**
 
     - Parses the master with SimpleHLSParser.parseMasterPlaylist(...).

     - Prints color-coded or plain text lines about each variant.

     - **validateVariants(...)** checks for missing attributes or near-duplicate 
       bandwidth in the same resolution.

     - Optionally also details rendition groups.

  
#### 3.4.2 MediaPlaylistAnalyzer.swift
 
 - **analyze(content:useANSI:)**
 
     - Parses a media playlist.

     - Lists target duration, segments, URIs.

     - Calls **validateCMAF(content:useANSI:)** to check for CMAF compliance 
       (#EXT-X-MAP, #EXT-X-INDEPENDENT-SEGMENTS, etc.).

     - Calls **AdMarkersAnalyzer** to detect ad markers (#EXT-X-DISCONTINUITY, 
       #EXT-X-DATERANGE, etc.).

     - Optionally calls **DRMAnalyzer** to detect #EXT-X-KEY lines.

#### 3.4.3 AdMarkersAnalyzer.swift
 
 - Looks for #EXT-X-DISCONTINUITY (SSAI), #EXT-X-DATERANGE (SGAI), #EXT-X-CUE-OUT/IN.

 - Prints a dancing emoji (🕺) for discontinuities, indicates various ad insertion styles in summary.

#### 3.4.4 DRMAnalyzer.swift (Optional)
 
 - Finds #EXT-X-KEY, logs **🔐** if found, extracts METHOD, URI, etc.

 - Identifies possible FairPlay if KEYFORMAT="com.apple.streamingkeydelivery", etc.


## 4) The CLI (HLSAnalyzerCLI/main.swift)

Uses **Swift Argument Parser** to define a command with:

 -  **pathOrURL** argument: The user supplies either an HTTP(S) URL or local file path.

 -  **--json** flag: If set, the analyzer's output is encoded to JSON and printed; otherwise, color-coded text is printed.

  
### Key Steps:

1. **Identify Remote vs. Local**: If the argument looks like http:// or https://, 
   download with URLSession; otherwise, read local file.

2. **Determine Playlist Type**: HLSAnalyzerCore.determinePlaylistType (master vs. 
   media vs. unknown).

3. **Analyze**:
 
     - If master, call MasterPlaylistAnalyzer.analyze(..., useANSI: !json).

     - If media, call MediaPlaylistAnalyzer.analyze(..., useANSI: !json).

     - If unknown, just report "Unknown."

4. **Output**:

     - In normal mode, prints color-coded lines from each analyzer.

     - In JSON mode, encodes a simple struct { playlistType, analysisText } as a 
       JSON object.

## 5) Testing

### 5.1 Unit Tests

 - **HLSAnalyzerCoreTests** in Tests/HLSAnalyzerCoreTests:

 - Checks determinePlaylistType logic.

 - Verifies parseMasterPlaylist & parseMediaPlaylist with minimal M3U8 strings.

 - **AdMarkersTests**, **CMAFValidationTests**:

 - Provide short M3U8 strings with discontinuities, date-range, or CMAF tags.

 - Expect certain lines or emojis in the analyzer output.

### 5.2 CLI Tests

 - **SampleUrlTest**: tries reading Samples/urls.txt line by line, runs the CLI 
   in a subprocess, checks for errors.

 - **HLSAnalyzerLocalFilesTest**: runs hls-analyzer on each file in Samples/, 
   ensuring correct detection of variant streams, segments, etc.



## 6) Notable Features & Functionality

1. **Emoji Indicators**

     - 🕺 for #EXT-X-DISCONTINUITY

     - 🔐 for #EXT-X-KEY (DRM)

     - ⚠️ for warnings (like missing tags)

     - ✅ or ❌ for success/failure checks (e.g. CMAF compliance)

2. **CMAF Validation**

     - Checks for required tags like #EXT-X-MAP.

     - Recommends #EXT-X-INDEPENDENT-SEGMENTS.

     - Expects #EXT-X-VERSION >= 7.

     - Prints color-coded lines for missing or found tags.

3. **Ad Marker Aggregation**

     - Summarizes whether the stream uses SSAI (discontinuities), SGAI 
       (date ranges), or older CUE-OUT/IN markers.

     - Groups them in a final "Ad Insertion Type Detected" line.

4. **DRM Tag Checks** (if integrated)

     - Reports encryption method (AES-128, SAMPLE-AES).

     - Identifies KEYFORMAT for FairPlay or Widevine.

     - Possible session key usage in a master playlist.

5. **Master Variant Validation**

     - Warns if multiple variants share the same resolution but have nearly 
       identical bandwidth.

     - Alerts if missing essential attributes like BANDWIDTH or CODECS.

## 7) Future / Extensibility**

1. **Deep RFC 8216 Compliance**

     - Currently we do partial checks. A more thorough approach might enforce 
       each mandated tag and attribute.

2. **Segment-Level Verification**

     - Potentially download & parse segments for true CMAF box compliance, but 
       that's beyond the quick CLI scope.

3. **GUI**

     - Because of the modular design, a SwiftUI or Catalyst app could easily 
       call HLSAnalyzerCore behind the scenes for a visual HLS inspector.

4. **Multiple Output Formats**

     - We currently have color-coded text or JSON. Could add other structured 
       outputs (YAML, CSV) or a web-based UI.


## 8) Conclusion

**HLS-Analyzer** offers a modular Swift codebase that highlights best practices 
in **master vs. media parsing**, **CMAF checks**, **DRM detection**, 
**ad marker identification**, and **user-friendly output**. The design is 
intentionally flexible--third-party libraries can be dropped in if deeper 
parsing or compliance is required, and the analyzers can be extended to 
handle more advanced use cases (like per-segment ad durations or DRM key 
rotations).

This 1.0 release includes:

 - A stable **CLI** with --json for machine parsing

 - Well-separated analyzers for master playlists, media playlists, ad markers, and optional DRM logic

 - **Color-coded** text mode for quick human scanning

 - Basic test coverage verifying parsing, CMAF checks, and CLI usage

