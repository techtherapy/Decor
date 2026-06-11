# Changelog


## Unreleased

## Version 1.2.1 (22)

- New `showCollectionTitles` managed-preference key. When set to `false`, collection section headers (the folder name and underline above each grid section) are hidden while wallpapers remain grouped by their source subfolder. Defaults to `true`, so existing profiles behave exactly as before.

## Version 1.2.0 (21)

- **Currently-applied indicator.** A green checkmark badge now appears on the wallpaper card that matches what's currently set on the displays this window controls, so users can see at a glance what's live before clicking around. Refreshes on launch, after cancelling a preview, when the wallpapers folder changes, and when toggling between "set all" and "set displays individually" modes.
- **Keyboard navigation.** Arrow keys move focus across the grid (up/down step by the current column count). Space previews the focused wallpaper. Return - or numpad Enter - sets it directly. The first arrow press lands on the currently-applied wallpaper if it's in the grid, otherwise the first item. The grid auto-scrolls to keep the focused card visible.
- **Faster multi-display apply.** Per-screen `setDesktopImageURL` calls now run in parallel on a background queue instead of cascading serially on the main thread, so the displays update much closer together. This window's own screen fires first so its request reaches the Dock daemon ahead of the secondaries' - the user's primary display updates first. Each screen also keeps its existing scaling/positioning options instead of getting reset on every apply.
- **Snappier preview entry.** The window shrink animation now runs in parallel with the wallpaper apply instead of waiting for the IPC roundtrip to complete, so clicking a thumbnail feels noticeably more responsive.
- **Internal refactor.** `DecorConfig` defaults consolidated into a single `Defaults` enum (previously duplicated between property initializers and `loadConfig`). Loads now go through a value-equality guard so unrelated `UserDefaults` changes elsewhere in the app no longer churn `@Observable` observers. Layout constants pulled out of `launchContentSize` into a dedicated `Layout` enum next to the views they describe. Two near-duplicate `launchFrame` helpers collapsed into one.

## Version 1.0.10 (11)

- "Wallpaper is set" message stays on screen longer

## Version 1.0.9 (10)

- Fixed an occasional launch-time crash in the wallpaper grid caused by concurrent thumbnail loads racing on the shared cache's internal dictionaries. The cache is now main-actor isolated, while the actual image decode still runs off the main thread.

## Version 1.0.8 (9)

- **Per-display wallpapers.** New "Set displays individually" mode opens an additional grid window on every connected screen; each window's preview / Keep / Cancel only affects its own screen, so users can pick a different wallpaper per display in a single session. A two-state pill at the bottom of the primary window ("Set all displays" / "Set displays individually") toggles between modes. The pill is hidden on single-display setups.
- **Faster thumbnail loading.** Thumbnails now use ImageIO's `CGImageSourceCreateThumbnailAtIndex` to downsample directly from the source file instead of fully decoding the original NSImage and redrawing it. Substantial speedup on 4K+ wallpapers.
- **Shared thumbnail cache and collections.** The wallpaper folder is enumerated once per session, and decoded thumbnails are shared between the primary and every aux per-display window — so toggling into individual mode is instant rather than re-decoding the grid for each screen.
- **Recommended:** prefer WebP for wallpapers where possible. WebP files are typically 25–35 % smaller than equivalent-quality JPEG (and significantly smaller than PNG) while retaining visual quality, which reduces disk footprint in managed deployments and speeds up initial image load. macOS reads WebP natively via `NSImage`; the `wallpapersPath` folder already accepts `.webp` files.

## Version 1.0.7 (8)

- Increased the vertical spacing between collection sections in the wallpaper grid so each named section feels visually distinct from its neighbours.

## Version 1.0.6 (7)

- Removed the `textColor` and `backgroundColor` managed-preference keys. Text and window background now follow the system appearance automatically, adapting to light and dark mode. Existing profiles that set these keys will have them silently ignored.

## Version 1.0.5 (6)

- Added a Jamf Pro custom schema manifest at `deploy/decor-jamf-manifest.json` covering every managed preference, so Jamf admins get a labelled form (with descriptions, bounds, and enum options) instead of authoring raw plist XML.
- Removed the redundant `hideFilename` preference. `showWallpaperInfo` is now the single control for whether the filename label appears under each thumbnail. Existing profiles that set `hideFilename` will have that key silently ignored — set `showWallpaperInfo` to `false` instead.

## Version 1.0.4 (5)

- Wallpapers folder now recognises `.webp` files.

## Version 1.0.3 (4)

- Collections: subfolders inside `wallpapersPath` now render as named sections with a title and underline above each grid. Loose images at the root stay where they are (no header). Folder names support a leading numeric prefix (e.g. `01-Featured`) for ordering, which is stripped from the displayed title.
- Wallpaper card filenames now use a lighter font weight for a less heavy look.

## Version 1.0.2 (3)

- fix for app being hidden on first launch

## Version 1.0.1 (2)

- dafault settings fix

## Version 1.0.0 (1)

- Initial release
