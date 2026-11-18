import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/sonic_providers.dart';
import '../../core/services/media_source_service.dart';
import '../../core/theme/sonic_tokens.dart';

class AddSourceModal extends ConsumerStatefulWidget {
  final MediaSourceType? initialSource;
  const AddSourceModal({super.key, this.initialSource});

  static Future<void> show(BuildContext context, {MediaSourceType? initialSource}) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    if (isWide) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
            child: AddSourceModal(initialSource: initialSource),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddSourceModal(initialSource: initialSource),
      ),
    );
  }

  @override
  ConsumerState<AddSourceModal> createState() => _AddSourceModalState();
}

class _AddSourceModalState extends ConsumerState<AddSourceModal> {
  MediaSourceType? _activeSubScreen;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _activeSubScreen = widget.initialSource;
  }

  void _goTo(MediaSourceType type) {
    setState(() {
      _showHelp = false;
      _activeSubScreen = type;
    });
  }

  void _goBack() {
    setState(() {
      _showHelp = false;
      _activeSubScreen = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141721) : const Color(0xFFF2F2F7);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _buildCurrentContent(context, isDark),
        ),
      ),
    );
  }

  Widget _buildCurrentContent(BuildContext context, bool isDark) {
    if (_showHelp) {
      return _HelpView(
        key: const ValueKey('help_view'),
        isDark: isDark,
        onBack: _goBack,
      );
    }

    if (_activeSubScreen == null) {
      return _SourceListView(
        key: const ValueKey('list_view'),
        isDark: isDark,
        onSelect: _goTo,
        onHelp: () => setState(() => _showHelp = true),
        onClose: () => Navigator.of(context).pop(),
      );
    }

    switch (_activeSubScreen!) {
      case MediaSourceType.m3u:
        return _M3uConnectView(
          key: const ValueKey('m3u_view'),
          isDark: isDark,
          onBack: _goBack,
          onSuccess: () {
            ref.read(libraryProvider.notifier).refresh();
            Navigator.of(context).pop();
          },
          onHelp: () => setState(() => _showHelp = true),
        );
      case MediaSourceType.jellyfin:
        return _JellyfinConnectView(
          key: const ValueKey('jf_view'),
          isDark: isDark,
          onBack: _goBack,
          onSuccess: () {
            ref.read(libraryProvider.notifier).refresh();
            Navigator.of(context).pop();
          },
        );
      case MediaSourceType.emby:
        return _EmbyConnectView(
          key: const ValueKey('emby_view'),
          isDark: isDark,
          onBack: _goBack,
          onSuccess: () {
            ref.read(libraryProvider.notifier).refresh();
            Navigator.of(context).pop();
          },
        );
      case MediaSourceType.xtream:
        return _XtreamConnectView(
          key: const ValueKey('xtream_view'),
          isDark: isDark,
          onBack: _goBack,
          onSuccess: () {
            ref.read(libraryProvider.notifier).refresh();
            Navigator.of(context).pop();
          },
        );
      case MediaSourceType.plex:
        return _PlexConnectView(
          key: const ValueKey('plex_view'),
          isDark: isDark,
          onBack: _goBack,
          onSuccess: () {
            ref.read(libraryProvider.notifier).refresh();
            Navigator.of(context).pop();
          },
        );
    }
  }
}

// ==========================================
// 1. SOURCE LIST VIEW (MATCHES IMAGE 5)
// ==========================================
class _SourceListView extends StatelessWidget {
  final bool isDark;
  final ValueChanged<MediaSourceType> onSelect;
  final VoidCallback onHelp;
  final VoidCallback onClose;

  const _SourceListView({
    super.key,
    required this.isDark,
    required this.onSelect,
    required this.onHelp,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E2333) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;
    final dividerColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Sheet Grabber Handle
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 12),
          // Top Header Row: Close (X) | Title "Add a Source"
          Row(
            children: [
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 20, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Expanded(
                child: Text(
                  'Add a Source',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 36), // Balance
            ],
          ),
          const SizedBox(height: 20),
          // Grouped Card containing 5 items
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  _SourceRow(
                    icon: _buildM3uIcon(),
                    title: 'M3U',
                    subtitle: 'Playlist link or M3U content',
                    isDark: isDark,
                    onTap: () => onSelect(MediaSourceType.m3u),
                  ),
                  Divider(height: 1, indent: 64, color: dividerColor),
                  _SourceRow(
                    icon: _buildJellyfinIcon(),
                    title: 'Jellyfin',
                    subtitle: 'Connect your media server',
                    isDark: isDark,
                    onTap: () => onSelect(MediaSourceType.jellyfin),
                  ),
                  Divider(height: 1, indent: 64, color: dividerColor),
                  _SourceRow(
                    icon: _buildEmbyIcon(),
                    title: 'Emby',
                    subtitle: 'Connect your media server',
                    isDark: isDark,
                    onTap: () => onSelect(MediaSourceType.emby),
                  ),
                  Divider(height: 1, indent: 64, color: dividerColor),
                  _SourceRow(
                    icon: _buildXtreamIcon(),
                    title: 'Xtream',
                    subtitle: 'Server address, username and password',
                    isDark: isDark,
                    onTap: () => onSelect(MediaSourceType.xtream),
                  ),
                  Divider(height: 1, indent: 64, color: dividerColor),
                  _SourceRow(
                    icon: _buildPlexIcon(),
                    title: 'Plex',
                    subtitle: 'Sign in with your Plex account',
                    isDark: isDark,
                    onTap: () => onSelect(MediaSourceType.plex),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Get Help Row
          InkWell(
            onTap: onHelp,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Text(
                    'Get Help',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Soniclane does not provide, host, or endorse any content. Add only sources you own or have the legal right to access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildM3uIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF6B7280).withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.3)),
      ),
      child: const Icon(Icons.list_alt_rounded, size: 22, color: Color(0xFF6B7280)),
    );
  }

  Widget _buildJellyfinIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.change_history_rounded, size: 22, color: Colors.white),
    );
  }

  Widget _buildEmbyIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
    );
  }

  Widget _buildXtreamIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.live_tv_rounded, size: 20, color: Colors.white),
    );
  }

  Widget _buildPlexIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.double_arrow_rounded, size: 20, color: Color(0xFFE5A00D)),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. M3U CONNECT VIEW (MATCHES IMAGE 4)
// ==========================================
class _M3uConnectView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSuccess;
  final VoidCallback onHelp;

  const _M3uConnectView({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSuccess,
    required this.onHelp,
  });

  @override
  State<_M3uConnectView> createState() => _M3uConnectViewState();
}

class _M3uConnectViewState extends State<_M3uConnectView> {
  final _inputCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await MediaSourceService.instance.connectM3u(input: text);
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(res.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _inputCtrl.text = data.text!;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E2333) : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : Colors.black87;
    final textSecondary = widget.isDark ? Colors.white54 : Colors.black45;
    final hasContent = _inputCtrl.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grabber
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Top Nav Bar: < | M3U | Add
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: widget.onBack,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: widget.isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Text(
                'M3U',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              ElevatedButton(
                onPressed: (hasContent && !_isLoading) ? _handleSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: widget.isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                  disabledForegroundColor: widget.isDark ? Colors.white30 : Colors.black26,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Text Input Box matching Image 4
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _inputCtrl,
                  maxLines: 5,
                  minLines: 4,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 14, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Paste a link or a whole config',
                    hintStyle: TextStyle(
                      color: widget.isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Paste from clipboard',
                      icon: const Icon(Icons.paste_rounded, size: 20),
                      color: widget.isDark ? Colors.white54 : Colors.black45,
                      onPressed: _pasteFromClipboard,
                    ),
                    IconButton(
                      tooltip: 'Scan QR / Config',
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      color: widget.isDark ? Colors.white54 : Colors.black45,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Paste clipboard link or enter M3U URL directly.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            Text(_errorMsg!,
                style: const TextStyle(color: SonicTokens.errorRed, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          // Help text matching Image 4
          RichText(
            textAlign: TextAlign.left,
            text: TextSpan(
              style: TextStyle(fontSize: 12, height: 1.4, color: textSecondary),
              children: [
                const TextSpan(
                  text: 'Paste a subscription link, config file, or M3U content — or tap the scan icon at the bottom right. ',
                ),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: widget.onHelp,
                    child: const Text(
                      'What is a source?',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Legal disclaimer matching Image 4
          Text(
            'Soniclane does not provide, host, or endorse any content. Add only sources you own or have the legal right to access.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. JELLYFIN CONNECT VIEW (MATCHES IMAGE 3)
// ==========================================
class _JellyfinConnectView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _JellyfinConnectView({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_JellyfinConnectView> createState() => _JellyfinConnectViewState();
}

class _JellyfinConnectViewState extends State<_JellyfinConnectView> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final s = _serverCtrl.text.trim();
    final u = _userCtrl.text.trim();
    if (s.isEmpty || u.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await MediaSourceService.instance.connectJellyfin(
      serverUrl: s,
      username: u,
      password: _passCtrl.text,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8B5CF6),
          content: Text(res.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildServerForm(
      title: 'Connect to Jellyfin',
      titleIcon: Icons.change_history_rounded,
      titleIconColor: const Color(0xFF8B5CF6),
      serverPlaceholder: 'http://192.168.1.8:8096',
      userPlaceholder: 'Must be filled in',
      passPlaceholder: 'Skip if not needed',
      serverCtrl: _serverCtrl,
      userCtrl: _userCtrl,
      passCtrl: _passCtrl,
      obscurePass: _obscurePass,
      isLoading: _isLoading,
      errorMsg: _errorMsg,
      isDark: widget.isDark,
      onBack: widget.onBack,
      onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
      onConnect: _handleConnect,
      canConnect: _serverCtrl.text.trim().isNotEmpty && _userCtrl.text.trim().isNotEmpty,
    );
  }
}

// ==========================================
// 4. EMBY CONNECT VIEW (MATCHES IMAGE 2)
// ==========================================
class _EmbyConnectView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _EmbyConnectView({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_EmbyConnectView> createState() => _EmbyConnectViewState();
}

class _EmbyConnectViewState extends State<_EmbyConnectView> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final s = _serverCtrl.text.trim();
    final u = _userCtrl.text.trim();
    if (s.isEmpty || u.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await MediaSourceService.instance.connectEmby(
      serverUrl: s,
      username: u,
      password: _passCtrl.text,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(res.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildServerForm(
      title: 'Connect to Emby',
      titleIcon: Icons.play_arrow_rounded,
      titleIconColor: const Color(0xFF10B981),
      serverPlaceholder: 'http://192.168.1.8:8096',
      userPlaceholder: 'Must be filled in',
      passPlaceholder: 'Skip if not needed',
      serverCtrl: _serverCtrl,
      userCtrl: _userCtrl,
      passCtrl: _passCtrl,
      obscurePass: _obscurePass,
      isLoading: _isLoading,
      errorMsg: _errorMsg,
      isDark: widget.isDark,
      onBack: widget.onBack,
      onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
      onConnect: _handleConnect,
      canConnect: _serverCtrl.text.trim().isNotEmpty && _userCtrl.text.trim().isNotEmpty,
    );
  }
}

// ==========================================
// 5. XTREAM CONNECT VIEW (MATCHES IMAGE 1)
// ==========================================
class _XtreamConnectView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _XtreamConnectView({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_XtreamConnectView> createState() => _XtreamConnectViewState();
}

class _XtreamConnectViewState extends State<_XtreamConnectView> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final s = _serverCtrl.text.trim();
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();
    if (s.isEmpty || u.isEmpty || p.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await MediaSourceService.instance.connectXtream(
      serverUrl: s,
      username: u,
      password: p,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF4F46E5),
          content: Text(res.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildServerForm(
      title: 'Connect to Xtream',
      titleIcon: Icons.live_tv_rounded,
      titleIconColor: const Color(0xFF4F46E5),
      serverPlaceholder: 'http://example.com:8080',
      userPlaceholder: 'Must be filled in',
      passPlaceholder: 'Must be filled in',
      serverCtrl: _serverCtrl,
      userCtrl: _userCtrl,
      passCtrl: _passCtrl,
      obscurePass: _obscurePass,
      isLoading: _isLoading,
      errorMsg: _errorMsg,
      isDark: widget.isDark,
      onBack: widget.onBack,
      onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
      onConnect: _handleConnect,
      canConnect: _serverCtrl.text.trim().isNotEmpty &&
          _userCtrl.text.trim().isNotEmpty &&
          _passCtrl.text.trim().isNotEmpty,
    );
  }
}

// ==========================================
// 6. PLEX CONNECT VIEW
// ==========================================
class _PlexConnectView extends StatefulWidget {
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const _PlexConnectView({
    super.key,
    required this.isDark,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<_PlexConnectView> createState() => _PlexConnectViewState();
}

class _PlexConnectViewState extends State<_PlexConnectView> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    final s = _serverCtrl.text.trim();
    final u = _userCtrl.text.trim();
    if (s.isEmpty || u.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    final res = await MediaSourceService.instance.connectPlex(
      serverUrl: s,
      usernameOrToken: u,
      password: _passCtrl.text,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFE5A00D),
          content: Text(res.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildServerForm(
      title: 'Connect to Plex',
      titleIcon: Icons.double_arrow_rounded,
      titleIconColor: const Color(0xFFE5A00D),
      serverPlaceholder: 'http://192.168.1.8:32400',
      userPlaceholder: 'Token / Must be filled in',
      passPlaceholder: 'Skip if using token',
      serverCtrl: _serverCtrl,
      userCtrl: _userCtrl,
      passCtrl: _passCtrl,
      obscurePass: _obscurePass,
      isLoading: _isLoading,
      errorMsg: _errorMsg,
      isDark: widget.isDark,
      onBack: widget.onBack,
      onToggleObscure: () => setState(() => _obscurePass = !_obscurePass),
      onConnect: _handleConnect,
      canConnect: _serverCtrl.text.trim().isNotEmpty && _userCtrl.text.trim().isNotEmpty,
    );
  }
}

// ==========================================
// COMMON SERVER FORM BUILDER
// ==========================================
Widget _buildServerForm({
  required String title,
  required IconData titleIcon,
  required Color titleIconColor,
  required String serverPlaceholder,
  required String userPlaceholder,
  required String passPlaceholder,
  required TextEditingController serverCtrl,
  required TextEditingController userCtrl,
  required TextEditingController passCtrl,
  required bool obscurePass,
  required bool isLoading,
  required String? errorMsg,
  required bool isDark,
  required VoidCallback onBack,
  required VoidCallback onToggleObscure,
  required VoidCallback onConnect,
  required bool canConnect,
}) {
  final cardBg = isDark ? const Color(0xFF1E2333) : Colors.white;
  final textPrimary = isDark ? Colors.white : Colors.black87;
  final textSecondary = isDark ? Colors.white54 : Colors.black45;
  final dividerColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

  return StatefulBuilder(
    builder: (context, setInner) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Header Row: Back < | [Icon] Title | Connect
            Row(
              children: [
                InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(titleIcon, size: 20, color: titleIconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: (canConnect && !isLoading) ? onConnect : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                    disabledForegroundColor: isDark ? Colors.white30 : Colors.black26,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Connect', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Grouped Form Card matching Images 1, 2, 3
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    _FormFieldRow(
                      label: 'Server Address',
                      hintText: serverPlaceholder,
                      controller: serverCtrl,
                      isDark: isDark,
                      onChanged: (_) => setInner(() {}),
                    ),
                    Divider(height: 1, indent: 16, color: dividerColor),
                    _FormFieldRow(
                      label: 'Username',
                      hintText: userPlaceholder,
                      controller: userCtrl,
                      isDark: isDark,
                      onChanged: (_) => setInner(() {}),
                    ),
                    Divider(height: 1, indent: 16, color: dividerColor),
                    _FormFieldRow(
                      label: 'Password',
                      hintText: passPlaceholder,
                      controller: passCtrl,
                      obscureText: obscurePass,
                      isDark: isDark,
                      onChanged: (_) => setInner(() {}),
                      trailing: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        onPressed: onToggleObscure,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(errorMsg,
                  style: const TextStyle(color: SonicTokens.errorRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            // Caption matching Images 1, 2, 3
            Text(
              'Your login is stored only on this device and used solely to connect to your own server.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: textSecondary,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _FormFieldRow extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? trailing;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _FormFieldRow({
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscureText = false,
    this.trailing,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white30 : const Color(0xFF9CA3AF);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14.5, color: textPrimary),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(color: hintColor, fontSize: 14.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ==========================================
// 7. HELP & WHAT IS A SOURCE VIEW
// ==========================================
class _HelpView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;

  const _HelpView({super.key, required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Media Sources Guide',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _helpCard(
            title: 'What is a Source?',
            description:
                'A source is an external media server, personal playlist, or IPTV stream that you host or subscribe to. Soniclane lets you play and organize music, videos, and live audio from all your personal media hubs in one unified in-car cockpit interface.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _helpCard(
            title: 'M3U / M3U8 Playlists',
            description:
                'Paste an HTTP/HTTPS playlist link (e.g. from your cloud storage or radio subscription) or paste raw #EXTM3U text directly. Soniclane automatically parses categories, logos, and audio/video stream links.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _helpCard(
            title: 'Jellyfin & Emby',
            description:
                'Enter your server address (e.g. http://192.168.1.8:8096) and your username. If your server is protected, enter your password. Soniclane securely stores your token locally on this device.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _helpCard(
            title: 'Xtream Codes',
            description:
                'Enter your Xtream server address, username, and password. Soniclane connects to player_api.php to load your live audio/video channels into a high-speed cockpit playlist.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _helpCard({required String title, required String description, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2333) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          Text(description, style: TextStyle(fontSize: 13, height: 1.45, color: isDark ? Colors.white70 : Colors.black54)),
        ],
      ),
    );
  }
}
