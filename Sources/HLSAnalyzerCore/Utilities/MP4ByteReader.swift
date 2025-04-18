//
//  MP4ByteReader.swift
//  HLSAnalyzerCLI
//
//  Created by Joseph R. Jones on 4/7/25.
//

import Foundation

struct MP4ByteReader {
    private let data: Data
    private(set) var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    var bytesLeft: Int {
        data.count - offset
    }

    mutating func readUInt32() throws -> UInt32 {
        try checkAvailable(count: 4)
        // Read 4 bytes manually to avoid misaligned loads (big-endian)
        let start = offset
        let b0 = UInt32(data[start])
        let b1 = UInt32(data[start + 1])
        let b2 = UInt32(data[start + 2])
        let b3 = UInt32(data[start + 3])
        offset += 4
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    mutating func readUInt64() throws -> UInt64 {
        try checkAvailable(count: 8)
        // Read 8 bytes manually to avoid misaligned loads (big-endian)
        let start = offset
        let b0 = UInt64(data[start])
        let b1 = UInt64(data[start + 1])
        let b2 = UInt64(data[start + 2])
        let b3 = UInt64(data[start + 3])
        let b4 = UInt64(data[start + 4])
        let b5 = UInt64(data[start + 5])
        let b6 = UInt64(data[start + 6])
        let b7 = UInt64(data[start + 7])
        offset += 8
        return (b0 << 56) | (b1 << 48) | (b2 << 40) | (b3 << 32)
             | (b4 << 24) | (b5 << 16) | (b6 << 8)  | b7
    }

    mutating func readAtomType() throws -> String {
        try checkAvailable(count: 4)
        let typeData = data.subdata(in: offset..<(offset+4))
        offset += 4
        guard let typeString = String(data: typeData, encoding: .ascii) else {
            throw MP4ReaderError.invalidAtomType
        }
        return typeString
    }

    mutating func skipBytes(_ count: Int) throws {
        try checkAvailable(count: count)
        offset += count
    }

    private func checkAvailable(count: Int) throws {
        if count > bytesLeft {
            throw MP4ReaderError.outOfData
        }
    }
    mutating func subdata(count: Int) throws -> Data {
        try checkAvailable(count: count)
        let chunk = data.subdata(in: offset..<(offset+count))
        offset += count
        return chunk
    }
}

enum MP4ReaderError: Error {
    case outOfData
    case invalidAtomType
    case invalidSize(String)
    case parsingError(String)
}
