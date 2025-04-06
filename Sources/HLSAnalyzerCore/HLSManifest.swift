import Foundation

/// Represents a simple Master playlist model.
public struct MasterPlaylist {
    public var variantStreams: [VariantStream] = []
    public var renditionGroups: [RenditionGroup] = []
    public init() {}
}

/// Represents a single variant stream entry in a Master playlist.
public struct VariantStream {
    public var bandwidth: Int?
    // Use a Hashable struct instead of a tuple for resolution
    public var resolution: Resolution?
    public var codecs: String?
    public var uri: String?
}

/// Group of renditions (e.g., audio, subtitles).
public struct RenditionGroup {
    public var groupID: String
    public var name: String?
    public var uri: String?
    public var type: String?
}

/// Represents a simple Media (variant) playlist model.
public struct MediaPlaylist {
    public var targetDuration: Int?
    public var segments: [MediaSegment] = []
    public init() {}
}

/// Represents one segment entry in a Media playlist.
public struct MediaSegment {
    public var duration: Double
    public var uri: String?
}

/// A Hashable struct to store resolution instead of an (Int, Int) tuple
public struct Resolution: Hashable {
    public let width: Int
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
