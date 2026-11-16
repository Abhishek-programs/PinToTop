# Pin To Top — Product Requirements Document

**Status:** Local macOS prototype, iterating toward a distributable utility  
**Version:** 0.4  
**Platform:** macOS 14+ (currently built for Apple Silicon)

## Product intent

Pin To Top keeps a live, view-only preview of a user-selected app window visible while the user works elsewhere. The experience should feel like a persistent desktop mini overlay: by default one preview panel opens on the display the pointer is on and can be dragged to any display; with Show on all displays, every connected display gets a copy. The preview stays visible across Spaces, including eligible full-screen app Spaces. The user chooses a source window from the menu bar or the main app.

The app does not move, activate, or control the source app. Call controls remain in the original app.

## Users and primary use case

People who want to watch a video call or other app window while working in a browser, editor, or another full-screen app.

Primary flow:

1. Open the Pin To Top menu bar picker.
2. Select an open app window.
3. Start the mirror.
4. Continue working across displays or Spaces while the preview remains visible where macOS permits it.
5. Unpin from the menu bar or main app, or close the floating panel; closing it unpins and brings back the main app with the same window selected.

## Functional requirements

### Window selection

- **FR-1:** Show a refreshable list of eligible open app windows in the menu bar picker and the main app. The main app refreshes automatically while visible.
- **FR-2:** Each row identifies the app, window title, and approximate size.
- **FR-3:** Exclude Pin To Top’s own windows, Dock, menu bar/control center, notification center, login UI, and other system-owned or non-normal-layer windows.
- **FR-4:** Do not present a full-display capture option in the normal selection flow.
- **FR-5:** Keep the selected window visible in both the menu picker and main app until it disappears or the user changes selection.
- **FR-5a:** Show the source app icon and a live thumbnail preview in each visible main-app window card. Refresh thumbnails periodically without creating a separate persistent stream for every window.
- **FR-5b:** Update the selected-window label immediately on selection and update its title/metadata as the source window changes.
- **FR-5c:** In the main app, group eligible windows under horizontal tabs for each connected physical display. Show a window count on each tab and update the grid when the user changes displays.
- **FR-5d:** Show only windows currently onscreen on the connected displays. Exclude minimized/offscreen windows and accessory/menu-bar-only apps; retain normal application windows, including full-screen app windows.

### Capture and overlay

- **FR-6:** Capture only the explicitly selected window through ScreenCaptureKit.
- **FR-7:** Do not capture system audio. The `SCStreamConfiguration` must keep `capturesAudio` disabled.
- **FR-8:** By default, present a single view-only overlay, opened on the display the pointer is on; the user can drag it to another display. If its display is removed, move it back onto a connected one.
- **FR-8a:** A "Show on all displays" switch (menu bar picker and main app, saved between launches) shows one overlay per connected display instead. Switching while pinned applies immediately and keeps the panel the user is looking at.
- **FR-8b:** A "Launch at login" switch (menu bar picker and main app) registers the app as a login item via `SMAppService.mainApp`. It reflects the live system state, including changes made in System Settings → Login Items. If macOS needs approval, open Login Items settings and say so in the status text.
- **FR-9:** Configure overlays to join all Spaces and eligible full-screen app Spaces, and reassert front ordering after Space/app transitions.
- **FR-10:** Handle source-window removal, stream failure, permission denial, and display changes without crashing; show actionable status text.

### Controls and lifecycle

- **FR-11:** Provide Pin and Unpin in both the menu bar picker and main app.
- **FR-12:** Closing any mirror overlay unpins: it stops the stream, hides all mirror overlays, and opens/raises the main app with the same window still selected so it can be pinned again. Closing the preview must not silently restart the overlay.
- **FR-13:** Stopping capture releases the ScreenCaptureKit stream, frame output, overlay panels, and notification observers.
- **FR-14:** The menu bar picker refreshes the eligible window list when opened and exposes a manual refresh control.

## Privacy and security

- Screen Recording permission is required. Passive inventory and thumbnail refreshes must preflight permission and make no ScreenCaptureKit calls while access is denied. A user-initiated Refresh may request access once per app launch; after denial, suppress further requests until the app is reopened. Do not add an in-app link to System Settings.
- The app captures video only. It must not request microphone permission or capture audio.
- Capture remains local; the prototype must not upload or transmit captured frames.
- The app is view-only. Do not add click-through, accessibility control, keyboard capture, or source-app automation without a separate product decision.
- Screen capture is visibly active while mirroring; the menu and main window must expose the active source and a reliable Unpin action.
- Ad-hoc signing changes the code identity across rebuilds and can invalidate TCC permissions. Development and release builds should use a stable signing identity.

## UX requirements

- Menu bar icon is the primary entry point; the user should not need to open the main window to start or stop a mirror.
- Menu picker is compact, keyboard accessible, and distinguishes the selected window with a checkmark/selection treatment.
- System UI such as Dock and menu bar accessories must not clutter the source-window list.
- Empty, loading, permission-denied, and stream-error states should explain the next action plainly.
- Closing the overlay unpins and brings back the main app with the same window selected.
- One stream per pin, shared by every overlay panel; do not start a separate capture stream per display.

## Technical architecture

- **UI:** SwiftUI `MenuBarExtra` with `.window` style for the window picker; `WindowGroup(id: "main")` for the full app UI.
- **Window inventory:** Preflight Screen Recording access before calling ScreenCaptureKit. When authorized, use `SCShareableContent` with the onscreen-only restriction, retain onscreen normal-layer windows owned by regular apps, assign each window to a display by frame intersection, and exclude known system services and this app. The main picker uses a tab per display.
- **Main-app previews:** `SCScreenshotManager.captureImage` captures periodic single-frame thumbnails for visible window cards; a shared gate limits concurrent preview captures. `NSWorkspace` supplies cached app icons.
- **Capture:** `SCContentFilter(desktopIndependentWindow:)` and a single `SCStream` configured for up to 30 fps, cursor hidden, audio disabled.
- **Frames:** `SCStreamOutput` converts sample buffers through Core Image into shared observable frame state.
- **Overlay:** Non-activating `NSPanel`s: one on the `NSScreen` under the pointer, or one per screen when Show on all displays is on, configured for all Spaces/full-screen eligibility and status-bar window level.
- **Lifecycle:** Main-actor `MirrorModel` owns the stream, frame output, selected source, overlay panels, and observers.
- **Signing:** Local build supports an explicit `CODESIGN_IDENTITY`. Ad-hoc is a fallback only.

## Acceptance criteria

1. Menu bar icon opens the picker and lists app windows without Dock or other system chrome.
1a. Main app shows a tab for each connected display; selecting a tab filters the preview cards to eligible, onscreen windows assigned to that display. Minimized windows and menu-bar-only apps are absent; full-screen app windows remain eligible.
1b. Automatic refreshes never prompt for Screen Recording access. A user-initiated Refresh may invoke the system prompt once per app launch; after denial, another prompt is possible only after reopening the app.
2. A selected window starts one ScreenCaptureKit stream and shows the preview in one overlay on the display the pointer is on, or on every display when Show on all displays is on.
3. Switching Spaces and entering a normal full-screen browser keeps the overlay visible where supported by macOS.
4. Stopping from either control surface stops the stream and closes all overlays.
5. Closing any overlay unpins: capture stops, all overlays hide, and the main window opens with the same window selected.
6. No system audio or microphone capture occurs.
7. Permission denial, source closure, and display changes produce a recoverable user-facing state.

## Known limitations and release gates

- AppKit exposes full-screen auxiliary/join behaviors, but macOS makes the final eligibility decision. No third-party app can guarantee visibility over secure desktop, login UI, protected media, or every system surface.
- Window-level system filtering is intentionally conservative; unusual user app windows may be omitted if they use non-normal window levels.
- The current build script targets arm64 and produces an ad-hoc local app unless a signing identity is supplied.
- Before public distribution: stable Apple Developer signing, hardened runtime review, notarization, universal binary decision, crash/stream recovery, and an explicit macOS compatibility matrix are required.

## Contributor notes

For follow-on implementation work:

1. Read this document and `README.md` before editing code.
2. Preserve the core contract: selected-window-only video, no audio capture, menu bar start/stop, overlays that follow Spaces (one display by default, all displays as an option), and close-to-unpin behavior.
3. Build with `./build-app.sh`; do not treat an ad-hoc signed rebuild as permission-stable.
4. Keep capture/session lifecycle in `MirrorModel`. Avoid duplicating streams per display.
5. If splitting work among agents, assign non-overlapping files and have one integrator review the combined UI, window-management, permission, and lifecycle behavior.
6. Do not claim universal full-screen behavior without reproducing it on the stated macOS version and target app.
