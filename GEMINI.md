# Soniclane Development Rules & Architectural Guidelines

## 1. Permanent Video Player & Streaming Architecture (STRICTLY LOCKED)
> [!IMPORTANT]
> **DO NOT MODIFY, REFACTOR, OR REPLACE THE VIDEO PLAYER / STREAM RESOLUTION MECHANISM WHEN WORKING ON UI OR OTHER FEATURES.**
> This implementation has been thoroughly tested, verified, and locked in commit `4bb96bf` / `667779c`.

### The Core Video Engine
- **Component**: `_EmbeddedWebVideoStage` in `lib/features/now_playing/now_playing_screen.dart`.
- **Platform Strategy**: On mobile platforms (`_isMobileDevice && isCustomStream`), online video is ALWAYS rendered directly via this instant Cốc Cốc-style Web Player.
- **WebView Setup**:
  - Direct watch URL loading: `Uri.parse('$_kWebWatchBase${widget.videoId}')`.
  - Android configuration: MUST use `displayWithHybridComposition: true` via `AndroidWebViewWidgetCreationParams`.
  - CSS cleaner injection (`#sl-clean-style`): hides topbar, headers, comments, ads, and scales the HTML5 video element to fill the exact container with a pure black background.
  - Auto-play & un-mute loop: monitors the HTML5 video tag, auto-skips ads, dismisses consent dialogs, and sets `video.muted = false; video.volume = 1.0;`.
  - Audio focus coordination: In `SonicAudioEngine` (`setVideoMode` and `playTrack`), background native audio is paused when mobile online video is active to prevent sound collision and buffering spinners.
- **What is NOT allowed**:
  - DO NOT change this back to iframe embed (`loadHtmlString` / `nocookie` / `embed` URL) — it causes Google `Error code: 152-4`.
  - DO NOT force native MPV hardware player (`canRenderNativeVideo` / `media_kit_video`) on online mobile video streams — it causes the infinite `Loading video stream...` spinner due to CDN rate limits and signature restrictions.

---

## 2. Strict Trademark Compliance
> [!CAUTION]
> ZERO occurrences of the following trademarks (case-insensitive) anywhere in `lib/` or `test/`:
> - `youtube`
> - `spotify`
> - `soundcloud`
>
> Always verify via: `git grep -i -E "youtube|spotify|soundcloud" lib/ test/` (must return exit code 1 / 0 matches).

---

## 3. UI Modification Boundaries
When modifying UI layouts, styling, screens, or controls:
1. Touch ONLY the layout, widgets, styling, and visual elements.
2. Keep the playback logic, stream resolving, and webview container callbacks intact.
3. Always verify with automated tests: `& "D:\tools\flutter\bin\flutter.bat" test test/widget_test.dart`.
