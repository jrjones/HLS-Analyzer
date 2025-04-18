// HLS Analyzer (c) Copyright JRJ - https://github.com/jrjones/HLS-Analyzer
// Licensed under MIT license, attribution requested


import Foundation

public struct MP4Atom {
    public let type: String
    public let size: UInt64
    public let children: [MP4Atom]
    // Payload for non-container atoms (optional)
    public let payload: Data?
}

public struct MP4ParseResult {
    public let atoms: [MP4Atom]
    public let issues: [String]
}

public struct MP4Parser {

    public init() {}

    public func parseMP4(data: Data) -> MP4ParseResult {
        var reader = MP4ByteReader(data: data)
        var topLevelAtoms = [MP4Atom]()
        var issues = [String]()

        // Keep parsing until we don’t have enough bytes for an atom header
        while reader.bytesLeft > 8 {
            do {
                let atom = try readAtom(reader: &reader)
                topLevelAtoms.append(atom)
            } catch let err {
                issues.append("Error while parsing atom: \(err)")
                break
            }
        }

        return MP4ParseResult(atoms: topLevelAtoms, issues: issues)
    }

    private func readAtom(reader: inout MP4ByteReader) throws -> MP4Atom {
        let size32 = try reader.readUInt32()
        let type = try reader.readAtomType()

        var size: UInt64 = UInt64(size32)
        if size == 1 {
            // 64-bit size
            size = try reader.readUInt64()
        } else if size == 0 {
            // extends to end of file or container
            size = UInt64(reader.bytesLeft + 8) // 8 for size+type we consumed
        }

        let startOffset = reader.offset
        let contentSize = size > 8 ? size - 8 : 0

        if contentSize > reader.bytesLeft {
            throw MP4ReaderError.invalidSize("Atom \(type) size \(size) exceeds available data.")
        }

        var children = [MP4Atom]()
        var payload: Data? = nil

        // Check if container
        if isContainer(type: type) {
            let containerEnd = startOffset + Int(contentSize)
            while reader.offset < containerEnd {
                let subAtom = try readAtom(reader: &reader)
                children.append(subAtom)
            }
        } else {
            // Non-container: read the payload so we can parse further in the analyzer.
            do {
                payload = try reader.subdata(count: Int(contentSize))
            } catch {
                throw MP4ReaderError.invalidSize("Could not read payload for atom \(type)")
            }
        }

        return MP4Atom(
            type: type,
            size: size,
            children: children,
            payload: payload
        )
    }

    private func isContainer(type: String) -> Bool {
        switch type {
        case "moov", "trak", "mdia", "minf", "stbl",
             "moof", "traf", "mfra", "udta":
            return true
        default:
            return false
        }
    }
}
