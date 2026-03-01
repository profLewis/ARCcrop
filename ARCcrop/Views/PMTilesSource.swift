#if !os(tvOS)
import UIKit
import Compression

// MARK: - PMTiles URL Protocol for MapLibre

/// Intercepts `pmtiles://` URLs and serves raster tiles from a remote PMTiles v3 archive
/// via HTTP range requests. Tile URL format: `pmtiles://host/path#z/x/y`
final class PMTilesURLProtocol: URLProtocol {
    private var dataTask: URLSessionDataTask?

    /// Shared session with aggressive caching (tiles are immutable)
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        let cache = URLCache(memoryCapacity: 30_000_000, diskCapacity: 200_000_000)
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    // MARK: - Loaded archive metadata (cached per URL)
    private nonisolated(unsafe) static var archiveCache: [String: PMTilesArchive] = [:]
    private static let archiveLock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "pmtiles"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            fail("Invalid pmtiles URL")
            return
        }

        // URL format: pmtiles://host/path/to/file.pmtiles/{z}/{x}/{y}
        // Extract z/x/y from the last 3 path components
        let pathParts = url.pathComponents.filter { $0 != "/" }
        guard pathParts.count >= 4,
              let y = Int(pathParts[pathParts.count - 1]),
              let x = Int(pathParts[pathParts.count - 2]),
              let z = Int(pathParts[pathParts.count - 3]) else {
            fail("Invalid pmtiles URL: need /file.pmtiles/{z}/{x}/{y}")
            return
        }

        // Build HTTPS URL to the .pmtiles file (without z/x/y suffix)
        let fileParts = pathParts.dropLast(3)
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = url.host
        comps.path = "/" + fileParts.joined(separator: "/")
        guard let httpsURL = comps.url else {
            fail("Cannot build HTTPS URL")
            return
        }

        let archiveKey = httpsURL.absoluteString

        // Load archive header if needed
        Self.archiveLock.lock()
        let cached = Self.archiveCache[archiveKey]
        Self.archiveLock.unlock()

        if let archive = cached {
            serveTile(z: z, x: x, y: y, archive: archive)
        } else {
            // Fetch header (first 16KB)
            fetchHeader(httpsURL: httpsURL, key: archiveKey) { [weak self] archive in
                guard let self, let archive else {
                    self?.fail("Failed to load PMTiles header")
                    return
                }
                self.serveTile(z: z, x: x, y: y, archive: archive)
            }
        }
    }

    override func stopLoading() {
        dataTask?.cancel()
    }

    // MARK: - Serve a tile

    private func serveTile(z: Int, x: Int, y: Int, archive: PMTilesArchive) {
        let tileID = PMTilesArchive.zxyToTileID(z: z, x: x, y: y)

        guard let entry = archive.findTile(id: tileID) else {
            // No tile at this location — return empty transparent PNG
            returnEmpty()
            return
        }

        let offset = archive.header.dataOffset + entry.offset
        let length = entry.length

        Self.fetchRange(from: archive.url, offset: offset, length: length) { [weak self] data in
            guard let self, let data else {
                self?.returnEmpty()
                return
            }

            // Decompress if needed
            let tileData: Data
            if archive.header.tileCompression == 2 { // gzip
                tileData = Self.gunzip(data) ?? data
            } else {
                tileData = data
            }

            let headers: [String: String] = [
                "Content-Type": "image/png",
                "Content-Length": "\(tileData.count)",
                "Cache-Control": "max-age=31536000" // 1 year (immutable tiles)
            ]
            if let url = self.request.url,
               let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) {
                self.client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .allowed)
            }
            self.client?.urlProtocol(self, didLoad: tileData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    private func returnEmpty() {
        // 1x1 transparent PNG
        let empty = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAABJREFUeJxjYAAAAAMAAUbRyNIAAAAASUVORK5CYII=")!
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

    // MARK: - Header loading

    private func fetchHeader(httpsURL: URL, key: String, completion: @escaping (PMTilesArchive?) -> Void) {
        Self.fetchRange(from: httpsURL, offset: 0, length: 16384) { [weak self] data in
            guard let data, data.count >= 127 else {
                completion(nil)
                return
            }

            let magic = data[0..<7]
            guard String(data: magic, encoding: .ascii) == "PMTiles" else {
                completion(nil)
                return
            }

            let h = PMTilesV3Header(
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

            // Parse root directory
            let rootEnd = Int(h.rootDirOffset + h.rootDirLength)
            let rootDir: Data?
            if rootEnd <= data.count {
                let raw = Data(data[Int(h.rootDirOffset)..<rootEnd])
                rootDir = h.internalCompression == 2 ? Self.gunzip(raw) : raw
            } else {
                // Need separate fetch
                let sem = DispatchSemaphore(value: 0)
                var fetched: Data?
                Self.fetchRange(from: httpsURL, offset: h.rootDirOffset, length: h.rootDirLength) { d in
                    fetched = d
                    sem.signal()
                }
                sem.wait()
                if let f = fetched {
                    rootDir = h.internalCompression == 2 ? Self.gunzip(f) : f
                } else {
                    rootDir = nil
                }
            }

            guard let rootDir else { completion(nil); return }

            let archive = PMTilesArchive(url: httpsURL, header: h, rootDirectory: rootDir)

            Self.archiveLock.lock()
            Self.archiveCache[key] = archive
            Self.archiveLock.unlock()

            completion(archive)
        }
    }

    // MARK: - HTTP range requests

    static func fetchRange(from url: URL, offset: UInt64, length: UInt64, completion: @escaping (Data?) -> Void) {
        var req = URLRequest(url: url)
        req.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        req.timeoutInterval = 15
        req.cachePolicy = .returnCacheDataElseLoad

        session.dataTask(with: req) { data, response, _ in
            if let data, let http = response as? HTTPURLResponse,
               http.statusCode == 206 || http.statusCode == 200 {
                completion(data)
            } else {
                completion(nil)
            }
        }.resume()
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

// MARK: - PMTiles v3 archive

final class PMTilesArchive {
    let url: URL
    let header: PMTilesV3Header
    let rootDirectory: Data
    private var leafCache: [UInt64: Data] = [:]
    private let leafLock = NSLock()

    init(url: URL, header: PMTilesV3Header, rootDirectory: Data) {
        self.url = url
        self.header = header
        self.rootDirectory = rootDirectory
    }

    func findTile(id: UInt64, directory: Data? = nil, depth: Int = 0) -> (offset: UInt64, length: UInt64)? {
        guard depth < 4 else { return nil }
        let dir = directory ?? rootDirectory
        let entries = Self.parseDirectory(dir)
        guard !entries.isEmpty else { return nil }

        // Binary search
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
            let leafOffset = header.leafDirOffset + e.offset
            guard let leafDir = fetchLeafSync(offset: leafOffset, length: e.length) else { return nil }
            return findTile(id: id, directory: leafDir, depth: depth + 1)
        }

        guard id < e.tileID + UInt64(e.runLength) else { return nil }
        return (offset: e.offset, length: e.length)
    }

    private func fetchLeafSync(offset: UInt64, length: UInt64) -> Data? {
        leafLock.lock()
        if let cached = leafCache[offset] { leafLock.unlock(); return cached }
        leafLock.unlock()

        let sem = DispatchSemaphore(value: 0)
        var result: Data?
        PMTilesURLProtocol.fetchRange(from: url, offset: offset, length: length) { data in
            result = data
            sem.signal()
        }
        sem.wait()

        guard let raw = result else { return nil }
        let dir = header.internalCompression == 2 ? (PMTilesURLProtocol.gunzip(raw) ?? raw) : raw

        leafLock.lock()
        leafCache[offset] = dir
        leafLock.unlock()
        return dir
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
