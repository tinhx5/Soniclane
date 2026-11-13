import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/sonic_tokens.dart';

/// Neutral general-purpose In-App Web Browser accessible from Settings.
///
/// Opens with a blank address prompt so users can navigate to any website
/// manually inside Soniclane without pre-loaded third-party portals or
/// media extraction overlays.
class WebBrowserScreen extends StatefulWidget {
  final String? initialUrl;

  const WebBrowserScreen({super.key, this.initialUrl});

  static Future<void> open(BuildContext context, {String? initialUrl}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebBrowserScreen(initialUrl: initialUrl),
      ),
    );
  }

  @override
  State<WebBrowserScreen> createState() => _WebBrowserScreenState();
}

class _WebBrowserScreenState extends State<WebBrowserScreen> {
  final _urlCtrl = TextEditingController();
  WebViewController? _controller;
  bool _hasLoadedPage = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  int _progress = 0;
  String _currentTitle = 'Web Browser';

  bool get _supportsEmbeddedWebView => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (_supportsEmbeddedWebView) {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(SonicTokens.surfaceBase)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _hasLoadedPage = url != 'about:blank';
                  if (_hasLoadedPage) _urlCtrl.text = url;
                });
              }
            },
            onPageFinished: (url) async {
              final title = await _controller?.getTitle();
              final back = await _controller?.canGoBack() ?? false;
              final fwd = await _controller?.canGoForward() ?? false;
              if (mounted) {
                setState(() {
                  _progress = 100;
                  _canGoBack = back;
                  _canGoForward = fwd;
                  if (title != null && title.isNotEmpty && url != 'about:blank') {
                    _currentTitle = title;
                  }
                });
              }
            },
          ),
        );
      _controller = ctrl;

      final init = widget.initialUrl?.trim();
      if (init != null && init.isNotEmpty) {
        _navigateTo(init);
      }
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Uri? _normalizeInputToUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains(' ') || !trimmed.contains('.')) {
      final encoded = Uri.encodeQueryComponent(trimmed);
      return Uri.parse('https://duckduckgo.com/?q=$encoded');
    }
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'https://$trimmed';
    return Uri.tryParse(withScheme);
  }

  Future<void> _navigateTo(String raw) async {
    final uri = _normalizeInputToUri(raw);
    if (uri == null || _controller == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _hasLoadedPage = true;
      _progress = 10;
      _urlCtrl.text = uri.toString();
    });
    await _controller!.loadRequest(uri);
  }

  void _resetHome() {
    setState(() {
      _hasLoadedPage = false;
      _currentTitle = 'Web Browser';
      _progress = 0;
      _urlCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SonicTokens.surfaceBase,
      appBar: AppBar(
        backgroundColor: SonicTokens.surfaceLowest,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Close Browser',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter URL (e.g. https://example.com)',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: SonicTokens.surfaceCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SonicTokens.radiusLg),
                  borderSide: const BorderSide(color: SonicTokens.glassBorder),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlCtrl.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear URL',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _urlCtrl.clear();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      tooltip: 'Go',
                      icon: const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: SonicTokens.secondaryContainer),
                      onPressed: () => _navigateTo(_urlCtrl.text),
                    ),
                  ],
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _navigateTo,
            ),
          ),
        ),
        bottom: (_hasLoadedPage && _progress > 0 && _progress < 100)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  backgroundColor: Colors.transparent,
                  color: SonicTokens.secondaryContainer,
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: !_supportsEmbeddedWebView
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded,
                              size: 52, color: SonicTokens.secondaryContainer),
                          const SizedBox(height: 12),
                          Text(
                            _currentTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'The embedded WebView browser runs on Android and iOS devices.\nEnter any URL on a mobile device to browse inside Soniclane.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SonicTokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : !_hasLoadedPage || _controller == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: SonicTokens.surfaceCard,
                              borderRadius:
                                  BorderRadius.circular(SonicTokens.radiusXl),
                              border:
                                  Border.all(color: SonicTokens.glassBorder),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.public_rounded,
                                    size: 46,
                                    color: SonicTokens.secondaryContainer),
                                const SizedBox(height: 12),
                                Text(
                                  'In-App Web Browser',
                                  style:
                                      Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Type any website URL or search query in the bar above to browse securely inside Soniclane.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: SonicTokens.textSecondary,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : WebViewWidget(controller: _controller!),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: SonicTokens.surfaceLowest,
              border: Border(
                top: BorderSide(color: SonicTokens.divider),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20),
                    onPressed: _canGoBack
                        ? () async {
                            await _controller?.goBack();
                            final back = await _controller?.canGoBack() ?? false;
                            final fwd =
                                await _controller?.canGoForward() ?? false;
                            if (mounted) {
                              setState(() {
                                _canGoBack = back;
                                _canGoForward = fwd;
                              });
                            }
                          }
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Forward',
                    icon: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 20),
                    onPressed: _canGoForward
                        ? () async {
                            await _controller?.goForward();
                            final back = await _controller?.canGoBack() ?? false;
                            final fwd =
                                await _controller?.canGoForward() ?? false;
                            if (mounted) {
                              setState(() {
                                _canGoBack = back;
                                _canGoForward = fwd;
                              });
                            }
                          }
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: _hasLoadedPage
                        ? () => _controller?.reload()
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Start Page',
                    icon: const Icon(Icons.home_outlined, size: 22),
                    onPressed: _hasLoadedPage ? _resetHome : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
