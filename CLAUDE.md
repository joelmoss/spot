# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spot is a native macOS mini player for Spotify, built with SwiftUI. It runs as a floating, always-on-top borderless window (LSUIElement — no Dock icon). Requires macOS 14.0+ (Sonoma).

## Build Commands

```bash
# Debug build and run
swift build && swift run Spot

# Release build → creates build/Spot.app and build/Spot.dmg
./scripts/build.sh
```

No external dependencies — uses only SwiftUI, AppKit, Foundation, CryptoKit, and URLSession.

## Version Control

This repo uses Jujutsu (`.jj` directory). Use `jj` commands instead of `git`.

## Architecture

**SpotApp.swift** — Entry point. Configures NSWindow (floating, borderless, draggable). Two scenes: main player window and settings window.

**SpotifyController.swift** — `@Observable` state manager. Polls Spotify every 1 second via AppleScript for track info, playback state, and volume. Exposes playback control methods (play/pause, next, previous, volume). Bridges to SpotifyAuth for like/unlike via Web API.

**SpotifyAuth.swift** — OAuth 2.0 PKCE flow against Spotify's API. Manages token lifecycle (store in UserDefaults, auto-refresh). Handles `spot-app://callback` URL scheme redirects. Provides Web API calls for track library operations (`/me/tracks`).

**MiniPlayerView.swift** — Main UI. Two layout modes controlled by `@AppStorage("showControls")`: horizontal (320×110) and vertical (220×310). Shows artwork, track info, volume slider, playback controls, and like button (when authenticated).

**SettingsView.swift** — Preferences panel. Layout toggle and Spotify account connection status/controls.

## Key Patterns

- **Spotify control uses two mechanisms**: AppleScript for local playback control (no auth needed), Web API for user library operations (requires OAuth)
- **`@Observable` macro** (Swift 5.10+) for reactive state in SpotifyController and SpotifyAuth
- **App bundle config** is in `Info.plist` — includes URL scheme registration (`spot-app`), AppleScript usage description, and LSUIElement flag
- **Bundle ID**: `com.joelmoss.spot`
