# Decor Configuration Reference

Every setting Decor honours is read from `UserDefaults.standard` under the app's bundle id (`techtherapy.decor`). The macOS managed-preferences system writes MDM-pushed values into `/Library/Managed Preferences/<user>/techtherapy.decor.plist`, and they're visible to `UserDefaults.standard` automatically — managed values take precedence over any user-set values, exactly per Apple's standard behaviour.

All keys are optional. Any omitted key uses its declared default. Values that fail validation (wrong type, out of range, unknown string) are ignored and the default is used.

The app re-reads its configuration live whenever `UserDefaults.didChangeNotification` fires, so MDM pushes are picked up without a relaunch. The only exceptions are launch-time-only behaviours (window size, position, `hideOtherAppsOnLaunch`) which apply on the next launch.

## How values are validated

`DecorConfig.loadConfig()` first resets every property to its declared default, then overlays values from `UserDefaults`. This means **removing a managed-preferences key reverts to the default** instead of retaining the previously-overlaid value.

Numeric and string values that lie outside the documented validation range are silently clamped or ignored. Hex colour strings that don't parse fall back to **magenta** (`#FF00FF`) so administrators spot mistyped values immediately rather than seeing an invisible colour.

## Settings reference

### Layout

| Key | Type | Default | Validation | Description |
|---|---|---|---|---|
| `thumbnailSize` | Number | `200` | Clamped 100 – 400 | Width of each card in points. Card height is auto-derived from a 16:10 aspect ratio. |
| `gridSpacing` | Number | `16` | Clamped 4 – 32 | Spacing between cards, both horizontally and vertically. |
| `cornerRadius` | Number | `12` | Clamped 0 – 24 | Corner radius applied to card image, background, and hover/selection borders. |
| `shadowRadius` | Number | `2` | Clamped 0 – 10 | Drop-shadow radius on cards (multiplied 1.5× on hover, 2× on selection). |
| `maxThumbnailsPerRow` | Integer | `6` | Clamped 2 – 20 | Upper bound on column count. The grid reflows columns based on window width but never exceeds this. |
| `defaultColumnCount` | Integer | `4` | Clamped 1 – 20 | Number of columns visible at the configured launch size. Effective value is `min(defaultColumnCount, maxThumbnailsPerRow)`. |
| `defaultRowCount` | Integer | `3` | Clamped 1 – 20 | Number of rows visible at the configured launch size. |
| `wallpapersPath` | String | `/Library/Desktop Pictures` | Non-empty; tilde-expanded | Folder Decor scans for wallpapers. Supports paths like `~/Pictures/Wallpapers`. Loose images and one level of subfolders (rendered as named collections) are read. Accepted file extensions: `jpg`, `jpeg`, `png`, `heic`, `tiff`, `bmp`, `webp` — see the README for why WebP is preferred for managed deployments. |

### Colours

All colour values are hex strings. The leading `#` is optional. Supported lengths are 3 (RGB12), 6 (RGB24), and 8 (ARGB32). Any other length parses as magenta (`#FF00FF`) so misconfiguration is immediately visible on screen.

| Key | Type | Default | Description |
|---|---|---|---|
| `thumbnailHighlightColor` | String (hex) | `.blue` (system) | Border colour drawn on hover (50 % opacity) and selection (full opacity). |
| `textHighlightColor` | String (hex) | `.blue` (system) | Wallpaper filename colour when card is selected. |

### Filename label

| Key | Type | Default | Description |
|---|---|---|---|
| `showWallpaperInfo` | Bool | `true` | Toggle for the filename label beneath each thumbnail. When `false`, no name is shown. |

### Collection titles

| Key | Type | Default | Description |
|---|---|---|---|
| `showCollectionTitles` | Bool | `true` | Toggle for the section header (folder name + underline) shown above each collection. When `false`, wallpapers are still grouped by their source subfolder but the title is hidden. Has no effect on loose images at the root of `wallpapersPath`, which never had a header. |

### Behaviour

| Key | Type | Default | Description |
|---|---|---|---|
| `doubleClickToSetWallpaper` | Bool | `false` | When `true`, double-clicking a thumbnail bypasses the preview pill and immediately commits the wallpaper. When `false`, double-clicks are ignored and single-click → preview is the only path. |
| `hideOtherAppsOnLaunch` | Bool | `true` | When `true`, the app calls `NSApp.hideOtherApplications(nil)` on launch (same as choosing "Hide Others" in the app menu). Useful for showing what the applied wallpaper will look like. |

### Header (logo and title)

The header bar is hidden entirely if neither `logoPath`, `logoPathDark`, nor `logoTitle` is configured.

| Key | Type | Default | Description |
|---|---|---|---|
| `logoPath` | String | `/Library/Icons/icon-dark.png` | File path to a logo image rendered at 50 pt tall in the header. Used in light mode, and in dark mode if `logoPathDark` is empty. Tilde-expanded. Any image format `NSImage` understands (PNG, JPG, PDF, SVG via Bitmap rep, …). |
| `logoPathDark` | String | `/Library/Icons/icon-light.png` | Optional dark-mode variant. When set, used in dark mode. If empty, `logoPath` is used for both modes. |
| `logoTitle` | String | `Select your wallpaper` | Title text rendered next to the logo. Empty string hides the title. |

### Launch position

| Key | Type | Default | Validation | Description |
|---|---|---|---|---|
| `launchPosition` | String | `center` | `left` \| `right` \| `center` | Where on the screen the window appears at launch. The window is positioned within the visible frame (excluding the menu bar and Dock) and vertically centred. |

## Sample plist

A complete reference plist is checked into the repository at `techtherapy.decor.sample.plist`. Every key Decor honours appears there with a sensible example value.

For local testing, you can import it directly into your `UserDefaults`:

```bash
defaults import techtherapy.decor /path/to/techtherapy.decor.sample.plist
```

To clear all overrides and return to code defaults:

```bash
defaults delete techtherapy.decor
```

For MDM deployment, the values from `mcx_preference_settings` in your `.mobileconfig` payload correspond one-to-one to the keys in this reference. See **[DEPLOYMENT.md](./DEPLOYMENT.md)** for the full wrapper structure.

## Behaviour worth knowing

- **Live updates.** Changes to managed preferences while the app is running are picked up automatically. The window size and position do *not* re-apply mid-session (those are launch-only), but colours, filename visibility, header text, wallpaper folder, etc., update immediately.
- **Wallpaper folder changes.** When `wallpapersPath` changes, Decor clears its thumbnail cache, drops the current selection, and reloads the directory.
- **Dynamic / aerial wallpapers.** If the user had a dynamic wallpaper, aerial screensaver, or stack active before launch, Decor's "restore on Cancel" only restores what `NSWorkspace.desktopImageURL(for:)` returns — a static URL. The dynamic mode itself can't be restored through public AppKit APIs.
- **Multi-display.** By default a chosen wallpaper is applied to every connected screen via `NSScreen.screens`. The user can opt into per-display picking via the "Set displays individually" pill at the bottom of the main window (visible only when more than one display is connected). In that mode an additional grid window appears on every non-primary screen and each window's preview / Keep / Cancel affects only its own screen.
