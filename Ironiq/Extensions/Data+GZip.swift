import Foundation

// MARK: - GZip compression / decompression without a third-party dependency
//
// gzipped(): Compresses using NSData.compressed(.zlib), extracts the raw DEFLATE
// bitstream, and wraps it in a gzip file. Stores the Adler-32 of the original data
// in the gzip EXTRA field (sub-field ID "A2") so gunzipped() can reconstruct a
// complete, verifiable zlib stream without the C inflate API.
//
// gunzipped(): If the file was produced by this gzipped() (FLG=FEXTRA, "A2" present),
// reads the Adler-32 from the EXTRA field, reconstructs a valid zlib stream, and
// decompresses with NSData.decompressed(using: .zlib). Falls back gracefully for
// files without the EXTRA field (returns decompressionFailed rather than crashing).

extension Data {
    /// Returns a gzip-compressed copy. Stores the Adler-32 in the gzip EXTRA field
    /// so gunzipped() can reconstruct a valid zlib stream for decompression.
    func gzipped() throws -> Data {
        guard !isEmpty else { return Data() }

        let zlibData = try (self as NSData).compressed(using: .zlib) as Data

        guard zlibData.count >= 6 else { throw GZipError.compressionFailed }
        let fdict = (zlibData[1] & 0x20) != 0
        let headerLength = fdict ? 6 : 2
        guard zlibData.count >= headerLength + 4 else { throw GZipError.compressionFailed }

        // The last 4 bytes of the zlib stream ARE the Adler-32 of the original data.
        let a32 = UInt32(zlibData[zlibData.count - 4]) << 24
               |  UInt32(zlibData[zlibData.count - 3]) << 16
               |  UInt32(zlibData[zlibData.count - 2]) << 8
               |  UInt32(zlibData[zlibData.count - 1])

        let deflate = zlibData[headerLength ..< zlibData.count - 4]

        // EXTRA field: sub-field 'A2' carrying the 4-byte Adler-32 (big-endian).
        // XLEN = 8 (4 bytes header per sub-field + 4 bytes data)
        let xlen: UInt16 = 8
        let extra: [UInt8] = [
            UInt8(xlen & 0xFF), UInt8((xlen >> 8) & 0xFF),  // XLEN LE
            0x41, 0x32,                                       // SI "A2"
            0x04, 0x00,                                       // sub-field length = 4 LE
            UInt8((a32 >> 24) & 0xFF), UInt8((a32 >> 16) & 0xFF),
            UInt8((a32 >>  8) & 0xFF), UInt8( a32        & 0xFF),
        ]

        var output = Data(capacity: 10 + extra.count + deflate.count + 8)

        // Gzip header with FLG=0x04 (FEXTRA)
        output += Data([0x1f, 0x8b, 0x08, 0x04,
                        0x00, 0x00, 0x00, 0x00,  // mtime
                        0x00, 0xFF])              // xfl, OS
        output += extra
        output += deflate

        // Footer: CRC-32 LE + original size LE
        let crc = Data.crc32(self)
        let crcLE = crc.littleEndian
        output.append(contentsOf: [
            UInt8(crcLE & 0xFF), UInt8((crcLE >> 8) & 0xFF),
            UInt8((crcLE >> 16) & 0xFF), UInt8((crcLE >> 24) & 0xFF),
        ])
        let sizeLE = UInt32(count).littleEndian
        output.append(contentsOf: [
            UInt8(sizeLE & 0xFF), UInt8((sizeLE >> 8) & 0xFF),
            UInt8((sizeLE >> 16) & 0xFF), UInt8((sizeLE >> 24) & 0xFF),
        ])

        return output
    }

    /// Returns gzip-decompressed data.
    /// For files produced by this gzipped(), reads the Adler-32 from the EXTRA field
    /// and reconstructs a valid zlib stream for NSData.decompressed(using: .zlib).
    func gunzipped() throws -> Data {
        guard !isEmpty else { return Data() }
        guard count >= 18, self[0] == 0x1f, self[1] == 0x8b else {
            throw GZipError.decompressionFailed
        }

        let flags = self[3]
        var offset = 10
        var recoveredAdler32: UInt32? = nil

        // Parse FEXTRA: look for sub-field 'A2' containing the stored Adler-32.
        if flags & 0x04 != 0 {
            guard offset + 2 <= count else { throw GZipError.decompressionFailed }
            let xlen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            let extraEnd = offset + 2 + xlen
            guard extraEnd <= count else { throw GZipError.decompressionFailed }

            var pos = offset + 2
            while pos + 4 <= extraEnd {
                let id1 = self[pos], id2 = self[pos + 1]
                let sfLen = Int(self[pos + 2]) | (Int(self[pos + 3]) << 8)
                if id1 == 0x41, id2 == 0x32, sfLen == 4, pos + 4 + 4 <= extraEnd {
                    recoveredAdler32 =
                        UInt32(self[pos + 4]) << 24 | UInt32(self[pos + 5]) << 16
                      | UInt32(self[pos + 6]) <<  8 | UInt32(self[pos + 7])
                    break
                }
                pos += 4 + sfLen
            }
            offset = extraEnd
        }

        if flags & 0x08 != 0 { while offset < count && self[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x10 != 0 { while offset < count && self[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x02 != 0 { offset += 2 }
        guard offset <= count - 8 else { throw GZipError.decompressionFailed }

        let deflate = self[offset ..< count - 8]

        guard let a32 = recoveredAdler32 else {
            // Old file without the EXTRA field — cannot decompress without Adler-32.
            throw GZipError.decompressionFailed
        }

        // Reconstruct a complete, valid zlib stream and decompress.
        // Header: 0x78 0x9C (deflate, 32 KB window, check bits mod-31 = 0)
        var zlibStream = Data([0x78, 0x9C])
        zlibStream.append(contentsOf: deflate)
        zlibStream.append(contentsOf: [
            UInt8((a32 >> 24) & 0xFF), UInt8((a32 >> 16) & 0xFF),
            UInt8((a32 >>  8) & 0xFF), UInt8( a32        & 0xFF),
        ])

        do {
            return try (zlibStream as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw GZipError.decompressionFailed
        }
    }

    // MARK: - CRC-32 (ISO 3309 / ITU-T V.42)

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crc32Table[index]
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crc32Table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
}

enum GZipError: Error, Equatable {
    case compressionFailed
    case decompressionFailed
}
