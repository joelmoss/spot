# Spot

A tiny, native macOS mini player for Spotify. Floats above all windows and shows what's currently playing.

## Features

- Album artwork, track title, and artist name
- Play/pause, next, and previous track controls
- Volume slider
- Always-on-top floating window with no title bar
- Translucent material background
- Draggable by clicking anywhere on the window
- Close button appears on hover
- Like/unlike tracks from the player
- Graceful fallback when there's no active playback

## Requirements

- macOS 14.0+
- Spotify Premium account (required for playback control)
- Swift 5.10+

## Install

Download the latest `Spot.dmg` from [Releases](https://github.com/joelmoss/spot/releases), open it, and drag **Spot.app** to your Applications folder.

On first launch, open Settings and connect your Spotify account.

## Build from source

```sh
git clone https://github.com/joelmoss/spot.git
cd spot
./scripts/build.sh
```

This produces:

- `build/Spot.app` -- the app bundle
- `build/Spot.dmg` -- distributable disk image

For a quick debug build:

```sh
swift build
swift run Spot
```

## How it works

Spot uses the Spotify Web API for all communication -- playback control, track polling, and library operations. It polls every second for the current track info (name, artist, artwork URL, player state, volume). Authentication uses OAuth 2.0 with PKCE (no client secret needed).

The window is configured as a borderless, floating panel (`NSWindow.Level.floating`) with `LSUIElement` set to `true` in the Info.plist, so it runs without a Dock icon.

## License

[MIT](LICENSE)
