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

        // Capture the exact CMF and FLG bytes NSData used — stored verbatim so
        // gunzipped() can reconstruct an identical zlib header.
        let cmf = zlibData[0]
        let flg = zlibData[1]

        let deflate = zlibData[headerLength ..< zlibData.count - 4]

        // EXTRA field: sub-field 'IZ' (Ironiq Zlib) carries CMF(1)+FLG(1)+Adler-32(4) = 6 bytes.
        // XLEN = 2(SI) + 2(LEN) + 6(data) = 10
        let xlen: UInt16 = 10
        let extra: [UInt8] = [
            UInt8(xlen & 0xFF), UInt8((xlen >> 8) & 0xFF),  // XLEN LE
            0x49, 0x5A,                                       // SI "IZ"
            0x06, 0x00,                                       // sub-field length = 6 LE
            cmf, flg,                                         // original zlib header bytes
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
        var recoveredCMF: UInt8 = 0x78
        var recoveredFLG: UInt8 = 0x9C

        // Parse FEXTRA: look for sub-field 'IZ' containing CMF, FLG, and Adler-32.
        if flags & 0x04 != 0 {
            guard offset + 2 <= count else { throw GZipError.decompressionFailed }
            let xlen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            let extraEnd = offset + 2 + xlen
            guard extraEnd <= count else { throw GZipError.decompressionFailed }

            var pos = offset + 2
            while pos + 4 <= extraEnd {
                let id1 = self[pos], id2 = self[pos + 1]
                let sfLen = Int(self[pos + 2]) | (Int(self[pos + 3]) << 8)
                if id1 == 0x49, id2 == 0x5A, sfLen == 6, pos + 4 + 6 <= extraEnd {
                    // 'IZ' sub-field: CMF(1) FLG(1) Adler-32-BE(4)
                    recoveredCMF = self[pos + 4]
                    recoveredFLG = self[pos + 5]
                    recoveredAdler32 =
                        UInt32(self[pos + 6]) << 24 | UInt32(self[pos + 7]) << 16
                      | UInt32(self[pos + 8]) <<  8 | UInt32(self[pos + 9])
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

        // Reconstruct the exact zlib stream using the stored CMF/FLG bytes.
        var zlibStream = Data([recoveredCMF, recoveredFLG])
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
