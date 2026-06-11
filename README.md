# Decor

![Latest release](https://img.shields.io/github/v/release/techtherapy/Decor)

A lightweight macOS wallpaper picker for managed environments. Decor shows a configurable grid of desktop wallpapers, lets the user preview any choice live on their desktop, and is fully MDM-configurable. The wallpaper folder and all settings are supplied by an MDM profile (or a local plist for testing).

https://github.com/user-attachments/assets/4beecede-0cd4-462b-868f-bbe289740720

- **Platform:** macOS 15.0+ (built and tested on macOS 26)
- **Bundle identifier:** `techtherapy.decor`
- **Distribution model:** one-shot utility (quits after the user commits or cancels)

## Installation

The signed `.dmg` attached to each [GitHub release](https://github.com/techtherapy/Decor/releases) is **already notarised and stapled by Apple** - install it on any macOS 15+ Mac and it launches without Gatekeeper prompts or right-click-to-open workarounds. Package and install via your MDM or via Installomator (see **[DEPLOYMENT.md](docs/DEPLOYMENT.md#installomator-label)**)

## How it's configured

Decor is designed for managed environments: an admin points it at a folder of approved wallpapers (and optionally sets branding, layout and behaviour) via an MDM configuration profile. End users then have nothing to set up - they just run the app and pick.

**Note:** with no configuration at all, Decor shows an empty window - it has no built-in wallpaper folder. At minimum, set `wallpapersPath` so the app knows where the images live.

**Setting it up (admins):**

1. Decide which settings you want to enforce - at minimum, `wallpapersPath`.
2. Build a `.mobileconfig` profile with a `com.apple.ManagedClient.preferences` payload targeting bundle id `techtherapy.decor`.
3. Use `techtherapy.decor.sample.plist` (in this repo) as the source of values for the `mcx_preference_settings` dict.
4. Package and deploy your wallpaper images.
5. Distribute via your MDM.

For local testing without MDM: `defaults import techtherapy.decor /path/to/your.plist`, then relaunch the app.

**For end users:** nothing to configure. Run the app, click a wallpaper, then click ✓ to keep it or ⊞ to go back.

## What it does

Decor scans the configured folder for image files (`jpg`, `jpeg`, `png`, `heic`, `tiff`, `bmp`, `webp`), shows them as a reflowable grid of thumbnails, and applies a chosen image as the desktop background. By default the chosen image is applied to **every connected display**; users on a multi-display Mac can also opt into picking a different wallpaper per display.

Subfolders inside that folder are treated as **collections**: each subfolder becomes a named section with its own grid. Loose images at the root render at the top with no header. Folder names may use a leading numeric prefix (e.g. `01-Featured`, `02_Nature`, `03 Abstract`) to force display order - the prefix is stripped from the visible title.

## User flow

1. **Launch.** The app opens at its configured size and position.
2. **Browse.** Hover and click thumbnails to preview them, or use the keyboard: arrow keys move focus, Space previews the focused wallpaper, Return sets it directly. Hovered and focused cards lift slightly and gain a soft border; selected cards get a more prominent border, scale up, and brighten subtly. A green checkmark badge marks whichever wallpaper is already set on the displays this window controls.
3. **Preview.** Single-clicking a thumbnail:
   - Immediately applies that wallpaper to all displays (or just this window's display in per-display mode - see below).
   - Shrinks the main window down to a small pill in the top-right corner of the screen.
   - Shows the wallpaper name and four icon buttons: ◀ ▶ (cycle) · ⊞ (back to grid) · ✓ (keep).
4. **Browse from the pill.** ◀ / ▶ (or the left/right arrow keys) cycle through wallpapers without leaving preview mode. Each click swaps the desktop wallpaper but keeps the original captured for restore.
5. **Decide.**
   - **Keep** (✓ / Return) - shows a green "Wallpaper set" confirmation, then closes the window.
   - **Back to grid** (⊞ / Esc) - restores the original wallpaper and re-expands the window to the grid view.
   - **Close window** (red traffic light) - treated as Back to grid, then quits.
6. **Shortcut: double-click a thumbnail** (when `doubleClickToSetWallpaper` is enabled) - bypasses the preview entirely, sets the wallpaper, and closes the window.

### Per-display wallpapers (multi-display Macs)

A two-state pill at the bottom of the main window toggles the picking mode (shown only when more than one display is connected):

- **Set all displays** *(default)* - one selection applies to every connected display. This is the original behaviour.
- **Set displays individually** - a separate grid window appears on every other connected display. Each window's preview / Keep / Cancel affects only the screen it lives on, so the user can pick a different wallpaper per display. The app quits once every per-display window has been resolved (kept, cancelled, or closed).

## Keyboard shortcuts

| Key | In the grid | In preview |
| --- | --- | --- |
| ← / → | Move focus left / right | Cycle to previous / next wallpaper |
| ↑ / ↓ | Move focus up / down by one row | - |
| Space | Preview the focused wallpaper | - |
| Return / Enter | Set the focused wallpaper and quit | Keep the previewed wallpaper |
| Esc | - | Cancel preview, return to the grid |
| ⌘W (window close) | Quit | Treated as Cancel (reverts), then quits |

The first arrow press in the grid focuses the currently-applied wallpaper (the one with the green checkmark) if it's visible, otherwise the first item. The grid auto-scrolls to keep the focused card in view.

## Key features

- **Live preview** - the wallpaper is actually applied during preview, not just shown as a mock-up.
- **Currently-applied indicator** - a green checkmark badge on the wallpaper card that matches what's currently set on the targeted displays, so users see what's live before clicking around.
- **Keyboard navigation** - arrow keys focus cards, Space previews, Return sets. First arrow press jumps to the currently-applied wallpaper when it's in the grid.
- **Multi-display aware** - captures and restores per-screen wallpaper URL and `desktopImageOptions` (scaling, clipping, fill colour) when reverting. Supports both single-pick-for-all-displays and pick-per-display modes. Per-screen apply calls run in parallel, with the primary display fired first so the user's main screen updates ahead of the rest.
- **Reflowable grid** - fixed-size cards reflow into more or fewer columns as the user resizes the window, capped at the admin-configured `maxThumbnailsPerRow`.
- **Collections from subfolders** - one level of subfolders inside `wallpapersPath` automatically becomes named sections, with optional numeric prefixes (`01-`, `02_`, `03 `) for ordering.
- **Configurable header** - optional logo image (separate light/dark variants) and an optional title.
- **Light/dark mode aware** - content respects the system appearance; logo switches automatically if both variants are set.
- **MDM-driven** - 21 configurable keys for branding, layout, behaviour, and launch positioning.
- **Fast image loading** - thumbnails are produced via ImageIO downsampling (no full decode of the source) and shared across every Decor window, so each wallpaper is decoded at most once per session.
- **No window state pollution** - `isRestorable = false` ensures the window opens at the configured size every time, not at whatever size the user last had it.

## Wallpaper format recommendation: use WebP

Decor accepts `.jpg`, `.jpeg`, `.png`, `.heic`, `.tiff`, `.bmp`, and `.webp`. For managed deployments, **prefer WebP** for the wallpaper assets:

- **Smaller files.** Typical lossy WebP encodes are 25-35 % smaller than equivalent-quality JPEG; lossless WebP is significantly smaller than PNG with comparable detail. That compounds when you're pushing a wallpaper folder to a fleet.
- **Native macOS support.** `NSImage` reads WebP directly on supported macOS versions - no extra codecs or third-party libraries required.
- **Faster first paint.** Smaller files decode faster, especially when Decor enumerates the folder and ImageIO downsamples each image for thumbnails.

Tools that produce WebP from your existing assets:

- `cwebp` (from Google's libwebp): `cwebp -q 85 input.jpg -o output.webp` for high-quality lossy, or `cwebp -lossless input.png -o output.webp`.
- ImageMagick / GraphicsMagick: `magick input.png output.webp`.
- macOS Preview's "Export As..." with the WebP option (macOS 15+).

A reasonable starting point for desktop-sized wallpapers is `cwebp -q 85` - visually indistinguishable from the source on typical photographic content, at a substantial size reduction. For UI-style wallpapers (gradients, illustrations) `-lossless` is usually small enough.

## Building from source

Prefer to ship your own build - to audit the source, swap in your organisation's signing identity, or pin to an internal version? Open `Xcode/Decor.xcodeproj` in Xcode and build the `Decor` target.

To produce a notarised release for redistribution, you'll need an Apple Developer ID Application certificate and an App Store Connect notary credential in your keychain. The included `release_new_version.py` automates the full archive → sign (hardened runtime) → DMG → notarise → staple → publish pipeline:

1. Copy `app.yml.example` to `app.yml` and fill in your app name, bundle id, scheme, GitHub owner/repo, and (optionally) your signing-identity hash.
2. Export your Apple team id: `export APPLE_TEAM_ID=XXXXXXXXXX`.
3. Run `uv run release_new_version.py <major|minor|patch> ./build`.

The script bumps the version, builds and signs the app, builds and notarises the DMG, updates the changelog, and creates the git tag and GitHub release.

## Documentation

- **[CONFIGURATION.md](./docs/CONFIGURATION.md)** - complete reference for every config key: types, defaults, validation, examples.
- **[DEPLOYMENT.md](./docs/DEPLOYMENT.md)** - MDM deployment guide with a full `.mobileconfig` template, local-testing instructions, and troubleshooting.
- **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** - developer notes on the code structure, animation pipeline, preview flow, and design decisions.

## Project layout

```
Decor/
├── Xcode/
│   └── Decor.xcodeproj/             Xcode project
│       └── Decor/                   App source
│           ├── ContentView.swift    Main app code
│           ├── AppIcon.appiconset/   Standard icon set
│           ├── Assets.xcassets/      Other catalog assets
│           └── decor.entitlements    Sandbox entitlements
├── docs/
│   ├── CONFIGURATION.md             Config key reference
│   ├── DEPLOYMENT.md                MDM deployment guide
│   └── ARCHITECTURE.md              Developer notes
├── techtherapy.decor.sample.plist   Reference plist with every config key
├── release_new_version.py           Release automation pipeline
├── app.yml.example                  Release-config template (copy to app.yml)
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Licence

Apache 2.0
