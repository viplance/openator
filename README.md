# Openator

macOS menu bar app that routes URLs to different browsers based on configurable rules.

Openator registers itself as the default web browser and intercepts all URL opens. It matches each URL against your rules and forwards it to the right browser — or falls back to whichever browser you pick as default.

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (`xcode-select --install`)
- Node.js & pnpm

## Setup

```bash
pnpm icon    # generate app icon
pnpm build   # build, assemble .app bundle, sign with Developer ID
pnpm start   # build + launch
```

## Usage

1. Launch Openator — it appears as a Y-fork icon in the menu bar
2. When prompted, set Openator as your default web browser
3. Configure your rules via the menu:
   - **Default Browser** — select the fallback browser (used when no rule matches)
   - **Open on System Start** — toggle launch at login
   - **Rules** — manage URL routing rules:
     - Click **Add Rule…** to create a new rule
     - Click an existing rule to edit or delete it
     - Each rule matches URLs containing a given string and opens them in a specific browser

## How Rules Work

Each rule has two fields:

- **URL includes** — a substring to match against the full URL (case-insensitive)
- **Open with** — the browser to use when the pattern matches

Rules are evaluated in order. The first match wins. If no rule matches, the URL opens in your selected default browser.

### Example

| URL includes | Open with |
|---|---|
| `github.com` | Safari |
| `youtube.com` | Chrome |
| `figma.com` | Firefox |

## Scripts

| Command | Description |
|---|---|
| `pnpm build` | Build release binary, assemble `.app` bundle, sign with Developer ID |
| `pnpm start` | Build and launch |
| `pnpm dev` | Alias for `pnpm start` |
| `pnpm icon` | Regenerate all icon assets (icns, xcassets, App Store marketing icon) |
| `pnpm clean` | Remove `.build/` and `dist/` |

## App Store

### Generated assets

`pnpm icon` produces everything needed for App Store submission:

| Path | Purpose |
|---|---|
| `assets/icon.icns` | App bundle icon |
| `assets/AppStore-1024x1024.png` | Marketing icon for App Store Connect |
| `Assets.xcassets/AppIcon.appiconset/` | Full asset catalog with all sizes (16–1024px) |

### Publishing checklist

1. Create an **Apple Distribution** certificate in [Apple Developer portal](https://developer.apple.com/account/resources/certificates)
2. Create an App ID for `com.openator.app` and a provisioning profile
3. Build and sign with the distribution certificate
4. Upload to App Store Connect via Xcode or Transporter
5. Add screenshots (macOS: 2560x1600 or 2880x1800) in App Store Connect
6. Submit for review

`Openator.entitlements` is the App Store entitlement set and must be paired with
the App Store provisioning profile. The local `pnpm build` Developer ID flow uses
`Openator.DeveloperID.entitlements` instead.
