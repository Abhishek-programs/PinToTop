# Floaty Mirror

Floaty Mirror captures a selected app window and keeps a live, view-only mirror visible as a floating overlay across connected displays, Spaces, and eligible full-screen app Spaces. The main app refreshes its window picker automatically and shows live thumbnail previews with app icons.

## Build

```bash
cd ~/Code/PinToTop
./build-app.sh
```

The app bundle is written to `outputs/Pin To Top.app`. To sign with a stable Apple Development identity, pass its exact keychain identity name:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./build-app.sh
```

Ad-hoc signing is suitable for local experiments, but macOS may treat each rebuilt binary as a new Screen Recording client. A stable signing identity is required for a reliable development/release permission flow. Distribution also requires a Developer ID signing and notarization workflow.

## Use

1. Launch Floaty Mirror. Use its menu bar icon or main window to choose an open app window.
2. Choose **Start Mirror**. Floaty Mirror requests Screen Recording access; it captures video only and does not capture system audio.
3. The mirror appears on each connected display. Use **Stop Mirror** in the menu bar or main window to end capture.
4. In the main app, select a preview card to see the current window name and live thumbnail. The list refreshes automatically; use Refresh for an immediate update.
5. Closing a mirror hides all overlays and opens the main window with **Stop Mirror** focused.

## Current platform limits

- The source app window must remain open and unminimized.
- The mirror is view-only; interact with the source app window for call controls.
- macOS only permits third-party overlays in eligible full-screen Spaces. Secure and protected system surfaces can cover app windows.
- The app is currently a local proof of concept. Release signing, notarization, universal architecture, an app icon, and a broad macOS/app compatibility pass remain before public distribution.

See [PRD.md](PRD.md) for requirements, architecture, acceptance criteria, and AI handoff notes.
