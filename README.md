# Spot

A tiny, native macOS mini player for Spotify. Built entirely with SwiftUI and AppKit, Spot floats above all windows as a compact, borderless player showing album artwork, track info, volume control, and synced lyrics. It runs without a Dock icon, living quietly in your menu bar.

## Table of Contents

- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Spotify Developer Setup](#spotify-developer-setup)
- [Building from Source](#building-from-source)
- [Architecture](#architecture)
- [Testing](#testing)
- [Release Process](#release-process)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Key Features

- **Album artwork, track title, and artist name** displayed in a compact 220x300 floating window
- **Volume slider** with real-time control via AppleScript to the Spotify desktop app
- **Like/unlike tracks** directly from the player (heart button on artwork)
- **Synced lyrics overlay** powered by [LRCLIB](https://lrclib.net/) with line-by-line highlighting, blur, and scale animations
- **Always-on-top floating window** with no title bar, draggable by background
- **Menu bar icon** with quick access to preferences and quit
- **Hide when not playing** option to auto-hide the player when Spotify is inactive
- **Automatic updates** via Sparkle with EdDSA-signed releases
- **Onboarding flow** that guides new users through Spotify Developer setup

## Tech Stack

- **Language**: Swift 5.10+
- **UI Framework**: SwiftUI + AppKit (hybrid for window management)
- **Platform**: macOS 14.0+ (Sonoma)
- **Package Manager**: Swift Package Manager
- **Dependency**: [Sparkle 2](https://sparkle-project.org/) (auto-updater framework)
- **APIs**: Spotify Web API (OAuth 2.0 PKCE), LRCLIB API (lyrics)
- **CI/CD**: GitHub Actions (test on push/PR, release on tag)
- **Code Signing**: Apple Developer ID + notarization
- **Bundle ID**: `com.joelmoss.spot`

## Prerequisites

- **macOS 14.0 (Sonoma)** or later
- **Spotify Premium** account (required for playback state and control via Web API)
- **Xcode Command Line Tools** (for building from source): `xcode-select --install`
- **A Spotify Developer app** (free -- see [Spotify Developer Setup](#spotify-developer-setup))

## Installation

### Download

Download the latest `Spot.dmg` from [GitHub Releases](https://github.com/joelmoss/spot/releases), open the disk image, and drag **Spot.app** to your Applications folder.

### First Launch

On first launch, Spot displays an onboarding screen that walks you through three steps:

1. Create a Spotify Developer app (a button opens the dashboard for you)
2. Set the redirect URI to `spot-app://callback` and select **Web API** as the API type
3. Paste your **Client ID** into Spot

Once saved, Spot opens a browser window to authorize with your Spotify account via OAuth. After authorization, the player appears and begins showing your current playback.

## Spotify Developer Setup

Spotify requires all apps using their Web API to register. This is free and takes about a minute. Spot uses the **PKCE authorization flow**, so no client secret is needed -- only the Client ID.

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Click **Create App**
3. Fill in the app name (e.g., "Spot") and description
4. Set the **Redirect URI** to:
   ```
   spot-app://callback
   ```
5. Under **Which API/SDKs are you planning to use?**, select **Web API**
6. Save the app
7. Copy the **Client ID** from the app's settings page

### Required Scopes

Spot requests the following OAuth scopes (handled automatically during authorization):

| Scope | Purpose |
|-------|---------|
| `user-read-playback-state` | Read current track, artist, artwork, volume, and play state |
| `user-modify-playback-state` | Play, pause, skip, and adjust volume |
| `user-read-currently-playing` | Get the currently playing track |
| `user-library-read` | Check if a track is in the user's saved library |
| `user-library-modify` | Save/remove tracks from the user's library |

## Building from Source

### Debug Build

For rapid iteration during development:

```bash
git clone https://github.com/joelmoss/spot.git
cd spot
swift build && swift run Spot
```

This builds a debug binary and launches Spot directly. When running via `swift run` (outside an `.app` bundle), the OAuth callback uses `ASWebAuthenticationSession` instead of the registered URL scheme, and the Sparkle updater is disabled.

### Release Build (Signed App Bundle + DMG)

The `scripts/build.sh` script produces a fully signed and notarized release:

```bash
./scripts/build.sh
```

This performs the following steps:

1. Builds a release binary (`swift build -c release`)
2. Assembles the `.app` bundle with Info.plist, icon, menu bar images, and Sparkle framework
3. Signs the Sparkle framework components inside-out (XPC services, Autoupdate, Updater.app, then the framework)
4. Signs the app bundle with Developer ID and entitlements
5. Creates a DMG with `create-dmg` (with app icon and Applications drop link)
6. Signs the DMG
7. Submits to Apple for notarization and staples the ticket

**Requirements for release builds:**

- Apple Developer ID certificate installed in keychain
- `create-dmg` installed (`brew install create-dmg`)
- Notarization keychain profile configured as `spot-notary` (`xcrun notarytool store-credentials`)
- Team ID: `B898J443L9`

Output:

- `build/Spot.app` -- signed and notarized app bundle
- `build/Spot.dmg` -- distributable disk image

### Makefile Targets

The project includes a Makefile for common operations:

| Command | Description |
|---------|-------------|
| `make build` | Build debug binary |
| `make run` | Build and run (debug) |
| `make test` | Run tests |
| `make release` | Build release binary |
| `make app` | Build release app bundle (unsigned) |
| `make dmg` | Build release DMG (unsigned) |
| `make clean` | Remove build artifacts |
| `make help` | Show available targets |

## Architecture

### Directory Structure

```
spot/
├── Sources/Spot/
│   ├── SpotApp.swift              # Entry point, window config, menu bar, app delegate
│   ├── SpotifyController.swift    # Playback state manager, polling, lyrics fetching
│   ├── SpotifyAuth.swift          # OAuth 2.0 PKCE, token lifecycle, all Spotify API calls
│   ├── MiniPlayerView.swift       # Main player UI (artwork, track info, volume, like/lyrics buttons)
│   ├── LyricsOverlayView.swift    # Full-screen synced lyrics overlay
│   ├── LyricsModel.swift          # Lyrics data types and LRC parser
│   ├── ConnectingView.swift       # OAuth in-progress view with retry
│   ├── OnboardingView.swift       # First-launch setup wizard
│   ├── SettingsView.swift         # Preferences window (account, updates, hide option)
│   ├── UpdaterController.swift    # Sparkle auto-updater wrapper
│   └── Resources/
│       ├── AppIcon.icns           # Application icon
│       ├── MenuBarIcon.png        # Menu bar icon (1x)
│       └── MenuBarIcon@2x.png    # Menu bar icon (2x Retina)
├── Tests/SpotTests/
│   ├── SpotifyControllerTests.swift
│   ├── LyricsModelTests.swift
│   ├── LyricsTests.swift
│   └── LyricsWindowTests.swift
├── scripts/
│   ├── build.sh                   # Release build, sign, notarize, DMG
│   └── entitlements.plist         # Network client + unsigned executable memory
├── .github/workflows/
│   ├── test.yml                   # CI: build + test on push/PR to main
│   └── release.yml                # CD: universal binary, sign, notarize, GitHub release
├── Package.swift                  # SPM manifest (macOS 14+, Sparkle dependency)
├── Info.plist                     # Bundle config, URL scheme, Sparkle keys, LSUIElement
├── Makefile                       # Build shortcuts
└── appcast.xml                    # Sparkle update feed (auto-updated by release workflow)
```

### Component Overview

#### SpotApp (Entry Point)

`SpotApp.swift` is the `@main` entry point. It defines three scenes:

- **Main WindowGroup** -- the mini player (MiniPlayerView)
- **Settings Window** -- preferences panel (SettingsView)
- **MenuBarExtra** -- system menu bar icon with Preferences and Quit

The `AppDelegate` handles:
- OAuth URL scheme callbacks (`spot-app://callback`) via Apple Events
- Player window configuration (borderless, floating, draggable, transparent background)
- Lyrics overlay window lifecycle (creating/dismissing a full-screen `LyricsWindow`)
- Activation policy switching between `.accessory` (normal) and `.regular` (when lyrics overlay needs key events)

The player window uses `NSWindow.Level.floating` to stay above all other windows. `LSUIElement` is set to `true` in Info.plist so the app runs without a Dock icon.

#### SpotifyController (State Manager)

`SpotifyController` is an `@Observable` class that manages all playback state. It:

- **Polls the Spotify Web API** at adaptive intervals:
  - 5 seconds while playing
  - 3 seconds while playing with lyrics overlay open
  - 15 seconds while paused
  - 30 seconds when Spotify is not active
- **Exposes playback controls**: play/pause, next, previous, volume (with 300ms debounce)
- **Manages track likes**: optimistic UI updates with rollback on failure
- **Fetches lyrics** from the LRCLIB API when the lyrics overlay is toggled
- **Tracks playback progress** with a 100ms timer for synced lyrics line highlighting, including a 400ms lookahead offset to compensate for API latency

#### SpotifyAuth (OAuth + API)

`SpotifyAuth` is an `@Observable` class conforming to `SpotifyAuthProviding` that handles:

- **OAuth 2.0 PKCE flow**: generates code verifier/challenge using CryptoKit SHA-256, exchanges authorization code for tokens
- **Token lifecycle**: stores access/refresh tokens in UserDefaults, auto-refreshes expired tokens, clears tokens on 401 responses
- **Auth versioning**: an `authVersion` counter forces re-authorization when scopes change
- **All Spotify Web API calls**: playback control (`/me/player/*`), current track (`/me/player`), library operations (`/me/library`)
- **Rate limit handling**: respects `Retry-After` headers on 429 responses
- **Volume control**: uses AppleScript to set/get Spotify's volume directly (more reliable than the Web API)

When running from an `.app` bundle, OAuth uses the registered `spot-app://` URL scheme via Apple Events. When running via `swift run`, it falls back to `ASWebAuthenticationSession`.

#### MiniPlayerView (Main UI)

The mini player is a 220x300 SwiftUI view with:

- Album artwork (220x220) loaded via `AsyncImage`
- Like button (heart) overlaid on bottom-right of artwork
- Lyrics button (quote bubble) overlaid on bottom-left of artwork
- Track name and artist name below artwork
- Volume slider with dynamic speaker icon
- Adaptive window size: 340x380 for onboarding, 220x160 for connecting, 220x300 for playback
- `.ultraThinMaterial` background with rounded corners

#### LyricsOverlayView (Full-Screen Lyrics)

When the lyrics button is tapped, a full-screen overlay appears with:

- Dark semi-transparent background (0.85 opacity)
- Synced lyrics with the current line displayed large (64pt bold) and surrounding lines progressively smaller, more transparent, and blurred
- Spring animations for line transitions
- Auto-scrolling `ScrollViewReader` that centers the current line
- Plain text fallback for non-synced lyrics
- Track info bar at the bottom (artwork thumbnail, track name, artist)
- Dismisses on any tap or key press

#### LyricsModel (Data + Parser)

Defines the lyrics data types and LRC format parser:

- `LyricsLine`: a single line with timestamp (milliseconds) and text
- `ParsedLyrics`: enum of `.synced([LyricsLine])`, `.plain(String)`, or `.none`
- `LyricsParser.parseSyncedLyrics()`: parses `[mm:ss.cc]` LRC format timestamps
- `LyricsParser.currentLineIndex()`: binary search for the active line given current progress

### Data Flow

```
User Action (play/pause/skip/volume/like)
    │
    ▼
SpotifyController ──► SpotifyAuth ──► Spotify Web API
    │                                       │
    │                                       ▼
    │                              Spotify responds
    │                                       │
    ▼                                       ▼
MiniPlayerView ◄── SpotifyController ◄── SpotifyAuth
(SwiftUI @Observable updates)

Lyrics Flow:
SpotifyController ──► LRCLIB API ──► ParsedLyrics
    │                                     │
    ▼                                     ▼
LyricsOverlayView ◄── progress timer ◄── synced lines
```

### Key Design Decisions

- **No SPM resource bundle**: `Package.swift` uses `exclude: ["Resources"]` instead of `.copy("Resources")`. The app icon and menu bar images are copied manually during the build script. This avoids SPM's `Bundle.module` accessor which doesn't work correctly inside `.app` bundles (it looks in the bundle root, but code signing requires everything inside `Contents/`).

- **All Spotify interaction via Web API**: no AppleScript for playback control (except volume, which is more reliable via AppleScript). Requires OAuth authentication and Spotify Premium.

- **`@Observable` macro** (Swift 5.10+): used for reactive state in SpotifyController, SpotifyAuth, and UpdaterController instead of `ObservableObject`/`@Published`.

- **Adaptive polling intervals**: reduces API calls when playback is paused or inactive, and increases frequency when lyrics are displayed.

- **Volume control via AppleScript**: the Spotify Web API volume endpoint is unreliable for some device types, so Spot uses AppleScript to directly control the Spotify desktop app's volume.

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run via Make
make test
```

### Test Structure

```
Tests/SpotTests/
├── SpotifyControllerTests.swift   # Playback state, polling, likes, lyrics integration
├── LyricsModelTests.swift         # LRC parser, line indexing
├── LyricsTests.swift              # Lyrics fetching and display logic
└── LyricsWindowTests.swift        # Lyrics window lifecycle
```

Tests use a mock `SpotifyAuthProviding` protocol implementation to test the controller without hitting the real Spotify API.

### CI

Tests run automatically on every push to `main` and on pull requests via GitHub Actions (`.github/workflows/test.yml`). The CI environment is macOS 15.

## Release Process

Releases are automated via GitHub Actions. To create a new release:

1. **Bump the version** in `Info.plist` (both `CFBundleVersion` and `CFBundleShortVersionString`)
2. **Commit** the version change
3. **Tag** with `v*` format (e.g., `v1.7.0`)
4. **Push** the tag to GitHub

The release workflow (`.github/workflows/release.yml`) then:

1. Builds universal binary (arm64 + x86_64) via `lipo`
2. Assembles the `.app` bundle with Sparkle framework
3. Imports the signing certificate from GitHub secrets
4. Signs the bundle with Developer ID
5. Creates a DMG with `create-dmg`
6. Signs the DMG
7. Submits to Apple for notarization and staples the ticket
8. Creates a ZIP for Sparkle updates, signed with EdDSA
9. Creates a GitHub Release with DMG and ZIP attached
10. Updates `appcast.xml` on the `main` branch for Sparkle auto-updates

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `CERTIFICATE_P12` | Base64-encoded Developer ID certificate (.p12) |
| `CERTIFICATE_PASSWORD` | Password for the .p12 certificate |
| `APPLE_TEAM_ID` | Apple Developer Team ID (`B898J443L9`) |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key for Sparkle update signing |

### Entitlements

The app is signed with two entitlements (`scripts/entitlements.plist`):

- `com.apple.security.network.client` -- required for Spotify Web API and LRCLIB API calls
- `com.apple.security.cs.allow-unsigned-executable-memory` -- required by the Sparkle framework

## Troubleshooting

### "No active playback" even though Spotify is playing

This means Spot cannot reach the Spotify Web API or your session has expired.

- Ensure your Spotify Premium subscription is active (the Web API playback endpoints require Premium)
- Open Preferences and check if your account shows as "Connected"
- If not connected, click **Connect** to re-authorize
- If already connected, try disconnecting and reconnecting

### OAuth authorization fails or times out

The connecting screen shows a "Try again" button after 10 seconds if authorization hasn't completed.

- Verify the **redirect URI** in your Spotify Developer app is exactly `spot-app://callback`
- Ensure the **API type** is set to **Web API** in your Spotify Developer app settings
- Check that your Client ID is correct (no extra spaces)
- Click **Restart** to go back to the onboarding screen and re-enter your Client ID

### Rate limiting ("Rate limited -- retrying in...")

Spotify enforces rate limits on their Web API. Spot respects `Retry-After` headers and will automatically resume polling when the rate limit expires. The player displays a countdown timer showing when it will retry.

If you see frequent rate limiting, this may indicate another app or integration is also making heavy API calls with your account.

### Volume slider doesn't work

Volume control uses AppleScript to communicate directly with the Spotify desktop app. Ensure:

- The Spotify desktop app is running (not just Spotify Connect on another device)
- Spot has accessibility/automation permissions if prompted by macOS
- Some devices (e.g., Spotify Connect speakers) don't support volume control -- the slider will be hidden for unsupported devices

### Lyrics not showing or "No lyrics found"

Lyrics are fetched from [LRCLIB](https://lrclib.net/), a community-maintained lyrics database.

- Not all songs have lyrics in the LRCLIB database
- Synced (timed) lyrics may not be available for all tracks; Spot falls back to plain text lyrics when synced lyrics aren't available
- The lyrics overlay can be toggled with the quote bubble button on the bottom-left of the artwork

### App doesn't appear after launch

Spot runs as an `LSUIElement` app (no Dock icon). Look for the music note icon in your **menu bar** (top-right of the screen). The player window floats above other windows but may be off-screen if you've changed display configurations.

If you have "Hide when not playing" enabled and Spotify isn't playing, the window is intentionally hidden. Start playing something in Spotify or disable the option in Preferences.

### Build fails with missing Sparkle framework

```bash
# Clean SPM caches and rebuild
swift package clean
swift package resolve
swift build
```

If the issue persists, remove the `.build` directory entirely:

```bash
rm -rf .build
swift build
```

## License

[MIT](LICENSE)
