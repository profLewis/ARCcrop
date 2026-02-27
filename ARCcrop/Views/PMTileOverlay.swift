#if !os(tvOS)
import MapKit
import UIKit
import Compression

/// MKTileOverlay that reads PMTiles v3 archives (containing MVT vector tiles)
/// and rasterises the polygon features into tile PNGs on the fly.
final class PMTileOverlay: MKTileOverlay {
    let pmtilesURL: URL
    private var header: PMTilesHeader?
    private var rootDirectory: Data?
    private var headerLoaded = false
    private let queue = DispatchQueue(label: "pmtiles", qos: .userInitiated, attributes: .concurrent)
    private var leafCache: [UInt64: Data] = [:]
    private let leafLock = NSLock()

    private static let cachedSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 50_000_000, diskCapacity: 500_000_000)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    /// Cancel all in-flight PMTiles downloads
    static func cancelAllDownloads() {
        cachedSession.getAllTasks { tasks in
            for task in tasks { task.cancel() }
        }
    }

    init(url: URL) {
        self.pmtilesURL = url
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = 0
        self.maximumZ = 14
    }

    // MARK: - Tile loading

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        queue.async { [weak self] in
            guard let self else { result(nil, nil); return }

            // Lazily load header
            if !self.headerLoaded {
                self.loadHeader()
            }
            guard let header = self.header, let rootDir = self.rootDirectory else {
                result(nil, nil)
                return
            }

            let tileID = Self.zxyToTileID(z: path.z, x: path.x, y: path.y)
            guard let entry = self.findTile(id: tileID, in: rootDir, header: header) else {
                result(nil, nil)
                return
            }

            // Fetch tile data via HTTP range request
            guard let tileData = Self.fetchRange(from: self.pmtilesURL, offset: entry.offset, length: entry.length) else {
                result(nil, nil)
                return
            }

            // Decompress if needed
            let decompressed: Data
            switch header.tileCompression {
            case 2: // gzip
                decompressed = Self.gunzip(tileData) ?? tileData
            default:
                decompressed = tileData
            }

            // Route by tile type
            switch header.tileType {
            case 2, 3, 4: // PNG, JPEG, WebP — return raw image data
                result(decompressed, nil)
            case 1: // MVT — decode and rasterise
                let layers = MVTDecoder.decode(decompressed)
                let png = Self.rasterise(layers: layers, tileSize: 256)
                result(png, nil)
            default:
                result(decompressed, nil)
            }
        }
    }

    // MARK: - PMTiles header (127 bytes)

    private func loadHeader() {
        guard let data = Self.fetchRange(from: pmtilesURL, offset: 0, length: 16384) else { return }
        guard data.count >= 127 else { return }

        let magic = data[0..<7]
        guard String(data: magic, encoding: .ascii) == "PMTiles" else { return }

        let h = PMTilesHeader(
            version: data[7],
            rootDirOffset: Self.readUInt64(data, at: 8),
            rootDirLength: Self.readUInt64(data, at: 16),
            metadataOffset: Self.readUInt64(data, at: 24),
            metadataLength: Self.readUInt64(data, at: 32),
            leafDirOffset: Self.readUInt64(data, at: 40),
            leafDirLength: Self.readUInt64(data, at: 48),
            dataOffset: Self.readUInt64(data, at: 56),
            dataLength: Self.readUInt64(data, at: 64),
            numAddressedTiles: Self.readUInt64(data, at: 72),
            numTileEntries: Self.readUInt64(data, at: 80),
            numTileContents: Self.readUInt64(data, at: 88),
            clustered: data[96] == 1,
            internalCompression: data[97],
            tileCompression: data[98],
            tileType: data[99],
            minZoom: data[100],
            maxZoom: data[101]
        )

        // Root directory may be embedded in the header fetch
        let rootEnd = Int(h.rootDirOffset + h.rootDirLength)
        if rootEnd <= data.count {
            let rootRaw = data[Int(h.rootDirOffset)..<rootEnd]
            if h.internalCompression == 2 {
                rootDirectory = Self.gunzip(Data(rootRaw))
            } else {
                rootDirectory = Data(rootRaw)
            }
        } else if let rootData = Self.fetchRange(from: pmtilesURL, offset: h.rootDirOffset, length: h.rootDirLength) {
            if h.internalCompression == 2 {
                rootDirectory = Self.gunzip(rootData)
            } else {
                rootDirectory = rootData
            }
        }

        self.header = h
        self.minimumZ = Int(h.minZoom)
        self.maximumZ = Int(h.maxZoom)
        self.headerLoaded = true
    }

    // MARK: - Directory search

    private func findTile(id: UInt64, in directory: Data, header: PMTilesHeader, depth: Int = 0) -> (offset: UInt64, length: UInt64)? {
        guard depth < 4 else { return nil } // Max depth per PMTiles spec
        let entries = Self.parseDirectory(directory)
        guard !entries.isEmpty else { return nil }

        // Binary search: find last entry where tileID <= id
        var lo = 0, hi = entries.count - 1, matchIdx = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if entries[mid].tileID <= id {
                matchIdx = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        guard matchIdx >= 0 else { return nil }
        let e = entries[matchIdx]

        if e.runLength == 0 {
            // Leaf directory — fetch, decompress, recurse
            guard let leafDir = fetchLeafDirectory(
                offset: header.leafDirOffset + e.offset,
                length: e.length,
                compression: header.internalCompression
            ) else { return nil }
            return findTile(id: id, in: leafDir, header: header, depth: depth + 1)
        }

        guard id < e.tileID + UInt64(e.runLength) else { return nil }
        return (offset: header.dataOffset + e.offset, length: e.length)
    }

    private func fetchLeafDirectory(offset: UInt64, length: UInt64, compression: UInt8) -> Data? {
        leafLock.lock()
        if let cached = leafCache[offset] { leafLock.unlock(); return cached }
        leafLock.unlock()

        guard let raw = Self.fetchRange(from: pmtilesURL, offset: offset, length: length) else { return nil }
        let dir = compression == 2 ? (Self.gunzip(raw) ?? raw) : raw

        leafLock.lock()
        leafCache[offset] = dir
        leafLock.unlock()
        return dir
    }

    private static func parseDirectory(_ data: Data) -> [PMTileEntry] {
        var entries: [PMTileEntry] = []
        var offset = 0
        let bytes = [UInt8](data)

        // Read number of entries (varint)
        let (numEntries, consumed) = readVarint(bytes, at: offset)
        offset += consumed

        // Read tile IDs (delta-encoded varints)
        var tileIDs: [UInt64] = []
        var lastID: UInt64 = 0
        for _ in 0..<numEntries {
            let (delta, c) = readVarint(bytes, at: offset)
            offset += c
            lastID += delta
            tileIDs.append(lastID)
        }

        // Read run lengths
        var runLengths: [UInt32] = []
        for _ in 0..<numEntries {
            let (val, c) = readVarint(bytes, at: offset)
            offset += c
            runLengths.append(UInt32(val))
        }

        // Read lengths
        var lengths: [UInt64] = []
        for _ in 0..<numEntries {
            let (val, c) = readVarint(bytes, at: offset)
            offset += c
            lengths.append(val)
        }

        // Read offsets (delta-encoded)
        var offsets: [UInt64] = []
        var lastOffset: UInt64 = 0
        for i in 0..<Int(numEntries) {
            let (delta, c) = readVarint(bytes, at: offset)
            offset += c
            if delta == 0 && i > 0 {
                lastOffset += lengths[i - 1]
            } else {
                lastOffset = delta - 1
            }
            offsets.append(lastOffset)
        }

        for i in 0..<Int(numEntries) {
            entries.append(PMTileEntry(
                tileID: tileIDs[i],
                offset: offsets[i],
                length: lengths[i],
                runLength: runLengths[i]
            ))
        }
        return entries
    }

    // MARK: - Tile ID from ZXY (Hilbert curve)

    static func zxyToTileID(z: Int, x: Int, y: Int) -> UInt64 {
        if z == 0 { return 0 }
        // Accumulate tile counts for all lower zoom levels
        var acc: UInt64 = 0
        for i in 0..<z {
            acc += UInt64(1) << (2 * i)
        }
        let n = 1 << z
        return acc + UInt64(Self.xyToHilbert(x: x, y: y, order: n))
    }

    private static func xyToHilbert(x: Int, y: Int, order: Int) -> Int {
        var rx = 0, ry = 0, s = 0, d = 0
        var x = x, y = y
        s = order / 2
        while s > 0 {
            rx = (x & s) > 0 ? 1 : 0
            ry = (y & s) > 0 ? 1 : 0
            d += s * s * ((3 * rx) ^ ry)
            // Rotate
            if ry == 0 {
                if rx == 1 { x = s - 1 - x; y = s - 1 - y }
                let t = x; x = y; y = t
            }
            s /= 2
        }
        return d
    }

    // MARK: - HTTP range request

    private static func fetchRange(from url: URL, offset: UInt64, length: UInt64) -> Data? {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        request.timeoutInterval = 15
        request.cachePolicy = .returnCacheDataElseLoad

        let sem = DispatchSemaphore(value: 0)
        var result: Data?
        cachedSession.dataTask(with: request) { data, response, error in
            if let data, let http = response as? HTTPURLResponse, http.statusCode == 206 || http.statusCode == 200 {
                result = data
            }
            sem.signal()
        }.resume()
        sem.wait()
        return result
    }

    // MARK: - Rasterise MVT features to PNG

    private static func rasterise(layers: [MVTLayer], tileSize: Int) -> Data? {
        guard !layers.isEmpty else { return nil }
        let size = CGFloat(tileSize)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let data = renderer.pngData { ctx in
            let gc = ctx.cgContext
            gc.setStrokeColor(UIColor.systemYellow.cgColor)
            gc.setFillColor(UIColor.systemYellow.withAlphaComponent(0.15).cgColor)
            gc.setLineWidth(1.0)

            for layer in layers {
                let extent = CGFloat(layer.extent)
                let scale = size / extent
                for feature in layer.features where feature.type == .polygon || feature.type == .lineString {
                    for ring in feature.rings {
                        guard ring.count >= 2 else { continue }
                        if feature.type == .polygon, Self.isDegenerate(ring, extent: extent) { continue }
                        gc.beginPath()
                        gc.move(to: CGPoint(x: ring[0].x * scale, y: ring[0].y * scale))
                        for i in 1..<ring.count {
                            gc.addLine(to: CGPoint(x: ring[i].x * scale, y: ring[i].y * scale))
                        }
                        if feature.type == .polygon {
                            gc.closePath()
                            gc.drawPath(using: .fillStroke)
                        } else {
                            gc.strokePath()
                        }
                    }
                }
            }
        }
        return data
    }

    /// Reject degenerate polygon rings (stray points, zero-area slivers, sub-pixel artifacts)
    private static func isDegenerate(_ ring: [CGPoint], extent: CGFloat) -> Bool {
        if ring.count < 3 { return true }
        let xs = ring.map(\.x), ys = ring.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let w = (maxX - minX) / extent
        let h = (maxY - minY) / extent
        // Sub-pixel: both dimensions tiny
        if w < 0.002 && h < 0.002 { return true }
        // Extremely thin line (one dimension near-zero, other large)
        if (w < 0.001 || h < 0.001) && max(w, h) > 0.5 { return true }
        // Near-zero signed area
        var area: CGFloat = 0
        for i in 0..<ring.count - 1 {
            area += ring[i].x * ring[i+1].y - ring[i+1].x * ring[i].y
        }
        return abs(area) / (extent * extent) < 0.000001
    }

    // MARK: - Varint / uint64 helpers

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        data.withUnsafeBytes { buf in
            buf.load(fromByteOffset: offset, as: UInt64.self).littleEndian
        }
    }

    private static func readVarint(_ bytes: [UInt8], at offset: Int) -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var i = offset
        while i < bytes.count {
            let b = bytes[i]
            result |= UInt64(b & 0x7F) << shift
            i += 1
            if b & 0x80 == 0 { break }
            shift += 7
        }
        return (result, i - offset)
    }

    // MARK: - Gzip decompression

    private static func gunzip(_ data: Data) -> Data? {
        // Skip gzip header (find deflate stream)
        guard data.count > 10, data[0] == 0x1f, data[1] == 0x8b else {
            // Try raw inflate
            return inflate(data)
        }
        // Skip past gzip header to deflate payload
        var offset = 10
        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard offset + 2 <= data.count else { return nil }
            let xlen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { offset += 2 } // FHCRC
        guard offset < data.count else { return nil }
        return inflate(Data(data[offset...]))
    }

    private static func inflate(_ data: Data) -> Data? {
        let bufSize = 1024 * 1024 // 1MB output buffer
        var output = Data(count: bufSize)
        let result = data.withUnsafeBytes { srcBuf -> Int in
            output.withUnsafeMutableBytes { dstBuf -> Int in
                guard let src = srcBuf.baseAddress, let dst = dstBuf.baseAddress else { return 0 }
                return compression_decode_buffer(
                    dst.assumingMemoryBound(to: UInt8.self), bufSize,
                    src.assumingMemoryBound(to: UInt8.self), data.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard result > 0 else { return nil }
        output.count = result
        return output
    }
}

// MARK: - PMTiles v3 header

struct PMTilesHeader {
    let version: UInt8
    let rootDirOffset: UInt64
    let rootDirLength: UInt64
    let metadataOffset: UInt64
    let metadataLength: UInt64
    let leafDirOffset: UInt64
    let leafDirLength: UInt64
    let dataOffset: UInt64
    let dataLength: UInt64
    let numAddressedTiles: UInt64
    let numTileEntries: UInt64
    let numTileContents: UInt64
    let clustered: Bool
    let internalCompression: UInt8 // 0=none, 1=unknown, 2=gzip, 3=brotli, 4=zstd
    let tileCompression: UInt8
    let tileType: UInt8 // 1=mvt, 2=png, 3=jpeg, 4=webp
    let minZoom: UInt8
    let maxZoom: UInt8
}

struct PMTileEntry {
    let tileID: UInt64
    let offset: UInt64
    let length: UInt64
    let runLength: UInt32
}

// MARK: - Minimal MVT (Mapbox Vector Tile) decoder

enum MVTGeomType: Int { case unknown = 0, point = 1, lineString = 2, polygon = 3 }

struct MVTLayer {
    let name: String
    let features: [MVTFeature]
    let extent: Int
}

struct MVTFeature {
    let type: MVTGeomType
    let rings: [[CGPoint]]  // Each ring is an array of points
}

enum MVTDecoder {
    static func decode(_ data: Data) -> [MVTLayer] {
        let bytes = [UInt8](data)
        var layers: [MVTLayer] = []
        var offset = 0

        while offset < bytes.count {
            let (tag, consumed) = readTag(bytes, at: offset)
            offset += consumed
            guard tag.wireType == 2 else {
                offset += skipField(bytes, at: offset, wireType: tag.wireType)
                continue
            }
            // Field 3 = layers
            if tag.fieldNumber == 3 {
                let (len, lc) = readVarint(bytes, at: offset)
                offset += lc
                if let layer = decodeLayer(bytes, offset: offset, length: Int(len)) {
                    layers.append(layer)
                }
                offset += Int(len)
            } else {
                let (len, lc) = readVarint(bytes, at: offset)
                offset += lc + Int(len)
            }
        }
        return layers
    }

    private static func decodeLayer(_ bytes: [UInt8], offset: Int, length: Int) -> MVTLayer? {
        var pos = offset
        let end = offset + length
        var name = ""
        var extent = 4096
        var features: [MVTFeature] = []

        while pos < end {
            let (tag, tc) = readTag(bytes, at: pos)
            pos += tc

            switch (tag.fieldNumber, tag.wireType) {
            case (1, 2): // name (string)
                let (len, lc) = readVarint(bytes, at: pos)
                pos += lc
                name = String(bytes: bytes[pos..<pos+Int(len)], encoding: .utf8) ?? ""
                pos += Int(len)
            case (2, 2): // features
                let (len, lc) = readVarint(bytes, at: pos)
                pos += lc
                if let f = decodeFeature(bytes, offset: pos, length: Int(len)) {
                    features.append(f)
                }
                pos += Int(len)
            case (5, 0): // extent
                let (val, vc) = readVarint(bytes, at: pos)
                pos += vc
                extent = Int(val)
            default:
                pos += skipField(bytes, at: pos, wireType: tag.wireType)
            }
        }
        guard !features.isEmpty else { return nil }
        return MVTLayer(name: name, features: features, extent: extent)
    }

    private static func decodeFeature(_ bytes: [UInt8], offset: Int, length: Int) -> MVTFeature? {
        var pos = offset
        let end = offset + length
        var geomType: MVTGeomType = .unknown
        var geometry: [UInt32] = []

        while pos < end {
            let (tag, tc) = readTag(bytes, at: pos)
            pos += tc

            switch (tag.fieldNumber, tag.wireType) {
            case (3, 0): // type
                let (val, vc) = readVarint(bytes, at: pos)
                pos += vc
                geomType = MVTGeomType(rawValue: Int(val)) ?? .unknown
            case (4, 2): // geometry (packed uint32)
                let (len, lc) = readVarint(bytes, at: pos)
                pos += lc
                let gEnd = pos + Int(len)
                while pos < gEnd {
                    let (val, vc) = readVarint(bytes, at: pos)
                    pos += vc
                    geometry.append(UInt32(val))
                }
            default:
                pos += skipField(bytes, at: pos, wireType: tag.wireType)
            }
        }

        guard !geometry.isEmpty, geomType != .unknown else { return nil }
        let rings = decodeGeometry(geometry)
        return MVTFeature(type: geomType, rings: rings)
    }

    /// Decode MVT command-encoded geometry into rings of CGPoints
    private static func decodeGeometry(_ commands: [UInt32]) -> [[CGPoint]] {
        var rings: [[CGPoint]] = []
        var currentRing: [CGPoint] = []
        var x: Int32 = 0, y: Int32 = 0
        var i = 0

        while i < commands.count {
            let cmdInt = commands[i]
            let cmd = cmdInt & 0x7
            let count = Int(cmdInt >> 3)
            i += 1

            switch cmd {
            case 1: // MoveTo
                if !currentRing.isEmpty {
                    rings.append(currentRing)
                    currentRing = []
                }
                for _ in 0..<count {
                    guard i + 1 < commands.count else { break }
                    let dx = zigzagDecode(commands[i])
                    let dy = zigzagDecode(commands[i + 1])
                    x += dx; y += dy
                    currentRing.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                    i += 2
                }
            case 2: // LineTo
                for _ in 0..<count {
                    guard i + 1 < commands.count else { break }
                    let dx = zigzagDecode(commands[i])
                    let dy = zigzagDecode(commands[i + 1])
                    x += dx; y += dy
                    currentRing.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                    i += 2
                }
            case 7: // ClosePath
                if !currentRing.isEmpty {
                    currentRing.append(currentRing[0]) // Close
                    rings.append(currentRing)
                    currentRing = []
                }
            default:
                break
            }
        }
        if !currentRing.isEmpty { rings.append(currentRing) }
        return rings
    }

    private static func zigzagDecode(_ n: UInt32) -> Int32 {
        Int32(bitPattern: (n >> 1) ^ (0 &- (n & 1)))
    }

    // MARK: - Protobuf helpers

    private static func readTag(_ bytes: [UInt8], at offset: Int) -> ((fieldNumber: Int, wireType: Int), Int) {
        let (val, consumed) = readVarint(bytes, at: offset)
        return ((fieldNumber: Int(val >> 3), wireType: Int(val & 0x7)), consumed)
    }

    private static func readVarint(_ bytes: [UInt8], at offset: Int) -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var i = offset
        while i < bytes.count {
            let b = bytes[i]
            result |= UInt64(b & 0x7F) << shift
            i += 1
            if b & 0x80 == 0 { break }
            shift += 7
        }
        return (result, i - offset)
    }

    private static func skipField(_ bytes: [UInt8], at offset: Int, wireType: Int) -> Int {
        switch wireType {
        case 0: // varint
            let (_, c) = readVarint(bytes, at: offset)
            return c
        case 1: return 8 // 64-bit
        case 2: // length-delimited
            let (len, c) = readVarint(bytes, at: offset)
            return c + Int(len)
        case 5: return 4 // 32-bit
        default: return 0
        }
    }
}
#endif
