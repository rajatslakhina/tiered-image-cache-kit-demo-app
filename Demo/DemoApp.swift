import SwiftUI
import TieredImageCacheCore
import TieredImageCacheUI

@main
struct DemoApp: App {
    let cache: TieredImageCache
    let prefetcher: PrefetchController
    let memoryTier: MemoryCacheTier
    let diskTier: DiskCacheTier

    init() {
        // Real on-disk location under Caches/, so this demo genuinely
        // exercises the "survives relaunch" contract documented in
        // TieredImageCacheKit's README -- not a temp directory that gets
        // wiped every run.
        //
        // `.first` rather than an unchecked `[0]`: FileManager.urls(for:in:)
        // returns an array, and while `.cachesDirectory`/`.userDomainMask`
        // is guaranteed non-empty on iOS in practice, this repo's own bar
        // (see library README) is "no unguarded collection access, full
        // stop" -- so this falls back to `temporaryDirectory` (always
        // available) rather than trusting that guarantee blindly.
        let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let cachesDirectory = cachesRoot.appendingPathComponent("TieredImageCacheDemo", isDirectory: true)

        let memory = MemoryCacheTier(capacityInBytes: 20_000_000)     // 20 MB
        let disk = DiskCacheTier(directory: cachesDirectory, capacityInBytes: 100_000_000) // 100 MB
        let cache = TieredImageCache(memory: memory, disk: disk, loader: URLSessionImageLoader())

        self.memoryTier = memory
        self.diskTier = disk
        self.cache = cache
        self.prefetcher = PrefetchController(cache: cache)
    }

    var body: some Scene {
        WindowGroup {
            GalleryView(cache: cache, prefetcher: prefetcher, memoryTier: memoryTier, diskTier: diskTier)
        }
    }
}
