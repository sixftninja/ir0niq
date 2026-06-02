import Foundation

// MARK: - GZip compression / decompression without a third-party dependency
//
// gzipped(): NSData.compressed(using: .zlib) produces a DEFLATE stream with a
// 2-byte zlib header and a 4-byte Adler-32 footer. A valid .gz file is the
// same DEFLATE bitstream wrapped in a 10-byte gzip header and an 8-byte footer
// (CRC-32 + original size). We strip the zlib envelope and re-wrap in gzip.
//
// gunzipped(): Strips the gzip envelope, prepends a valid zlib header, and uses
// NSData.decompressed(using: .zlib). Apple's Compression framework reads DEFLATE
// to the end-of-stream marker without enforcing the trailing Adler-32 checksum.

extension Data {
    /// Returns a gzip-compressed copy.
    func gzipped() throws -> Data {
        guard !isEmpty else { return Data() }

        let zlibData = try (self as NSData).compressed(using: .zlib) as Data

        // zlib stream layout: [CMF FLG? (DICTID: 4 bytes if FDICT set) ... DEFLATE ... Adler-32 (4 bytes)]
        guard zlibData.count >= 6 else { throw GZipError.compressionFailed }
        let fdict = (zlibData[1] & 0x20) != 0
        let headerLength = fdict ? 6 : 2
        guard zlibData.count >= headerLength + 4 else { throw GZipError.compressionFailed }
        let deflate = zlibData[headerLength ..< zlibData.count - 4]

        var output = Data(capacity: 10 + deflate.count + 8)

        // ── Gzip header ─────────────────────────────────────────────────────
        output += Data([0x1f, 0x8b])             // Magic
        output += Data([0x08])                    // Compression: DEFLATE
        output += Data([0x00])                    // Flags: none
        output += Data([0x00, 0x00, 0x00, 0x00]) // Modification time
        output += Data([0x00])                    // Extra flags
        output += Data([0xff])                    // OS: unknown

        // ── Payload ─────────────────────────────────────────────────────────
        output += deflate

        // ── Gzip footer: CRC-32 LE + original size LE ────────────────────────
        let crc = Data.crc32(self)
        let crcLE = crc.littleEndian
        output.append(contentsOf: [
            UInt8(crcLE & 0xFF), UInt8((crcLE >> 8) & 0xFF),
            UInt8((crcLE >> 16) & 0xFF), UInt8((crcLE >> 24) & 0xFF)
        ])
        let sizeLE = UInt32(count).littleEndian
        output.append(contentsOf: [
            UInt8(sizeLE & 0xFF), UInt8((sizeLE >> 8) & 0xFF),
            UInt8((sizeLE >> 16) & 0xFF), UInt8((sizeLE >> 24) & 0xFF)
        ])

        return output
    }

    /// Returns gzip-decompressed data. Works with any valid .gz file.
    func gunzipped() throws -> Data {
        guard !isEmpty else { return Data() }
        guard count >= 18, self[0] == 0x1f, self[1] == 0x8b else {
            throw GZipError.decompressionFailed
        }

        // Parse gzip header to find where DEFLATE payload begins.
        let flags = self[3]
        var offset = 10
        if flags & 0x04 != 0 {
            guard offset + 2 <= count else { throw GZipError.decompressionFailed }
            let xlen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { while offset < count && self[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x10 != 0 { while offset < count && self[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x02 != 0 { offset += 2 }
        guard offset <= count - 8 else { throw GZipError.decompressionFailed }

        let deflate = self[offset ..< count - 8]

        // Reconstruct a zlib stream: valid 2-byte header + raw DEFLATE payload.
        // 0x78 0x9C = CMF (deflate, 32 KB window) + FLG (check bits satisfying mod-31 = 0).
        // NSData.decompressed(using: .zlib) reads DEFLATE to its end-of-stream marker;
        // it does not enforce the trailing 4-byte Adler-32 checksum.
        var zlibStream = Data([0x78, 0x9C])
        zlibStream.append(contentsOf: deflate)

        do {
            let result = try (zlibStream as NSData).decompressed(using: .zlib)
            return result as Data
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
