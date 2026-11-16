# Pin To Top

Picture-in-picture for video calls on your Mac. Pin your FaceTime, Zoom, Meet, or Teams window and a live, view-only copy floats on top of everything else: on every display, in every Space, and over most full-screen apps. Works with any other app window too.

Website: https://bhattaraiabhishek.com.np/apps/pintotop

Typical use: you're on a video call, but you need to work in a full-screen editor or browser. Pin the call window and a small live mirror stays in the corner while you work.

![Pin To Top demo: pin a YouTube window, then switch to full-screen apps and other Spaces while the video keeps playing in a floating panel](docs/demo.gif)

## What it does

- Lists your open app windows (per display, with live thumbnails) from the menu bar or the main window.
- **Pin** a window and it gets mirrored into a small floating panel on each connected display.
- The panel follows you across Spaces and into full-screen app Spaces where macOS allows it.
- **Unpin** from the menu bar or main window, or just close the floating panel, to stop capture.

It is a *mirror*, not a window manager. The original window stays where it is. You can't click through the mirror; use the source app for controls (mute, leave call, and so on).

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (the build script targets `arm64` only for now)
- Xcode Command Line Tools (`xcode-select --install`)

## Install (build from source)

There is no signed download yet. You build it yourself:

```bash
git clone <REPO_URL>
cd PinToTop
./build-app.sh
open "outputs/Pin To Top.app"
```

The build is **ad-hoc signed** and **not notarized**. That's fine on the machine that built it. If you copy the `.app` to another Mac, Gatekeeper will block it, and you'll need to right-click → Open (or remove the quarantine attribute) at your own risk.

### Stable signing (optional, recommended if you rebuild often)

macOS ties the Screen Recording permission to the app's code signature. With ad-hoc signing every rebuild looks like a new app, so you may have to grant permission again. If you have an Apple Development certificate, sign with it:

```bash
CODESIGN_IDENTITY="Apple Development: Your Name (TEAMID)" ./build-app.sh
```

List your identities with `security find-identity -v -p codesigning`.

## Permissions

Pin To Top needs **Screen Recording** permission. That's how macOS lets any app capture another app's window.

- On first launch macOS shows the system prompt. Grant it in **System Settings → Privacy & Security → Screen & System Audio Recording**, then reopen the app.
- The app asks at most once per launch. If you deny it, nothing else is captured and it won't nag you.
- **Video only.** Audio capture is explicitly disabled, and the app never asks for microphone access.
- **Local only.** Frames stay in memory and are drawn to the overlay. Nothing is written to disk or sent over the network.

## How it works

About 1,100 lines of Swift, no dependencies.

| Piece | Implementation |
|---|---|
| Window list | `SCShareableContent` (onscreen only), filtered to normal-layer windows of regular apps, assigned to displays by frame intersection |
| Thumbnails | `SCScreenshotManager.captureImage`, max 2 concurrent captures through a small actor gate |
| Live capture | One `SCStream` per pinned window via `SCContentFilter(desktopIndependentWindow:)`, up to 30 fps, cursor hidden, audio off |
| Overlay | One non-activating `NSPanel` per screen at `.statusBar` level with `.canJoinAllSpaces` + `.fullScreenAuxiliary`, re-raised on Space changes. All panels share one stream. |
| Permission | `CGPreflightScreenCaptureAccess` before every ScreenCaptureKit call, so background refreshes never trigger the system prompt |

[PRD.md](PRD.md) has the full requirements and design notes.

## Known limits

- The source window must stay open and **not minimized**. Minimized windows can't be captured.
- macOS decides which full-screen Spaces accept overlays. Secure surfaces (login window, some protected video, certain system UI) will cover the mirror. No third-party app can override that.
- Apps that use unusual window levels may not show up in the list (the filter is deliberately conservative).
- Apple Silicon only, unsigned, not notarized (see below).
- Early software, tested on a small number of setups. Bug reports with your macOS version and the source app are very welcome.

## Roadmap to a proper release

- [ ] Developer ID signing + hardened runtime
- [ ] Notarization and a downloadable `.dmg` / `.zip`
- [ ] Universal binary (Apple Silicon + Intel)
- [ ] Compatibility matrix (macOS versions × common call/video apps)

## Later

- [ ] **Interactive pin mode** (opt-in): keep the *real* window on top in place so you can click and type into it, alongside the picture-in-picture mirror. Starting point: [iamshakibali/pin-top](https://github.com/iamshakibali/pin-top) (MIT), which puts a click-through overlay over the window and brings the real one forward when clicked. Needs Accessibility permission, so it must stay opt-in.

## Contributing

Issues and PRs are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
