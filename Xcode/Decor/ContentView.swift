import SwiftUI
import AppKit

// Configuration manager for admin-controlled settings.
//
// Each property is read from UserDefaults.standard under the flat key listed
// below. The macOS managed-preferences system writes MDM-pushed values into
// the app's defaults domain (`/Library/Managed Preferences/<user>/<bundle-id>.plist`),
// so reading them is identical to reading any other default — managed values
// automatically take precedence over user-set values.
@Observable
class DecorConfig {
    var thumbnailSize: CGFloat = Defaults.thumbnailSize
    var thumbnailHighlightColor: Color = Defaults.thumbnailHighlightColor
    var textHighlightColor: Color = Defaults.textHighlightColor
    var gridSpacing: CGFloat = Defaults.gridSpacing
    var cornerRadius: CGFloat = Defaults.cornerRadius
    var shadowRadius: CGFloat = Defaults.shadowRadius
    var maxThumbnailsPerRow: Int = Defaults.maxThumbnailsPerRow
    var defaultColumnCount: Int = Defaults.defaultColumnCount
    var defaultRowCount: Int = Defaults.defaultRowCount
    var showWallpaperInfo: Bool = Defaults.showWallpaperInfo
    var showCollectionTitles: Bool = Defaults.showCollectionTitles
    var wallpapersPath: String = Defaults.wallpapersPath
    var doubleClickToSetWallpaper: Bool = Defaults.doubleClickToSetWallpaper
    var hideOtherAppsOnLaunch: Bool = Defaults.hideOtherAppsOnLaunch
    var logoPath: String = Defaults.logoPath
    var logoPathDark: String = Defaults.logoPathDark
    var logoTitle: String = Defaults.logoTitle
    var launchPosition: String = Defaults.launchPosition // "left" | "right" | "center"

    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?

    private enum Defaults {
        static let thumbnailSize: CGFloat = 200
        static let thumbnailHighlightColor: Color = .blue
        static let textHighlightColor: Color = .blue
        static let gridSpacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 2
        static let maxThumbnailsPerRow: Int = 6
        static let defaultColumnCount: Int = 4
        static let defaultRowCount: Int = 3
        static let showWallpaperInfo: Bool = true
        static let showCollectionTitles: Bool = true
        static let wallpapersPath: String = "/Library/Desktop Pictures"
        static let doubleClickToSetWallpaper: Bool = false
        static let hideOtherAppsOnLaunch: Bool = true
        static let logoPath: String = "/Library/Icons/icon-dark.png"
        static let logoPathDark: String = "/Library/Icons/icon-light.png"
        static let logoTitle: String = "Select your wallpaper"
        static let launchPosition: String = "center"
    }

    init() {
        loadConfig()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadConfig()
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private func loadConfig() {
        let d = UserDefaults.standard

        set(\.thumbnailSize, clampedFloat(d, "thumbnailSize", min: 100, max: 400, or: Defaults.thumbnailSize))
        set(\.thumbnailHighlightColor, color(d, "thumbnailHighlightColor", or: Defaults.thumbnailHighlightColor))
        set(\.textHighlightColor, color(d, "textHighlightColor", or: Defaults.textHighlightColor))
        set(\.gridSpacing, clampedFloat(d, "gridSpacing", min: 4, max: 32, or: Defaults.gridSpacing))
        set(\.cornerRadius, clampedFloat(d, "cornerRadius", min: 0, max: 24, or: Defaults.cornerRadius))
        set(\.shadowRadius, clampedFloat(d, "shadowRadius", min: 0, max: 10, or: Defaults.shadowRadius))
        set(\.maxThumbnailsPerRow, clampedInt(d, "maxThumbnailsPerRow", min: 2, max: 20, or: Defaults.maxThumbnailsPerRow))
        set(\.defaultColumnCount, clampedInt(d, "defaultColumnCount", min: 1, max: 20, or: Defaults.defaultColumnCount))
        set(\.defaultRowCount, clampedInt(d, "defaultRowCount", min: 1, max: 20, or: Defaults.defaultRowCount))
        set(\.showWallpaperInfo, (d.object(forKey: "showWallpaperInfo") as? Bool) ?? Defaults.showWallpaperInfo)
        set(\.showCollectionTitles, (d.object(forKey: "showCollectionTitles") as? Bool) ?? Defaults.showCollectionTitles)
        let resolvedPath = d.string(forKey: "wallpapersPath")
            .flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
        set(\.wallpapersPath, resolvedPath ?? Defaults.wallpapersPath)
        set(\.doubleClickToSetWallpaper, (d.object(forKey: "doubleClickToSetWallpaper") as? Bool) ?? Defaults.doubleClickToSetWallpaper)
        set(\.hideOtherAppsOnLaunch, (d.object(forKey: "hideOtherAppsOnLaunch") as? Bool) ?? Defaults.hideOtherAppsOnLaunch)
        set(\.logoPath, expandedPath(d, "logoPath", or: Defaults.logoPath))
        set(\.logoPathDark, expandedPath(d, "logoPathDark", or: Defaults.logoPathDark))
        set(\.logoTitle, d.string(forKey: "logoTitle") ?? Defaults.logoTitle)
        let validPositions: Set<String> = ["left", "right", "center"]
        let position = d.string(forKey: "launchPosition")
            .flatMap { validPositions.contains($0) ? $0 : nil }
        set(\.launchPosition, position ?? Defaults.launchPosition)
    }

    // Skip the write when the value hasn't changed so @Observable doesn't
    // emit a mutation on every UserDefaults.didChangeNotification (which
    // fires for unrelated defaults writes elsewhere in the app).
    private func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<DecorConfig, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func clampedFloat(_ d: UserDefaults, _ key: String, min lower: CGFloat, max upper: CGFloat, or fallback: CGFloat) -> CGFloat {
        guard let v = d.object(forKey: key) as? NSNumber else { return fallback }
        return Swift.min(Swift.max(lower, CGFloat(v.doubleValue)), upper)
    }

    private func clampedInt(_ d: UserDefaults, _ key: String, min lower: Int, max upper: Int, or fallback: Int) -> Int {
        guard let v = d.object(forKey: key) as? NSNumber else { return fallback }
        return Swift.min(Swift.max(lower, v.intValue), upper)
    }

    private func color(_ d: UserDefaults, _ key: String, or fallback: Color) -> Color {
        guard let hex = d.string(forKey: key) else { return fallback }
        return Color(hex: hex)
    }

    private func expandedPath(_ d: UserDefaults, _ key: String, or fallback: String) -> String {
        guard let path = d.string(forKey: key) else { return fallback }
        return path.isEmpty ? "" : (path as NSString).expandingTildeInPath
    }

    // Content-area size the window should open at to show exactly the
    // configured number of columns and rows with no leftover whitespace.
    var launchContentSize: NSSize {
        let n = CGFloat(min(max(1, defaultColumnCount), maxThumbnailsPerRow))
        let width = n * thumbnailSize + (n - 1) * gridSpacing + Layout.outerPadding

        let rows = CGFloat(max(1, defaultRowCount))
        let imageHeight = thumbnailSize / Layout.thumbnailAspectRatio
        let nameSection: CGFloat = showWallpaperInfo ? Layout.nameSectionHeight : 0
        let cardHeight = imageHeight + nameSection
        let gridContentHeight = rows * cardHeight + (rows - 1) * gridSpacing + Layout.outerPadding
        let hasHeader = !logoPath.isEmpty || !logoPathDark.isEmpty || !logoTitle.isEmpty
        let headerHeight: CGFloat = hasHeader ? Layout.headerHeight : 0
        // The multi-display mode pill is only laid out when >1 screen is
        // attached; reserve room for it so the bottom row of cards isn't
        // clipped on first launch.
        let pillHeight: CGFloat = NSScreen.screens.count > 1 ? Layout.modePillContainerHeight : 0
        let height = gridContentHeight + headerHeight + pillHeight

        return NSSize(width: width, height: height)
    }
}

// Layout constants pulled from the SwiftUI views below. Kept in one place
// so the launch-size precomputation in DecorConfig.launchContentSize stays
// in sync when the visual layout is tweaked.
private enum Layout {
    // .padding() applied to the grid ScrollView: 16pt on each side.
    static let outerPadding: CGFloat = 32
    // 16:10 image aspect; image height = thumbnailSize / aspectRatio.
    static let thumbnailAspectRatio: CGFloat = 1.6
    // 8pt VStack spacing + ~34pt for a line of .headline on macOS + 8pt bottom padding.
    static let nameSectionHeight: CGFloat = 50
    // 50pt logo + 16pt top + 12pt bottom padding.
    static let headerHeight: CGFloat = 78
    // 20pt top + 16pt bottom padding around the ~32pt mode pill in mainView.
    static let modePillContainerHeight: CGFloat = 68
}

// Color extension for hex values
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            // Visible "configuration error" fallback so admins spot
            // mistyped hex values in their managed-preferences plist
            // immediately rather than seeing a silently-transparent fill.
            (a, r, g, b) = (255, 255, 0, 255) // magenta
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Quit when the user closes the window — this is a one-shot utility,
    // not a background/menu-bar app, so staying alive in the Dock with no
    // window would be confusing.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// Hides the host window the moment SwiftUI attaches us to it, so the
// whole window (chrome + content) can fade in via the launch animation.
// Doing this from a view-attached NSViewRepresentable rather than
// applicationDidFinishLaunching avoids a race on first launch where the
// delegate callback could fire AFTER the fade-in had already run,
// leaving the window stuck at alphaValue 0. The `launchHandled` flag
// coordinates with applyLaunchActionsIfNeeded for the inverse race: if
// .onAppear fires before viewWillMove, the fade-in claims alpha first
// and the late viewWillMove becomes a no-op (otherwise it would zero
// out the alpha after the animation had already finished).
struct LaunchWindowHider: NSViewRepresentable {
    static var launchHandled = false

    func makeNSView(context: Context) -> NSView { HiderView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class HiderView: NSView {
        private var didHide = false
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            guard !didHide, let newWindow else { return }
            didHide = true
            guard !LaunchWindowHider.launchHandled else { return }
            newWindow.alphaValue = 0
        }
    }
}

// Shared thumbnail cache so primary + every aux window decode each
// wallpaper at most once, even though they all show the same grid.
// Uses CGImageSourceCreateThumbnailAtIndex to downsample directly from
// the file without fully decoding the source image, which is the
// biggest single-image cost on high-res wallpapers.
// @MainActor-isolated so the dictionaries stay race-free under the
// many concurrent WallpaperCard `.task` calls that fire on launch;
// the actual decode runs in a Task.detached so main isn't blocked.
@MainActor
final class WallpaperCache {
    private var thumbnails: [UUID: NSImage] = [:]
    private var inFlight: [UUID: Task<NSImage?, Never>] = [:]

    func cached(_ id: UUID) -> NSImage? { thumbnails[id] }

    func clear() {
        thumbnails.removeAll()
        inFlight.removeAll()
    }

    func thumbnail(for wallpaper: WallpaperItem, targetSize: NSSize, scale: CGFloat) async -> NSImage? {
        if let cached = thumbnails[wallpaper.id] { return cached }
        if let existing = inFlight[wallpaper.id] { return await existing.value }

        let id = wallpaper.id
        let path = wallpaper.path
        let task = Task<NSImage?, Never>.detached(priority: .userInitiated) {
            WallpaperCache.makeThumbnail(path: path, targetSize: targetSize, scale: scale)
        }
        inFlight[id] = task
        let result = await task.value
        if let result {
            thumbnails[id] = result
        }
        inFlight[id] = nil
        return result
    }

    nonisolated private static func makeThumbnail(path: String, targetSize: NSSize, scale: CGFloat) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let maxPixel = max(targetSize.width, targetSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: targetSize)
    }
}

// Coordinates the "set each display individually" mode. When enabled,
// one auxiliary NSWindow is spawned on every non-primary NSScreen, each
// running its own ContentView. Each window's preview/apply targets only
// its own screen. The mode toggle pill lives on the primary window only.
// Also owns the shared wallpaper collections + thumbnail cache so every
// ContentView reads the same already-decoded images.
@MainActor
@Observable
final class MultiDisplayController {
    var individualMode: Bool = false
    weak var primaryWindow: NSWindow?
    var collections: [WallpaperCollection] = []
    @ObservationIgnored let cache = WallpaperCache()
    @ObservationIgnored private var loadedPath: String?
    @ObservationIgnored private var auxWindows: [NSWindow] = []
    @ObservationIgnored private weak var config: DecorConfig?

    func registerPrimary(_ window: NSWindow, config: DecorConfig) {
        guard primaryWindow == nil else { return }
        primaryWindow = window
        self.config = config
    }

    // Load wallpaper collections from `path`, no-op if we've already
    // loaded this path. Synchronous because the filesystem enumeration
    // is fast and the result needs to be visible before .onAppear
    // returns so the grid paints on the first frame.
    func loadCollections(from path: String) {
        if loadedPath == path { return }
        loadedPath = path
        cache.clear()
        collections = loadWallpapersFromDirectory(path)
    }

    func reloadCollections(from path: String) {
        loadedPath = nil
        loadCollections(from: path)
    }

    func setIndividualMode(_ on: Bool) {
        guard on != individualMode else { return }
        individualMode = on
        // Defer window spawn/close by one runloop tick so the pill's
        // bool flip is committed and SwiftUI's pill animation can begin
        // before the main thread spends time on NSHostingController
        // setup (or teardown).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.individualMode {
                self.spawnAuxWindows()
            } else {
                self.closeAuxWindows()
            }
        }
    }

    private func spawnAuxWindows() {
        closeAuxWindows()
        guard let config else { return }
        let primaryScreen = primaryWindow?.screen
        let others = NSScreen.screens.filter { $0 != primaryScreen }
        for screen in others {
            auxWindows.append(makeAuxWindow(on: screen, config: config, controller: self))
        }
    }

    private func closeAuxWindows() {
        for window in auxWindows where window.isVisible {
            window.close()
        }
        auxWindows.removeAll()
    }
}

// Top-level so MultiDisplayController.loadCollections can call it
// without going through ContentView.
private func loadWallpapersFromDirectory(_ path: String) -> [WallpaperCollection] {
    let fileManager = FileManager.default
    let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "bmp", "webp"]

    func loadImages(in directory: String) -> [WallpaperItem] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { return [] }
        var items: [WallpaperItem] = []
        for filename in contents where !filename.hasPrefix(".") {
            let ext = (filename as NSString).pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }
            items.append(WallpaperItem(
                id: UUID(),
                name: (filename as NSString).deletingPathExtension,
                path: "\(directory)/\(filename)"
            ))
        }
        return items.sorted { $0.name < $1.name }
    }

    func isDirectory(_ fullPath: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) && isDir.boolValue
    }

    // Strip a leading numeric prefix used purely for ordering, so admins
    // can force display order with names like "01-Featured", "02_Nature",
    // "03 Abstract". The raw name is still used as the sort key.
    func displayName(forFolder raw: String) -> String {
        guard let sep = raw.firstIndex(where: { $0 == "-" || $0 == "_" || $0 == " " }) else { return raw }
        let prefix = raw[..<sep]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return raw }
        let remainder = raw[raw.index(after: sep)...]
        return remainder.isEmpty ? raw : String(remainder)
    }

    guard let topLevel = try? fileManager.contentsOfDirectory(atPath: path) else {
        return []
    }

    var looseItems: [WallpaperItem] = []
    var subfolders: [(sortKey: String, title: String, items: [WallpaperItem])] = []

    for entry in topLevel where !entry.hasPrefix(".") {
        let fullPath = "\(path)/\(entry)"
        if isDirectory(fullPath) {
            let items = loadImages(in: fullPath)
            guard !items.isEmpty else { continue }
            subfolders.append((sortKey: entry, title: displayName(forFolder: entry), items: items))
        } else {
            let ext = (entry as NSString).pathExtension.lowercased()
            guard imageExtensions.contains(ext) else { continue }
            looseItems.append(WallpaperItem(
                id: UUID(),
                name: (entry as NSString).deletingPathExtension,
                path: fullPath
            ))
        }
    }

    var result: [WallpaperCollection] = []
    if !looseItems.isEmpty {
        result.append(WallpaperCollection(
            id: UUID(),
            title: "",
            wallpapers: looseItems.sorted { $0.name < $1.name }
        ))
    }
    for sub in subfolders.sorted(by: { $0.sortKey < $1.sortKey }) {
        result.append(WallpaperCollection(id: UUID(), title: sub.title, wallpapers: sub.items))
    }
    return result
}

private func makeAuxWindow(
    on screen: NSScreen,
    config: DecorConfig,
    controller: MultiDisplayController
) -> NSWindow {
    let size = config.launchContentSize
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size),
        styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 600, height: 400)
    window.isRestorable = false

    let host = NSHostingController(rootView: ContentView(
        config: config,
        controller: controller,
        isPrimary: false,
        initialHostWindow: window
    ))
    window.contentViewController = host

    window.setContentSize(size)
    window.setFrame(launchFrame(on: screen, size: window.frame.size, position: config.launchPosition), display: true)
    window.makeKeyAndOrderFront(nil)

    return window
}

private func launchFrame(on screen: NSScreen, size: NSSize, position: String) -> NSRect {
    let visible = screen.visibleFrame
    var frame = NSRect(origin: .zero, size: size)
    frame.origin.y = visible.origin.y + (visible.height - frame.height) / 2
    switch position {
    case "left":  frame.origin.x = visible.origin.x
    case "right": frame.origin.x = visible.maxX - frame.width
    default:      frame.origin.x = visible.origin.x + (visible.width - frame.width) / 2
    }
    return frame
}

@main
struct DecorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var config = DecorConfig()
    @State private var multiDisplayController = MultiDisplayController()

    var body: some Scene {
        Window("Decor", id: "main") {
            ContentView(config: config, controller: multiDisplayController)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: config.launchContentSize.width, height: config.launchContentSize.height)
    }
}

private struct DesktopSnapshot {
    let screen: NSScreen
    let url: URL?
    let options: [NSWorkspace.DesktopImageOptionKey: Any]
}

struct ContentView: View {
    let config: DecorConfig
    let controller: MultiDisplayController
    // Primary vs aux is fixed at view-construction time. Storing it as
    // a plain `let` instead of deriving it from controller.primaryWindow
    // means body never reads (and therefore never subscribes to) the
    // primaryWindow @Observable property — which used to trigger a
    // re-render mid-launch that snapped the alpha animation.
    let isPrimary: Bool
    // Aux ContentViews receive their host window at init time;
    // primary ContentViews resolve it from NSApp.windows.first on
    // .onAppear so no in-body NSViewRepresentable is needed.
    private let initialHostWindow: NSWindow?
    @State private var hostWindow: NSWindow?
    @State private var selectedWallpaper: WallpaperItem?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var didApplyLaunchActions = false
    @State private var logoImage: NSImage?
    @State private var isPreviewing = false
    @State private var originalWindowFrame: NSRect = .zero
    @State private var originalDesktopState: [DesktopSnapshot] = []
    @State private var isAnimatingBack = false
    @State private var isConfirming = false
    @State private var currentlyAppliedPaths: Set<String> = []
    @State private var focusedWallpaperID: UUID?
    @State private var currentColumnCount: Int = 1
    @State private var keyMonitor: Any?
    @Namespace private var pillHighlightNamespace
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveLogoPath: String {
        if colorScheme == .dark && !config.logoPathDark.isEmpty {
            return config.logoPathDark
        }
        return config.logoPath
    }
    
    // Wallpaper collections live on the controller so all ContentViews
    // (primary + every aux per-screen window) share the same loaded list
    // and the same thumbnail cache.
    private var collections: [WallpaperCollection] {
        controller.collections
    }

    // Flat ordered list of every wallpaper currently shown, across all
    // collections. Used by preview cycling so left/right arrows flow across
    // section boundaries in display order rather than dead-ending at one.
    private var allWallpapers: [WallpaperItem] {
        collections.flatMap(\.wallpapers)
    }

    // Compute how many fixed-width columns fit in the available width.
    // Cards stay at config.thumbnailSize regardless of window size; the
    // window just shows more or fewer of them. Capped by maxThumbnailsPerRow.
    private func columnCount(for width: CGFloat) -> Int {
        let cellWidth = config.thumbnailSize
        let spacing = config.gridSpacing
        let outerPadding: CGFloat = 32 // .padding() applies 16 on each side
        let availableWidth = max(0, width - outerPadding)
        let maxFit = max(1, Int((availableWidth + spacing) / (cellWidth + spacing)))
        return min(config.maxThumbnailsPerRow, maxFit)
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.fixed(config.thumbnailSize), spacing: config.gridSpacing),
              count: columnCount(for: width))
    }

    init(
        config: DecorConfig,
        controller: MultiDisplayController,
        isPrimary: Bool = true,
        initialHostWindow: NSWindow? = nil
    ) {
        self.config = config
        self.controller = controller
        self.isPrimary = isPrimary
        self.initialHostWindow = initialHostWindow
    }

    var body: some View {
        Group {
            if isAnimatingBack {
                // Render nothing during the grow-back so thumbnails don't
                // pop into a partially-resized window. The background color
                // below fills the entire animating frame.
                Color.clear
            } else if isPreviewing {
                previewView
            } else {
                mainView
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .background(LaunchWindowHider())
        .onAppear {
            if hostWindow == nil {
                // Aux ContentViews get their window via init; the primary
                // resolves it from NSApp.windows.first which at first
                // .onAppear is the SwiftUI Window scene's window (no aux
                // windows can exist yet — they only spawn on toggle).
                hostWindow = initialHostWindow ?? NSApp.windows.first
            }
            loadDefaultWallpapers()
            applyLaunchActionsIfNeeded()
            refreshCurrentlyApplied()
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
        .onChange(of: config.wallpapersPath) {
            // The new directory has different filenames, so any UUIDs we
            // had selected are stale. Controller also clears its cache
            // in reloadCollections.
            selectedWallpaper = nil
            focusedWallpaperID = nil
            controller.reloadCollections(from: config.wallpapersPath)
            refreshCurrentlyApplied()
        }
        .onChange(of: controller.individualMode) {
            refreshCurrentlyApplied()
        }
        .task(id: effectiveLogoPath) {
            await loadLogo()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
            handleWindowClose(note)
        }
        .alert("Decor", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }

    // Closing the window via the red traffic light is treated the same way
    // as the visible buttons: in preview, it's a Cancel (silently revert);
    // on the grid, it's a quit (no desktop changes to undo). The Keep flow
    // sets `isConfirming` true while it fades out, so we skip restore there.
    private func handleWindowClose(_ note: Notification) {
        guard let window = note.object as? NSWindow,
              window == hostWindow,
              isPreviewing, !isConfirming
        else { return }
        restoreDesktopState(originalDesktopState)
    }

    // Screens whose desktop this window's preview/apply will affect.
    // In "all displays" mode every window targets every screen; in
    // individual mode each window targets only the screen it lives on.
    private var targetScreens: [NSScreen] {
        if controller.individualMode {
            if let screen = hostWindow?.screen {
                return [screen]
            }
            return []
        }
        return NSScreen.screens
    }

    // Hide the mode pill when there's nothing to choose between (single
    // display) or when this ContentView is hosted in an aux per-screen
    // window — the toggle belongs only on the primary.
    private var shouldShowModePill: Bool {
        NSScreen.screens.count > 1 && isPrimary
    }

    @ViewBuilder
    private var mainView: some View {
        VStack(spacing: 0) {
            // Optional header. Shown when there's a logo, a title, or both.
            // When neither is configured the grid sits at the top as before.
            if logoImage != nil || !config.logoTitle.isEmpty {
                HStack(spacing: 12) {
                    if let logoImage {
                        Image(nsImage: logoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                    }
                    if !config.logoTitle.isEmpty {
                        Text(config.logoTitle)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }

            // Wallpaper Grid — fills the remaining vertical space and
            // reflows columns based on the current window width. Each
            // collection renders as an optional header followed by its
            // grid; an empty title means no header (loose root files or
            // the legacy no-subfolders layout).
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: config.gridSpacing * 2) {
                            ForEach(collections) { collection in
                                VStack(alignment: .leading, spacing: config.gridSpacing) {
                                    if config.showCollectionTitles && !collection.title.isEmpty {
                                        collectionHeader(collection.title)
                                    }
                                    LazyVGrid(columns: columns(for: proxy.size.width), spacing: config.gridSpacing) {
                                        ForEach(collection.wallpapers, id: \.id) { wallpaper in
                                            wallpaperCard(wallpaper)
                                                .id(wallpaper.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: focusedWallpaperID) { _, newID in
                        guard let newID else { return }
                        withAnimation(.easeOut(duration: 0.15)) {
                            scrollProxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    currentColumnCount = columnCount(for: proxy.size.width)
                }
                .onChange(of: proxy.size.width) { _, width in
                    currentColumnCount = columnCount(for: width)
                }
            }

            if shouldShowModePill {
                HStack {
                    Spacer()
                    modePill
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // Two-state segmented pill at the bottom of the primary window.
    // Switches the controller between "set the same wallpaper on every
    // display" and "spawn a per-display grid for individual choices".
    // The highlight slides between segments via matchedGeometryEffect.
    @ViewBuilder
    private var modePill: some View {
        HStack(spacing: 0) {
            modePillSegment(title: "Set all displays", active: !controller.individualMode) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    controller.setIndividualMode(false)
                }
            }
            modePillSegment(title: "Set displays individually", active: controller.individualMode) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                    controller.setIndividualMode(true)
                }
            }
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func modePillSegment(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(active ? Color.white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    // matchedGeometryEffect treats the appearing/
                    // disappearing capsule on each side as the same
                    // view, so withAnimation can slide it between
                    // segments instead of fading two separate fills.
                    if active {
                        Capsule(style: .continuous)
                            .fill(config.thumbnailHighlightColor)
                            .matchedGeometryEffect(id: "pillHighlight", in: pillHighlightNamespace)
                    }
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    // Section header: collection title with an almost-full-width underline.
    // Left-aligned, with a small trailing margin so the line stops short of
    // the right edge for a more polished look.
    @ViewBuilder
    private func collectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            Rectangle()
                .fill(Color.primary.opacity(0.25))
                .frame(height: 1)
                .padding(.trailing, 24)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func wallpaperCard(_ wallpaper: WallpaperItem) -> some View {
        WallpaperCard(
            wallpaper: wallpaper,
            isSelected: selectedWallpaper?.id == wallpaper.id,
            isCurrentlyApplied: currentlyAppliedPaths.contains(wallpaper.path),
            isFocused: focusedWallpaperID == wallpaper.id,
            onSelect: { enterPreview(wallpaper) },
            onSetWallpaper: { setWallpaperAndQuit(wallpaper) },
            config: config,
            cache: controller.cache
        )
    }

    @ViewBuilder
    private var previewView: some View {
        if isConfirming {
            confirmationView
        } else {
            previewControlsView
        }
    }

    @ViewBuilder
    private var confirmationView: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)
                .font(.system(size: 30, weight: .bold))
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallpaper set")
                    .font(.headline)
                if let wallpaper = selectedWallpaper {
                    Text(wallpaper.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var previewControlsView: some View {
        HStack(spacing: 10) {
            if let wallpaper = selectedWallpaper {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(wallpaper.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Group all right-side controls so we can shift the whole strip
            // down to align with the wallpaper name (the headline), instead
            // of sitting at the VStack's geometric center between "Preview"
            // and the name.
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Button(action: { cyclePreview(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .help("Previous wallpaper")
                    .disabled(allWallpapers.count < 2)

                    Button(action: { cyclePreview(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .help("Next wallpaper")
                    .disabled(allWallpapers.count < 2)
                }
                .padding(.trailing, 16)

                Button(action: { cancelPreview() }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .help("Back to grid")

                Button(action: { confirmPreview() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .help("Keep wallpaper")
            }
            // Push the alignment line up inside the buttons' frame so HStack
            // positions them ~8pt below its geometric center — matching the
            // headline line within the VStack.
            .alignmentGuide(VerticalAlignment.center) { d in
                d[VerticalAlignment.center] - 8
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cyclePreview(by delta: Int) {
        let all = allWallpapers
        guard !all.isEmpty,
              let current = selectedWallpaper,
              let currentIndex = all.firstIndex(where: { $0.id == current.id })
        else { return }
        let count = all.count
        let newIndex = ((currentIndex + delta) % count + count) % count
        enterPreview(all[newIndex])
    }
    
    private func loadDefaultWallpapers() {
        controller.loadCollections(from: config.wallpapersPath)
    }

    private func applyLaunchActionsIfNeeded() {
        guard !didApplyLaunchActions else { return }
        didApplyLaunchActions = true

        // Aux ContentViews skip the primary launch sequence — their own
        // makeAuxWindow handles their positioning + fade-in.
        guard isPrimary, let window = hostWindow else { return }
        controller.registerPrimary(window, config: config)

        // Claim alpha management before LaunchWindowHider can re-zero
        // it; then show the window at full alpha as soon as it's
        // positioned. No fade — fastest possible appearance.
        LaunchWindowHider.launchHandled = true
        window.isRestorable = false
        window.setContentSize(config.launchContentSize)
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(launchFrame(on: screen, size: window.frame.size, position: config.launchPosition), display: true)
        }
        window.alphaValue = 1

        if config.hideOtherAppsOnLaunch {
            // Ensure Decor is the frontmost app before asking the system to
            // hide everyone else. On a cold launch .onAppear can fire before
            // activation has fully propagated, and hideOtherApplications
            // would then treat Decor as one of the "others" and hide it too.
            NSApp.activate(ignoringOtherApps: true)
            NSApp.hideOtherApplications(nil)
        }
    }

    // Animates an NSWindow frame change with the content rasterized to a
    // bitmap layer for the duration of the animation. This avoids per-frame
    // SwiftUI layout work (GeometryReader column reflow, grid invalidation),
    // which is what makes the default `animator().setFrame` feel jerky.
    private func smoothlyAnimate(
        _ window: NSWindow,
        toFrame target: NSRect,
        duration: TimeInterval,
        onCompletion: (() -> Void)? = nil
    ) {
        let contentView = window.contentView
        contentView?.wantsLayer = true
        if let layer = contentView?.layer {
            layer.rasterizationScale = window.backingScaleFactor
            layer.shouldRasterize = true
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.65, 0, 0.35, 1)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(target, display: true)
        }, completionHandler: {
            contentView?.layer?.shouldRasterize = false
            onCompletion?()
        })
    }

    // MARK: - Preview flow

    private func enterPreview(_ wallpaper: WallpaperItem) {
        selectedWallpaper = wallpaper

        // Capture state on first entry only; subsequent clicks while in
        // preview replace the previewed wallpaper but keep the original
        // capture for restore-on-cancel.
        let firstEntry = !isPreviewing
        if firstEntry {
            originalDesktopState = captureDesktopState()
            if let window = hostWindow {
                originalWindowFrame = window.frame
            }
        }
        isPreviewing = true

        // Kick off the apply on a background queue and start the window
        // shrink animation immediately — they run in parallel so the
        // animation doesn't wait on the per-screen IPC roundtrips.
        applyWallpaper(wallpaper) { error in
            if let error {
                showAlert("Failed to preview wallpaper: \(error.localizedDescription)")
            }
        }

        // Animate the window down to a small preview pill in the top-right
        // corner of the screen, but only on first entry — subsequent clicks
        // while previewing just swap the wallpaper without re-animating.
        if firstEntry, let window = hostWindow {
            // Let the window go smaller than the main view's 600×400 floor.
            window.minSize = NSSize(width: 440, height: 80)
            let target = previewWindowFrame(for: window)
            smoothlyAnimate(window, toFrame: target, duration: 0.3)
        }
    }

    private func cancelPreview() {
        restoreDesktopState(originalDesktopState)
        let target = originalWindowFrame

        // If we never captured a real window frame (shouldn't happen via
        // the UI path), skip the animation rather than animating to .zero.
        guard target != .zero, let window = hostWindow else {
            isPreviewing = false
            selectedWallpaper = nil
            originalDesktopState = []
            return
        }

        // Restore main-view minimum first so the animation can grow back.
        window.minSize = NSSize(width: 600, height: 400)
        // Show the empty "animating back" state during the grow so the
        // grid (and its thumbnails) doesn't render in a partially-resized
        // window. mainView only mounts once the animation completes.
        isAnimatingBack = true
        isPreviewing = false
        DispatchQueue.main.async {
            smoothlyAnimate(window, toFrame: target, duration: 0.3) {
                isAnimatingBack = false
                selectedWallpaper = nil
                originalDesktopState = []
                refreshCurrentlyApplied()
            }
        }
    }

    private func confirmPreview() {
        // Re-entrancy guard: rapid clicks on Keep would otherwise spawn
        // overlapping tasks and stacked terminate() calls.
        guard !isConfirming else { return }

        // Wallpaper is already applied as preview. Swap the pill content
        // to a "Wallpaper set" confirmation, hold briefly, then fade the
        // window out and terminate.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            isConfirming = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s hold
            fadeOutAndQuit()
        }
    }

    private func setWallpaperAndQuit(_ wallpaper: WallpaperItem) {
        applyWallpaper(wallpaper) { error in
            if let error {
                showAlert("Failed to set wallpaper: \(error.localizedDescription)")
                return
            }
            // Match the Keep flow's exit animation rather than terminating
            // abruptly from the double-click path.
            fadeOutAndQuit()
        }
    }

    // Fade this window out and close it. In single-window mode the
    // AppDelegate terminates the app when the last window closes; in
    // individual mode the other per-screen windows stay open until their
    // own Keep/Cancel resolves them, and termination happens naturally
    // once they're all gone.
    private func fadeOutAndQuit() {
        guard let window = hostWindow else {
            NSApp.terminate(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.close()
        })
    }

    private func previewWindowFrame(for window: NSWindow) -> NSRect {
        let previewSize = NSSize(width: 430, height: 100)
        let screen = window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: previewSize)
        let margin: CGFloat = 20
        return NSRect(
            x: visible.maxX - previewSize.width - margin,
            y: visible.maxY - previewSize.height - margin,
            width: previewSize.width,
            height: previewSize.height
        )
    }

    // MARK: - Desktop wallpaper helpers

    // Captures the current wallpaper state for the screens this window
    // controls (all screens in "all" mode, just our own in individual).
    private func captureDesktopState() -> [DesktopSnapshot] {
        let workspace = NSWorkspace.shared
        return targetScreens.map { screen in
            DesktopSnapshot(
                screen: screen,
                url: workspace.desktopImageURL(for: screen),
                options: workspace.desktopImageOptions(for: screen) ?? [:]
            )
        }
    }

    private func applyWallpaper(_ wallpaper: WallpaperItem, completion: ((Error?) -> Void)? = nil) {
        let url = URL(fileURLWithPath: wallpaper.path)
        let workspace = NSWorkspace.shared
        let screens = targetScreens
        guard !screens.isEmpty else {
            completion?(nil)
            return
        }

        // This window's own screen fires first so its IPC lands in Dock's
        // queue before the secondaries' — the daemon picks the visible
        // order, and putting primary first matches where the user's
        // attention is. Also reuse each screen's existing scaling/
        // positioning options instead of passing [:], which would
        // otherwise wipe the user's chosen fill mode.
        let primary = hostWindow?.screen
        var primaryWork: (NSScreen, [NSWorkspace.DesktopImageOptionKey: Any])?
        var otherWork: [(NSScreen, [NSWorkspace.DesktopImageOptionKey: Any])] = []
        for screen in screens {
            let options = workspace.desktopImageOptions(for: screen) ?? [:]
            if screen == primary, primaryWork == nil {
                primaryWork = (screen, options)
            } else {
                otherWork.append((screen, options))
            }
        }

        // Run on a background queue so the calling UI work (window
        // shrink animation) doesn't wait on the IPC roundtrips.
        DispatchQueue.global(qos: .userInitiated).async {
            var firstError: Error?

            if let primaryWork {
                do {
                    try workspace.setDesktopImageURL(url, for: primaryWork.0, options: primaryWork.1)
                } catch {
                    firstError = error
                }
            }

            if !otherWork.isEmpty {
                let lock = NSLock()
                DispatchQueue.concurrentPerform(iterations: otherWork.count) { i in
                    let (screen, options) = otherWork[i]
                    do {
                        try workspace.setDesktopImageURL(url, for: screen, options: options)
                    } catch {
                        lock.lock()
                        if firstError == nil { firstError = error }
                        lock.unlock()
                    }
                }
            }

            if let completion {
                DispatchQueue.main.async { completion(firstError) }
            }
        }
    }

    private func restoreDesktopState(_ snapshots: [DesktopSnapshot]) {
        let workspace = NSWorkspace.shared
        for snap in snapshots {
            guard let url = snap.url else { continue }
            try? workspace.setDesktopImageURL(url, for: snap.screen, options: snap.options)
        }
    }

    private func loadLogo() async {
        let path = effectiveLogoPath
        guard !path.isEmpty else {
            logoImage = nil
            return
        }
        let image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            NSImage(contentsOfFile: path)
        }.value
        logoImage = image
    }

    // MARK: - Currently applied tracking

    private func refreshCurrentlyApplied() {
        let workspace = NSWorkspace.shared
        var paths: Set<String> = []
        for screen in targetScreens {
            if let url = workspace.desktopImageURL(for: screen) {
                paths.insert(url.path)
            }
        }
        currentlyAppliedPaths = paths
    }

    // MARK: - Keyboard navigation

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleGridKey(event)
        }
    }

    private func removeKeyMonitor() {
        if let token = keyMonitor {
            NSEvent.removeMonitor(token)
            keyMonitor = nil
        }
    }

    // Returns nil to consume the event, the original event to pass it on.
    private func handleGridKey(_ event: NSEvent) -> NSEvent? {
        // Only intercept while the grid is showing for this window.
        guard !isPreviewing, !isAnimatingBack else { return event }
        guard event.window === hostWindow else { return event }
        guard !allWallpapers.isEmpty else { return event }

        if let special = event.specialKey {
            switch special {
            case .leftArrow:
                moveFocus(by: -1); return nil
            case .rightArrow:
                moveFocus(by: 1); return nil
            case .upArrow:
                moveFocus(by: -max(1, currentColumnCount)); return nil
            case .downArrow:
                moveFocus(by: max(1, currentColumnCount)); return nil
            case .carriageReturn, .enter:
                if let wp = currentFocusedWallpaper {
                    setWallpaperAndQuit(wp)
                    return nil
                }
            default:
                break
            }
        }

        if event.charactersIgnoringModifiers == " " {
            let target = currentFocusedWallpaper ?? defaultFocusTarget()
            if let target {
                focusedWallpaperID = target.id
                enterPreview(target)
            }
            return nil
        }

        return event
    }

    private var currentFocusedWallpaper: WallpaperItem? {
        guard let id = focusedWallpaperID else { return nil }
        return allWallpapers.first { $0.id == id }
    }

    // First key press lands on the currently-applied wallpaper if it's in
    // the grid, otherwise on the first item — saves a tap when the user
    // wants to step away from what's already set.
    private func defaultFocusTarget() -> WallpaperItem? {
        if let applied = allWallpapers.first(where: { currentlyAppliedPaths.contains($0.path) }) {
            return applied
        }
        return allWallpapers.first
    }

    private func moveFocus(by delta: Int) {
        let all = allWallpapers
        guard !all.isEmpty else { return }
        if focusedWallpaperID == nil {
            focusedWallpaperID = defaultFocusTarget()?.id
            return
        }
        let currentIndex = all.firstIndex { $0.id == focusedWallpaperID } ?? 0
        let newIndex = max(0, min(all.count - 1, currentIndex + delta))
        focusedWallpaperID = all[newIndex].id
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

struct WallpaperCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let isCurrentlyApplied: Bool
    let isFocused: Bool
    let onSelect: () -> Void
    let onSetWallpaper: () -> Void
    let config: DecorConfig
    let cache: WallpaperCache
    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    private var isHighlighted: Bool { isHovering || isFocused }

    private var cardScale: CGFloat {
        if isSelected { return 1.05 }
        if isHighlighted { return 1.02 }
        return 1.0
    }

    private var cardShadow: CGFloat {
        if isSelected { return config.shadowRadius * 2 }
        if isHighlighted { return config.shadowRadius * 1.5 }
        return config.shadowRadius
    }

    private var borderColor: Color {
        if isSelected { return config.thumbnailHighlightColor }
        if isFocused { return config.thumbnailHighlightColor.opacity(0.7) }
        if isHovering { return config.thumbnailHighlightColor.opacity(0.5) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if isSelected || isFocused { return 2 }
        if isHovering { return 1.5 }
        return 0
    }

    @ViewBuilder
    private var imagePreview: some View {
        Group {
            if let image = thumbnail ?? cache.cached(wallpaper.id) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipped()
                    .clipShape(.rect(cornerRadius: config.cornerRadius))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(16/10, contentMode: .fill)
                    .clipShape(.rect(cornerRadius: config.cornerRadius))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            }
        }
        .brightness(isHighlighted && !isSelected ? 0.05 : 0)
        .overlay(alignment: .topTrailing) {
            if isCurrentlyApplied {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.green)
                    .font(.title3)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .padding(8)
                    .accessibilityLabel("Currently applied")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image Preview — bind double-click gesture only when enabled
            // to avoid the single-tap recognition delay otherwise.
            Group {
                if config.doubleClickToSetWallpaper {
                    imagePreview
                        .onTapGesture(count: 2) { onSetWallpaper() }
                        .onTapGesture { onSelect() }
                } else {
                    imagePreview
                        .onTapGesture { onSelect() }
                }
            }
            .task {
                await loadThumbnail()
            }

            // Name
            if config.showWallpaperInfo {
                Text(wallpaper.name)
                    .font(.headline.weight(.regular))
                    .lineLimit(2)
                    .foregroundColor(isSelected ? config.textHighlightColor : .primary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(radius: cardShadow)
        )
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(cardScale)
        .contentShape(.rect(cornerRadius: config.cornerRadius))
        .onHover { hovering in
            isHovering = hovering
        }
        .pointerStyle(.link)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
    
    @MainActor
    private func loadThumbnail() async {
        if thumbnail != nil { return }
        if let hit = cache.cached(wallpaper.id) {
            thumbnail = hit
            return
        }
        let aspectRatio: CGFloat = 16/10
        let targetSize = NSSize(width: config.thumbnailSize, height: config.thumbnailSize / aspectRatio)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        thumbnail = await cache.thumbnail(for: wallpaper, targetSize: targetSize, scale: scale)
    }
}

struct WallpaperItem {
    let id: UUID
    let name: String
    let path: String
}

// A named grouping of wallpapers. An empty title renders without a header,
// which covers two cases: loose images in the root wallpapersPath, and the
// back-compat single-folder layout (no subfolders at all).
struct WallpaperCollection: Identifiable {
    let id: UUID
    let title: String
    let wallpapers: [WallpaperItem]
}

#Preview {
    ContentView(config: DecorConfig(), controller: MultiDisplayController())
}
