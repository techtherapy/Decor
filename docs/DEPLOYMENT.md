# Decor Deployment Guide

This document covers deploying Decor to managed Macs via MDM (Mobile Device Management). For the meaning of each configurable key, see **[CONFIGURATION.md](./CONFIGURATION.md)**.

## Audience

Mac admins running Jamf, Iru, Mosyle, Addigy, Fleet, Workspace ONE, Intune, AirWatch, or any other MDM that supports custom configuration profiles. Also useful for IT staff who want to test the configuration locally before pushing to fleet.

## Distribution prerequisites

- Decor.app built and signed by your organisation (or downloaded from your internal distribution channel).
- Bundle identifier: **`techtherapy.decor`**.
- Target devices running macOS 15.0 or later.

## Configuration profile structure

Decor reads its configuration from `UserDefaults.standard`, which means it sees any value the MDM writes into the `techtherapy.decor` defaults domain. The standard MDM mechanism is a `com.apple.ManagedClient.preferences` payload inside a `Configuration` profile.

### Use `Forced`

Decor has no in-app settings UI — every configurable value is read from `UserDefaults` and there is no preferences window for users to change anything. In practice that means **`Forced` is the only mode worth using**. Set-Once exists in the managed-preferences schema for apps that expose a settings UI users can interact with afterwards; Decor doesn't, so Set-Once would just behave like a one-shot seed value with no follow-up path for the user to override it (short of running `defaults write` in Terminal).

The example below uses `Forced`.

## Full `.mobileconfig` template

Replace the four `UUID` placeholders with freshly generated UUIDs (`uuidgen` on the command line, or any UUID v4 generator). Update `PayloadOrganization` and the `Identifier` strings to match your organisation's naming conventions.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Top-level Configuration payload -->
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>PayloadIdentifier</key>
    <string>com.yourorg.decor</string>
    <key>PayloadUUID</key>
    <string>REPLACE-WITH-UUID-1</string>
    <key>PayloadDisplayName</key>
    <string>Decor Wallpaper Picker</string>
    <key>PayloadOrganization</key>
    <string>Your Organisation</string>
    <key>PayloadScope</key>
    <string>User</string>

    <key>PayloadContent</key>
    <array>
        <dict>
            <!-- Managed preferences payload -->
            <key>PayloadType</key>
            <string>com.apple.ManagedClient.preferences</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.yourorg.decor.prefs</string>
            <key>PayloadUUID</key>
            <string>REPLACE-WITH-UUID-2</string>

            <key>PayloadContent</key>
            <dict>
                <!-- Target app's bundle id -->
                <key>techtherapy.decor</key>
                <dict>
                    <key>Forced</key>
                    <array>
                        <dict>
                            <key>mcx_preference_settings</key>
                            <dict>
                                <!-- ====================================== -->
                                <!-- DECOR SETTINGS START HERE              -->
                                <!-- Mirror the keys in CONFIGURATION.md    -->
                                <!-- ====================================== -->

                                <key>thumbnailSize</key>
                                <integer>250</integer>

                                <key>thumbnailHighlightColor</key>
                                <string>#3B82F6</string>

                                <key>textHighlightColor</key>
                                <string>#2563EB</string>

                                <key>gridSpacing</key>
                                <integer>20</integer>

                                <key>cornerRadius</key>
                                <integer>16</integer>

                                <key>shadowRadius</key>
                                <integer>4</integer>

                                <key>maxThumbnailsPerRow</key>
                                <integer>4</integer>

                                <key>defaultColumnCount</key>
                                <integer>3</integer>

                                <key>defaultRowCount</key>
                                <integer>3</integer>

                                <key>showWallpaperInfo</key>
                                <true/>

                                <key>wallpapersPath</key>
                                <string>/Library/Wallpapers/YourOrg</string>

                                <key>doubleClickToSetWallpaper</key>
                                <false/>

                                <key>hideOtherAppsOnLaunch</key>
                                <true/>

                                <key>logoPath</key>
                                <string>/Library/Application Support/YourOrg/decor-logo-light.png</string>

                                <key>logoPathDark</key>
                                <string>/Library/Application Support/YourOrg/decor-logo-dark.png</string>

                                <key>logoTitle</key>
                                <string>Select your wallpaper</string>

                                <key>launchPosition</key>
                                <string>center</string>

                                <!-- ====================================== -->
                                <!-- DECOR SETTINGS END                     -->
                                <!-- ====================================== -->
                            </dict>
                        </dict>
                    </array>
                </dict>
            </dict>
        </dict>
    </array>
</dict>
</plist>
```

### Validation tips

- After authoring, run `plutil -lint your-profile.mobileconfig` to catch XML errors before deployment.
- Sign the `.mobileconfig` with your organisation's certificate (`security cms -S -N "Cert Name" -i unsigned.mobileconfig -o signed.mobileconfig`) so the user isn't prompted with an "Unsigned profile" warning.

## Deployment via specific MDMs

### Jamf Pro

The repo ships a ready-to-use Jamf custom schema at **[`deploy/decor-jamf-manifest.json`](../deploy/decor-jamf-manifest.json)**. It describes every managed preference (title, description, type, default, bounds, and enum options for `launchPosition`), so Jamf renders a labelled form instead of asking you to author raw plist XML.

**Preferred path — upload the schema:**

1. **Computers → Configuration Profiles → New**.
2. **Application & Custom Settings → External Applications → Add → Custom Schema**.
3. Preference Domain: `techtherapy.decor`.
4. Upload `deploy/decor-jamf-manifest.json` as the Custom Schema.
5. Fill in the rendered form for the values you want to override, leave the rest at their defaults.
6. Scope to the target computer groups, save, deploy.

**Alternative — upload the full `.mobileconfig`:** use **Computers → Configuration Profiles → Upload** with the signed `.mobileconfig` from the template above. Use this when you'd rather manage the profile XML in source control than via the Jamf UI.

### Kandji

1. **Library → Add New → Custom Profile**.
2. Upload the signed `.mobileconfig`.
3. Assign to a Blueprint.

### Mosyle

1. **Management → macOS → Customize**.
2. Add a new "Custom Settings" profile.
3. Specify bundle id `techtherapy.decor` and add the key/value pairs.

### Intune

1. **Devices → Configuration profiles → Create → macOS → Templates → Custom**.
2. Upload the signed `.mobileconfig`.

## Required image deployment

The header logo files (`logoPath`, `logoPathDark`) must exist on disk at the configured paths before Decor launches. The expected pattern is to push the image files via the MDM's file-deployment mechanism (Jamf Composer policy, Kandji File payload, Mosyle Custom Apps file deployment, etc.) into a stable location such as `/Library/Application Support/YourOrg/`.

Image format recommendations:
- Use PNG with transparency for both variants.
- Light-mode logo (`logoPath`) should read against a light window background.
- Dark-mode logo (`logoPathDark`) should read against a dark window background.
- 50 pt tall is the rendered height; provide @2x assets (100 px tall) for retina displays.

Wallpaper images at `wallpapersPath` likewise need to be deployed to all target Macs before Decor will display them. Decor only reads from that folder; it does not download or sync.

### Recommended wallpaper format: WebP

For fleet deployments, prefer **WebP** for the wallpaper assets:

- Typically 25–35 % smaller than equivalent-quality JPEG at the same visual fidelity, and significantly smaller than PNG for photographic content. That meaningfully reduces both the per-device disk footprint and the bandwidth your MDM spends pushing the folder out.
- Decoded natively by `NSImage` on supported macOS versions — no codec install required.
- Faster initial image load: smaller files decode faster, especially when ImageIO downsamples them for thumbnails.

A reasonable starting point is `cwebp -q 85 input.jpg -o output.webp` for photographic content, or `cwebp -lossless input.png -o output.webp` for UI-style wallpapers (gradients, illustrations, flat colour). See the README for a longer note on tooling.

Decor accepts the full set `jpg`, `jpeg`, `png`, `heic`, `tiff`, `bmp`, `webp` — switching is a drop-in replacement; no config change required.

## Local testing without MDM

You can simulate an MDM push locally before going to fleet:

```bash
# Apply the sample plist
defaults import techtherapy.decor /path/to/techtherapy.decor.sample.plist

# Launch Decor — settings are picked up immediately
open /Applications/Decor.app

# Inspect current effective defaults
defaults read techtherapy.decor

# Tweak a single key
defaults write techtherapy.decor thumbnailSize -int 300

# Clear all local overrides (back to code defaults)
defaults delete techtherapy.decor
```

> **Note:** `defaults` writes to *user* preferences, not the managed-preferences plist. For full fidelity testing of `Forced` behaviour (where user defaults can't override MDM values), install an actual signed `.mobileconfig` via System Settings → Privacy & Security → Profiles.

## Troubleshooting

### "My settings aren't being respected"

1. Confirm the bundle id matches exactly: `techtherapy.decor`.
2. Check the effective defaults after the profile is installed:
   ```bash
   defaults read techtherapy.decor
   ```
3. Verify the profile actually installed:
   ```bash
   profiles list -type configuration
   ```
4. Relaunch Decor. Most settings update live, but launch-time settings (window size, position, `hideOtherAppsOnLaunch`) only apply on the next launch.

### "The header logo doesn't appear"

- Confirm the file exists at the path you specified. Tilde paths are expanded relative to the user's home dir; absolute paths should resolve as-is.
- Check `NSImage` can read the file (try `qlmanage -p /path/to/your.png`).
- The header is hidden entirely if both `logoPath` and `logoPathDark` are empty *and* `logoTitle` is empty.

### "Colours show as magenta"

The hex parser falls back to magenta (`#FF00FF`) for invalid input — that's a *feature*, not a bug. Check the value you supplied:
- Length must be 3, 6, or 8 hex digits.
- Leading `#` is optional but other non-alphanumeric characters are stripped.

### "Wallpaper changes don't persist after Decor quits"

When the user clicks **Keep** or double-clicks a thumbnail, Decor commits the wallpaper via `NSWorkspace.setDesktopImageURL(_:for:options:)`. This is the same API System Settings uses; macOS persists the choice across reboots. If you're seeing reverts, check whether another agent on the system (another MDM payload, a `defaults`-based wallpaper enforcer, etc.) is overwriting it.

### "The app stays alive in the Dock after closing the window"

It shouldn't — `applicationShouldTerminateAfterLastWindowClosed` returns `true`, so closing the window quits the app. If you see this, you may have an old build cached. Quit explicitly via ⌘Q and relaunch.

### "App Intents / linkd errors in Console"

Decor doesn't expose App Intents. macOS still tries to register the app with the Shortcuts daemon on launch and logs `com.apple.linkd.autoShortcut` connection errors when the registration is a no-op. These are cosmetic; ignore them.

## Updating configuration

Decor reads its configuration on every `UserDefaults.didChangeNotification`, so a fresh MDM push reaches the running app within a few seconds. Exceptions:

- Window **size** and **position** — apply on next launch only.
- **`hideOtherAppsOnLaunch`** — applies on launch only.
- Everything else updates live: colours, header, filename visibility, wallpaper folder, double-click behaviour, launch corner.

To force a fully clean state on a target Mac:

```bash
defaults delete techtherapy.decor
killall Decor 2>/dev/null
open /Applications/Decor.app
```
