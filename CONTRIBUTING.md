# Contributing to Pin To Top

Thanks for taking a look. This is a small project. Keep changes focused and you'll get a quick review.

## Bug reports

Use the **Bug report** issue template and include:

- macOS version (`sw_vers -productVersion`) and Mac model (Apple Silicon or Intel)
- The **source app** you pinned (Zoom, Meet in Chrome, FaceTime, …) and whether it was full screen
- Your display setup (number of displays, Spaces, Stage Manager on or off)
- What you expected and what happened. A screen recording helps a lot.

Most overlay and full-screen issues depend on the macOS version and the source app, so these details matter.

## Development

```bash
./build-app.sh                    # ad-hoc signed build → outputs/Pin To Top.app
open "outputs/Pin To Top.app"
```

- No dependencies, no Xcode project. `build-app.sh` calls `swiftc` directly. `Package.swift` is there for editor/SourceKit support.
- If you rebuild often, sign with a stable identity (`CODESIGN_IDENTITY=...`, see README) so macOS doesn't keep asking for Screen Recording permission again.
- Code layout:
  - `Sources/PinToTop/Capture/`: ScreenCaptureKit stream, thumbnails, permission checks
  - `Sources/PinToTop/Model/`: `MirrorModel` (owns all capture/overlay lifecycle) and window inventory
  - `Sources/PinToTop/Overlay/`: floating `NSPanel`s
  - `Sources/PinToTop/UI/`: SwiftUI menu bar picker and main window

## Ground rules (please don't break these)

These are product decisions, not accidents. Open an issue first if you want to change one.

1. **Selected window only.** Never capture the full display.
2. **No audio.** `capturesAudio` stays `false`; never request microphone access.
3. **Local only.** No network calls, no writing frames to disk.
4. **View-only.** No click-through, Accessibility control, or automating the source app. (An opt-in interactive pin mode is planned; see README → Later. Open an issue before starting on it.)
5. **One stream.** All display overlays share a single `SCStream`.
6. **No surprise permission prompts.** Preflight before any ScreenCaptureKit call; background refreshes must never trigger the system dialog.

## Pull requests

- One logical change per PR, with a short description of what you tested (macOS version, source app, display setup).
- Keep the existing style: small types, `@MainActor` for UI and lifecycle, no third-party dependencies.
- For UI changes, include a screenshot or short clip.

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).
