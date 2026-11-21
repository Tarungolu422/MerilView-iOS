import Foundation
import UIKit

/// High-performance memory cache manager for medical image slices and scalar volumes.
public final class MerilCacheManager {
    
    public static let shared = MerilCacheManager()
    
    // Memory-bounded slice image cache
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Memory-bounded 16-bit scalar pixel buffer cache (approx max 64MB)
    private let pixelCache = NSCache<NSString, NSData>()
    
    private init() {
        // Allow up to 300 cached 512x512 slices (~300MB uncompressed)
        imageCache.countLimit = 300
        // Limit raw pixel cache to ~64MB
        pixelCache.totalCostLimit = 64 * 1024 * 1024
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("[MerilCacheManager] Memory warning received. Purging in-memory image caches.")
        imageCache.removeAllObjects()
        pixelCache.removeAllObjects()
    }
    
    public func clearAll() {
        imageCache.removeAllObjects()
        pixelCache.removeAllObjects()
    }
    
    // MARK: - Rendered Image Cache
    
    public func getCachedImage(filePath: String, wc: Double, ww: Double, invert: Bool) -> UIImage? {
        let key = cacheKey(filePath: filePath, wc: wc, ww: ww, invert: invert)
        return imageCache.object(forKey: key as NSString)
    }
    
    public func cacheImage(_ image: UIImage, filePath: String, wc: Double, ww: Double, invert: Bool) {
        let key = cacheKey(filePath: filePath, wc: wc, ww: ww, invert: invert)
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    // MARK: - Decoded Pixel Cache
    
    public func getDecodedPixels(filePath: String) -> [Int16]? {
        guard let data = pixelCache.object(forKey: filePath as NSString) else { return nil }
        let count = data.count / 2
        var result = [Int16](repeating: 0, count: count)
        _ = result.withUnsafeMutableBytes { buf in
            data.copyBytes(to: buf)
        }
        return result
    }
    
    public func cacheDecodedPixels(_ pixels: [Int16], filePath: String) {
        let byteCount = pixels.count * 2
        let data = pixels.withUnsafeBufferPointer { buf in
            Data(buffer: buf)
        }
        pixelCache.setObject(data as NSData, forKey: filePath as NSString, cost: byteCount)
    }
    
    private func cacheKey(filePath: String, wc: Double, ww: Double, invert: Bool) -> String {
        return "\(filePath):\(Int(wc)):\(Int(ww)):\(invert ? 1 : 0)"
    }
}
