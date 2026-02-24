#if !os(tvOS)
import MapKit
import UIKit

// MARK: - MKOverlay for GEOGLAM raster data (pre-rendered PNG)

final class GEOGLAMMapOverlay: NSObject, MKOverlay {
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let image: UIImage

    init(image: UIImage) {
        self.image = image
        // Full Mercator world — image was reprojected to match this exactly
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.boundingMapRect = MKMapRect.world
        super.init()
    }
}

// MARK: - Renderer

final class GEOGLAMOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let geoglamOverlay = overlay as? GEOGLAMMapOverlay,
              let cgImage = geoglamOverlay.image.cgImage else { return }

        let rect = self.rect(for: geoglamOverlay.boundingMapRect)
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
}

// MARK: - Overlay manager

@MainActor
final class GEOGLAMOverlayManager {
    static let shared = GEOGLAMOverlayManager()
    private var cropCache: [GEOGLAMCrop: GEOGLAMMapOverlay] = [:]
    private var cropPictureCache: GEOGLAMMapOverlay?

    func overlay(for crop: GEOGLAMCrop) -> GEOGLAMMapOverlay? {
        if let cached = cropCache[crop] { return cached }

        guard let url = Bundle.main.url(forResource: crop.filename, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            print("GEOGLAM: \(crop.filename).png not found in bundle")
            return nil
        }

        let overlay = GEOGLAMMapOverlay(image: image)
        cropCache[crop] = overlay
        return overlay
    }

    func cropPictureOverlay() -> GEOGLAMMapOverlay? {
        if let cached = cropPictureCache { return cached }

        guard let url = Bundle.main.url(forResource: "GEOGLAM_CropPicture", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            print("GEOGLAM: GEOGLAM_CropPicture.png not found in bundle")
            return nil
        }

        let overlay = GEOGLAMMapOverlay(image: image)
        cropPictureCache = overlay
        return overlay
    }
}
#endif
