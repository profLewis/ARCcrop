import Foundation
import os

@Observable @MainActor
final class ActivityLog {
    static let shared = ActivityLog()

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let level: Level

        enum Level {
            case info, success, warning, error
        }

        var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: timestamp)
        }
    }

    private(set) var entries: [Entry] = []
    /// True while an async operation is in progress (show spinner)
    var isActive: Bool = false
    /// Tile download progress (0...1), nil when not tracking tiles
    var tileProgress: Double? = nil
    /// Live progress text shown in the banner (updated frequently without spamming log)
    var progressText: String? = nil
    private var tilesRequested: Int = 0
    private var tilesCompleted: Int = 0

    func tileRequested() {
        tilesRequested += 1
        tileProgress = tilesRequested > 0 ? Double(tilesCompleted) / Double(tilesRequested) : nil
    }

    /// Accumulated download size for current batch in bytes
    private var batchBytes: Int = 0

    func tileCompleted(bytes: Int = 0) {
        tilesCompleted += 1
        batchBytes += bytes
        tileProgress = tilesRequested > 0 ? Double(tilesCompleted) / Double(tilesRequested) : nil
        // Update live progress text (shown in banner, not logged to entries)
        if tilesCompleted < tilesRequested {
            let pct = Int(Double(tilesCompleted) / Double(tilesRequested) * 100)
            progressText = "\(tilesCompleted)/\(tilesRequested) tiles (\(pct)%)"
        } else {
            progressText = nil
            isActive = false
            if batchBytes > 0 {
                let mb = Double(batchBytes) / (1024 * 1024)
                success(String(format: "Done — %.1fMB (%d tiles)", mb, tilesCompleted))
            } else {
                success("Done")
            }
        }
    }

    func resetTileProgress() {
        tilesRequested = 0
        tilesCompleted = 0
        tileProgress = nil
        progressText = nil
        batchBytes = 0
    }

    /// Log current tile cache stats
    func logCacheStats() {
        #if !os(tvOS)
        let cache = WMSTileOverlay.tileCache
        let usedMB = Double(cache.currentDiskUsage) / (1024 * 1024)
        let capMB = Double(cache.diskCapacity) / (1024 * 1024)
        let memMB = Double(cache.currentMemoryUsage) / (1024 * 1024)
        info(String(format: "Cache: %.1fMB disk (%.0fMB cap), %.1fMB memory", usedMB, capMB, memMB))
        #endif
    }
    var latestMessage: String? { entries.last?.message }
    var latestLevel: Entry.Level? { entries.last?.level }

    func info(_ msg: String) { append(msg, level: .info) }
    func success(_ msg: String) { isActive = false; progressText = nil; append(msg, level: .success) }
    func warn(_ msg: String) { isActive = false; progressText = nil; append(msg, level: .warning) }
    func error(_ msg: String) { isActive = false; progressText = nil; append(msg, level: .error) }
    /// Log an activity message and mark as active (shows spinner)
    func activity(_ msg: String) { isActive = true; append(msg, level: .info) }
    func clear() { entries.removeAll(); isActive = false; progressText = nil }

    private func append(_ msg: String, level: Entry.Level) {
        entries.append(Entry(message: msg, level: level))
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        let osLevel: OSLogType = switch level {
        case .info: .info
        case .success: .info
        case .warning: .default
        case .error: .error
        }
        os_log("%{public}@", log: .default, type: osLevel, msg)
    }

    private init() {}
}
