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
    var thumbnailSize: CGFloat = 200
    var thumbnailHighlightColor: Color = .blue
    var textHighlightColor: Color = .blue
    var gridSpacing: CGFloat = 16
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 2
    var maxThumbnailsPerRow: Int = 6
    var defaultColumnCount: Int = 4
    var defaultRowCount: Int = 3
    var showWallpaperInfo: Bool = true
    var wallpapersPath: String = "/Library/Desktop Pictures"
    var doubleClickToSetWallpaper: Bool = false
    var hideOtherAppsOnLaunch: Bool = true
    var logoPath: String = "/Library/Icons/icon-dark.png"
    var logoPathDark: String = "/Library/Icons/icon-light.png"
    var logoTitle: String = "Select your wallpaper"
    var launchPosition: String = "center" // "left" | "right" | "center"

    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?

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
        // Reset to declared defaults first so removing a managed-preferences
        // key (e.g. via MDM) cleanly reverts to the default instead of
        // retaining the previously-overlaid value.
        thumbnailSize = 200
        thumbnailHighlightColor = .blue
        textHighlightColor = .blue
        gridSpacing = 16
        cornerRadius = 12
        shadowRadius = 2
        maxThumbnailsPerRow = 6
        defaultColumnCount = 4
        defaultRowCount = 3
        showWallpaperInfo = true
        wallpapersPath = "/Library/Desktop Pictures"
        doubleClickToSetWallpaper = false
        hideOtherAppsOnLaunch = true
        logoPath = "/Library/Icons/icon-dark.png"
        logoPathDark = "/Library/Icons/icon-light.png"
        logoTitle = "Select your wallpaper"
        launchPosition = "center"

        let defaults = UserDefaults.standard

        if let size = defaults.object(forKey: "thumbnailSize") as? NSNumber {
            thumbnailSize = max(100, min(400, CGFloat(size.doubleValue)))
        }
        if let hex = defaults.string(forKey: "thumbnailHighlightColor") {
            thumbnailHighlightColor = Color(hex: hex)
        }
        if let hex = defaults.string(forKey: "textHighlightColor") {
            textHighlightColor = Color(hex: hex)
        }
        if let spacing = defaults.object(forKey: "gridSpacing") as? NSNumber {
            gridSpacing = max(4, min(32, CGFloat(spacing.doubleValue)))
        }
        if let radius = defaults.object(forKey: "cornerRadius") as? NSNumber {
            cornerRadius = max(0, min(24, CGFloat(radius.doubleValue)))
        }
        if let shadow = defaults.object(forKey: "shadowRadius") as? NSNumber {
            shadowRadius = max(0, min(10, CGFloat(shadow.doubleValue)))
        }
        if let maxCols = defaults.object(forKey: "maxThumbnailsPerRow") as? NSNumber {
            maxThumbnailsPerRow = max(2, min(20, maxCols.intValue))
        }
        if let cols = defaults.object(forKey: "defaultColumnCount") as? NSNumber {
            defaultColumnCount = max(1, min(20, cols.intValue))
        }
        if let rows = defaults.object(forKey: "defaultRowCount") as? NSNumber {
            defaultRowCount = max(1, min(20, rows.intValue))
        }
        if let showInfo = defaults.object(forKey: "showWallpaperInfo") as? Bool {
            showWallpaperInfo = showInfo
        }
        if let path = defaults.string(forKey: "wallpapersPath"), !path.isEmpty {
            wallpapersPath = (path as NSString).expandingTildeInPath
        }
        if let doubleClick = defaults.object(forKey: "doubleClickToSetWallpaper") as? Bool {
            doubleClickToSetWallpaper = doubleClick
        }
        if let hide = defaults.object(forKey: "hideOtherAppsOnLaunch") as? Bool {
            hideOtherAppsOnLaunch = hide
        }
        if let path = defaults.string(forKey: "logoPath") {
            logoPath = path.isEmpty ? "" : (path as NSString).expandingTildeInPath
        }
        if let path = defaults.string(forKey: "logoPathDark") {
            logoPathDark = path.isEmpty ? "" : (path as NSString).expandingTildeInPath
        }
        if let title = defaults.string(forKey: "logoTitle") {
            logoTitle = title
        }
        if let position = defaults.string(forKey: "launchPosition"),
           ["left", "right", "center"].contains(position) {
            launchPosition = position
        }
    }

    // Content-area size the window should open at to show exactly the
    // configured number of columns and rows with no leftover whitespace.
    var launchContentSize: NSSize {
        let n = CGFloat(min(max(1, defaultColumnCount), maxThumbnailsPerRow))
        let outerPadding: CGFloat = 32
        let width = n * thumbnailSize + (n - 1) * gridSpacing + outerPadding

        let rows = CGFloat(max(1, defaultRowCount))
        let imageHeight = thumbnailSize / 1.6 // 16:10 aspect
        let showName = showWallpaperInfo
        // 8pt VStack spacing + ~34pt for a line of .headline on macOS + 8pt bottom padding
        let nameSection: CGFloat = showName ? 50 : 0
        let cardHeight = imageHeight + nameSection
        let gridContentHeight = rows * cardHeight + (rows - 1) * gridSpacing + outerPadding
        let hasHeader = !logoPath.isEmpty || !logoPathDark.isEmpty || !logoTitle.isEmpty
        let headerHeight: CGFloat = hasHeader ? 78 : 0 // 50 logo + 16 top + 12 bottom
        let height = gridContentHeight + headerHeight

        return NSSize(width: width, height: height)
    }
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

@main
struct DecorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var config = DecorConfig()

    var body: some Scene {
        Window("Decor", id: "main") {
            ContentView(config: config)
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
    @State private var collections: [WallpaperCollection] = []
    @State private var selectedWallpaper: WallpaperItem?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var didApplyLaunchActions = false
    @State private var logoImage: NSImage?
    @State private var isPreviewing = false
    @State private var originalWindowFrame: NSRect = .zero
    @State private var originalDesktopState: [DesktopSnapshot] = []
    // Thumbnails live here, not inside WallpaperCard. Mounting/unmounting
    // mainView (preview entry/exit) used to dump every card's @State image
    // and trigger ~20 simultaneous reloads on remount, which jankified the
    // grow-back animation. Keeping a shared cache in the parent means cards
    // remount with their thumbnails already populated.
    @State private var thumbnailCache: [UUID: NSImage] = [:]
    @State private var isAnimatingBack = false
    @State private var isConfirming = false
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveLogoPath: String {
        if colorScheme == .dark && !config.logoPathDark.isEmpty {
            return config.logoPathDark
        }
        return config.logoPath
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
    private func columns(for width: CGFloat) -> [GridItem] {
        let cellWidth = config.thumbnailSize
        let spacing = config.gridSpacing
        let outerPadding: CGFloat = 32 // .padding() applies 16 on each side
        let availableWidth = max(0, width - outerPadding)
        let maxFit = max(1, Int((availableWidth + spacing) / (cellWidth + spacing)))
        let columnCount = min(config.maxThumbnailsPerRow, maxFit)
        return Array(repeating: GridItem(.fixed(cellWidth), spacing: spacing), count: columnCount)
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
            loadDefaultWallpapers()
            applyLaunchActionsIfNeeded()
        }
        .onChange(of: config.wallpapersPath) {
            // The new directory has different filenames, so any UUIDs we
            // had selected or cached are stale. Clear both before reload.
            thumbnailCache.removeAll()
            selectedWallpaper = nil
            loadDefaultWallpapers()
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
              window == NSApp.windows.first,
              isPreviewing, !isConfirming
        else { return }
        restoreDesktopState(originalDesktopState)
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: config.gridSpacing) {
                        ForEach(collections) { collection in
                            if !collection.title.isEmpty {
                                collectionHeader(collection.title)
                            }
                            LazyVGrid(columns: columns(for: proxy.size.width), spacing: config.gridSpacing) {
                                ForEach(collection.wallpapers, id: \.id) { wallpaper in
                                    wallpaperCard(wallpaper)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
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
            onSelect: { enterPreview(wallpaper) },
            onSetWallpaper: { setWallpaperAndQuit(wallpaper) },
            config: config,
            cachedThumbnail: thumbnailCache[wallpaper.id],
            storeThumbnail: { id, image in thumbnailCache[id] = image }
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
        loadWallpapersFromDirectory(config.wallpapersPath)
    }

    private func applyLaunchActionsIfNeeded() {
        guard !didApplyLaunchActions else { return }
        didApplyLaunchActions = true

        // Force the configured launch size on every launch and disable
        // window state restoration so macOS's saved size doesn't override
        // our config on subsequent launches.
        if let window = NSApp.windows.first {
            // Claim alpha management before LaunchWindowHider can re-zero
            // it; force alpha to 0 here in case viewWillMove hasn't fired
            // yet, so the fade-in is correct regardless of which runs first.
            LaunchWindowHider.launchHandled = true
            window.alphaValue = 0
            window.isRestorable = false
            window.setContentSize(config.launchContentSize)
            // Position at the configured location immediately — no slide.
            window.setFrame(launchFrame(for: window, position: config.launchPosition), display: true)
            // Fade in the whole window from alpha 0 to 1.0.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.9
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
                window.animator().alphaValue = 1.0
            }, completionHandler: nil)
        }

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

    private func launchFrame(for window: NSWindow, position: String) -> NSRect {
        guard let screen = window.screen ?? NSScreen.main else { return window.frame }
        let visible = screen.visibleFrame
        var frame = window.frame
        // Vertically center within the screen's visible area.
        frame.origin.y = visible.origin.y + (visible.height - frame.height) / 2
        switch position {
        case "left":
            frame.origin.x = visible.origin.x
        case "right":
            frame.origin.x = visible.maxX - frame.width
        default: // "center"
            frame.origin.x = visible.origin.x + (visible.width - frame.width) / 2
        }
        return frame
    }

    // MARK: - Preview flow

    private func enterPreview(_ wallpaper: WallpaperItem) {
        selectedWallpaper = wallpaper

        // Capture state on first entry only; subsequent clicks while in
        // preview replace the previewed wallpaper but keep the original
        // capture for restore-on-cancel.
        if !isPreviewing {
            originalDesktopState = captureDesktopState()
            if let window = NSApp.windows.first {
                originalWindowFrame = window.frame
            }
        }

        if let error = applyWallpaperToAllScreens(wallpaper) {
            showAlert("Failed to preview wallpaper: \(error.localizedDescription)")
            return
        }

        let firstEntry = !isPreviewing
        isPreviewing = true

        // Animate the window down to a small preview pill in the top-right
        // corner of the screen, but only on first entry — subsequent clicks
        // while previewing just swap the wallpaper without re-animating.
        if firstEntry, let window = NSApp.windows.first {
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
        guard target != .zero, let window = NSApp.windows.first else {
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
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s hold
            fadeOutAndQuit()
        }
    }

    private func setWallpaperAndQuit(_ wallpaper: WallpaperItem) {
        if let error = applyWallpaperToAllScreens(wallpaper) {
            showAlert("Failed to set wallpaper: \(error.localizedDescription)")
            return
        }
        // Match the Keep flow's exit animation rather than terminating
        // abruptly from the double-click path.
        fadeOutAndQuit()
    }

    private func fadeOutAndQuit() {
        guard let window = NSApp.windows.first else {
            NSApp.terminate(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            window.animator().alphaValue = 0
        }, completionHandler: {
            NSApp.terminate(nil)
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

    // MARK: - Desktop wallpaper helpers (all screens)

    private func captureDesktopState() -> [DesktopSnapshot] {
        let workspace = NSWorkspace.shared
        return NSScreen.screens.map { screen in
            DesktopSnapshot(
                screen: screen,
                url: workspace.desktopImageURL(for: screen),
                options: workspace.desktopImageOptions(for: screen) ?? [:]
            )
        }
    }

    private func applyWallpaperToAllScreens(_ wallpaper: WallpaperItem) -> Error? {
        let url = URL(fileURLWithPath: wallpaper.path)
        let workspace = NSWorkspace.shared
        for screen in NSScreen.screens {
            do {
                try workspace.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                return error
            }
        }
        return nil
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
    
    private func loadWallpapersFromDirectory(_ path: String) {
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
            collections = []
            return
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

        collections = result
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

struct WallpaperCard: View {
    let wallpaper: WallpaperItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onSetWallpaper: () -> Void
    let config: DecorConfig
    let cachedThumbnail: NSImage?
    let storeThumbnail: (UUID, NSImage) -> Void
    @State private var isHovering = false

    private var cardScale: CGFloat {
        if isSelected { return 1.05 }
        if isHovering { return 1.02 }
        return 1.0
    }

    private var cardShadow: CGFloat {
        if isSelected { return config.shadowRadius * 2 }
        if isHovering { return config.shadowRadius * 1.5 }
        return config.shadowRadius
    }

    private var borderColor: Color {
        if isSelected { return config.thumbnailHighlightColor }
        if isHovering { return config.thumbnailHighlightColor.opacity(0.5) }
        return .clear
    }

    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        if isHovering { return 1.5 }
        return 0
    }

    @ViewBuilder
    private var imagePreview: some View {
        Group {
            if let image = cachedThumbnail {
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
        .brightness(isHovering && !isSelected ? 0.05 : 0)
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
    }
    
    private func loadThumbnail() async {
        guard cachedThumbnail == nil else { return }

        let path = wallpaper.path
        let aspectRatio: CGFloat = 16/10
        let targetSize = NSSize(width: config.thumbnailSize, height: config.thumbnailSize / aspectRatio)
        let id = wallpaper.id

        let thumbnail = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let fullImage = NSImage(contentsOfFile: path) else { return nil }
            return NSImage(size: targetSize, flipped: false) { rect in
                fullImage.draw(in: rect)
                return true
            }
        }.value

        if let thumbnail {
            storeThumbnail(id, thumbnail)
        }
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
    ContentView(config: DecorConfig())
}
