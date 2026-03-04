#if !os(tvOS)
import UIKit

// MARK: - WMS Source Parameters for MapLibre

/// Parameters for creating an MLNRasterTileSource from a WMS endpoint.
struct WMSSourceParams {
    let identifier: String
    let tileURLTemplate: String
    let minZoom: Int
    let maxZoom: Int
    /// Whether this source needs EPSG:4326 (server rejects 3857)
    let needs4326: Bool

    /// The maximum zoom level MapLibre should use for the tile source.
    /// For WMS sources the server renders any bbox on-the-fly, so we can
    /// go higher than maxZoom without 404s. For XYZ tile sources we must
    /// stay at maxZoom because tiles beyond that don't exist.
    var effectiveMaxZoom: Int {
        // XYZ tile sources use {z}/{y}/{x} — don't overshoot their maxZoom
        if tileURLTemplate.contains("{z}") { return maxZoom }
        // WMS/bbox sources: allow MapLibre to request tiles up to z18 or
        // the source maxZoom, whichever is higher.  The server generates
        // each tile on-the-fly at whatever bbox we send.
        return max(maxZoom, 22)
    }
}

// MARK: - WMS Tile URLProtocol

/// Intercepts `arccrop-wms://` URLs for two purposes:
/// 1. **EPSG:4326 reprojection**: converts 3857 bbox to 4326
/// 2. **Per-pixel class filtering**: makes pixels transparent for hidden legend classes
///
/// URL format: `arccrop-wms://t/{bbox-epsg-3857}/BASE64URL?filter=R,G,B|...&crs4326=1`
/// - MapLibre substitutes `{bbox-epsg-3857}` in the path
/// - BASE64URL encodes the real WMS URL (with BBOX= placeholder)
/// - `filter` query param: pipe-separated RGB triples to make transparent
/// - `crs4326` query param: if present, reproject bbox to EPSG:4326
final class WMSTileURLProtocol: URLProtocol, @unchecked Sendable {
    /// Fake HTTP host that signals this request should be intercepted.
    /// Uses http:// so MapLibre's networking layer passes it through to NSURLSession.
    static let proxyHost = "arccrop-filter.internal"
    private var dataTask: URLSessionDataTask?

    /// Shared session for fetching original tiles (does NOT include this protocol class
    /// to avoid infinite recursion).
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 128 * 1024 * 1024, diskCapacity: 1024 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        let host = request.url?.host
        return host == proxyHost || host == PMTilesURLProtocol.proxyHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            fail(msg: "No URL")
            return
        }

        // Delegate to PMTilesURLProtocol for pmtiles requests
        if url.host == PMTilesURLProtocol.proxyHost {
            // Parse keep colors from query params (only these colors stay visible)
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let hasKeep = comps?.queryItems?.contains { $0.name == "keep" } ?? false
            var pmtilesKeepColors: [(r: UInt8, g: UInt8, b: UInt8)] = []
            if let keepParam = comps?.queryItems?.first(where: { $0.name == "keep" })?.value, !keepParam.isEmpty {
                for rgb in keepParam.split(separator: "|") {
                    let parts = rgb.split(separator: ",")
                    if parts.count == 3,
                       let r = UInt8(parts[0]), let g = UInt8(parts[1]), let b = UInt8(parts[2]) {
                        pmtilesKeepColors.append((r: r, g: g, b: b))
                    }
                }
            }
            PMTilesURLProtocol.serveTile(
                for: request, client: client, protocol: self,
                filterColors: pmtilesKeepColors, wantsFiltering: hasKeep)
            return
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // Parse query params (shared by both paths)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let needs4326 = queryItems.contains { $0.name == "crs4326" }
        let hasKeepFilter = queryItems.contains { $0.name == "keep" }

        // Parse keep colors (only these colors stay visible when filtering)
        var filterColors: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if let filterParam = queryItems.first(where: { $0.name == "keep" })?.value, !filterParam.isEmpty {
            for rgb in filterParam.split(separator: "|") {
                let parts = rgb.split(separator: ",")
                if parts.count == 3,
                   let r = UInt8(parts[0]), let g = UInt8(parts[1]), let b = UInt8(parts[2]) {
                    filterColors.append((r: r, g: g, b: b))
                }
            }
        }

        var realURLString: String
        var bboxString: String? // only set for WMS/bbox paths

        if pathComponents.first == "xyz", pathComponents.count >= 5 {
            // XYZ tile path: ["xyz", z, y, x, base64_encoded_url]
            let z = pathComponents[1], y = pathComponents[2], x = pathComponents[3]
            let base64Part = pathComponents[4]
            let base64 = base64Part
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
            guard let data = Data(base64Encoded: padded),
                  var template = String(data: data, encoding: .utf8) else {
                fail(msg: "Failed to decode base64 (xyz)")
                return
            }
            template = template.replacingOccurrences(of: "PROXY_Z", with: z)
            template = template.replacingOccurrences(of: "PROXY_Y", with: y)
            template = template.replacingOccurrences(of: "PROXY_X", with: x)
            realURLString = template
        } else if pathComponents.first == "t", pathComponents.count >= 3 {
            // WMS/bbox path: ["t", bbox_string, base64_encoded_url]
            bboxString = pathComponents[1]
            let base64Part = pathComponents[2]
            let base64 = base64Part
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
            guard let data = Data(base64Encoded: padded),
                  var template = String(data: data, encoding: .utf8) else {
                fail(msg: "Failed to decode base64")
                return
            }
            // Substitute bbox placeholder (case-insensitive for non-WMS REST APIs)
            template = template.replacingOccurrences(
                of: "BBOX=PROXY_BBOX", with: "BBOX=\(bboxString!)", options: .caseInsensitive)
            realURLString = template

            // 4326 reprojection
            if needs4326 {
                realURLString = Self.reproject3857to4326(realURLString, bbox: bboxString!)
            }
        } else {
            fail(msg: "Invalid proxy path: \(url.path)")
            return
        }

        guard let realURL = URL(string: realURLString) else {
            fail(msg: "Invalid URL: \(realURLString)")
            return
        }

        // Fetch original tile — always cache the originals aggressively
        var req = URLRequest(url: realURL)
        req.cachePolicy = .returnCacheDataElseLoad

        let fetchStart = CFAbsoluteTimeGetCurrent()
        let sourceHost = realURL.host ?? "unknown"

        dataTask = Self.session.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }
            let elapsed = CFAbsoluteTimeGetCurrent() - fetchStart

            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                Task { @MainActor in
                    ActivityLog.shared.warn("\(sourceHost): failed (\(error.localizedDescription))")
                }
                return
            }
            guard var tileData = data else {
                self.fail(msg: "No tile data")
                return
            }

            // Determine if response came from cache
            let httpResponse = response as? HTTPURLResponse
            let fromCache = Self.session.configuration.urlCache?
                .cachedResponse(for: req) != nil
            let tileBytes = tileData.count
            let sizeKB = Double(tileBytes) / 1024.0
            let cacheLabel = fromCache ? "cache" : "network"
            let status = httpResponse?.statusCode ?? 0

            // Detect auth failures and surface a helpful message
            if status == 401 || status == 403 {
                Task { @MainActor in
                    ActivityLog.shared.error("\(sourceHost): access denied (HTTP \(status)). Your API key may be invalid or expired — check Settings to update it.")
                }
                self.fail(msg: "Access denied (HTTP \(status))")
                return
            }

            // Log tile fetch details
            Task { @MainActor in
                ActivityLog.shared.tileCompleted(bytes: tileBytes)
                ActivityLog.shared.info(String(
                    format: "%@ %dKB %.1fs [%@] %d",
                    sourceHost, Int(sizeKB), elapsed, cacheLabel, status))
            }

            // Reproject tile from 4326 back to 3857 if needed
            if needs4326, let bbox = bboxString, let reprojected = Self.reprojectTile4326to3857(tileData, mercBbox: bbox) {
                tileData = reprojected
            }

            // Apply pixel filtering if keep= param was present (empty = keep nothing)
            if hasKeepFilter, let filtered = Self.filterPixels(tileData, keeping: filterColors) {
                tileData = filtered
            }

            // Return with cache-friendly headers
            let headers: [String: String] = [
                "Content-Type": "image/png",
                "Content-Length": "\(tileData.count)",
                "Cache-Control": "max-age=604800"  // 7 days
            ]
            if let httpResp = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers
            ) {
                self.client?.urlProtocol(self, didReceive: httpResp, cacheStoragePolicy: .allowed)
            }
            self.client?.urlProtocol(self, didLoad: tileData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
    }

    private func fail(msg: String) {
        client?.urlProtocol(self, didFailWithError: NSError(
            domain: "WMSTileURLProtocol", code: -1,
            userInfo: [NSLocalizedDescriptionKey: msg]))
    }

    // MARK: EPSG:3857 → 4326 reprojection

    private static func reproject3857to4326(_ urlString: String, bbox: String) -> String {
        let parts = bbox.split(separator: ",")
        guard parts.count == 4,
              let x1 = Double(parts[0]), let y1 = Double(parts[1]),
              let x2 = Double(parts[2]), let y2 = Double(parts[3]) else {
            return urlString
        }

        let a = 20037508.342789244
        let lon1 = x1 / a * 180.0
        let lon2 = x2 / a * 180.0
        let lat1 = (2 * atan(exp(y1 / a * Double.pi)) - Double.pi / 2) * 180.0 / Double.pi
        let lat2 = (2 * atan(exp(y2 / a * Double.pi)) - Double.pi / 2) * 180.0 / Double.pi

        let newBbox = String(format: "%.8f,%.8f,%.8f,%.8f", lon1, lat1, lon2, lat2)
        var result = urlString.replacingOccurrences(
            of: "BBOX=\(bbox)", with: "BBOX=\(newBbox)")
        result = result.replacingOccurrences(of: "SRS=EPSG:3857", with: "SRS=EPSG:4326")
        result = result.replacingOccurrences(of: "CRS=EPSG:3857", with: "CRS=EPSG:4326")
        return result
    }

    // MARK: 4326 → 3857 tile reprojection (pixel-level)

    /// Reproject a tile image received in EPSG:4326 into EPSG:3857.
    /// Uses nearest-neighbor (correct for classified/categorical raster data).
    /// `mercBbox` is the original 3857 bbox string "x1,y1,x2,y2".
    private static func reprojectTile4326to3857(_ pngData: Data, mercBbox: String) -> Data? {
        let bboxParts = mercBbox.split(separator: ",")
        guard bboxParts.count == 4,
              let mx1 = Double(bboxParts[0]), let my1 = Double(bboxParts[1]),
              let mx2 = Double(bboxParts[2]), let my2 = Double(bboxParts[3]) else { return nil }

        guard let image = UIImage(data: pngData), let cgImage = image.cgImage else { return nil }
        let size = 256
        let srcW = cgImage.width, srcH = cgImage.height
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

        // Read source pixels
        guard let srcCtx = CGContext(
            data: nil, width: srcW, height: srcH, bitsPerComponent: 8, bytesPerRow: srcW * 4,
            space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let srcData = srcCtx.data else { return nil }
        srcCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
        let srcPixels = srcData.bindMemory(to: UInt8.self, capacity: srcW * srcH * 4)

        // Create output
        guard let outCtx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outData = outCtx.data else { return nil }
        let outPixels = outData.bindMemory(to: UInt8.self, capacity: size * size * 4)

        // 4326 bbox (what the WMS server delivered)
        let a = 20037508.342789244
        let lon1 = mx1 / a * 180.0
        let lon2 = mx2 / a * 180.0
        let lat1 = (2 * atan(exp(my1 / a * .pi)) - .pi / 2) * 180.0 / .pi
        let lat2 = (2 * atan(exp(my2 / a * .pi)) - .pi / 2) * 180.0 / .pi

        for oy in 0..<size {
            // Map output pixel row to 3857 Y coordinate
            let yFrac = (Double(oy) + 0.5) / Double(size)
            let mercY = my2 - yFrac * (my2 - my1)  // top to bottom
            // Convert 3857 Y → latitude
            let lat = (2 * atan(exp(mercY / a * .pi)) - .pi / 2) * 180.0 / .pi
            // Map latitude to source row (lat2 at top row 0, lat1 at bottom row srcH-1)
            let srcRowFrac = (lat2 - lat) / (lat2 - lat1)
            let srcRow = min(max(Int(srcRowFrac * Double(srcH)), 0), srcH - 1)

            for ox in 0..<size {
                let xFrac = (Double(ox) + 0.5) / Double(size)
                let lon = lon1 + xFrac * (lon2 - lon1)
                let srcColFrac = (lon - lon1) / (lon2 - lon1)
                let srcCol = min(max(Int(srcColFrac * Double(srcW)), 0), srcW - 1)

                let si = (srcRow * srcW + srcCol) * 4
                let oi = (oy * size + ox) * 4
                outPixels[oi]     = srcPixels[si]
                outPixels[oi + 1] = srcPixels[si + 1]
                outPixels[oi + 2] = srcPixels[si + 2]
                outPixels[oi + 3] = srcPixels[si + 3]
            }
        }

        guard let result = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: result).pngData()
    }

    // MARK: Per-pixel filtering

    /// Filter pixels using "keep mode": only pixels matching the given VISIBLE colors
    /// are kept; everything else is made transparent.
    /// This correctly handles anti-aliased/blended pixels at low zoom — they don't match
    /// any visible class, so they're hidden along with the explicitly hidden classes.
    static func filterPixels(_ pngData: Data, keeping colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> Data? {
        guard let image = UIImage(data: pngData), let cgImage = image.cgImage else { return nil }
        let w = cgImage.width, h = cgImage.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let pixels = ctx.data else { return nil }
        let buf = pixels.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // Build histogram of actual pixel colors in this tile
        var colorHistogram: [UInt32: Int] = [:]
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if buf[i + 3] == 0 { continue }
            let key = UInt32(buf[i]) << 16 | UInt32(buf[i + 1]) << 8 | UInt32(buf[i + 2])
            colorHistogram[key, default: 0] += 1
        }

        // For each actual pixel color, check if it's close to ANY keep color.
        // Colors that match a visible class are KEPT; everything else is hidden.
        var keepColors: Set<UInt32> = []
        for (key, _) in colorHistogram {
            let r = Int(key >> 16 & 0xFF)
            let g = Int(key >> 8 & 0xFF)
            let b = Int(key & 0xFF)
            for (tr, tg, tb) in colors {
                let dist = abs(r - Int(tr)) + abs(g - Int(tg)) + abs(b - Int(tb))
                if dist < 100 {
                    keepColors.insert(key)
                    break
                }
            }
        }

        // Hide pixels NOT matching any visible class
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if buf[i + 3] == 0 { continue }
            let key = UInt32(buf[i]) << 16 | UInt32(buf[i + 1]) << 8 | UInt32(buf[i + 2])
            if !keepColors.contains(key) {
                buf[i + 3] = 0
            }
        }

        guard let result = ctx.makeImage() else { return nil }
        return UIImage(cgImage: result).pngData()
    }
}

// MARK: - Overlay Factory

enum CropMapOverlayFactory {

    /// Build a WMS GetMap URL template.
    /// Uses `PROXY_BBOX` placeholder (replaced by URLProtocol with actual bbox).
    /// For direct (non-proxy) use, `{bbox-epsg-3857}` goes in the BBOX param.
    private static func wmsTemplate(
        baseURL: String, layers: String,
        format: String = "image/png",
        styles: String = "",
        extraParams: String = "",
        wmsVersion: String = "1.1.1",
        useProxy: Bool = false
    ) -> String {
        let srsParam = wmsVersion == "1.3.0" ? "CRS" : "SRS"
        let bboxToken = useProxy ? "PROXY_BBOX" : "{bbox-epsg-3857}"
        var url = "\(baseURL)?SERVICE=WMS&VERSION=\(wmsVersion)&REQUEST=GetMap" +
            "&LAYERS=\(layers)&\(srsParam)=EPSG:3857&BBOX=\(bboxToken)" +
            "&WIDTH=256&HEIGHT=256&FORMAT=\(format)&TRANSPARENT=TRUE&STYLES=\(styles)"
        if !extraParams.isEmpty { url += "&\(extraParams)" }
        return url
    }

    /// Wrap a WMS URL template in the arccrop-wms:// proxy scheme.
    /// Format: `arccrop-wms://t/{bbox-epsg-3857}/BASE64URL?keep=...&crs4326=1`
    static func proxyURL(template: String, needs4326: Bool, filterColors: [(r: UInt8, g: UInt8, b: UInt8)] = []) -> String {
        // Base64url-encode the real URL template (contains PROXY_BBOX placeholder)
        let base64 = Data(template.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Use http:// with a fake hostname so MapLibre's networking passes it to NSURLSession.
        // {bbox-epsg-3857} goes in the path so MapLibre substitutes it.
        var proxyURL = "http://\(WMSTileURLProtocol.proxyHost)/t/{bbox-epsg-3857}/\(base64)"

        var queryParts: [String] = []
        if needs4326 { queryParts.append("crs4326=1") }
        // Always add keep= when filterColors is provided (empty = keep nothing = all transparent)
        let colorStr = filterColors.map { "\($0.r),\($0.g),\($0.b)" }.joined(separator: "|")
        queryParts.append("keep=\(colorStr)")
        if !queryParts.isEmpty {
            proxyURL += "?" + queryParts.joined(separator: "&")
        }
        return proxyURL
    }

    /// Wrap an XYZ tile URL template in the proxy scheme for per-pixel filtering.
    /// Format: `http://host/xyz/{z}/{y}/{x}/BASE64?keep=...`
    static func xyzProxyURL(template: String, filterColors: [(r: UInt8, g: UInt8, b: UInt8)]) -> String {
        // Replace {z},{y},{x} with PROXY placeholders before base64-encoding
        let proxyTemplate = template
            .replacingOccurrences(of: "{z}", with: "PROXY_Z")
            .replacingOccurrences(of: "{y}", with: "PROXY_Y")
            .replacingOccurrences(of: "{x}", with: "PROXY_X")

        let base64 = Data(proxyTemplate.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // {z},{y},{x} go in the path so MapLibre substitutes them
        var proxyURL = "http://\(WMSTileURLProtocol.proxyHost)/xyz/{z}/{y}/{x}/\(base64)"

        // Always add keep= (empty = keep nothing = all transparent)
        let colorStr = filterColors.map { "\($0.r),\($0.g),\($0.b)" }.joined(separator: "|")
        proxyURL += "?keep=\(colorStr)"
        return proxyURL
    }

    /// Create WMS source parameters for a crop map source.
    /// Returns nil for sources that are not WMS-based (GEOGLAM, auth-required, etc.)
    static func sourceParams(for source: CropMapSource) -> WMSSourceParams? {
        switch source {
        case .usdaCDL(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi",
                    layers: "cdl_\(year)"),
                minZoom: 0, maxZoom: 17, needs4326: true)

        case .jrcEUCropMap(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap",
                    layers: "LC.EUCROPMAP.\(year)"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .cromeEngland(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://environment.data.gov.uk/spatialdata/crop-map-of-england-\(year)/wms",
                    layers: "Crop_Map_of_England_\(year)"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .dlrCropTypes:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geoservice.dlr.de/eoc/land/wms",
                    layers: "CROPTYPES_DE_P1Y",
                    styles: "croptypes"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .rpgFrance:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://data.geopf.fr/wms-r/wms",
                    layers: "LANDUSE.AGRICULTURE.LATEST",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .brpNetherlands:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0",
                    layers: "BrpGewas",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .aafcCanada(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://www.agr.gc.ca/imagery-images/services/annual_crop_inventory/\(year)/ImageServer/WMSServer",
                    layers: "\(year):annual_crop_inventory"),
                minZoom: 0, maxZoom: 17, needs4326: false)

        case .esaWorldCover(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://services.terrascope.be/wms/v2",
                    layers: "WORLDCOVER_\(year)_MAP"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .worldCereal:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://services.terrascope.be/wms/v2",
                    layers: "WORLDCEREAL_TEMPORARYCROPS_V1"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .worldCerealMaize:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://services.terrascope.be/wms/v2",
                    layers: "WORLDCEREAL_MAIZE_V1"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .worldCerealWinterCereals:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://services.terrascope.be/wms/v2",
                    layers: "WORLDCEREAL_WINTERCEREALS_V1"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .worldCerealSpringCereals:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://services.terrascope.be/wms/v2",
                    layers: "WORLDCEREAL_SPRINGCEREALS_V1"),
                minZoom: 0, maxZoom: 18, needs4326: false)

        case .invekosAustria:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://inspire.lfrz.gv.at/009501/wms",
                    layers: "inspire_feldstuecke_2025-2",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .alvFlanders:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geo.api.vlaanderen.be/ALV/wms",
                    layers: "LbGebrPerc2024",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .sigpacSpain:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://wms.mapa.gob.es/sigpac/wms",
                    layers: "AU.Sigpac:recinto"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .fvmDenmark:
            // Use Jordbrugsanalyser namespace which has crop-type coloring
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geodata.fvm.dk/geoserver/ows",
                    layers: "Jordbrugsanalyser:Marker24",
                    styles: "Marker"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .lpisCzechia:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://mze.gov.cz/public/app/wms/public_DPB_PB_OPV.fcgi",
                    layers: "DPB_UCINNE"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .gerkSlovenia:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://storitve.eprostor.gov.si/ows-pub-wms/SI.MKGP.GERK/ows",
                    layers: "RKG_BLOK_GERK",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .arkodCroatia:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://servisi.apprrr.hr/NIPP/wms",
                    layers: "hr.land_parcels"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .gsaaEstonia:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://kls.pria.ee/geoserver/inspire_gsaa/wms",
                    layers: "LU.GSAA.AGRICULTURAL_PARCELS",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .latviaFieldBlocks:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://karte.lad.gov.lv/arcgis/services/lauku_bloki/MapServer/WMSServer",
                    layers: "0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .ifapPortugal:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://www.ifap.pt/isip/ows/isip.data/wms",
                    layers: "isip.data:ocupacoes.solo.Centro_N.2017jun10",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .lpisPoland:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://mapy.geoportal.gov.pl/wss/ext/arimr_lpis",
                    layers: "14"),
                minZoom: 0, maxZoom: 19, needs4326: true)

        case .jordbrukSweden:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://epub.sjv.se/inspire/inspire/wms",
                    layers: "arslager_block"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .flikLuxembourg:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://wms.inspire.geoportail.lu/geoserver/af/wms",
                    layers: "LU.ExistingLandUseObject_LPIS_2024",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .blwSwitzerland:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://wms.geo.admin.ch/",
                    layers: "ch.blw.landwirtschaftliche-nutzungsflaechen",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .abaresAustralia:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://di-daa.img.arcgis.com/arcgis/services/Land_and_vegetation/Catchment_Scale_Land_Use_Simplified/ImageServer/WMSServer",
                    layers: "Catchment_Scale_Land_Use_Simplified",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 17, needs4326: false)

        case .lcdbNewZealand:
            // Use cached PMTiles overview for fast loading if available
            let pmtilesFile = "newzealand-overview.pmtiles"
            if RemotePMTilesCache.isAvailable(pmtilesFile) {
                return WMSSourceParams(
                    identifier: source.id,
                    tileURLTemplate: "http://\(PMTilesURLProtocol.proxyHost)/{z}/{x}/{y}/\(pmtilesFile)",
                    minZoom: 0, maxZoom: 10, needs4326: false)
            }
            // Fall back to WMS and trigger background download
            RemotePMTilesCache.download(pmtilesFile)
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://maps.scinfo.org.nz/lcdb/wms",
                    layers: "lcdb_lcdb6"),
                minZoom: 0, maxZoom: 17, needs4326: false)

        case .geoIntaArgentina:
            // Server unreachable (timeout to 200.61.223.5)
            return nil

        case .mapBiomas:
            // Server data files corrupted (Java IOException) + HTTP only
            return nil

        case .modisLandCover(year: let year):
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi",
                    layers: "MODIS_Combined_L3_IGBP_Land_Cover_Type_Annual",
                    extraParams: "TIME=\(year)-01-01"),
                minZoom: 0, maxZoom: 8, needs4326: false)

        case .gfsadCropland:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://gibs.earthdata.nasa.gov/wms/epsg3857/best/wms.cgi",
                    layers: "Agricultural_Lands_Croplands_2000"),
                minZoom: 0, maxZoom: 8, needs4326: false)

        case .nalcms:
            // NALCMS layer not available on GIBS; no public WMS endpoint found
            return nil

        case .deAfricaCrop:
            let deafPmtiles = "deafrica-crop.pmtiles"
            if RemotePMTilesCache.isAvailable(deafPmtiles) {
                return WMSSourceParams(
                    identifier: source.id,
                    tileURLTemplate: "http://\(PMTilesURLProtocol.proxyHost)/{z}/{x}/{y}/\(deafPmtiles)",
                    minZoom: 0, maxZoom: 10, needs4326: false)
            }
            RemotePMTilesCache.download(deafPmtiles)
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://ows.digitalearth.africa/wms",
                    layers: "crop_mask",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 10, needs4326: false)

        case .deaLandCover(year: let year):
            // Use cached PMTiles overview for fast loading if available
            let deaPmtiles = "dea-landcover-overview.pmtiles"
            if RemotePMTilesCache.isAvailable(deaPmtiles) {
                return WMSSourceParams(
                    identifier: source.id,
                    tileURLTemplate: "http://\(PMTilesURLProtocol.proxyHost)/{z}/{x}/{y}/\(deaPmtiles)",
                    minZoom: 0, maxZoom: 10, needs4326: false)
            }
            // Fall back to WMS and trigger background download
            RemotePMTilesCache.download(deaPmtiles)
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://ows.dea.ga.gov.au/",
                    layers: "ga_ls_landcover",
                    extraParams: "TIME=\(year)-01-01"),
                minZoom: 0, maxZoom: 12, needs4326: false)

        case .mexicoMadmex:
            // CONABIO server broken (500 filesystem error)
            return nil

        case .indiaBhuvan:
            // Layer name invalid (LayerNotDefined error from server)
            return nil

        case .turkeyCorine(year: let year):
            // CORINE has data for 2000, 2006, 2012, 2018 — snap to nearest valid year
            let validYears = [2000, 2006, 2012, 2018]
            let snapYear = validYears.min(by: { abs($0 - year) < abs($1 - year) }) ?? 2018
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://image.discomap.eea.europa.eu/arcgis/services/Corine/CLC\(snapYear)_WM/MapServer/WMSServer",
                    layers: "12"),
                minZoom: 0, maxZoom: 12, needs4326: false)

        case .indonesiaKlhk:
            // Server unreachable (connection timeout)
            return nil

        case .waporLCC:
            // FAO server returning 502 Bad Gateway
            return nil

        case .walloniaAgriculture(year: let year):
            // Layer 0 = crop categories (visible at all zooms), layer 1 = individual crops (high zoom only)
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geoservices.wallonie.be/arcgis/services/AGRICULTURE/SIGEC_PARC_AGRI_ANON__\(year)/MapServer/WMSServer",
                    layers: "0",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .nibioNorway:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://wms.nibio.no/cgi-bin/ar5",
                    layers: "Arealtype"),
                minZoom: 0, maxZoom: 19, needs4326: false)

        case .dynamicWorld(year: let year):
            // Esri/Impact Observatory Sentinel-2 10m Land Cover (free, no auth)
            // renderingRule forces classified color output instead of raw integer values
            let rule = "%7B%22rasterFunction%22%3A%22Cartographic%20Renderer%20for%20Visualization%20and%20Analysis%22%7D"
            // Time filter: epoch milliseconds for Jan 1 - Dec 31 of the requested year
            let cal = Calendar(identifier: .gregorian)
            let startDate = cal.date(from: DateComponents(year: year, month: 1, day: 1))!
            let endDate = cal.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
            let startMs = Int(startDate.timeIntervalSince1970 * 1000)
            let endMs = Int(endDate.timeIntervalSince1970 * 1000)
            // format=png32 returns RGBA with transparent noData; noData=0 makes black (ocean) transparent
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: "https://ic.imagery1.arcgis.com/arcgis/rest/services/Sentinel2_10m_LandCover/ImageServer/exportImage?bbox={bbox-epsg-3857}&bboxSR=3857&size=256,256&imageSR=3857&format=png32&f=image&renderingRule=\(rule)&time=\(startMs),\(endMs)&noData=0&noDataInterpretation=esriNoDataMatchAny",
                minZoom: 0, maxZoom: 14, needs4326: false)

        case .copernicusLandCover:
            // Copernicus Global Land Service LC100 — migrated to CDSE WMTS
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: "https://land.copernicus.eu/cdse/lc_global_100m_yearly_v3?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=A_DISCRETE_CLASSIFICATION&STYLE=default&FORMAT=image/png&TILEMATRIXSET=PopularWebMercator256&TILEMATRIX={z}&TILEROW={y}&TILECOL={x}&TIME=2019-01-01",
                minZoom: 0, maxZoom: 13, needs4326: false)

        case .fromGLC:
            // GLAD Global Land Cover/Land Use via ArcGIS tile service (XYZ, starts at z1)
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: "https://tiles.arcgis.com/tiles/HVjI8GKrRtjcQ4Ry/arcgis/rest/services/Global_Land_Cover_Land_Use_Systems/MapServer/tile/{z}/{y}/{x}",
                minZoom: 1, maxZoom: 9, needs4326: false)

        default:
            return nil
        }
    }

    /// OS Field Boundary tile URL template (ZXY, no WMS)
    static func osFieldBoundaryTemplate(apiKey: String) -> String {
        "https://api.os.uk/maps/raster/v1/zxy/Outdoor_3857/{z}/{x}/{y}.png?key=\(apiKey)"
    }

    /// LSIB political boundaries WMS URL template
    static let lsibTemplate: String = {
        let base = "https://services.geodata.state.gov/geoserver/lsib/wms"
        return "\(base)?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap" +
            "&LAYERS=lsib:LSIB&SRS=EPSG:3857&BBOX={bbox-epsg-3857}" +
            "&WIDTH=256&HEIGHT=256&FORMAT=image/png&TRANSPARENT=TRUE&STYLES="
    }()
}

// MARK: - Color extraction utility

enum LegendColorExtractor {
    /// Convert legend entries' SwiftUI Colors to RGB byte tuples for pixel filtering.
    /// Forces sRGB color space to match the CGContext used in filterPixels.
    static func rgbValues(for entries: [LegendEntry], matching labels: Set<String>) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        entries.compactMap { entry in
            guard labels.contains(entry.label) else { return nil }
            let uiColor = UIColor(entry.color)
            // Extract in sRGB to match the sRGB CGContext in filterPixels
            guard let srgb = uiColor.cgColor.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!,
                intent: .defaultIntent, options: nil
            ), let c = srgb.components, c.count >= 3 else {
                // Fallback to getRed
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
                return (r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
            }
            return (r: UInt8(c[0] * 255), g: UInt8(c[1] * 255), b: UInt8(c[2] * 255))
        }
    }
}
#endif
