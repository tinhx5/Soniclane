enum MediaUrlType { directMedia, streamItem, streamPlaylist }

class MediaUrlMatch {
  final MediaUrlType type;
  final String id;
  final String originalUrl;
  final bool isDirectVideo;

  const MediaUrlMatch({
    required this.type,
    required this.id,
    required this.originalUrl,
    this.isDirectVideo = false,
  });
}

/// Parses direct audio/video media URLs (.mp3, .flac, .mp4, .m3u8, etc.)
/// and generic user-configured media server item/playlist links.
class UrlParser {
  static final RegExp _directMediaExtRegex = RegExp(
    r'\.(mp3|flac|wav|m4a|aac|ogg|opus|mp4|mkv|webm|m3u8|pls)(?:\?|#|$)',
    caseSensitive: false,
  );
  static final RegExp _videoExtRegex = RegExp(
    r'\.(mp4|mkv|webm|m3u8)(?:\?|#|$)',
    caseSensitive: false,
  );
  static final RegExp _playlistQueryRegex = RegExp(
    r'[?&]list=([a-zA-Z0-9_-]{4,})',
  );
  static final RegExp _itemPathOrQueryRegex = RegExp(
    r'(?:[?&]v=|\/watch\/|\/v\/|\/embed\/)([a-zA-Z0-9_-]{6,})',
  );

  static MediaUrlMatch? parse(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return null;
    }

    if (_directMediaExtRegex.hasMatch(trimmed)) {
      return MediaUrlMatch(
        type: MediaUrlType.directMedia,
        id: trimmed,
        originalUrl: trimmed,
        isDirectVideo: _videoExtRegex.hasMatch(trimmed),
      );
    }

    final playlistMatch = _playlistQueryRegex.firstMatch(trimmed);
    final itemMatch = _itemPathOrQueryRegex.firstMatch(trimmed);

    if (playlistMatch != null && trimmed.contains('/playlist')) {
      return MediaUrlMatch(
        type: MediaUrlType.streamPlaylist,
        id: playlistMatch.group(1)!,
        originalUrl: trimmed,
      );
    }

    if (itemMatch != null) {
      return MediaUrlMatch(
        type: MediaUrlType.streamItem,
        id: itemMatch.group(1)!,
        originalUrl: trimmed,
      );
    }

    if (playlistMatch != null) {
      return MediaUrlMatch(
        type: MediaUrlType.streamPlaylist,
        id: playlistMatch.group(1)!,
        originalUrl: trimmed,
      );
    }

    return null;
  }

  static bool isMediaUrl(String input) => parse(input) != null;
}
