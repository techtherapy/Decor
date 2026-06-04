# Decor

![Latest release](https://img.shields.io/github/v/release/techtherapy/Decor)

A lightweight macOS wallpaper picker designed for managed environments. Decor presents a configurable grid of desktop wallpapers, lets the user preview any choice live on their desktop, and is fully MDM-configurable.

- **Platform:** macOS 15.0+ (built and tested on macOS 26)
- **Bundle identifier:** `techtherapy.decor`
- **Distribution model:** one-shot utility (quits after the user commits or cancels)

## What it does

Decor scans a configurable folder for image files (`jpg`, `jpeg`, `png`, `heic`, `tiff`, `bmp`), shows them as a reflowable grid of thumbnails, and applies a chosen image as the desktop background on every connected display. The user reviews their selection before committing.

Subfolders inside that folder are treated as **collections**: each subfolder becomes a named section with its own grid. Loose images at the root render at the top with no header. Folder names may use a leading numeric prefix (e.g. `01-Featured`, `02_Nature`, `03 Abstract`) to force display order — the prefix is stripped from the visible title.

## User flow

1. **Launch.** The app fades into view at its configured size and position.
2. **Browse.** Hover and click thumbnails to preview them. Hovered cards lift slightly and gain a soft border; selected cards get a more prominent border, scale up, and brighten subtly.
3. **Preview.** Single-clicking a thumbnail:
   - Immediately applies that wallpaper to all displays.
   - Shrinks the main window down to a small pill in the top-right corner of the screen.
   - Shows the wallpaper name and four icon buttons: ◀ ▶ (cycle) · ⊞ (back to grid) · ✓ (keep).
4. **Browse from the pill.** ◀ / ▶ (or the left/right arrow keys) cycle through wallpapers without leaving preview mode. Each click swaps the desktop wallpaper but keeps the original captured for restore.
5. **Decide.**
   - **Keep** (✓ / Return) — shows a green "Wallpaper set" confirmation for 0.7 s, fades the window out, and quits.
   - **Back to grid** (⊞ / Esc) — restores the original wallpaper and re-expands the window to the grid view.
   - **Close window** (red traffic light) — treated as Back to grid, then quits.
6. **Shortcut: double-click a thumbnail** (when `doubleClickToSetWallpaper` is enabled) — bypasses the preview entirely, sets the wallpaper, and quits with the same fade-out.

## Key features

- **Live preview on every display** — the wallpaper is actually applied during preview, not just shown as a mock-up.
- **Multi-display aware** — captures and restores per-screen wallpaper URL and `desktopImageOptions` (scaling, clipping, fill color) when reverting.
- **Reflowable grid** — fixed-size cards reflow into more or fewer columns as the user resizes the window, capped at the admin-configured `maxThumbnailsPerRow`.
- **Collections from subfolders** — one level of subfolders inside `wallpapersPath` automatically becomes named sections, with optional numeric prefixes (`01-`, `02_`, `03 `) for ordering.
- **Configurable header** — optional logo image (separate light/dark variants) and an optional title.
- **Light/dark mode aware** — content respects the system appearance; logo switches automatically if both variants are set.
- **MDM-driven** — 20 configurable keys for branding, layout, behaviour, and launch positioning.
- **No window state pollution** — `isRestorable = false` ensures the window opens at the configured size every time, not at whatever size the user last had it.

## Quick start for users

There's nothing to configure. Run the app. Click a wallpaper. Click ✓ to keep it or ⊞ to go back. That's it.

## Quick start for admins

1. Decide which settings you want to enforce.
2. Build a `.mobileconfig` profile with a `com.apple.ManagedClient.preferences` payload targeting bundle id `techtherapy.decor`.
3. Use `techtherapy.decor.sample.plist` (in this repo) as the source of values for the `mcx_preference_settings` dict.
4. Distribute via your MDM. The app picks up changes live (no relaunch needed) via a `UserDefaults.didChangeNotification` observer.

For local testing without MDM: `defaults import techtherapy.decor /path/to/your.plist`, then relaunch the app.

## Documentation

- **[CONFIGURATION.md](./docs/CONFIGURATION.md)** — complete reference for every config key: types, defaults, validation, examples.
- **[DEPLOYMENT.md](./docs/DEPLOYMENT.md)** — MDM deployment guide with a full `.mobileconfig` template, local-testing instructions, and troubleshooting.
- **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — developer notes on the code structure, animation pipeline, preview flow, and design decisions.

## Project layout

```
Decor/
├── Decor.xcodeproj/                 Xcode project
├── Decor/                           App source
│   ├── ContentView.swift            All app code lives here
│   ├── AppIcon.appiconset/          Standard iOS/macOS icon set
│   ├── Assets.xcassets/             Other catalog assets
│   └── decor.entitlements           Sandbox entitlements
├── DecorTests/                      Unit-test stub
├── DecorUITests/                    UI-test stubs
├── techtherapy.decor.sample.plist   Reference plist with every config key
├── README.md
├── CONFIGURATION.md
├── DEPLOYMENT.md
└── ARCHITECTURE.md
```

## Licence

MIT
