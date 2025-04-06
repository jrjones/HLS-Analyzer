# HLS-Analyzer

A simple Swift CLI tool for analyzing HLS (HTTP Live Streaming) playlists.  

## Features
- **Master Playlist Analysis**: Summarizes variant streams, bandwidth, resolution, etc.
- **Media Playlist Analysis**: Checks target duration, CMAF compliance, DRM, ad markers, more.
- **CMAF Validation**: Detects missing `#EXT-X-MAP`, warns if `#EXT-X-VERSION < 7`.
- **DRM Detection**: Finds `#EXT-X-KEY`, prints encryption method (`AES-128`, `SAMPLE-AES`), and shows `🔐`.
- **Ad Marker Detection**: Shows `🕺` for discontinuities, identifies date-range (SGAI), cue out/in markers.
- **Color-Coded Output**: Quick scanning for warnings/errors.

## Installation
```bash
git clone https://github.com/jrjones/HLS-Analyzer.git
cd HLS-Analyzer
swift build
```
# Analyze a remote playlist
`swift run hls-analyzer https://example.com/playlist.m3u8`

# Analyze a local file
`swift run hls-analyzer Samples/sample-media.m3u8`

# Output in JSON
`swift run hls-analyzer --json Samples/sample-media.m3u8`

For more details, please view the [design doc](design.md)
