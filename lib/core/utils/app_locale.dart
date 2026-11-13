import 'dart:ui';
import 'package:flutter/widgets.dart';

/// Lightweight localization helper that automatically detects the device's system language
/// (e.g. Vietnamese 'vi' vs English/Default).
class AppLocale {
  AppLocale._();

  /// Returns true if the device or context locale language is Vietnamese ('vi').
  static bool isVietnamese([BuildContext? context]) {
    final code = context != null
        ? Localizations.maybeLocaleOf(context)?.languageCode
        : null;
    return (code ?? PlatformDispatcher.instance.locale.languageCode)
            .toLowerCase() ==
        'vi';
  }

  // --- Follow / Unfollow ---
  static String follow([BuildContext? context]) =>
      isVietnamese(context) ? 'Theo dõi' : 'Follow';

  static String following([BuildContext? context]) =>
      isVietnamese(context) ? 'Đang theo dõi' : 'Following';

  static String followedChannels([BuildContext? context]) =>
      isVietnamese(context) ? 'Kênh đang theo dõi' : 'Followed Channels';

  static String followedChannelsCount(int count, [BuildContext? context]) =>
      isVietnamese(context)
          ? 'Kênh đang theo dõi ($count)'
          : 'Followed Channels ($count)';

  static String followedBadge([BuildContext? context]) =>
      isVietnamese(context) ? '⭐ Đang theo dõi' : '⭐ Following';

  static String followedCategory([BuildContext? context]) =>
      isVietnamese(context) ? '⭐ Kênh theo dõi' : '⭐ Followed Channels';

  static String followedChannelsShelfTitle([BuildContext? context]) =>
      isVietnamese(context) ? 'Kênh bạn theo dõi' : 'Channels You Follow';

  static String followActionHint([BuildContext? context]) =>
      isVietnamese(context)
          ? 'Bấm "+ Theo dõi" ở bài hát bất kỳ để lưu kênh vào Thư viện'
          : 'Tap "+ Follow" on any track to save the channel to your Library';

  static String followedSuccess(String name, [BuildContext? context]) =>
      isVietnamese(context)
          ? 'Đã theo dõi "$name" — ưu tiên hiển thị trên Trang chủ & Tìm kiếm'
          : 'Followed "$name" — prioritized on Home & Search';

  static String unfollowedSuccess(String name, [BuildContext? context]) =>
      isVietnamese(context)
          ? 'Đã hủy theo dõi "$name"'
          : 'Unfollowed "$name"';

  // --- Channel Actions ---
  static String playAll([BuildContext? context]) =>
      isVietnamese(context) ? 'Phát tất cả' : 'Play All';

  static String songsCount(int count, [BuildContext? context]) =>
      isVietnamese(context) ? '$count bài hát' : '$count songs';

  static String playlistsCount(int count, [BuildContext? context]) =>
      isVietnamese(context) ? '$count danh sách phát' : '$count playlists';

  // --- Offline & Downloads ---
  static String downloadOffline([BuildContext? context]) =>
      isVietnamese(context) ? 'Tải về ngoại tuyến' : 'Download Offline';

  static String downloadedOffline([BuildContext? context]) =>
      isVietnamese(context) ? 'Đã tải ngoại tuyến' : 'Downloaded';

  static String noOfflineTracks([BuildContext? context]) =>
      isVietnamese(context)
          ? 'Chưa có bài hát ngoại tuyến'
          : 'No offline tracks yet';
}
