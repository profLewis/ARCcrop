#if !os(tvOS)
import UIKit

// MARK: - GEOGLAM Overlay Manager

@MainActor
final class GEOGLAMOverlayManager {
    static let shared = GEOGLAMOverlayManager()
    private var cropCache: [GEOGLAMCrop: UIImage] = [:]
    private var majorityCropCache: UIImage?
    private var pendingCallbacks: [String: [(UIImage?) -> Void]] = [:]

    /// GitHub raw URL base for pre-projected GEOGLAM images
    private static let githubBase = "https://raw.githubusercontent.com/profLewis/ARCcrop/main/geoglam"

    /// Get a Mercator-projected image for a GEOGLAM crop (or majority crop if nil).
    /// First tries to load from the local cache directory (downloaded from GitHub).
    /// Falls back to downloading from GitHub, then to bundle + on-device reprojection.
    func mercatorImage(for crop: GEOGLAMCrop?) -> UIImage? {
        // Check memory cache
        if let crop {
            if let cached = cropCache[crop] { return cached }
        } else {
            if let cached = majorityCropCache { return cached }
        }

        let baseName = crop?.filename ?? "GEOGLAM_MajorityCrop"

        // 1. Try local cache (previously downloaded from GitHub)
        if let image = loadFromDiskCache(baseName) {
            cacheImage(image, for: crop)
            ActivityLog.shared.success("GEOGLAM \(crop?.rawValue ?? "Majority Crop") loaded from cache (\(Int(image.size.width))x\(Int(image.size.height)))")
            return image
        }

        // 2. Try bundle (pre-projected 3857 version if available)
        if let url = Bundle.main.url(forResource: "\(baseName)_3857_2048", withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            cacheImage(image, for: crop)
            ActivityLog.shared.success("GEOGLAM \(crop?.rawValue ?? "Majority Crop") loaded from bundle (\(Int(image.size.width))x\(Int(image.size.height)))")
            return image
        }

        // 3. Try bundle (original 4326 + on-device reprojection as last resort)
        if let url = Bundle.main.url(forResource: baseName, withExtension: "png"),
           let image = UIImage(contentsOfFile: url.path) {
            let mercator = Self.reprojectToMercator(image) ?? image
            cacheImage(mercator, for: crop)
            ActivityLog.shared.success("GEOGLAM \(crop?.rawValue ?? "Majority Crop") reprojected (\(Int(mercator.size.width))x\(Int(mercator.size.height)))")
            return mercator
        }

        // 4. Start async download from GitHub
        startDownload(baseName: baseName, crop: crop)
        return nil
    }

    /// Start async download from GitHub, notifying via activity log when done
    private func startDownload(baseName: String, crop: GEOGLAMCrop?) {
        let key = baseName
        // Avoid duplicate downloads
        guard pendingCallbacks[key] == nil else { return }
        pendingCallbacks[key] = []

        let urlString = "\(Self.githubBase)/\(baseName)_3857_2048.png"
        guard let url = URL(string: urlString) else { return }

        ActivityLog.shared.activity("Downloading GEOGLAM \(crop?.rawValue ?? "Majority Crop") from GitHub...")

        Task.detached {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard status == 200, let image = UIImage(data: data) else {
                    await MainActor.run {
                        ActivityLog.shared.error("GEOGLAM download failed (HTTP \(status))")
                        self.pendingCallbacks.removeValue(forKey: key)
                    }
                    return
                }

                // Save to disk cache
                await self.saveToDiskCache(data, name: baseName)

                await MainActor.run {
                    let sizeKB = data.count / 1024
                    self.cacheImage(image, for: crop)
                    ActivityLog.shared.success("GEOGLAM \(crop?.rawValue ?? "Majority Crop") downloaded (\(sizeKB) KB)")
                    self.pendingCallbacks.removeValue(forKey: key)

                    // Trigger map refresh so the layer appears
                    NotificationCenter.default.post(name: .geoglamDownloadComplete, object: nil)
                }
            } catch {
                await MainActor.run {
                    ActivityLog.shared.error("GEOGLAM download error: \(error.localizedDescription)")
                    self.pendingCallbacks.removeValue(forKey: key)
                }
            }
        }
    }

    private func cacheImage(_ image: UIImage, for crop: GEOGLAMCrop?) {
        if let crop {
            cropCache[crop] = image
        } else {
            majorityCropCache = image
        }
    }

    // MARK: - Disk cache

    private static var cacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("GEOGLAM")
    }

    private func loadFromDiskCache(_ name: String) -> UIImage? {
        guard let dir = Self.cacheDir else { return nil }
        let path = dir.appendingPathComponent("\(name)_3857.png")
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        return UIImage(contentsOfFile: path.path)
    }

    private func saveToDiskCache(_ data: Data, name: String) async {
        guard let dir = Self.cacheDir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("\(name)_3857.png")
        try? data.write(to: path)
    }

    // MARK: - On-device reprojection (fallback)

    /// Reproject an equirectangular (EPSG:4326) image to Web Mercator (EPSG:3857).
    /// Uses nearest-neighbor (correct for classified/categorical data).
    private static func reprojectToMercator(_ sourceImage: UIImage) -> UIImage? {
        guard let cgImage = sourceImage.cgImage else { return nil }
        let srcW = cgImage.width, srcH = cgImage.height
        let outSize = min(srcW, 2048)

        let srcLatMax = 90.0
        let srcLatMin = -90.0

        guard let srcCtx = CGContext(
            data: nil, width: srcW, height: srcH, bitsPerComponent: 8, bytesPerRow: srcW * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let srcData = srcCtx.data else { return nil }
        srcCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))
        let srcPixels = srcData.bindMemory(to: UInt8.self, capacity: srcW * srcH * 4)

        guard let outCtx = CGContext(
            data: nil, width: outSize, height: outSize, bitsPerComponent: 8, bytesPerRow: outSize * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
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
                let srcCol = min(max(Int(lonFrac * Double(srcW)), 0), srcW - 1)

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
    /// Uses nearest-color matching: for each target color, finds the closest actual pixel
    /// color in the image, then filters using that exact value. This avoids color space
    /// mismatches between legend definitions and actual pixel data.
    static func filterImage(_ image: UIImage, hiding colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> UIImage? {
        guard !colors.isEmpty, let cgImage = image.cgImage else { return image }
        let w = cgImage.width, h = cgImage.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let pixels = ctx.data else { return nil }
        let buf = pixels.bindMemory(to: UInt8.self, capacity: w * h * 4)

        // Build histogram of actual pixel colors in the image
        var colorHistogram: [UInt32: Int] = [:]
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if buf[i+3] == 0 { continue }
            let key = UInt32(buf[i]) << 16 | UInt32(buf[i+1]) << 8 | UInt32(buf[i+2])
            colorHistogram[key, default: 0] += 1
        }

        // For each target color, find the closest actual pixel color in the image.
        // This handles color space mismatches (sRGB vs P3 vs deviceRGB).
        var exactColors: Set<UInt32> = []
        for (tr, tg, tb) in colors {
            var bestDist = Int.max
            var bestKey: UInt32 = 0
            for (key, count) in colorHistogram where count > 100 {
                let r = Int(key >> 16 & 0xFF)
                let g = Int(key >> 8 & 0xFF)
                let b = Int(key & 0xFF)
                let dist = abs(r - Int(tr)) + abs(g - Int(tg)) + abs(b - Int(tb))
                if dist < bestDist {
                    bestDist = dist
                    bestKey = key
                }
            }
            if bestDist < 200 { // Sanity limit — don't match wildly different colors
                exactColors.insert(bestKey)
            }
        }

        // Filter using exact matched colors (tolerance 2 for rounding)
        var matched = 0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if buf[i+3] == 0 { continue }
            let key = UInt32(buf[i]) << 16 | UInt32(buf[i+1]) << 8 | UInt32(buf[i+2])
            if exactColors.contains(key) {
                buf[i+3] = 0
                matched += 1
            }
        }

        guard let filtered = ctx.makeImage() else { return nil }
        return UIImage(cgImage: filtered)
    }
}

extension Notification.Name {
    static let geoglamDownloadComplete = Notification.Name("geoglamDownloadComplete")
}
#endif
