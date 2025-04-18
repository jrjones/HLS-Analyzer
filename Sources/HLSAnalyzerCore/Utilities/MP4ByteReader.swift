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
        let value = data.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        return UInt32(bigEndian: value)
    }

    mutating func readUInt64() throws -> UInt64 {
        try checkAvailable(count: 8)
        let value = data.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: UInt64.self)
        }
        offset += 8
        return UInt64(bigEndian: value)
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
