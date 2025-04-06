import Foundation

// Potential placeholders or models for future expansions
public struct MasterPlaylist {
    public var variantStreams: [VariantStream] = []
    public var renditionGroups: [RenditionGroup] = []
    public init() {}
}

public struct VariantStream {
    public var bandwidth: Int?
    public var resolution: (width: Int, height: Int)?
    public var codecs: String?
    public var uri: String?
}

public struct RenditionGroup {
    public var groupID: String
    public var name: String?
    public var uri: String?
    public var type: String?
}

public struct MediaPlaylist {
    public var targetDuration: Int?
    public var segments: [MediaSegment] = []
    public init() {}
}

public struct MediaSegment {
    public var duration: Double
    public var uri: String?
}
