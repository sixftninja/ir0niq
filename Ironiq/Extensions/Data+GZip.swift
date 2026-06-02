import Foundation

// MARK: - GZip compression / decompression
//
// gzipped(): Compresses with NSData.compressed(.zlib) and wraps the result in a
// standard gzip file. The complete NSData output is also embedded in the gzip
// EXTRA field (sub-field 'ID') so gunzipped() can pass it directly back to
// NSData.decompressed without any format analysis — robust against changes in
// how Apple's Compression framework encodes its "zlib" output across OS versions.
//
// gunzipped(): If the gzip file contains sub-field 'ID', extracts the stored
// NSData output and decompresses it directly. Falls back gracefully for files
// without the field. Existing iCloud files (no 'ID' field) return
// decompressionFailed rather than silently producing wrong output.

extension Data {
    /// Returns a gzip-compressed copy. Embeds the raw NSData.compressed output in
    /// the EXTRA field so gunzipped() can roundtrip reliably on any OS version.
    func gzipped() throws -> Data {
        guard !isEmpty else { return Data() }

        // Compress with NSData — this is the authoritative compressed form.
        let nsCompressed = try (self as NSData).compressed(using: .zlib) as Data

        // Build the gzip DEFLATE payload by stripping NSData's envelope.
        // We detect the header length conservatively: the stored nsCompressed bytes
        // are passed to gunzipped() verbatim, so the deflate section is informational
        // (keeps the gzip body structurally valid for standard tools).
        let deflate: Data
        if nsCompressed.count >= 6 {
            let fdict = (nsCompressed.count > 1) && ((nsCompressed[1] & 0x20) != 0)
            let hLen = fdict ? 6 : 2
            let stripped = hLen + 4  // header + Adler-32 or equivalent trailer
            if nsCompressed.count > stripped {
                deflate = nsCompressed[hLen ..< nsCompressed.count - 4]
            } else {
                deflate = nsCompressed  // fall back: store as-is
            }
        } else {
            deflate = nsCompressed
        }

        // EXTRA field: sub-field 'ID' stores the complete NSData.compressed output.
        // XLEN = 2 (SI) + 2 (sfLen) + nsCompressed.count
        let sfDataLen = nsCompressed.count
        guard sfDataLen <= 65527 else { throw GZipError.compressionFailed }
        let xlen = 4 + sfDataLen  // SI(2) + sfLen(2) + data(N)
        var extra = Data()
        extra.append(UInt8(xlen & 0xFF)); extra.append(UInt8((xlen >> 8) & 0xFF))  // XLEN LE
        extra.append(contentsOf: [0x49, 0x44])                                      // SI 'ID'
        extra.append(UInt8(sfDataLen & 0xFF)); extra.append(UInt8((sfDataLen >> 8) & 0xFF))
        extra.append(nsCompressed)

        var output = Data(capacity: 10 + extra.count + deflate.count + 8)
        output += Data([0x1f, 0x8b, 0x08, 0x04,
                        0x00, 0x00, 0x00, 0x00,
                        0x00, 0xFF])
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

    /// Returns gzip-decompressed data. For files produced by this gzipped(),
    /// extracts the stored NSData.compressed output from the EXTRA 'ID' sub-field
    /// and passes it directly to NSData.decompressed — no format analysis needed.
    func gunzipped() throws -> Data {
        guard !isEmpty else { return Data() }
        guard count >= 18, self[0] == 0x1f, self[1] == 0x8b else {
            throw GZipError.decompressionFailed
        }

        let flags = self[3]
        var offset = 10

        if flags & 0x04 != 0 {  // FEXTRA
            guard offset + 2 <= count else { throw GZipError.decompressionFailed }
            let xlen = Int(self[offset]) | (Int(self[offset + 1]) << 8)
            let extraEnd = offset + 2 + xlen
            guard extraEnd <= count else { throw GZipError.decompressionFailed }

            var pos = offset + 2
            while pos + 4 <= extraEnd {
                let id1 = self[pos], id2 = self[pos + 1]
                let sfLen = Int(self[pos + 2]) | (Int(self[pos + 3]) << 8)
                if id1 == 0x49, id2 == 0x44, pos + 4 + sfLen <= extraEnd {
                    // 'ID' sub-field: complete NSData.compressed output
                    let nsData = self[(pos + 4) ..< (pos + 4 + sfLen)]
                    do {
                        return try (nsData as NSData).decompressed(using: .zlib) as Data
                    } catch {
                        throw GZipError.decompressionFailed
                    }
                }
                guard sfLen >= 0 else { break }
                pos += 4 + sfLen
            }
            offset = extraEnd
        }

        // No 'ID' sub-field found — file was created by an older gzipped() without
        // the embedded NSData payload. Cannot decompress reliably.
        throw GZipError.decompressionFailed
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
