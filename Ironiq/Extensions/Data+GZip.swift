import Foundation
import zlib

// MARK: - GZip compression / decompression without a third-party dependency
//
// gzipped(): NSData.compressed(using: .zlib) produces a DEFLATE stream with a
// 2-byte zlib header and a 4-byte Adler-32 footer. A valid .gz file is the
// same DEFLATE bitstream wrapped in a 10-byte gzip header and an 8-byte footer
// (CRC-32 + original size). We strip the zlib envelope and re-wrap in gzip.
//
// gunzipped(): Strips the gzip envelope and inflates the raw DEFLATE payload
// using the system zlib's inflateInit2 with windowBits=-15 (raw DEFLATE mode).

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

        // Original size is the last 4 bytes of the gzip footer, little-endian.
        let sizeStart = count - 4
        let originalSize = Int(self[sizeStart])
            | (Int(self[sizeStart + 1]) << 8)
            | (Int(self[sizeStart + 2]) << 16)
            | (Int(self[sizeStart + 3]) << 24)

        let deflate = self[offset ..< count - 8]
        let capacity = Swift.max(originalSize + 64, deflate.count * 4)
        var output = Data(count: capacity)
        var totalOut = 0

        let deflateBytes = Array(deflate)
        var stream = z_stream()

        try deflateBytes.withUnsafeBytes { (inBuf: UnsafeRawBufferPointer) throws in
            guard let inBase = inBuf.baseAddress else { throw GZipError.decompressionFailed }
            stream.next_in = UnsafeMutablePointer(mutating: inBase.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(deflate.count)

            // windowBits = -15 tells zlib to expect raw DEFLATE (no zlib/gzip header).
            guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                throw GZipError.decompressionFailed
            }
        }

        let status: Int32 = output.withUnsafeMutableBytes { (outBuf: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let outBase = outBuf.baseAddress else { return Z_STREAM_ERROR }
            stream.next_out = outBase.assumingMemoryBound(to: Bytef.self)
            stream.avail_out = uInt(capacity)
            let r = inflate(&stream, Z_FINISH)
            totalOut = Int(stream.total_out)
            return r
        }
        inflateEnd(&stream)
        guard status == Z_STREAM_END else { throw GZipError.decompressionFailed }

        output.removeLast(capacity - totalOut)
        return output
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
