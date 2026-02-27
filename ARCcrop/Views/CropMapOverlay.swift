#if !os(tvOS)
import MapKit
import UIKit

/// MKTileOverlay subclass that constructs WMS GetMap URLs from tile coordinates.
class WMSTileOverlay: MKTileOverlay {
    let baseURL: String
    let layers: String
    let crs: String
    let format: String
    let extraParams: String
    let wmsVersion: String   // "1.1.1" or "1.3.0"
    let minZoom: Int

    /// Shared URL cache for WMS tiles (200 MB memory, 2 GB disk default)
    static let tileCache: URLCache = {
        URLCache(
            memoryCapacity: 200 * 1024 * 1024,
            diskCapacity: 2 * 1024 * 1024 * 1024,
            diskPath: "WMSTileCache"
        )
    }()

    /// Update disk capacity at runtime (called from AppSettings)
    static func applyDiskCapacity(_ mb: Int) {
        tileCache.diskCapacity = mb * 1024 * 1024
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = WMSTileOverlay.tileCache
        // Use cached tiles across sessions; only fetch from network on cache miss
        config.requestCachePolicy = .returnCacheDataElseLoad
        // Limit concurrent downloads per host — reduces wasted fetches when zooming
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    /// Current active zoom level — used to cancel stale downloads when zoom changes
    nonisolated(unsafe) private static var activeZoom: Int = -1

    /// Cancel in-flight downloads for stale zoom levels
    static func cancelStaleDownloads(currentZoom: Int) {
        guard abs(currentZoom - activeZoom) >= 1 else { return }
        activeZoom = currentZoom
        session.getAllTasks { tasks in
            for task in tasks where task.state == .running {
                task.cancel()
            }
        }
    }

    /// Cancel all in-flight WMS tile downloads
    static func cancelAllDownloads() {
        session.getAllTasks { tasks in
            for task in tasks { task.cancel() }
        }
        Task { @MainActor in ActivityLog.shared.resetTileProgress() }
    }

    /// Force-cache a response even when the server sends no-cache / no-store headers.
    /// WMS tile data is static for a given year+layer, so aggressive caching is safe.
    private static func forceCache(data: Data, response: URLResponse, request: URLRequest) {
        let cached = CachedURLResponse(
            response: response, data: data,
            userInfo: nil, storagePolicy: .allowed
        )
        tileCache.storeCachedResponse(cached, for: request)
    }

    /// 1×1 transparent PNG returned for tiles below minZoom
    private static let emptyTile: Data = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.pngData { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }()

    init(baseURL: String, layers: String, crs: String = "EPSG:3857",
         format: String = "image/png", extraParams: String = "",
         minZoom: Int = 0, maxZoom: Int = 15, wmsVersion: String = "1.1.1") {
        self.baseURL = baseURL
        self.layers = layers
        self.crs = crs
        self.format = format
        self.extraParams = extraParams
        self.wmsVersion = wmsVersion
        self.minZoom = minZoom
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.maximumZ = maxZoom
    }

    /// Web Mercator origin shift in meters
    private static let originShift = 20037508.3427892

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let n = pow(2.0, Double(path.z))
        let bbox: String

        if crs == "EPSG:4326" {
            // Geographic coordinates
            let lonMin = Double(path.x) / n * 360.0 - 180.0
            let lonMax = Double(path.x + 1) / n * 360.0 - 180.0
            let latMax = atan(sinh(.pi * (1 - 2 * Double(path.y) / n))) * 180.0 / .pi
            let latMin = atan(sinh(.pi * (1 - 2 * Double(path.y + 1) / n))) * 180.0 / .pi
            // WMS 1.1.1: minx(lon),miny(lat),maxx(lon),maxy(lat)
            // WMS 1.3.0 EPSG:4326: miny(lat),minx(lon),maxy(lat),maxx(lon)
            if wmsVersion == "1.3.0" {
                bbox = "\(latMin),\(lonMin),\(latMax),\(lonMax)"
            } else {
                bbox = "\(lonMin),\(latMin),\(lonMax),\(latMax)"
            }
        } else {
            // EPSG:3857 (Web Mercator) BBOX in meters
            let tileSpan = 2.0 * Self.originShift / n
            let xMin = -Self.originShift + Double(path.x) * tileSpan
            let xMax = -Self.originShift + Double(path.x + 1) * tileSpan
            let yMax = Self.originShift - Double(path.y) * tileSpan
            let yMin = Self.originShift - Double(path.y + 1) * tileSpan
            bbox = "\(xMin),\(yMin),\(xMax),\(yMax)"
        }

        let srsParam = wmsVersion == "1.3.0" ? "CRS" : "SRS"
        var urlString = "\(baseURL)?SERVICE=WMS&VERSION=\(wmsVersion)&REQUEST=GetMap" +
            "&LAYERS=\(layers)&\(srsParam)=\(crs)&BBOX=\(bbox)" +
            "&WIDTH=256&HEIGHT=256&FORMAT=\(format)&TRANSPARENT=TRUE&STYLES="
        if !extraParams.isEmpty { urlString += "&\(extraParams)" }

        return URL(string: urlString)!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        // Below minimum useful zoom — return transparent tile
        if path.z < minZoom {
            result(Self.emptyTile, nil)
            return
        }

        let tileURL = url(forTilePath: path)
        let request = URLRequest(url: tileURL)

        // Serve from cache immediately (persists across sessions)
        if let cached = Self.tileCache.cachedResponse(for: request) {
            result(cached.data, nil)
            return
        }

        Task { @MainActor in ActivityLog.shared.tileRequested() }

        Self.session.dataTask(with: request) { data, response, error in
            let bytes = data?.count ?? 0
            // Force-cache the tile so it persists across app sessions
            if let data, let response, bytes > 0 {
                Self.forceCache(data: data, response: response, request: request)
            }
            Task { @MainActor in ActivityLog.shared.tileCompleted(bytes: bytes) }
            result(data, error)
        }.resume()
    }
}

/// Solid dark tile overlay used as "No Base Map" background.
final class BlankTileOverlay: MKTileOverlay {
    private let tileData: Data

    init(color: UIColor = UIColor(white: 0.12, alpha: 1)) {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        tileData = renderer.pngData { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = true
        self.tileSize = CGSize(width: 256, height: 256)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        result(tileData, nil)
    }
}

/// Tile overlay wrapper that filters out hidden colors from WMS tiles.
final class FilteredTileOverlay: MKTileOverlay {
    let sourceOverlay: MKTileOverlay
    let hiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)]
    let tolerance: Int

    init(source: MKTileOverlay, hiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)], tolerance: Int = 30) {
        self.sourceOverlay = source
        self.hiddenRGBs = hiddenRGBs
        self.tolerance = tolerance
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = source.canReplaceMapContent
        self.tileSize = source.tileSize
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        sourceOverlay.url(forTilePath: path)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        sourceOverlay.loadTile(at: path) { [hiddenRGBs, tolerance] data, error in
            guard let data, !hiddenRGBs.isEmpty else {
                result(data, error)
                return
            }
            if let filtered = Self.filterTile(data, hiding: hiddenRGBs, tolerance: tolerance) {
                result(filtered, nil)
            } else {
                result(data, error)
            }
        }
    }

    private static func filterTile(_ data: Data, hiding colors: [(r: UInt8, g: UInt8, b: UInt8)], tolerance: Int) -> Data? {
        guard let image = UIImage(data: data)?.cgImage else { return nil }
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let pixels = ctx.data else { return nil }
        let buf = pixels.bindMemory(to: UInt8.self, capacity: w * h * 4)

        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let r = buf[i], g = buf[i+1], b = buf[i+2]
            if buf[i+3] == 0 { continue } // already transparent
            for (tr, tg, tb) in colors {
                if abs(Int(r) - Int(tr)) <= tolerance &&
                   abs(Int(g) - Int(tg)) <= tolerance &&
                   abs(Int(b) - Int(tb)) <= tolerance {
                    buf[i+3] = 0
                    break
                }
            }
        }

        guard let filtered = ctx.makeImage() else { return nil }
        return UIImage(cgImage: filtered).pngData()
    }
}

// MARK: - Bounded WMS overlay (only loads tiles within geographic bounds)

final class BoundedWMSTileOverlay: WMSTileOverlay {
    let regionName: String
    let latRange: ClosedRange<Double>
    let lonRange: ClosedRange<Double>

    init(baseURL: String, layers: String, regionName: String,
         latRange: ClosedRange<Double>, lonRange: ClosedRange<Double>,
         crs: String = "EPSG:3857", format: String = "image/png", extraParams: String = "",
         minZoom: Int = 0) {
        self.regionName = regionName
        self.latRange = latRange
        self.lonRange = lonRange
        super.init(baseURL: baseURL, layers: layers, crs: crs, format: format, extraParams: extraParams, minZoom: minZoom)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        let n = pow(2.0, Double(path.z))
        let lonLeft = Double(path.x) / n * 360.0 - 180.0
        let lonRight = Double(path.x + 1) / n * 360.0 - 180.0
        let latTop = atan(sinh(.pi * (1 - 2 * Double(path.y) / n))) * 180.0 / .pi
        let latBottom = atan(sinh(.pi * (1 - 2 * Double(path.y + 1) / n))) * 180.0 / .pi

        // Skip tiles that don't overlap this region's bounds
        let overlaps = lonRight >= lonRange.lowerBound && lonLeft <= lonRange.upperBound &&
                       latTop >= latRange.lowerBound && latBottom <= latRange.upperBound
        guard overlaps else {
            result(nil, nil)
            return
        }

        super.loadTile(at: path, result: result)
    }
}

// MARK: - CROME English counties (from WMS GetCapabilities sublayers)

struct CROMECounty {
    let name: String       // Display name
    let layer: String      // WMS sublayer suffix
    let minLat: Double, maxLat: Double
    let minLon: Double, maxLon: Double

    func overlaps(mapLat: ClosedRange<Double>, mapLon: ClosedRange<Double>) -> Bool {
        maxLat >= mapLat.lowerBound && minLat <= mapLat.upperBound &&
        maxLon >= mapLon.lowerBound && minLon <= mapLon.upperBound
    }
}

enum CROMECounties {
    // Exact bounding boxes from WMS GetCapabilities
    static let all: [CROMECounty] = [
        CROMECounty(name: "Bedfordshire", layer: "Bedfordshire", minLat: 51.80, maxLat: 52.33, minLon: -0.71, maxLon: -0.14),
        CROMECounty(name: "Berkshire", layer: "Berkshire", minLat: 51.32, maxLat: 51.58, minLon: -1.59, maxLon: -0.49),
        CROMECounty(name: "Bristol & Somerset", layer: "Bristol_and_Somerset", minLat: 50.81, maxLat: 51.55, minLon: -3.85, maxLon: -2.24),
        CROMECounty(name: "Buckinghamshire", layer: "Buckinghamshire", minLat: 51.48, maxLat: 52.20, minLon: -1.15, maxLon: -0.45),
        CROMECounty(name: "Cambridgeshire", layer: "Cambridgeshire", minLat: 52.00, maxLat: 52.75, minLon: -0.52, maxLon: 0.54),
        CROMECounty(name: "Cheshire", layer: "Cheshire", minLat: 52.94, maxLat: 53.48, minLon: -3.12, maxLon: -1.97),
        CROMECounty(name: "Cornwall", layer: "Cornwall", minLat: 49.86, maxLat: 50.94, minLon: -6.51, maxLon: -4.15),
        CROMECounty(name: "Cumbria", layer: "Cumbria", minLat: 54.04, maxLat: 55.19, minLon: -3.67, maxLon: -2.16),
        CROMECounty(name: "Derbyshire", layer: "Derbyshire", minLat: 52.69, maxLat: 53.54, minLon: -2.03, maxLon: -1.16),
        CROMECounty(name: "Devon", layer: "Devon", minLat: 50.18, maxLat: 51.26, minLon: -4.68, maxLon: -2.88),
        CROMECounty(name: "Dorset", layer: "Dorset", minLat: 50.51, maxLat: 51.08, minLon: -2.96, maxLon: -1.68),
        CROMECounty(name: "Durham", layer: "Durham", minLat: 54.45, maxLat: 54.92, minLon: -2.36, maxLon: -1.15),
        CROMECounty(name: "East Riding", layer: "East_Riding_of_Yorkshire", minLat: 53.57, maxLat: 54.18, minLon: -1.11, maxLon: 0.18),
        CROMECounty(name: "East Sussex", layer: "East_Sussex", minLat: 50.72, maxLat: 51.15, minLon: -0.25, maxLon: 0.88),
        CROMECounty(name: "Essex", layer: "Essex", minLat: 51.43, maxLat: 52.10, minLon: -0.03, maxLon: 1.31),
        CROMECounty(name: "Gloucestershire", layer: "Gloucestershire", minLat: 51.41, maxLat: 52.11, minLon: -2.70, maxLon: -1.61),
        CROMECounty(name: "Hampshire", layer: "Hampshire", minLat: 50.70, maxLat: 51.39, minLon: -1.96, maxLon: -0.72),
        CROMECounty(name: "Herefordshire", layer: "Herefordshire", minLat: 51.82, maxLat: 52.40, minLon: -3.15, maxLon: -2.34),
        CROMECounty(name: "Hertfordshire", layer: "Hertfordshire", minLat: 51.59, maxLat: 52.09, minLon: -0.75, maxLon: 0.21),
        CROMECounty(name: "Kent", layer: "Kent", minLat: 50.90, maxLat: 51.50, minLon: 0.02, maxLon: 1.46),
        CROMECounty(name: "Lancashire", layer: "Lancashire", minLat: 53.48, maxLat: 54.24, minLon: -3.07, maxLon: -2.04),
        CROMECounty(name: "Leicestershire", layer: "Leicestershire", minLat: 52.39, maxLat: 52.98, minLon: -1.60, maxLon: -0.66),
        CROMECounty(name: "Lincolnshire", layer: "Lincolnshire", minLat: 52.63, maxLat: 53.72, minLon: -0.97, maxLon: 0.38),
        CROMECounty(name: "Norfolk", layer: "Norfolk", minLat: 52.34, maxLat: 53.00, minLon: 0.14, maxLon: 1.78),
        CROMECounty(name: "North Yorkshire", layer: "North_Yorkshire", minLat: 53.61, maxLat: 54.65, minLon: -2.57, maxLon: -0.19),
        CROMECounty(name: "Northamptonshire", layer: "Northamptonshire", minLat: 51.97, maxLat: 52.65, minLon: -1.34, maxLon: -0.34),
        CROMECounty(name: "Northumberland", layer: "Northumberland", minLat: 54.78, maxLat: 55.81, minLon: -2.70, maxLon: -1.45),
        CROMECounty(name: "Nottinghamshire", layer: "Nottinghamshire", minLat: 52.79, maxLat: 53.51, minLon: -1.35, maxLon: -0.66),
        CROMECounty(name: "Oxfordshire", layer: "Oxfordshire", minLat: 51.46, maxLat: 52.17, minLon: -1.72, maxLon: -0.85),
        CROMECounty(name: "Shropshire", layer: "Shropshire", minLat: 52.30, maxLat: 53.00, minLon: -3.25, maxLon: -2.23),
        CROMECounty(name: "South Yorkshire", layer: "South_Yorkshire", minLat: 53.30, maxLat: 53.66, minLon: -1.82, maxLon: -0.87),
        CROMECounty(name: "Staffordshire", layer: "Staffordshire", minLat: 52.42, maxLat: 53.23, minLon: -2.47, maxLon: -1.58),
        CROMECounty(name: "Suffolk", layer: "Suffolk", minLat: 51.92, maxLat: 52.58, minLon: 0.32, maxLon: 1.77),
        CROMECounty(name: "Surrey", layer: "Surrey", minLat: 51.06, maxLat: 51.48, minLon: -0.85, maxLon: 0.07),
        CROMECounty(name: "Warwickshire", layer: "Warwickshire", minLat: 51.95, maxLat: 52.69, minLon: -1.96, maxLon: -1.17),
        CROMECounty(name: "West Midlands", layer: "West_Midlands", minLat: 52.35, maxLat: 52.66, minLon: -2.21, maxLon: -1.42),
        CROMECounty(name: "West Sussex", layer: "West_Sussex", minLat: 50.71, maxLat: 51.18, minLon: -0.96, maxLon: 0.04),
        CROMECounty(name: "West Yorkshire", layer: "West_Yorkshire", minLat: 53.52, maxLat: 53.96, minLon: -2.17, maxLon: -1.19),
        CROMECounty(name: "Wiltshire", layer: "Wiltshire", minLat: 50.94, maxLat: 51.70, minLon: -2.37, maxLon: -1.48),
        CROMECounty(name: "Worcestershire", layer: "Worcestershire", minLat: 51.97, maxLat: 52.45, minLon: -2.67, maxLon: -1.76),
    ]

    /// Returns counties that overlap the given map region
    static func overlapping(center: CLLocationCoordinate2D, span: MKCoordinateSpan) -> [CROMECounty] {
        let latRange = (center.latitude - span.latitudeDelta / 2)...(center.latitude + span.latitudeDelta / 2)
        let lonRange = (center.longitude - span.longitudeDelta / 2)...(center.longitude + span.longitudeDelta / 2)
        return all.filter { $0.overlaps(mapLat: latRange, mapLon: lonRange) }
    }

    /// Create bounded tile overlays for visible counties using WMS county sublayers
    static func makeOverlays(year: Int, visibleCenter: CLLocationCoordinate2D, visibleSpan: MKCoordinateSpan,
                              hiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)] = []) -> [(name: String, overlay: MKTileOverlay)] {
        let counties = overlapping(center: visibleCenter, span: visibleSpan)
        return counties.map { county in
            let base = BoundedWMSTileOverlay(
                baseURL: "https://environment.data.gov.uk/spatialdata/crop-map-of-england-\(year)/wms",
                layers: "Crop_Map_of_England_\(year)_\(county.layer)",
                regionName: county.name,
                latRange: county.minLat...county.maxLat,
                lonRange: county.minLon...county.maxLon
            )
            if !hiddenRGBs.isEmpty {
                let filtered = FilteredTileOverlay(source: base, hiddenRGBs: hiddenRGBs)
                return (county.name, filtered)
            }
            return (county.name, base)
        }
    }
}

/// Factory to create tile overlays for different crop map sources.
enum CropMapOverlayFactory {
    static func makeTileOverlay(for source: CropMapSource) -> MKTileOverlay? {
        switch source {
        case .usdaCDL(let year):
            return WMSTileOverlay(
                baseURL: "https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi",
                layers: "cdl_\(year)",
                crs: "EPSG:4326",   // USDA only supports 4326 + 5070
                maxZoom: 17
            )
        case .jrcEUCropMap(let year):
            return WMSTileOverlay(
                baseURL: "https://jeodpp.jrc.ec.europa.eu/jeodpp/services/ows/wms/landcover/eucropmap",
                layers: "LC.EUCROPMAP.\(year)",
                maxZoom: 18
            )
        case .cromeEngland(let year):
            // Use full England layer — WMS renders all counties together
            return WMSTileOverlay(
                baseURL: "https://environment.data.gov.uk/spatialdata/crop-map-of-england-\(year)/wms",
                layers: "Crop_Map_of_England_\(year)",
                maxZoom: 19
            )
        case .dlrCropTypes:
            return WMSTileOverlay(
                baseURL: "https://geoservice.dlr.de/eoc/land/wms",
                layers: "CROPTYPES_DE_P1Y",
                extraParams: "STYLES=croptypes",
                maxZoom: 18
            )
        case .rpgFrance:
            return WMSTileOverlay(
                baseURL: "https://data.geopf.fr/wms-r/wms",
                layers: "LANDUSE.AGRICULTURE.LATEST",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .brpNetherlands:
            return WMSTileOverlay(
                baseURL: "https://service.pdok.nl/rvo/brpgewaspercelen/wms/v1_0",
                layers: "BrpGewas",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .aafcCanada(let year):
            return WMSTileOverlay(
                baseURL: "https://www.agr.gc.ca/imagery-images/services/annual_crop_inventory/\(year)/ImageServer/WMSServer",
                layers: "\(year):annual_crop_inventory",
                maxZoom: 17
            )
        case .esaWorldCover:
            return WMSTileOverlay(
                baseURL: "https://services.terrascope.be/wms/v2",
                layers: "WORLDCOVER_2021_MAP",
                maxZoom: 18
            )
        case .worldCereal:
            return WMSTileOverlay(
                baseURL: "https://services.terrascope.be/wms/v2",
                layers: "WORLDCEREAL_TEMPORARYCROPS_V1",
                maxZoom: 18
            )
        case .worldCerealMaize:
            return WMSTileOverlay(
                baseURL: "https://services.terrascope.be/wms/v2",
                layers: "WORLDCEREAL_MAIZE_V1",
                maxZoom: 18
            )
        case .worldCerealWinterCereals:
            return WMSTileOverlay(
                baseURL: "https://services.terrascope.be/wms/v2",
                layers: "WORLDCEREAL_WINTERCEREALS_V1",
                maxZoom: 18
            )
        case .worldCerealSpringCereals:
            return WMSTileOverlay(
                baseURL: "https://services.terrascope.be/wms/v2",
                layers: "WORLDCEREAL_SPRINGCEREALS_V1",
                maxZoom: 18
            )
        case .invekosAustria:
            return WMSTileOverlay(
                baseURL: "https://inspire.lfrz.gv.at/009501/wms",
                layers: "inspire_feldstuecke_2025-2",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .alvFlanders:
            return WMSTileOverlay(
                baseURL: "https://geo.api.vlaanderen.be/ALV/wms",
                layers: "LbGebrPerc2024",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .sigpacSpain:
            return WMSTileOverlay(
                baseURL: "https://wms.mapa.gob.es/sigpac/wms",
                layers: "AU.Sigpac:recinto",
                maxZoom: 19
            )
        case .fvmDenmark:
            return WMSTileOverlay(
                baseURL: "https://geodata.fvm.dk/geoserver/ows",
                layers: "Marker_2024",
                maxZoom: 19
            )
        case .lpisCzechia:
            return WMSTileOverlay(
                baseURL: "https://mze.gov.cz/public/app/wms/public_DPB_PB_OPV.fcgi",
                layers: "DPB_UCINNE",
                maxZoom: 19
            )
        case .gerkSlovenia:
            return WMSTileOverlay(
                baseURL: "https://storitve.eprostor.gov.si/ows-pub-wms/SI.MKGP.GERK/ows",
                layers: "RKG_BLOK_GERK",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .arkodCroatia:
            return WMSTileOverlay(
                baseURL: "https://servisi.apprrr.hr/NIPP/wms",
                layers: "hr.land_parcels",
                crs: "EPSG:4326",
                maxZoom: 19
            )
        case .gsaaEstonia:
            return WMSTileOverlay(
                baseURL: "https://kls.pria.ee/geoserver/inspire_gsaa/wms",
                layers: "inspire_gsaa",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .latviaFieldBlocks:
            return WMSTileOverlay(
                baseURL: "https://karte.lad.gov.lv/arcgis/services/lauku_bloki/MapServer/WMSServer",
                layers: "0",
                crs: "EPSG:4326",
                maxZoom: 19
            )
        case .ifapPortugal:
            return WMSTileOverlay(
                baseURL: "https://www.ifap.pt/isip/ows/isip.data/wms",
                layers: "Parcelas_2019_Centro",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .lpisPoland:
            return WMSTileOverlay(
                baseURL: "https://mapy.geoportal.gov.pl/wss/ext/arimr_lpis",
                layers: "14",  // Mazowieckie (Warsaw region) as default
                crs: "EPSG:4326",
                maxZoom: 19
            )
        case .jordbrukSweden:
            return WMSTileOverlay(
                baseURL: "https://epub.sjv.se/inspire/inspire/wms",
                layers: "jordbruksblock",
                maxZoom: 19
            )
        case .flikLuxembourg:
            return WMSTileOverlay(
                baseURL: "https://wms.inspire.geoportail.lu/geoserver/af/wms",
                layers: "af:asta_flik_parcels",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .blwSwitzerland:
            return WMSTileOverlay(
                baseURL: "https://wms.geo.admin.ch/",
                layers: "ch.blw.landwirtschaftliche-nutzungsflaechen",
                crs: "EPSG:4326",
                maxZoom: 19,
                wmsVersion: "1.3.0"
            )
        case .abaresAustralia:
            return WMSTileOverlay(
                baseURL: "https://di-daa.img.arcgis.com/arcgis/services/Land_and_vegetation/Catchment_Scale_Land_Use_Simplified/ImageServer/WMSServer",
                layers: "Catchment_Scale_Land_Use_Simplified",
                crs: "EPSG:4326",
                maxZoom: 17,
                wmsVersion: "1.3.0"
            )
        case .lcdbNewZealand:
            return WMSTileOverlay(
                baseURL: "https://maps.scinfo.org.nz/lcdb/wms",
                layers: "lcdb_lcdb6",
                crs: "EPSG:4326",
                maxZoom: 17
            )
        case .geoIntaArgentina:
            return WMSTileOverlay(
                baseURL: "https://geo-backend.inta.gob.ar/geoserver/wms",
                layers: "geonode:mnc_verano2024_f300268fd112b0ec3ef5f731edb78882",
                crs: "EPSG:4326",
                maxZoom: 17,
                wmsVersion: "1.3.0"
            )
        default:
            return nil
        }
    }
}

// MARK: - OS Data Hub field boundary overlay

final class OSFieldBoundaryOverlay: MKTileOverlay {
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
        // OS Maps API ZXY endpoint - "Outdoor" style shows field boundaries clearly
        super.init(urlTemplate: "https://api.os.uk/maps/raster/v1/zxy/Outdoor_3857/{z}/{x}/{y}.png?key=\(apiKey)")
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
        self.maximumZ = 20
    }
}

// MARK: - LSIB political boundaries overlay

final class LSIBOverlay: WMSTileOverlay {
    init() {
        super.init(
            baseURL: "https://services.geodata.state.gov/geoserver/lsib/wms",
            layers: "lsib:LSIB"
        )
    }
}

// MARK: - Color extraction utility

enum LegendColorExtractor {
    /// Convert legend entries' SwiftUI Colors to RGB byte tuples for pixel filtering
    static func rgbValues(for entries: [LegendEntry], matching labels: Set<String>) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        entries.compactMap { entry in
            guard labels.contains(entry.label) else { return nil }
            let uiColor = UIColor(entry.color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            return (r: UInt8(r * 255), g: UInt8(g * 255), b: UInt8(b * 255))
        }
    }
}
#endif
