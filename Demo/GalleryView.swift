import SwiftUI
import TieredImageCacheCore
import TieredImageCacheUI

/// The demo screen: a scrolling grid of images loaded through
/// `TieredImageCacheKit` end to end -- `CachedAsyncImageView` for
/// display, `PrefetchController` warming upcoming rows as you scroll,
/// and a live `CacheInspectorView` so the two-tier behavior is visible
/// instead of a black box. "Memory Warning" and "Clear All" buttons let
/// you trigger and observe eviction directly on device.
struct GalleryView: View {
    let cache: TieredImageCache
    let prefetcher: PrefetchController
    let memoryTier: MemoryCacheTier
    let diskTier: DiskCacheTier

    // Stable, seeded picsum.photos URLs -- the same key every launch, so
    // relaunching the app (or pull-to-refresh) demonstrates real
    // disk-tier persistence (near-instant reloads from the manifest)
    // rather than always re-downloading from scratch.
    private let imageKeys: [String] = (0..<30).map {
        "https://picsum.photos/seed/tiered-cache-demo-\($0)/400/400"
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if imageKeys.isEmpty {
                    ContentUnavailableFallback()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(imageKeys, id: \.self) { key in
                                CachedAsyncImageView(key: key, cache: cache) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(ProgressView())
                                }
                                .frame(height: 100)
                                .clipped()
                                .onAppear { schedulePrefetch(near: key) }
                            }
                        }
                        .padding(4)
                        .padding(.bottom, 64) // keep the last row clear of the inspector overlay
                    }
                }

                CacheInspectorView(memory: memoryTier, disk: diskTier)
                    .padding(.bottom, 8)
            }
            .navigationTitle("TieredImageCacheKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Memory Warning") {
                        Task {
                            await cache.handleMemoryPressure()
                            show("Simulated memory warning: memory tier trimmed to ~50%.")
                        }
                    }
                    Button("Clear All") {
                        Task {
                            await memoryTier.removeAll()
                            await diskTier.removeAll()
                            show("Cleared both tiers.")
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
        }
    }

    private func show(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }

    /// Bounds-safe prefetch scheduling: guards both the empty-list case
    /// and the "near the end of the list" case explicitly rather than
    /// relying on a Range subscript that could trap if `index + 1` ever
    /// exceeded `imageKeys.count`.
    private func schedulePrefetch(near key: String) {
        guard let index = imageKeys.firstIndex(of: key) else { return }
        let start = index + 1
        guard start < imageKeys.count else { return }
        let end = min(start + 4, imageKeys.count)
        let upcoming = Array(imageKeys[start..<end])
        guard !upcoming.isEmpty else { return }

        Task {
            await prefetcher.prefetch(keys: upcoming)
        }
    }
}

/// Guards the (here, unreachable, since `imageKeys` is a fixed literal
/// list) empty-collection case explicitly rather than silently rendering
/// a blank scroll view -- the crash-safety bar this repo holds itself to
/// applies to "renders nothing usefully" too, not just "doesn't trap."
private struct ContentUnavailableFallback: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No images configured")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let memory = MemoryCacheTier(capacityInBytes: 20_000_000)
    let disk = DiskCacheTier(
        directory: FileManager.default.temporaryDirectory.appendingPathComponent("PreviewCache"),
        capacityInBytes: 100_000_000
    )
    let cache = TieredImageCache(memory: memory, disk: disk, loader: URLSessionImageLoader())
    return GalleryView(
        cache: cache,
        prefetcher: PrefetchController(cache: cache),
        memoryTier: memory,
        diskTier: disk
    )
}
