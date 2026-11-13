# SONICLANE — MASTER DEVELOPMENT TASK LIST
*Nền tảng: Flutter Multiplatform (iOS • Android • Windows Desktop)*
*Tham chiếu thiết kế: `d:\DriveFlow\Design\` + Design System (`Space Grotesk` / `Plus Jakarta Sans`, OLED `#0D0F12`, `#FF0033`, `#3B82F6`, `#008CA7`/`#00D2FF`)*

---

## PHASE 0: Khởi tạo Dự án Flutter & Design System Foundation
- [x] **Task 0.1 — Khởi tạo Project Flutter Đa Nền Tảng**: Tạo cấu trúc `ios`, `android`, `windows` tại `d:\DriveFlow\`. Cấu hình `pubspec.yaml` (`flutter_riverpod`, `just_audio`, `just_audio_windows`, `audio_service`, `media_kit`, `media_kit_video`, `dio`, `sqflite_common_ffi`, `shelf`, `shelf_router`, `file_picker`, `geolocator`, `flutter_svg`, `google_fonts`, `window_manager`, `qr_flutter`, `wakelock_plus`, `in_app_purchase`, `speech_to_text`).
- [x] **Task 0.2 — Assets & Typography**: Đăng ký `assets/logo/logo.svg` và widget `SonicLogo`, cấu hình font `Space Grotesk` (Headline/Label) & `Plus Jakarta Sans` (Body/Title) kèm offline fallback.
- [x] **Task 0.3 — Design System (`lib/core/theme/sonic_tokens.dart` & `app_theme.dart`)**: Chuẩn hóa màu sắc, kích thước chạm $\ge 56\text{dp}$, nút Play chính `72dp–80dp`, Photonic Glow.
- [x] **Task 0.4 — Adaptive Shell (`lib/shared/widgets/cockpit_shell.dart`)**: Mobile Portrait (Bottom Nav + Floating Mini-Player) & Car/Tablet/Windows (`>= 700px` Left Navigation Rail + Docked Bottom Mini-Player + Phím tắt Media bàn phím).

---

## PHASE 1: Core Data, Local DB & 3-Tier Streaming Engine
- [x] **Task 1.1 — Cross-Platform SQLite (`database_service.dart`)**: Cấu hình `sqflite_common_ffi` chạy đa nền tảng (`playback_history`, `playlists`, `playlist_items`, `liked_tracks`, `recent_searches`, `cached_offline_tracks`).
- [x] **Task 1.2 — Bộ Bóc Tách 3 Tầng (`stream_resolver.dart`)**: Tầng 1 Invidious (Ping Latency + Rotator) $\to$ Tầng 2 Piped API $\to$ Tầng 3 Direct InnerTube (`ANDROID_MUSIC` payload).
- [x] **Task 1.3 — Smart URL Parser & Clipboard Watcher (`url_parser.dart` & `clipboardBannerProvider`)**: Regex bóc tách `watch?v=`, `youtu.be/`, `shorts/`, `playlist?list=`, tự động kiểm tra Clipboard khi mở/resume app.
- [x] **Task 1.4 — Bộ Quét Lưu Trữ Offline & USB (`storage_scanner.dart`)**: Quét ổ đĩa ngoài Windows (`E:`–`J:`), Android OTG (`/storage/`), bộ nhớ máy; tự lọc bỏ thư mục Camera hành trình (`DCIM`, `DVR`, `Dashcam`).
- [x] **Task 1.5 — Wi-Fi Web Transfer Server (`wifi_transfer_server.dart`)**: Mini HTTP Server cổng `8080` với trang HTML kéo-thả nhận file trực tiếp qua Wi-Fi.
- [x] **Task 1.6 — Cloud Drive & Offline Downloader (`cloud_drive_service.dart`, `offline_download_service.dart`)**: Stream/tải file từ Google Drive share URL hoặc thư mục API Key; tải 1-tap cả Playlist YouTube về `OfflineCache/` để nghe 4G-Free.

---

## PHASE 2: Core Audio/Video Playback, Auto-Queue & Vehicle Sensors
- [x] **Task 2.1 — Unified Audio/Video Engine (`sonic_audio_engine.dart`)**: `media_kit` + `audio_service` (`SonicAudioHandler`) ưu tiên phát file offline cache nếu đã tải, phát liên hoàn URL mạng + file nội bộ, lưu vị trí nghe dở định kỳ 5 giây.
- [x] **Task 2.2 — Dynamic Auto-Queue & Steering Wheel Controls**: Tự nạp `relatedTracks` cho nút Next vô lăng; nút Previous tua đầu bài nếu `> 3s`, quay lại bài cũ nếu `<= 3s`; Smart-Skip bài online khi mất mạng.
- [x] **Task 2.3 — Video Mode Sync & GPS Parked Detector (`parked_detector.dart`)**: Đồng bộ mili-giây khi gạt `[ Audio ⇄ Video ]` kèm `WakelockPlus`; đo vận tốc GPS `0 km/h > 15s` (`P-GEAR • VIDEO READY`) và `> 5 km/h` lockout.
- [x] **Task 2.4 — Real-Time Audio DSP (`libmpv` `af`) & Sleep Timer**: Bộ lọc EQ 10-band thật + `dynaudnorm` ReplayGain truyền thẳng xuống `NativePlayer.setProperty('af', ...)`, Playback Speed (`0.75x–2.0x`), Sleep Timer (`15m–60m`).
- [x] **Task 2.5 — Voice Search (`voice_search_service.dart`)**: Tích hợp `speech_to_text` đa nền tảng (iOS, Android, Windows) trực tiếp vào Voice HUD Drawer trên `SearchScreen`.

---

## PHASE 3: UI/UX — 4 Màn Hình Chính (Theo Chuẩn Stitch `d:\DriveFlow\Design\`)
- [x] **Task 3.1 — Home Screen (`lib/features/home/home_screen.dart`)**: Resume Hero Card (`Resumes at mm:ss`), Listen Again (`14x`), Blended Filter Chips (`All Blended`, `💾 In-Car USB`, ...), Smart Recommendations 70/30, Dynamic Clipboard Link Banner.
- [x] **Task 3.2 — Search Screen (`lib/features/search/search_screen.dart`)**: Thanh tìm kiếm + Paste Link + Voice Mic (`speech_to_text`), Voice HUD Listening Drawer & Shortcuts, Source Filter Chips, Recent Searches, Driving Mood Channels, Live Hybrid Search Results.
- [x] **Task 3.3 — Library Screen (`lib/features/library/library_screen.dart`)**: Hybrid Playlists (4-grid cover + huy hiệu `🌐 YouTube` / `💾 USB FLAC` / `📱 Local`), Quick Access (`Liked Songs`, `Offline Files`), Hardware USB Card, Device Storage Card, Wi-Fi Drop Card (`:8080`), Google Drive Cloud Card.
- [x] **Task 3.4 — Now Playing Screen (`lib/features/now_playing/now_playing_screen.dart`)**: Responsive Mobile + Split Widescreen (58/42), công tắc `[ AUDIO | VIDEO ]`, Visualizer, Scrubber, Transport cluster (`±15s`, `Prev/Next`, `80dp` Play/Pause), Up Next Queue (`PLAYLIST` / `HABIT AI` + `Auto-Flow: Driving Habits` + `SMART SHUFFLE` + `SAVE MIX`).

---

## PHASE 4: Các Màn Hình & Modal Tự Suy Theo Design Systems
- [x] **Task 4.1 — Settings Screen** (`lib/features/settings/settings_screen.dart`)
- [x] **Task 4.2 — Safety Disclaimer Modal** (`lib/features/overlays/safety_modal.dart`)
- [x] **Task 4.3 — Playlist Detail Screen** (`lib/features/library/playlist_detail_screen.dart` — kèm nút `Save All Offline` & tiến trình tải từng bài)
- [x] **Task 4.4 — Hardware, USB & Offline Downloads Browsers** (`lib/features/library/usb_browser_screen.dart`, `offline_downloads_screen.dart`)
- [x] **Task 4.5 — Create / Add / Import / Cloud Drive Modals** (`lib/features/overlays/playlist_modals.dart`, `cloud_drive_modal.dart`)
- [x] **Task 4.6 — Wi-Fi Transfer Modal + QR Code** (`lib/features/overlays/wifi_transfer_modal.dart`)
- [x] **Task 4.7 — 10-Band EQ DSP & Sleep Timer Sheets** (`lib/features/overlays/equalizer_modal.dart`)
- [x] **Task 4.8 — Playback History Screen** (`lib/features/home/history_screen.dart`)
- [x] **Task 4.9 — Driver Profile & Soniclane Pro Billing (`in_app_purchase`)** (`lib/features/overlays/pro_profile_modal.dart`, `billing_service.dart`)

---

## PHASE 5: Cầu Nối Ô Tô, Windows Shell & Kiểm Thử
- [x] **Task 5.1 — iOS & CarPlay Config**: `ios/Runner/Info.plist` (`UIBackgroundModes: audio`, Mic/Speech, Location, Local Network, CarPlay scene), `ios/Runner/CarPlaySceneDelegate.swift` (`Explore` + `Library` drill-down kèm retry `attachChannelWithRetry` khi khởi động nền), và toàn bộ 15 file icon trong `Assets.xcassets/AppIcon.appiconset/` render từ `assets/logo/logo.svg`.
- [x] **Task 5.2 — Android & Android Auto Config**: `AndroidManifest.xml` (cùng quyền `RECORD_AUDIO`), `MainActivity.kt` (`AudioServiceActivity`), `automotive_app_desc.xml`, `SonicAudioHandler` (`getChildren`, `search`, `playFromMediaId`), `minSdk = 23`, và launcher icons `mipmap-mdpi` đến `mipmap-xxxhdpi` từ `assets/logo/logo.svg`.
- [x] **Task 5.3 — Windows Desktop Shell**: `window_manager` (`1280x800`), `Runner.rc` branding, `windows/runner/resources/app_icon.ico` (16px–256px) từ `assets/logo/logo.svg`, và Keyboard Media Shortcuts.
- [x] **Task 5.4 — Unit & Widget Tests**: `test/services_test.dart`, `test/widget_test.dart`, `test/wifi_server_test.dart` (**14/14 pass**, `flutter analyze` **0 issues**).
- [ ] **Task 5.5 — Thực địa Build & Kiểm tra Sản phẩm trên Thiết bị Thật**:
  - Windows `.exe`: Bật **Developer Mode** trên Windows (`start ms-settings:developers`) rồi chạy `D:\tools\flutter\bin\flutter.bat run -d windows` hoặc `build windows`.
  - Android `.apk` / `.aab`: Cấu hình JDK (`JAVA_HOME`) rồi chạy `flutter build apk` / `flutter build appbundle`.
  - iOS `.ipa`: Build trên macOS + Xcode (`flutter build ipa` + CarPlay Entitlement).
