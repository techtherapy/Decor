# Decor Architecture

Developer-oriented notes on how Decor is put together, why it's structured the way it is, and where the load-bearing decisions live. Useful when you need to modify behaviour or add features without breaking the carefully-tuned animation and state flows.

All the code lives in a single file: `Decor/ContentView.swift`. The file is self-contained, organised top-down: config → colour helper → app delegate → window helpers → multi-display controller → app entry → views → helpers.

## Top-level structure

```
DecorConfig (@Observable class)           — MDM-driven configuration model
Color.init(hex:)                          — Hex string parser with magenta fallback
AppDelegate (NSApplicationDelegate)       — Quits on last window close
LaunchWindowHider (NSViewRepresentable)   — Holds primary alpha at 0 during launch positioning
WallpaperCache (final class)              — Shared, dedup'd, ImageIO-backed thumbnail cache
MultiDisplayController (@Observable)      — Owns shared collections + cache + aux windows
makeAuxWindow (function)                  — Spawns a per-screen NSWindow hosting a ContentView
DecorApp (App)                            — SwiftUI scene declaration
DesktopSnapshot (private struct)          — Per-screen wallpaper capture for restore
ContentView (View)                        — Main UI; owns per-window interaction state
WallpaperCard (View)                      — Individual grid cell
WallpaperItem / WallpaperCollection       — Plain data
```

## DecorConfig

A single `@Observable` class holds every MDM-configurable property. SwiftUI's macro-based observation system automatically subscribes any view that reads a property; mutating that property invalidates only the views that read it.

The config object is created once at the App scene level via `@State private var config = DecorConfig()` in `DecorApp`, then passed into `ContentView` as `let config: DecorConfig`. This single ownership lets:

- The Scene's `.defaultSize(...)` read `config.launchContentSize` so the window opens at exactly the configured columns × rows.
- `ContentView` and `WallpaperCard` consume the same observable instance with no plumbing.

### `loadConfig()` — reset-then-overlay pattern

`loadConfig()` first resets every property to its declared default, then overlays values from `UserDefaults.standard`. This means **removing an MDM key cleanly reverts** to the default — without the reset, a previously-overlaid value would stick until next launch.

### Live updates

In `init()`, the config installs a `UserDefaults.didChangeNotification` observer on the main queue that re-runs `loadConfig()` on every change. The observer token is `@ObservationIgnored` so it doesn't leak into the observation graph, and it's removed in `deinit`.

### `launchContentSize` — computed property

A computed property on `DecorConfig` returns the exact `NSSize` the window should open at to show `defaultColumnCount × defaultRowCount` cards with no leftover whitespace. The math is:

```
width  = n × thumbnailSize + (n - 1) × gridSpacing + 32     // n = effective col count
height = rows × cardHeight + (rows - 1) × gridSpacing + 32
       + headerHeight (78 if logo or title set, else 0)
cardHeight = (thumbnailSize / 1.6) + (50 if name shown, else 0)
```

The constants 32 (grid padding), 78 (header), and 50 (name section) are empirical — pulled by inspecting the rendered SwiftUI layout — and documented in inline comments next to the calculation. If you change the header or filename layout, update these.

## Color hex parser

A simple extension on `Color` parsing 3-, 6-, or 8-character hex strings (with optional `#` and other non-alphanumerics stripped). Invalid input falls back to **magenta** (`#FF00FF`) so administrators see typos immediately — silently rendering as a transparent or near-black colour would mask configuration errors.

## App entry: `DecorApp` + `AppDelegate`

```swift
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
        .defaultSize(width: config.launchContentSize.width,
                     height: config.launchContentSize.height)
    }
}
```

### Why `Window` not `WindowGroup`

The SwiftUI scene only ever produces the *primary* Decor window. `Window` (not `WindowGroup`) prevents the user from opening a second instance of the primary via the menu, and gives stable lifecycle semantics. Additional per-display "aux" windows in individual mode are created programmatically as `NSWindow`s — they live outside SwiftUI's scene system. See **Multi-display picking** below.

### Why an `AppDelegate`

`applicationShouldTerminateAfterLastWindowClosed` returns `true` so closing the window actually quits the app — matching the user's expectation for a one-shot utility. With multi-display picking enabled, this is also what guarantees the app exits cleanly once every per-screen window has been resolved (Kept, Cancelled, or closed).

## ContentView — the main UI

Each `ContentView` instance is bound to a single `NSWindow`. The primary window is created by the SwiftUI `Window` scene; aux per-screen windows are created programmatically by `makeAuxWindow` and host their own `ContentView` via `NSHostingController`. Both flow through the same struct.

### Init parameters

| Parameter | Purpose |
|---|---|
| `config: DecorConfig` | Shared MDM config (passed by reference). |
| `controller: MultiDisplayController` | Shared controller — owns collections, thumbnail cache, mode, and the aux window list. |
| `isPrimary: Bool` (default `true`) | Whether this ContentView is hosted in the primary window. Used to gate the mode-pill UI and the launch sequence. Kept as a plain `let` so body doesn't subscribe to `controller.primaryWindow`. |
| `initialHostWindow: NSWindow?` (default `nil`) | Pre-known host window for aux ContentViews. Primary leaves this nil and resolves the window from `NSApp.windows.first` in `.onAppear`. |

### State

| Property | Purpose |
|---|---|
| `hostWindow` | The `NSWindow` this ContentView is mounted in; populated in `.onAppear`. All per-window operations (preview shrink/grow, fade-out) target this rather than `NSApp.windows.first`. |
| `selectedWallpaper` | The currently-previewed wallpaper (drives the name in the pill). |
| `showingAlert` / `alertMessage` | Bound to the standard SwiftUI `.alert` for error reporting. |
| `didApplyLaunchActions` | One-shot guard so the primary's launch positioning only runs once. |
| `logoImage` | Loaded `NSImage` for the header, populated by `loadLogo()`. |
| `isPreviewing` | True while the pill is showing; drives the body branch. |
| `originalWindowFrame` | Captured at preview entry; restored on Cancel. |
| `originalDesktopState` | Per-screen wallpaper snapshot for restore (only the screens *this window* targets — see `targetScreens`). |
| `isAnimatingBack` | True during the grow-back; renders `Color.clear` instead of `mainView`. |
| `isConfirming` | True during the Keep flow; swaps `previewControlsView` for `confirmationView`. |
| `colorScheme` | `@Environment` value; drives `effectiveLogoPath`. |

Wallpaper collections and the thumbnail cache used to live on `ContentView` as `@State`. They now live on `MultiDisplayController` so primary + every aux window share the same enumerated folder listing and the same decoded thumbnails. See **Shared collections + thumbnail cache** below.

### Body — three-way branch

```swift
Group {
    if isAnimatingBack {
        Color.clear            // empty during grow-back
    } else if isPreviewing {
        previewView            // small pill (controls or confirmation)
    } else {
        mainView               // grid
    }
}
```

`Color.clear` during `isAnimatingBack` is critical — it prevents `mainView` from mounting in a partially-resized window during the grow animation, which would re-layout the grid at each frame size and cause visible jitter.

### Modifiers attached to body

- `.background(Color(NSColor.windowBackgroundColor))` — visible during the grow-back; adapts to dark/light mode.
- `.onAppear` — loads wallpapers and runs the once-only launch actions.
- `.onChange(of: config.wallpapersPath)` — clears thumbnail cache + selection, then reloads.
- `.task(id: effectiveLogoPath)` — loads (or reloads) the logo when the path or colour scheme changes.
- `.onReceive(NSWindow.willCloseNotification)` — reverts the wallpaper if the user closes the pill window without committing.
- `.alert(...)` — standard error reporting.

## The preview flow

Most of the app's behavioural complexity lives in the transition between `mainView` and `previewView`. Three lifecycle functions drive it:

### `enterPreview(_:)`

1. Set `selectedWallpaper`.
2. **On first entry only:** capture `originalDesktopState` (per-screen URL + options) and `originalWindowFrame`.
3. Apply the chosen wallpaper to every connected screen.
4. Set `isPreviewing = true` — body swaps to `previewView`.
5. **On first entry only:** lower `window.minSize` (so the window can shrink past `mainView`'s 600×400 floor) and call `smoothlyAnimate(window, toFrame: previewWindowFrame(...))` to shrink to the top-right pill.

Subsequent calls (from chevron cycling) skip steps 2 and 5 — they just swap the wallpaper and update `selectedWallpaper`. No re-animation.

### `cancelPreview()`

1. Restore every screen from `originalDesktopState`.
2. Restore `window.minSize` to the main-view floor.
3. Set `isAnimatingBack = true` and `isPreviewing = false` — body renders `Color.clear`.
4. Defer one runloop tick (`DispatchQueue.main.async`) so SwiftUI commits the layout change before the animation begins.
5. Animate the window back to `originalWindowFrame`.
6. On completion: `isAnimatingBack = false` (mainView mounts), then clear `selectedWallpaper` and `originalDesktopState`.

The defer is essential — without it, the rasterised snapshot used during the animation would capture a partially-laid-out view.

### `confirmPreview()`

1. Re-entrancy guard: `guard !isConfirming else { return }`.
2. `withAnimation(.spring)` flips `isConfirming = true` — body swaps to `confirmationView` (big green checkmark + "Wallpaper set" headline + filename).
3. Hold 700 ms.
4. Call `fadeOutAndQuit()` — animates `window.alphaValue` to 0 over 400 ms, then `NSApp.terminate(nil)`.

### `setWallpaperAndQuit(_:)` (double-click path)

Bypasses preview. Applies the wallpaper to all screens, then calls `fadeOutAndQuit()` — same fade as Keep, so the two commit paths share the same exit animation.

### `handleWindowClose(_:)`

Subscribed via `.onReceive` to `NSWindow.willCloseNotification`. If the user clicks the red traffic light while in preview (and not during a Keep), restores the original wallpaper before the window finishes closing. `applicationShouldTerminateAfterLastWindowClosed` then quits the app.

The state semantics are deliberately symmetric:

| User action | While previewing | On grid |
|---|---|---|
| Cancel button (⊞) | Revert + back to grid | n/a |
| Close window (X) | Revert + quit | Quit (nothing to revert) |
| Keep button (✓) | Commit + quit | n/a |
| Double-click thumbnail | n/a | Commit + quit (skip preview) |

## `smoothlyAnimate(_:toFrame:duration:onCompletion:)`

The window-resize animation helper used by both `enterPreview` and `cancelPreview`. Three things happen:

1. **Rasterise the contentView's layer.** `wantsLayer = true` and `shouldRasterize = true` (at backing scale factor) before the animation begins. SwiftUI's per-frame layout work (GeometryReader, grid invalidation, hover-state diffing) would otherwise jankify the resize; rasterising freezes the contentView as a bitmap that Core Animation just stretches.
2. **Animate `window.animator().setFrame(...)`** inside an `NSAnimationContext.runAnimationGroup` with a cubic ease-in-out curve `(0.65, 0, 0.35, 1)` and `allowsImplicitAnimation = true`.
3. **In the completion handler**, set `shouldRasterize = false` so subsequent rendering is crisp again, then call the caller's `onCompletion`.

## Shared collections + thumbnail cache (`MultiDisplayController` + `WallpaperCache`)

The wallpaper folder is enumerated once per session and the resulting `[WallpaperCollection]` lives on `MultiDisplayController.collections` (an `@Observable` property). Every `ContentView` instance reads it through a computed property; whichever ContentView's `.onAppear` fires first triggers the load via `controller.loadCollections(from:)`, subsequent calls with the same path are no-ops. When `config.wallpapersPath` changes, `reloadCollections(from:)` clears the cache and re-enumerates.

Thumbnails are produced and stored by `WallpaperCache`, owned by the controller (`@ObservationIgnored let cache = WallpaperCache()`). The cache:

- Dedupes by `WallpaperItem.id` (UUID). Two `WallpaperCard`s for the same wallpaper (e.g. the primary window's card and the aux window's card for the same screen position) share the decoded image.
- Dedupes **in-flight** loads via a `[UUID: Task<NSImage?, Never>]` map. If a thumbnail is already being decoded when a second caller arrives, the second caller awaits the same task instead of starting a parallel decode.
- Downsamples via `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceCreateThumbnailFromImageAlways` + `kCGImageSourceShouldCacheImmediately` + `kCGImageSourceCreateThumbnailWithTransform`. `kCGImageSourceThumbnailMaxPixelSize` is set to `max(target.width, target.height) × backingScaleFactor` so thumbnails are crisp on Retina without paying for a full-resolution decode of the source.
- Is `final class` (not `@MainActor`) — only main-thread call sites consume it, so no locking is needed. The `Task.detached` operation inside is the only off-main work.

`WallpaperCard` owns a `@State private var thumbnail: NSImage?`. On `.task`, the card first checks `cache.cached(wallpaper.id)` for a synchronous hit, then awaits `cache.thumbnail(for:targetSize:scale:)` otherwise. The two-step pattern means cards remount from cache instantly without a `ProgressView` flash, even when `mainView` unmounts and remounts during preview transitions.

## Multi-display picking

Decor supports two picking modes, gated by a two-state pill at the bottom of the *primary* window:

- **Set all displays** *(default)* — one selection applies to every connected screen. Capture/apply/restore iterate `NSScreen.screens` exactly as before.
- **Set displays individually** — a separate `NSWindow` is spawned on every non-primary `NSScreen`, each hosting its own `ContentView` via `NSHostingController`. Each window's capture/apply/restore operates only on its own screen.

### `MultiDisplayController`

Owns the mode flag (`individualMode: Bool`), the spawned aux windows, and the shared collections + cache. `setIndividualMode(_:)` flips the bool synchronously (so SwiftUI's pill highlight animation can start immediately) and `DispatchQueue.main.async`s the actual `spawnAuxWindows()` / `closeAuxWindows()` work — pushing the expensive `NSHostingController` setup off the synchronous toggle path.

`spawnAuxWindows()` filters `NSScreen.screens` to exclude `primaryWindow?.screen`, then calls the top-level `makeAuxWindow(on:config:controller:)` for each remaining screen. Each aux window:

- Style: `.titled, .closable, .resizable, .fullSizeContentView` with `titleVisibility = .hidden` and `titlebarAppearsTransparent = true`.
- Positioned via the shared `launchFrame(on:size:position:)` helper using the same `launchPosition` config the primary uses.
- `isReleasedWhenClosed = false` so we can track them in the controller's array even after close.
- Hosts a `ContentView(config:, controller:, isPrimary: false, initialHostWindow: window)` so the ContentView knows its host window at init time without an in-body `NSViewRepresentable`.

### `targetScreens` (computed on `ContentView`)

```swift
private var targetScreens: [NSScreen] {
    if controller.individualMode {
        return hostWindow?.screen.map { [$0] } ?? []
    }
    return NSScreen.screens
}
```

`captureDesktopState`, `applyWallpaper(_:)`, and `restoreDesktopState(_:)` all iterate `targetScreens`. In "all" mode every window targets all screens (which means only the primary should be alive in that mode — aux windows are closed on toggle-off); in individual mode each window only touches its own screen.

### Exit semantics

`fadeOutAndQuit` calls `window.close()` rather than `NSApp.terminate(nil)`. Combined with `applicationShouldTerminateAfterLastWindowClosed = true`, this means individual-mode windows resolve independently — Keep on display 1 closes that screen's window but leaves displays 2 and 3 alive for the user to continue picking; the app quits once every per-screen window has been resolved.

### Known limitation

Dynamic wallpapers, aerial screensavers, and stacks don't round-trip through `desktopImageURL(for:)`. When the API returns nil for a screen, restore is a no-op for that screen and the preview wallpaper effectively persists.

## Animations summary

| Animation | Driven by | Duration | Curve | Notes |
|---|---|---|---|---|
| Launch | `applyLaunchActionsIfNeeded` | — | — | No fade. `LaunchWindowHider` keeps alpha at 0 only while the window is being positioned, then `applyLaunchActionsIfNeeded` snaps alpha to 1 — fastest possible appearance. |
| Preview shrink (grid → pill) | `enterPreview` → `smoothlyAnimate` | 0.3 s | Ease-in-out cubic `(0.65, 0, 0.35, 1)` | Rasterised during animation. |
| Preview grow (pill → grid) | `cancelPreview` → `smoothlyAnimate` | 0.3 s | Same | `Color.clear` shown during, grid mounts after. |
| Mode pill highlight | Pill segment buttons | 0.32 s spring | `dampingFraction: 0.78` | `matchedGeometryEffect` slides the highlight between segments. |
| Confirmation appearance | `confirmPreview` | 0.35 s spring | `dampingFraction: 0.65` | SwiftUI `withAnimation`; checkmark uses scale + opacity transition. |
| Confirmation hold | `confirmPreview` | 0.7 s | — | `Task.sleep(nanoseconds: 700_000_000)`. |
| Exit fade-out | `fadeOutAndQuit` | 0.4 s | Ease-out cubic | Window alpha 1 → 0, then `window.close()`. App quits when the last window closes. |
| Card hover (border, scale, shadow, brightness) | `WallpaperCard` | 0.15 s | Ease-in-out | |
| Card selection | `WallpaperCard` | 0.2 s | Ease-in-out | |

## Layout — `mainView`

A `VStack(spacing: 0)` with three children:

1. **Header** — `if logoImage != nil || !config.logoTitle.isEmpty`. `HStack(spacing: 12)` of `Image(nsImage: logoImage)` at 50 pt height + optional `Text(config.logoTitle)` as `.title2.weight(.semibold)`, pushed to the leading edge with a trailing `Spacer()`. 16/16/12 pt padding around.
2. **Grid** — a `GeometryReader` wrapping a `ScrollView` + `LazyVGrid`. Columns are computed by `columns(for: width)` from the geometry proxy, which fits as many `GridItem(.fixed(thumbnailSize))` cells as the available width allows, capped at `config.maxThumbnailsPerRow`.
3. **Bottom button** — removed entirely; the preview pill is the only commit surface.

## Layout — `previewView`

Two states gated by `isConfirming`:

### `previewControlsView`

Single `HStack(spacing: 10)`:
- Name VStack (`Preview` caption + wallpaper name `headline`), expanded with `frame(maxWidth: .infinity, alignment: .leading)`.
- Right-side group wrapped in its own `HStack(spacing: 10)`:
  - Chevron pair (`.bordered` buttons with bold `chevron.left`/`chevron.right` icons, `.keyboardShortcut(.leftArrow/.rightArrow)`, disabled when `wallpapers.count < 2`), separated from the next group by `.padding(.trailing, 16)`.
  - Back-to-grid button (`square.grid.2x2` icon, `.bordered`, `.keyboardShortcut(.cancelAction)`).
  - Keep button (`checkmark` icon, `.borderedProminent`, `.keyboardShortcut(.defaultAction)`).

The right-side group has `.alignmentGuide(VerticalAlignment.center) { d in d[.center] - 8 }`, which shifts the whole strip ~8 pt below the HStack's geometric centre so it visually aligns with the headline line (rather than the geometric centre of the two-line text VStack).

### `confirmationView`

`HStack(spacing: 14)` with a 30 pt `checkmark.circle.fill` (green, hierarchical symbol rendering, with a `.scale(0.4).combined(with: .opacity)` transition) + VStack with "Wallpaper set" headline + filename caption + trailing `Spacer`.

## Why this code looks the way it does

A few decisions that aren't obvious from the source:

- **All code in one file.** Decor is small enough that splitting it across files would harm navigability more than it helps. If `ContentView.swift` grows past ~1200 lines, consider extracting `DecorConfig` and its plist loader, then the `WallpaperCard`.
- **`@Observable` not `@StateObject`.** The Swift Observation framework (macOS 14+) provides finer-grained dependency tracking than `ObservableObject`. Views only re-render when properties they actually read change.
- **No Combine.** Per project preference, the codebase uses Swift Concurrency (`async`/`await`, `Task`, `Task.detached`) rather than Combine publishers. The only `NotificationCenter` usage is the `UserDefaults.didChangeNotification` observer in `DecorConfig`, and SwiftUI's `.onReceive` for window-close.
- **Rasterised animations over SwiftUI transitions.** SwiftUI `.transition` works for small views but not for window-frame resizes carrying expensive content (grids, GeometryReader). The rasterised-layer approach in `smoothlyAnimate` is the workaround.
- **State-machine flags (`isPreviewing`, `isAnimatingBack`, `isConfirming`)** rather than a single enum. SwiftUI's `if/else` body branches work cleanly with separate `Bool`s, and the transitions between them are choreographed by separate functions rather than a state-machine type. Worth refactoring to an enum if more states are added.

## Adding a new config key

The pattern for a new MDM-driven setting:

1. Add a `var newKey: ValueType = default` property to `DecorConfig`.
2. Add a reset line in `loadConfig()`'s "Reset to defaults" block.
3. Add a `defaults.object(forKey: "newKey")` overlay block lower in `loadConfig()`, with appropriate type-casting and validation.
4. Use `config.newKey` in `ContentView` or `WallpaperCard` — `@Observable` handles the rest.
5. Document it in `CONFIGURATION.md`.
6. Add it to `techtherapy.decor.sample.plist` with a sensible default value.
7. If the new key affects launch size, update `launchContentSize`.
