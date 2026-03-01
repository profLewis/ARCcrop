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
    /// to avoid infinite recursion — uses a plain default configuration).
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 128 * 1024 * 1024, diskCapacity: 1024 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == proxyHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            fail(msg: "No URL")
            return
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        // Path: ["t", bbox_string, base64_encoded_url]
        guard pathComponents.count >= 3 else {
            fail(msg: "Invalid path (expected /t/bbox/base64): \(url.path)")
            return
        }

        let bboxString = pathComponents[1]
        let base64Part = pathComponents[2]

        // Decode real WMS URL from base64url
        let base64 = base64Part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: padded),
              var realURLString = String(data: data, encoding: .utf8) else {
            fail(msg: "Failed to decode base64")
            return
        }

        // Substitute bbox placeholder with actual values
        realURLString = realURLString.replacingOccurrences(of: "BBOX=PROXY_BBOX", with: "BBOX=\(bboxString)")

        // Parse query params
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let needs4326 = queryItems.contains { $0.name == "crs4326" }

        // Parse filter colors
        var filterColors: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if let filterParam = queryItems.first(where: { $0.name == "filter" })?.value {
            for rgb in filterParam.split(separator: "|") {
                let parts = rgb.split(separator: ",")
                if parts.count == 3,
                   let r = UInt8(parts[0]), let g = UInt8(parts[1]), let b = UInt8(parts[2]) {
                    filterColors.append((r: r, g: g, b: b))
                }
            }
        }

        // 4326 reprojection
        if needs4326 {
            realURLString = Self.reproject3857to4326(realURLString, bbox: bboxString)
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
            if needs4326, let reprojected = Self.reprojectTile4326to3857(tileData, mercBbox: bboxString) {
                tileData = reprojected
            }

            // Apply pixel filtering if needed
            if !filterColors.isEmpty, let filtered = Self.filterPixels(tileData, hiding: filterColors) {
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

    private static func filterPixels(_ pngData: Data, hiding colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> Data? {
        guard let image = UIImage(data: pngData), let cgImage = image.cgImage else { return nil }
        let w = cgImage.width, h = cgImage.height
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: srgb,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let pixels = ctx.data else { return nil }
        let buf = pixels.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let tolerance = 3  // Low tolerance — WMS classification tiles use exact colors

        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let r = buf[i], g = buf[i + 1], b = buf[i + 2]
            if buf[i + 3] == 0 { continue }
            for (tr, tg, tb) in colors {
                if abs(Int(r) - Int(tr)) <= tolerance &&
                   abs(Int(g) - Int(tg)) <= tolerance &&
                   abs(Int(b) - Int(tb)) <= tolerance {
                    buf[i + 3] = 0
                    break
                }
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
    /// Format: `arccrop-wms://t/{bbox-epsg-3857}/BASE64URL?filter=...&crs4326=1`
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
        if !filterColors.isEmpty {
            let colorStr = filterColors.map { "\($0.r),\($0.g),\($0.b)" }.joined(separator: "|")
            queryParts.append("filter=\(colorStr)")
        }
        if !queryParts.isEmpty {
            proxyURL += "?" + queryParts.joined(separator: "&")
        }
        return proxyURL
    }

    /// Create WMS source parameters for a crop map source.
    /// Returns nil for sources that are not WMS-based (GEOGLAM, auth-required, etc.)
    static func sourceParams(for source: CropMapSource) -> WMSSourceParams? {
        switch source {
        case .usdaCDL(year: let year):
            let pmtilesBase = "pmtiles://raw.githubusercontent.com/profLewis/ARCcrop/main/tiles"
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: "\(pmtilesBase)/usda_cdl_\(year).pmtiles/{z}/{x}/{y}",
                minZoom: 0, maxZoom: 8, needs4326: false)

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
                    extraParams: "STYLES=croptypes"),
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
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geodata.fvm.dk/geoserver/ows",
                    layers: "Marker_2024"),
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
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://maps.scinfo.org.nz/lcdb/wms",
                    layers: "lcdb_lcdb6"),
                minZoom: 0, maxZoom: 17, needs4326: false)

        case .geoIntaArgentina:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "https://geo-backend.inta.gob.ar/geoserver/wms",
                    layers: "geonode:mnc_verano2024_f300268fd112b0ec3ef5f731edb78882",
                    wmsVersion: "1.3.0"),
                minZoom: 0, maxZoom: 17, needs4326: false)

        case .mapBiomas:
            return WMSSourceParams(
                identifier: source.id,
                tileURLTemplate: wmsTemplate(
                    baseURL: "http://azure.solved.eco.br:8080/geoserver/solved/wms",
                    layers: "mapbiomas",
                    styles: "solved:mapbiomas_legend"),
                minZoom: 0, maxZoom: 14, needs4326: false)

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
