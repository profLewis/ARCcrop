#if !os(tvOS)
import UIKit

// MARK: - GEOGLAM Overlay Manager

@MainActor
final class GEOGLAMOverlayManager {
    static let shared = GEOGLAMOverlayManager()
    private var cropCache: [GEOGLAMCrop: UIImage] = [:]
    private var majorityCropCache: UIImage?

    /// Get a Mercator-reprojected image for a GEOGLAM crop (or majority crop if nil).
    func mercatorImage(for crop: GEOGLAMCrop?) -> UIImage? {
        if let crop {
            if let cached = cropCache[crop] { return cached }

            guard let url = Bundle.main.url(forResource: crop.filename, withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path) else {
                ActivityLog.shared.error("GEOGLAM \(crop.rawValue): image not found in bundle")
                return nil
            }

            let mercator = Self.reprojectToMercator(image) ?? image
            ActivityLog.shared.success("GEOGLAM \(crop.rawValue) loaded: \(Int(mercator.size.width))x\(Int(mercator.size.height))")
            cropCache[crop] = mercator
            return mercator
        } else {
            if let cached = majorityCropCache { return cached }

            guard let url = Bundle.main.url(forResource: "GEOGLAM_MajorityCrop", withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path) else {
                ActivityLog.shared.error("GEOGLAM Majority Crop: image not found in bundle")
                return nil
            }

            let mercator = Self.reprojectToMercator(image) ?? image
            ActivityLog.shared.success("GEOGLAM Majority Crop loaded (\(Int(mercator.size.width))x\(Int(mercator.size.height)))")
            majorityCropCache = mercator
            return mercator
        }
    }

    /// Reproject an equirectangular (EPSG:4326) image to Web Mercator (EPSG:3857).
    /// Uses nearest-neighbor (correct for classified/categorical data).
    ///
    /// The GEOGLAM PNGs are 7200x3600 (2:1 aspect ratio):
    /// Longitude: -180 to +180 (columns 0..W-1)
    /// Latitude:  +90 to -90  (rows 0..H-1)
    ///
    /// Output: square Web Mercator image (latitude ±85.051° projected to a square).
    private static func reprojectToMercator(_ sourceImage: UIImage) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }
        let srcW = cgImage.width, srcH = cgImage.height
        let outSize = min(srcW, 2048)  // Keep small to avoid OOM on iPhone

        let srcLonMin = -180.0, srcLonMax = 180.0
        let srcLatMax = 90.0
        let srcLatMin = -90.0

        guard let srcCtx = CGContext(
            data: nil, width: srcW, height: srcH, bitsPerComponent: 8, bytesPerRow: srcW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let srcData = srcCtx.data else { return nil }
        srcCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
        let srcPixels = srcData.bindMemory(to: UInt8.self, capacity: srcW * srcH * 4)

        guard let outCtx = CGContext(
            data: nil, width: outSize, height: outSize, bitsPerComponent: 8, bytesPerRow: outSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outData = outCtx.data else { return nil }
        let outPixels = outData.bindMemory(to: UInt8.self, capacity: outSize * outSize * 4)

        let mercMax = Double.pi

        for outRow in 0..<outSize {
            let yFrac = (Double(outRow) + 0.5) / Double(outSize)
            let mercY = mercMax * (1.0 - 2.0 * yFrac)
            let latRad = atan(sinh(mercY))
            let lat = latRad * 180.0 / .pi

            let rowFrac = (srcLatMax - lat) / (srcLatMax - srcLatMin)
            let srcRow = min(max(Int(rowFrac * Double(srcH)), 0), srcH - 1)

            for outCol in 0..<outSize {
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

        guard let result = outCtx.makeImage() else { return nil }
        return UIImage(cgImage: result)
    }

    /// Apply per-pixel filtering to a GEOGLAM image, hiding specified RGB colors.
    static func filterImage(_ image: UIImage, hiding colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> UIImage? {
        guard !colors.isEmpty, let cgImage = image.cgImage else { return image }
        let w = cgImage.width, h = cgImage.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
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

        guard let filtered = ctx.makeImage() else { return nil }
        return UIImage(cgImage: filtered)
    }
}
#endif
