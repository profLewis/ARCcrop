#if !os(tvOS)
import MapKit

/// MKTileOverlay subclass that constructs WMS GetMap URLs from tile coordinates.
final class WMSTileOverlay: MKTileOverlay {
    let baseURL: String
    let layers: String
    let crs: String
    let format: String

    init(baseURL: String, layers: String, crs: String = "EPSG:4326", format: String = "image/png") {
        self.baseURL = baseURL
        self.layers = layers
        self.crs = crs
        self.format = format
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = false
        self.tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let n = pow(2.0, Double(path.z))
        let lonLeft = Double(path.x) / n * 360.0 - 180.0
        let lonRight = Double(path.x + 1) / n * 360.0 - 180.0
        let latTop = atan(sinh(.pi * (1 - 2 * Double(path.y) / n))) * 180.0 / .pi
        let latBottom = atan(sinh(.pi * (1 - 2 * Double(path.y + 1) / n))) * 180.0 / .pi

        let bbox = "\(lonLeft),\(latBottom),\(lonRight),\(latTop)"
        let urlString = "\(baseURL)?SERVICE=WMS&VERSION=1.1.1&REQUEST=GetMap" +
            "&LAYERS=\(layers)&SRS=\(crs)&BBOX=\(bbox)" +
            "&WIDTH=256&HEIGHT=256&FORMAT=\(format)&TRANSPARENT=true"

        return URL(string: urlString)!
    }
}

/// Factory to create tile overlays for different crop map sources.
enum CropMapOverlayFactory {
    static func makeTileOverlay(for source: CropMapSource) -> MKTileOverlay? {
        switch source {
        case .usdaCDL(let year):
            return WMSTileOverlay(
                baseURL: "https://nassgeodata.gmu.edu/CropScapeService/wms_cdlall.cgi",
                layers: "cdl_\(year)"
            )
        default:
            return nil
        }
    }
}
#endif
