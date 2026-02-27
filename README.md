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
- Graceful fallback when Spotify isn't running

## Requirements

- macOS 14.0+
- Spotify desktop app
- Swift 5.10+

## Install

Download the latest `Spot.dmg` from [Releases](https://github.com/joelmoss/spot/releases), open it, and drag **Spot.app** to your Applications folder.

On first launch, macOS will ask for permission to control Spotify via AppleScript -- click Allow.

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

Spot communicates with Spotify using AppleScript via `NSAppleScript`. It polls every second for the current track info (name, artist, artwork URL, player state, volume). No API keys or authentication required.

The window is configured as a borderless, floating panel (`NSWindow.Level.floating`) with `LSUIElement` set to `true` in the Info.plist, so it runs without a Dock icon.

## License

[MIT](LICENSE)
