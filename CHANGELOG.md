# Changelog


## Unreleased

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
