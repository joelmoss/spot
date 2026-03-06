# Spot

A tiny, native macOS mini player for Spotify. Built with SwiftUI, it floats above all windows and shows what's currently playing.

## Features

- Album artwork, track title, and artist name
- Volume slider
- Like/unlike tracks from the player
- Always-on-top floating window with no title bar
- Menu bar icon with quick access to preferences and quit
- Option to hide the player when Spotify isn't playing

## Requirements

- macOS 14.0+ (Sonoma)
- Spotify Premium account (required for playback control)
- A Spotify Developer app (free — see Setup below)

## Setup

### 1. Create a Spotify Developer App

Spotify requires all apps that use their Web API to register as a developer app. This is free and only takes a minute — it gives you a **Client ID** that Spot uses to authenticate with your Spotify account. No client secret is needed (Spot uses the PKCE auth flow).

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create a new app
3. Set the redirect URI to `spot-app://callback`
4. Select **Web API** for the API type
5. Copy the **Client ID** from the app settings

### 2. Install Spot

Download the latest `Spot.dmg` from [Releases](https://github.com/joelmoss/spot/releases), open it, and drag **Spot.app** to your Applications folder.

### 3. Configure

On first launch, Spot walks you through setup — paste your **Client ID** and connect your Spotify account.

## Build from source

Requires Swift 5.10+.

```sh
git clone https://github.com/joelmoss/spot.git
cd spot
./scripts/build.sh
```

This produces:

- `build/Spot.app` — the signed app bundle
- `build/Spot.dmg` — distributable disk image

For a quick debug build:

```sh
swift build && swift run Spot
```

## How it works

Spot uses the Spotify Web API for all communication — playback control, track polling, and library operations. It polls every second for the current track info (name, artist, artwork URL, player state, volume). Authentication uses OAuth 2.0 with PKCE (no client secret needed).

The window is configured as a borderless, floating panel (`NSWindow.Level.floating`) with `LSUIElement` set to `true` in the Info.plist, so it runs without a Dock icon. A menu bar icon provides access to preferences and quitting the app.

## License

[MIT](LICENSE)
