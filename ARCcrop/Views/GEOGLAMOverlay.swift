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
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.boundingMapRect = MKMapRect.world
        super.init()
    }
}

// MARK: - Renderer with class filtering

final class GEOGLAMOverlayRenderer: MKOverlayRenderer {
    /// RGB values to hide. Set externally, then call setNeedsDisplay().
    var hiddenRGBs: [(r: UInt8, g: UInt8, b: UInt8)] = []
    private var filteredCache: CGImage?
    private var cacheKey: String = ""

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let geoglamOverlay = overlay as? GEOGLAMMapOverlay,
              let cgImage = geoglamOverlay.image.cgImage else { return }

        let imageToRender: CGImage
        if hiddenRGBs.isEmpty {
            imageToRender = cgImage
            filteredCache = nil
            cacheKey = ""
        } else {
            let key = hiddenRGBs.map { "\($0.r),\($0.g),\($0.b)" }.joined(separator: "|")
            if key == cacheKey, let cached = filteredCache {
                imageToRender = cached
            } else {
                let filtered = Self.filterImage(cgImage, hiding: hiddenRGBs)
                filteredCache = filtered
                cacheKey = key
                imageToRender = filtered ?? cgImage
            }
        }

        let rect = self.rect(for: geoglamOverlay.boundingMapRect)

        // DIAGNOSTIC: Log CTM once to determine context orientation
        struct LogOnce { nonisolated(unsafe) static var done = false }
        if !LogOnce.done {
            LogOnce.done = true
            let ctm = context.ctm
            print("[GEOGLAM DIAG] Renderer CTM: a=\(ctm.a) b=\(ctm.b) c=\(ctm.c) d=\(ctm.d) tx=\(ctm.tx) ty=\(ctm.ty)")
            print("[GEOGLAM DIAG] Renderer rect: x=\(rect.minX) y=\(rect.minY) w=\(rect.width) h=\(rect.height)")
            let imgW = CGFloat(imageToRender.width), imgH = CGFloat(imageToRender.height)
            print("[GEOGLAM DIAG] Image size: \(imgW)x\(imgH)")
        }

        context.saveGState()
        context.interpolationQuality = .none  // nearest-neighbor — categorical data
        context.setShouldAntialias(false)
        context.draw(imageToRender, in: rect)
        context.restoreGState()
    }

    private static func filterImage(_ image: CGImage, hiding colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        let w = image.width, h = image.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let pixels = ctx.data else { return nil }
        let buf = pixels.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let tolerance = 20

        for i in stride(from: 0, to: w * h * 4, by: 4) {
            let r = buf[i], g = buf[i+1], b = buf[i+2]
            if buf[i+3] == 0 { continue }
            for (tr, tg, tb) in colors {
                if abs(Int(r) - Int(tr)) <= tolerance &&
                   abs(Int(g) - Int(tg)) <= tolerance &&
                   abs(Int(b) - Int(tb)) <= tolerance {
                    buf[i+3] = 0
                    break
                }
            }
        }

        return ctx.makeImage()
    }
}

// MARK: - Overlay manager

@MainActor
final class GEOGLAMOverlayManager {
    static let shared = GEOGLAMOverlayManager()
    private var cropCache: [GEOGLAMCrop: GEOGLAMMapOverlay] = [:]
    private var majorityCropCache: GEOGLAMMapOverlay?

    func overlay(for crop: GEOGLAMCrop) -> GEOGLAMMapOverlay? {
        if let cached = cropCache[crop] { return cached }

        guard let url = Bundle.main.url(forResource: crop.filename, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            ActivityLog.shared.error("GEOGLAM \(crop.rawValue): image not found in bundle")
            return nil
        }

        let mercator = Self.reprojectToMercator(image) ?? image
        ActivityLog.shared.success("GEOGLAM \(crop.rawValue) loaded: src=\(Int(image.size.width))x\(Int(image.size.height)) merc=\(Int(mercator.size.width))x\(Int(mercator.size.height))")
        let overlay = GEOGLAMMapOverlay(image: mercator)
        cropCache[crop] = overlay
        return overlay
    }

    func majorityCropOverlay() -> GEOGLAMMapOverlay? {
        if let cached = majorityCropCache { return cached }

        guard let url = Bundle.main.url(forResource: "GEOGLAM_MajorityCrop", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else {
            ActivityLog.shared.error("GEOGLAM Majority Crop: image not found in bundle")
            return nil
        }

        let mercator = Self.reprojectToMercator(image) ?? image
        ActivityLog.shared.success("GEOGLAM Majority Crop loaded (\(Int(mercator.size.width))x\(Int(mercator.size.height)))")
        let overlay = GEOGLAMMapOverlay(image: mercator)
        majorityCropCache = overlay
        return overlay
    }

    /// Reproject an equirectangular (EPSG:4326) image to Web Mercator (EPSG:3857).
    /// Uses nearest-neighbor (correct for classified/categorical data).
    ///
    /// The GEOGLAM PNGs are SQUARE (7200×7200 or 3600×3600).
    /// Longitude: -180° to +180° (columns 0..W-1)
    /// Latitude:  +90° to -90° (rows H/4..3H/4 for square images)
    /// The full Y axis spans 360° but only the central 180° has data.
    ///
    /// Output: square Web Mercator image sized to MKMapRect.world
    /// (latitude ≈ ±85.051° projected to a square).
    private static func reprojectToMercator(_ sourceImage: UIImage) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }
        let srcW = cgImage.width, srcH = cgImage.height
        let outSize = min(srcW, 4096)

        // Source geographic extent
        // Square image: 360° longitude × 360° "latitude" (padded)
        let srcLonMin = -180.0, srcLonMax = 180.0
        let srcLatMax = 180.0 * Double(srcH) / Double(srcW)  // +180° for square
        let srcLatMin = -srcLatMax                              // -180° for square

        // Draw source into RGBA context
        guard let srcCtx = CGContext(
            data: nil, width: srcW, height: srcH, bitsPerComponent: 8, bytesPerRow: srcW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let srcData = srcCtx.data else { return nil }
        srcCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
        let srcPixels = srcData.bindMemory(to: UInt8.self, capacity: srcW * srcH * 4)

        // DIAGNOSTIC: Sample source pixel data to determine row orientation.
        // Check non-transparent pixel counts at specific rows to determine if
        // memory row 0 = north (top of image) or south (bottom).
        let sampleRows = [0, srcH/8, srcH/4, 3*srcH/8, srcH/2, 5*srcH/8, 3*srcH/4, 7*srcH/8, srcH-1]
        var diagMsg = "SRC \(srcW)x\(srcH) row data counts:"
        for row in sampleRows {
            var count = 0
            for col in stride(from: 0, to: srcW, by: 10) {
                let idx = (row * srcW + col) * 4
                if srcPixels[idx+3] > 0 && !(srcPixels[idx]==0 && srcPixels[idx+1]==0 && srcPixels[idx+2]==0) {
                    count += 1
                }
            }
            let latIfTop = srcLatMax - Double(row) / Double(srcH) * (srcLatMax - srcLatMin)
            diagMsg += " r\(row)(lat_if_top=\(Int(latIfTop)))=\(count)"
        }
        print("[GEOGLAM DIAG] \(diagMsg)")

        // Output Mercator image
        guard let outCtx = CGContext(
            data: nil, width: outSize, height: outSize, bitsPerComponent: 8, bytesPerRow: outSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outData = outCtx.data else { return nil }
        let outPixels = outData.bindMemory(to: UInt8.self, capacity: outSize * outSize * 4)

        // Web Mercator: the full square covers lat ≈ ±85.051°, lon ±180°
        // For each output row, compute the corresponding latitude via the
        // inverse Mercator formula, then map to source row.
        let mercMax = Double.pi  // atanh(sin(85.051°)) = π

        for outRow in 0..<outSize {
            // Output Y fraction: 0 = north edge, 1 = south edge
            let yFrac = (Double(outRow) + 0.5) / Double(outSize)
            // Mercator y value: +π at north edge, -π at south edge
            let mercY = mercMax * (1.0 - 2.0 * yFrac)
            // Convert to latitude in degrees
            let latRad = atan(sinh(mercY))
            let lat = latRad * 180.0 / .pi

            // Map lat to source row: row 0 = srcLatMax, row srcH-1 = srcLatMin
            let rowFrac = (srcLatMax - lat) / (srcLatMax - srcLatMin)
            let srcRow = min(max(Int(rowFrac * Double(srcH)), 0), srcH - 1)

            for outCol in 0..<outSize {
                // Map output col to longitude, then to source col
                let lonFrac = (Double(outCol) + 0.5) / Double(outSize)
                let lon = srcLonMin + lonFrac * (srcLonMax - srcLonMin)
                let colFrac = (lon - srcLonMin) / (srcLonMax - srcLonMin)
                let srcCol = min(max(Int(colFrac * Double(srcW)), 0), srcW - 1)

                let si = (srcRow * srcW + srcCol) * 4
                let oi = (outRow * outSize + outCol) * 4
                let r = srcPixels[si], g = srcPixels[si + 1], b = srcPixels[si + 2], a = srcPixels[si + 3]
                if r == 0 && g == 0 && b == 0 {
                    outPixels[oi + 3] = 0
                } else {
                    outPixels[oi]     = r
                    outPixels[oi + 1] = g
                    outPixels[oi + 2] = b
                    outPixels[oi + 3] = a
                }
            }
        }

        // DIAGNOSTIC: Add colored reference markers at known geographic locations
        // These will appear as colored squares on the map so we can check alignment.
        func markAt(lat: Double, lon: Double, r: UInt8, g: UInt8, b: UInt8, label: String) {
            // Convert lat/lon to output pixel using same Mercator math
            let mercY = log(tan(.pi/4 + (lat * .pi / 180) / 2))
            let outRow = Int((1.0 - mercY / .pi) / 2.0 * Double(outSize))
            let outCol = Int((lon + 180.0) / 360.0 * Double(outSize))
            let sz = 15 // marker size in pixels
            print("[GEOGLAM DIAG] Marker '\(label)' at lat=\(lat) lon=\(lon) -> outRow=\(outRow) outCol=\(outCol)")
            for dy in -sz...sz {
                for dx in -sz...sz {
                    let pr = outRow + dy, pc = outCol + dx
                    guard pr >= 0, pr < outSize, pc >= 0, pc < outSize else { continue }
                    let oi = (pr * outSize + pc) * 4
                    outPixels[oi] = r; outPixels[oi+1] = g; outPixels[oi+2] = b; outPixels[oi+3] = 255
                }
            }
        }
        markAt(lat: 0, lon: 0, r: 255, g: 0, b: 0, label: "Equator/PrimeMeridian")       // RED
        markAt(lat: 51.5, lon: -0.1, r: 0, g: 0, b: 255, label: "London")                 // BLUE
        markAt(lat: 42, lon: -93, r: 0, g: 255, b: 0, label: "Iowa")                      // GREEN
        markAt(lat: -33.9, lon: 18.4, r: 255, g: 255, b: 0, label: "CapeTown")            // YELLOW
        markAt(lat: -23, lon: -47, r: 255, g: 0, b: 255, label: "SaoPaulo")               // MAGENTA

        guard let result = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: result)
    }
}
#endif
