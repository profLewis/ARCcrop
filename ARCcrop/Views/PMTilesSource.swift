#if !os(tvOS)
import UIKit
import Compression

// MARK: - PMTiles URL Protocol for MapLibre

/// Intercepts `http://arccrop-pmtiles.internal/{z}/{x}/{y}/{filename}` URLs
/// and serves raster tiles from a bundled or remote PMTiles v3 archive.
final class PMTilesURLProtocol: URLProtocol {
    static let proxyHost = "arccrop-pmtiles.internal"

    // MARK: - Loaded archives (cached per filename)
    private nonisolated(unsafe) static var archiveCache: [String: PMTilesLocalArchive] = [:]
    private static let archiveLock = NSLock()

    /// Clear cached archive so it's reloaded from disk (e.g. after a new download)
    static func clearCache(for filename: String) {
        archiveLock.lock()
        archiveCache.removeValue(forKey: filename)
        archiveLock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == proxyHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { fail("No URL"); return }

        // URL format: http://arccrop-pmtiles.internal/{z}/{x}/{y}/{filename}
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 4,
              let z = Int(parts[0]), let x = Int(parts[1]), let y = Int(parts[2]) else {
            fail("Invalid PMTiles URL: \(url.path)")
            return
        }
        let filename = parts[3]

        // Load archive from bundle (cached after first load)
        guard let archive = loadArchive(named: filename) else {
            fail("PMTiles archive not found: \(filename)")
            return
        }

        guard let tileData = archive.readTileCorrected(z: z, x: x, y: y) else {
            returnEmpty()
            return
        }

        let headers: [String: String] = [
            "Content-Type": "image/png",
            "Content-Length": "\(tileData.count)",
            "Cache-Control": "max-age=31536000"
        ]
        if let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) {
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .allowed)
        }
        client?.urlProtocol(self, didLoad: tileData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // MARK: - Static entry point (called from WMSTileURLProtocol)

    /// Serve a PMTiles tile on behalf of another URLProtocol instance.
    static func serveTile(
        for request: URLRequest,
        client: URLProtocolClient?,
        protocol proto: URLProtocol,
        filterColors: [(r: UInt8, g: UInt8, b: UInt8)] = [],
        wantsFiltering: Bool = false
    ) {
        guard let url = request.url else {
            client?.urlProtocol(proto, didFailWithError: NSError(
                domain: "PMTilesURLProtocol", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No URL"]))
            return
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 4,
              let z = Int(parts[0]), let x = Int(parts[1]), let y = Int(parts[2]) else {
            client?.urlProtocol(proto, didFailWithError: NSError(
                domain: "PMTilesURLProtocol", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid PMTiles URL: \(url.path)"]))
            return
        }
        let filename = parts[3]

        guard let archive = loadArchiveStatic(named: filename) else {
            client?.urlProtocol(proto, didFailWithError: NSError(
                domain: "PMTilesURLProtocol", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "PMTiles archive not found: \(filename)"]))
            return
        }

        var tileData: Data
        if let data = archive.readTileCorrected(z: z, x: x, y: y) {
            tileData = data
        } else {
            // Empty transparent PNG
            tileData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAABJRUFUeJxjYAAAAAMAAUbRyNIAAAAASUVORK5CYII=")!
        }

        // Apply pixel filtering for hidden legend classes (empty colors = keep nothing)
        if wantsFiltering || !filterColors.isEmpty,
           let filtered = WMSTileURLProtocol.filterPixels(tileData, keeping: filterColors) {
            tileData = filtered
        }

        let headers: [String: String] = [
            "Content-Type": "image/png",
            "Content-Length": "\(tileData.count)",
            "Cache-Control": "max-age=31536000"
        ]
        if let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) {
            client?.urlProtocol(proto, didReceive: resp, cacheStoragePolicy: .allowed)
        }
        client?.urlProtocol(proto, didLoad: tileData)
        client?.urlProtocolDidFinishLoading(proto)
    }

    private static func loadArchiveStatic(named filename: String) -> PMTilesLocalArchive? {
        archiveLock.lock()
        if let cached = archiveCache[filename] {
            archiveLock.unlock()
            return cached
        }
        archiveLock.unlock()

        let name = (filename as NSString).deletingPathExtension
        guard let fileURL = Bundle.main.url(forResource: name, withExtension: "pmtiles"),
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            return nil
        }
        guard let archive = PMTilesLocalArchive(data: data) else { return nil }

        archiveLock.lock()
        archiveCache[filename] = archive
        archiveLock.unlock()
        return archive
    }

    private func returnEmpty() {
        let empty = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAABJRUFUeJxjYAAAAAMAAUbRyNIAAAAASUVORK5CYII=")!
        let headers: [String: String] = ["Content-Type": "image/png", "Content-Length": "\(empty.count)"]
        if let url = request.url,
           let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) {
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: empty)
        client?.urlProtocolDidFinishLoading(self)
    }

    private func fail(_ msg: String) {
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "PMTilesURLProtocol", code: -1,
            userInfo: [NSLocalizedDescriptionKey: msg]))
    }

    private func loadArchive(named filename: String) -> PMTilesLocalArchive? {
        Self.archiveLock.lock()
        if let cached = Self.archiveCache[filename] {
            Self.archiveLock.unlock()
            return cached
        }
        Self.archiveLock.unlock()

        var data: Data?
        let name = (filename as NSString).deletingPathExtension

        // 1. Check app bundle
        if let fileURL = Bundle.main.url(forResource: name, withExtension: "pmtiles") {
            data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        }

        // 2. Check downloaded cache directory
        if data == nil, let cacheURL = RemotePMTilesCache.cacheURL(for: filename) {
            data = try? Data(contentsOf: cacheURL, options: .mappedIfSafe)
        }

        guard let data, let archive = PMTilesLocalArchive(data: data) else { return nil }

        Self.archiveLock.lock()
        Self.archiveCache[filename] = archive
        Self.archiveLock.unlock()
        return archive
    }
}

// MARK: - Remote PMTiles Cache

/// Downloads and caches PMTiles files from remote URLs (e.g. GitHub).
/// Once cached, tiles are served locally by PMTilesURLProtocol.
enum RemotePMTilesCache {
    /// Known remote PMTiles files and their GitHub download URLs
    static let remoteFiles: [String: String] = [
        "newzealand-overview.pmtiles": "https://github.com/profLewis/crome-maps/raw/main/newzealand-overview.pmtiles",
        "dea-landcover-overview.pmtiles": "https://github.com/profLewis/crome-maps/raw/main/dea-landcover-overview.pmtiles",
        "deafrica-crop.pmtiles": "https://github.com/profLewis/crome-maps/raw/main/deafrica-crop.pmtiles",
    ]

    private static var cacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("PMTiles")
    }

    /// Get the local cache path for a PMTiles file (nil if not cached)
    static func cacheURL(for filename: String) -> URL? {
        guard let dir = cacheDir else { return nil }
        let path = dir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    /// Check if a PMTiles file is available locally (bundle or cache)
    static func isAvailable(_ filename: String) -> Bool {
        let name = (filename as NSString).deletingPathExtension
        if Bundle.main.url(forResource: name, withExtension: "pmtiles") != nil { return true }
        return cacheURL(for: filename) != nil
    }

    /// Download a remote PMTiles file to local cache
    static func download(_ filename: String) {
        guard let urlString = remoteFiles[filename],
              let url = URL(string: urlString),
              cacheURL(for: filename) == nil else { return }

        Task.detached(priority: .utility) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200, data.count > 127 else {
                    await MainActor.run {
                        ActivityLog.shared.warn("PMTiles download failed for \(filename) (HTTP \(status))")
                    }
                    return
                }

                guard let dir = cacheDir else { return }
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(filename)
                try data.write(to: dest)

                let sizeKB = data.count / 1024
                await MainActor.run {
                    ActivityLog.shared.success("PMTiles cached: \(filename) (\(sizeKB) KB)")
                    // Clear archive cache to pick up the newly downloaded file
                    PMTilesURLProtocol.clearCache(for: filename)
                }
            } catch {
                await MainActor.run {
                    ActivityLog.shared.warn("PMTiles download error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Local PMTiles v3 archive (memory-mapped from bundle)

final class PMTilesLocalArchive {
    let data: Data
    let header: PMTilesV3Header
    let rootDirectory: Data

    init?(data: Data) {
        guard data.count >= 127,
              String(data: data[0..<7], encoding: .ascii) == "PMTiles" else { return nil }
        self.data = data

        self.header = PMTilesV3Header(
            version: data[7],
            rootDirOffset: Self.readU64(data, at: 8),
            rootDirLength: Self.readU64(data, at: 16),
            metadataOffset: Self.readU64(data, at: 24),
            metadataLength: Self.readU64(data, at: 32),
            leafDirOffset: Self.readU64(data, at: 40),
            leafDirLength: Self.readU64(data, at: 48),
            dataOffset: Self.readU64(data, at: 56),
            dataLength: Self.readU64(data, at: 64),
            numAddressedTiles: Self.readU64(data, at: 72),
            numTileEntries: Self.readU64(data, at: 80),
            numTileContents: Self.readU64(data, at: 88),
            clustered: data[96] == 1,
            internalCompression: data[97],
            tileCompression: data[98],
            tileType: data[99],
            minZoom: data[100],
            maxZoom: data[101]
        )

        let rootStart = Int(header.rootDirOffset)
        let rootEnd = rootStart + Int(header.rootDirLength)
        guard rootEnd <= data.count else { return nil }
        let raw = Data(data[rootStart..<rootEnd])
        if header.internalCompression == 2 {
            guard let decompressed = Self.gunzip(raw) else { return nil }
            self.rootDirectory = decompressed
        } else {
            self.rootDirectory = raw
        }
    }

    func readTile(id: UInt64) -> Data? {
        guard let entry = findTile(id: id) else { return nil }
        let offset = Int(header.dataOffset + entry.offset)
        let length = Int(entry.length)
        guard offset + length <= data.count else { return nil }

        let raw = Data(data[offset..<(offset + length)])
        if header.tileCompression == 2 {
            return Self.gunzip(raw) ?? raw
        }
        return raw
    }

    /// Read a tile by z/x/y coordinates.
    func readTileCorrected(z: Int, x: Int, y: Int) -> Data? {
        let tileID = Self.zxyToTileID(z: z, x: x, y: y)
        return readTile(id: tileID)
    }

    private func findTile(id: UInt64, directory: Data? = nil, depth: Int = 0) -> (offset: UInt64, length: UInt64)? {
        guard depth < 4 else { return nil }
        let dir = directory ?? rootDirectory
        let entries = Self.parseDirectory(dir)
        guard !entries.isEmpty else { return nil }

        var lo = 0, hi = entries.count - 1, matchIdx = -1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if entries[mid].tileID <= id { matchIdx = mid; lo = mid + 1 }
            else { hi = mid - 1 }
        }
        guard matchIdx >= 0 else { return nil }
        let e = entries[matchIdx]

        if e.runLength == 0 {
            // Leaf directory
            let leafStart = Int(header.leafDirOffset + e.offset)
            let leafEnd = leafStart + Int(e.length)
            guard leafEnd <= data.count else { return nil }
            let raw = Data(data[leafStart..<leafEnd])
            let leafDir = header.internalCompression == 2 ? (Self.gunzip(raw) ?? raw) : raw
            return findTile(id: id, directory: leafDir, depth: depth + 1)
        }

        guard id < e.tileID + UInt64(e.runLength) else { return nil }
        return (offset: e.offset, length: e.length)
    }

    // MARK: - ZXY → Hilbert tile ID

    static func zxyToTileID(z: Int, x: Int, y: Int) -> UInt64 {
        if z == 0 { return 0 }
        var acc: UInt64 = 0
        for i in 0..<z { acc += UInt64(1) << (2 * i) }
        let n = 1 << z
        return acc + UInt64(xyToHilbert(x: x, y: y, order: n))
    }

    private static func xyToHilbert(x: Int, y: Int, order: Int) -> Int {
        var rx = 0, ry = 0, d = 0
        var x = x, y = y, s = order / 2
        while s > 0 {
            rx = (x & s) > 0 ? 1 : 0
            ry = (y & s) > 0 ? 1 : 0
            d += s * s * ((3 * rx) ^ ry)
            if ry == 0 {
                if rx == 1 { x = s - 1 - x; y = s - 1 - y }
                let t = x; x = y; y = t
            }
            s /= 2
        }
        return d
    }

    // MARK: - Directory parsing

    static func parseDirectory(_ data: Data) -> [(tileID: UInt64, offset: UInt64, length: UInt64, runLength: UInt32)] {
        let bytes = [UInt8](data)
        var offset = 0

        let (numEntries, c0) = readVarint(bytes, at: offset); offset += c0

        var tileIDs: [UInt64] = []
        var lastID: UInt64 = 0
        for _ in 0..<numEntries {
            let (delta, c) = readVarint(bytes, at: offset); offset += c
            lastID += delta; tileIDs.append(lastID)
        }

        var runLengths: [UInt32] = []
        for _ in 0..<numEntries {
            let (val, c) = readVarint(bytes, at: offset); offset += c
            runLengths.append(UInt32(val))
        }

        var lengths: [UInt64] = []
        for _ in 0..<numEntries {
            let (val, c) = readVarint(bytes, at: offset); offset += c
            lengths.append(val)
        }

        var offsets: [UInt64] = []
        var lastOffset: UInt64 = 0
        for i in 0..<Int(numEntries) {
            let (delta, c) = readVarint(bytes, at: offset); offset += c
            if delta == 0 && i > 0 { lastOffset += lengths[i - 1] }
            else { lastOffset = delta - 1 }
            offsets.append(lastOffset)
        }

        return (0..<Int(numEntries)).map { i in
            (tileID: tileIDs[i], offset: offsets[i], length: lengths[i], runLength: runLengths[i])
        }
    }

    private static func readVarint(_ bytes: [UInt8], at offset: Int) -> (UInt64, Int) {
        var result: UInt64 = 0; var shift = 0; var i = offset
        while i < bytes.count {
            let b = bytes[i]; result |= UInt64(b & 0x7F) << shift; i += 1
            if b & 0x80 == 0 { break }; shift += 7
        }
        return (result, i - offset)
    }

    // MARK: - Helpers

    private static func readU64(_ data: Data, at offset: Int) -> UInt64 {
        data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self).littleEndian }
    }

    static func gunzip(_ data: Data) -> Data? {
        guard data.count > 10, data[0] == 0x1f, data[1] == 0x8b else {
            return inflate(data)
        }
        var offset = 10
        let flags = data[3]
        if flags & 0x04 != 0 {
            guard offset + 2 <= data.count else { return nil }
            let xlen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + xlen
        }
        if flags & 0x08 != 0 { while offset < data.count && data[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x10 != 0 { while offset < data.count && data[offset] != 0 { offset += 1 }; offset += 1 }
        if flags & 0x02 != 0 { offset += 2 }
        guard offset < data.count else { return nil }
        return inflate(Data(data[offset...]))
    }

    private static func inflate(_ data: Data) -> Data? {
        let bufSize = 1024 * 1024
        var output = Data(count: bufSize)
        let result = data.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                guard let s = src.baseAddress, let d = dst.baseAddress else { return 0 }
                return compression_decode_buffer(
                    d.assumingMemoryBound(to: UInt8.self), bufSize,
                    s.assumingMemoryBound(to: UInt8.self), data.count,
                    nil, COMPRESSION_ZLIB)
            }
        }
        guard result > 0 else { return nil }
        output.count = result
        return output
    }
}

struct PMTilesV3Header {
    let version: UInt8
    let rootDirOffset, rootDirLength: UInt64
    let metadataOffset, metadataLength: UInt64
    let leafDirOffset, leafDirLength: UInt64
    let dataOffset, dataLength: UInt64
    let numAddressedTiles, numTileEntries, numTileContents: UInt64
    let clustered: Bool
    let internalCompression: UInt8
    let tileCompression: UInt8
    let tileType: UInt8
    let minZoom: UInt8
    let maxZoom: UInt8
}
#endif
