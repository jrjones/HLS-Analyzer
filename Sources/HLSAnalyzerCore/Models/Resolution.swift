// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested

public struct Resolution: Codable, Hashable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
