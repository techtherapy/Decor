# Decor Architecture

Developer-oriented notes on how Decor is put together, why it's structured the way it is, and where the load-bearing decisions live. Useful when you need to modify behaviour or add features without breaking the carefully-tuned animation and state flows.

All the code lives in a single file: `Decor/ContentView.swift`. The file is small (~860 lines) and self-contained, organised top-down: config → colour helper → app entry → views → helpers.

## Top-level structure

```
DecorConfig (@Observable class)           — MDM-driven configuration model
Color.init(hex:)                          — Hex string parser with magenta fallback
AppDelegate (NSApplicationDelegate)       — Hides window pre-fade, quits on close
DecorApp (App)                            — SwiftUI scene declaration
DesktopSnapshot (private struct)          — Per-screen wallpaper capture for restore
ContentView (View)                        — Main UI; owns all interaction state
WallpaperCard (View)                      — Individual grid cell
WallpaperItem (struct)                    — Plain data: id / name / path
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

    var body: some Scene {
        Window("Decor", id: "main") {
            ContentView(config: config)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: config.launchContentSize.width,
                     height: config.launchContentSize.height)
    }
}
```

### Why `Window` not `WindowGroup`

This is a single-window utility. `Window` (not `WindowGroup`) prevents the user from opening multiple instances and gives stable lifecycle semantics.

### Why an `AppDelegate`

Two pieces of behaviour need lifecycle hooks SwiftUI doesn't expose:

1. **`applicationDidFinishLaunching`** sets `windows.first?.alphaValue = 0` *before* the window is rendered visibly, so the fade-in animation in `ContentView.onAppear` can ramp it back to 1 cleanly. Without this, the window would already be at alpha 1 by the time `.onAppear` runs and our fade would have nothing to fade *from*.
2. **`applicationShouldTerminateAfterLastWindowClosed`** returns `true` so closing the window actually quits the app, matching the user's expectation for a one-shot utility.

## ContentView — the main UI

### State

| Property | Purpose |
|---|---|
| `wallpapers` | Loaded `WallpaperItem` array; populated from `loadDefaultWallpapers` |
| `selectedWallpaper` | The currently-previewed wallpaper (drives the name in the pill) |
| `showingAlert` / `alertMessage` | Bound to the standard SwiftUI `.alert` for error reporting |
| `didApplyLaunchActions` | One-shot guard so launch positioning + fade-in only run once |
| `logoImage` | Loaded `NSImage` for the header, populated by `loadLogo()` |
| `isPreviewing` | True while the pill is showing; drives the body branch |
| `originalWindowFrame` | Captured at preview entry; restored on Cancel |
| `originalDesktopState` | Per-screen wallpaper snapshot for restore |
| `thumbnailCache` | UUID → NSImage map; lives in the parent so cards remount without reloading |
| `isAnimatingBack` | True during the grow-back; renders `Color.clear` instead of `mainView` |
| `isConfirming` | True during the Keep flow; swaps `previewControlsView` for `confirmationView` |
| `colorScheme` | `@Environment` value; drives `effectiveLogoPath` |

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

- `.background(config.backgroundColor)` — visible during the grow-back.
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

## Thumbnail caching

Each `WallpaperCard` takes a `cachedThumbnail: NSImage?` and a `storeThumbnail: (UUID, NSImage) -> Void` closure. The actual cache `[UUID: NSImage]` lives in `ContentView` as `@State`.

This is a deliberate departure from the obvious `@State private var thumbnailImage` inside `WallpaperCard`. The reason: when `isPreviewing` flips, `mainView` unmounts and remounts. Per-card `@State` would be wiped, triggering ~20 simultaneous `loadThumbnail()` calls competing for the main runloop during the grow-back animation. Hoisting the cache to the parent means card remounts pick up their thumbnails from cache instantly — no async work fires, animation stays smooth.

`loadThumbnail()` itself loads `NSImage(contentsOfFile:)` in a `Task.detached`, then creates an `NSImage(size:flipped:drawingHandler:)` whose drawing handler renders the source image at the configured thumbnail size. The result is stored back into the cache via the closure.

## Multi-display wallpaper handling

The `DesktopSnapshot` private struct holds `(screen, url, options)` for a single display. Three small helpers operate over `NSScreen.screens`:

- `captureDesktopState()` — returns `[DesktopSnapshot]` for every connected screen.
- `applyWallpaperToAllScreens(_:)` — iterates and applies the chosen URL to every screen via `NSWorkspace.setDesktopImageURL(_:for:options:)`. Returns the first error encountered (or nil).
- `restoreDesktopState(_:)` — iterates the snapshots and re-applies each captured URL + options.

**Known limitation:** dynamic wallpapers, aerial screensavers, and stacks don't round-trip through `desktopImageURL(for:)`. When the API returns nil for a screen, restore is a no-op for that screen and the preview wallpaper effectively persists.

## Animations summary

| Animation | Driven by | Duration | Curve | Notes |
|---|---|---|---|---|
| Launch fade-in | `applyLaunchActionsIfNeeded` | 0.9 s | Ease-out cubic `(0.22, 1, 0.36, 1)` | Window alpha 0 → 1; AppDelegate pre-hides the window |
| Preview shrink (grid → pill) | `enterPreview` → `smoothlyAnimate` | 0.3 s | Ease-in-out cubic `(0.65, 0, 0.35, 1)` | Rasterised during animation |
| Preview grow (pill → grid) | `cancelPreview` → `smoothlyAnimate` | 0.3 s | Same | `Color.clear` shown during, grid mounts after |
| Confirmation appearance | `confirmPreview` | 0.35 s spring | `dampingFraction: 0.65` | SwiftUI `withAnimation`; checkmark uses scale + opacity transition |
| Confirmation hold | `confirmPreview` | 0.7 s | — | `Task.sleep(nanoseconds: 700_000_000)` |
| Exit fade-out | `fadeOutAndQuit` | 0.4 s | Ease-out cubic | Window alpha 1 → 0, then terminate |
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
