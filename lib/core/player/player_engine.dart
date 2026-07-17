import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import '../../main.dart' show ApiConfig;

// ═══════════════════════════════════════════════════════════
//  PLAYER ENGINE
// ═══════════════════════════════════════════════════════════
class PlayerEngine {
  PlayerEngine._();
  static final PlayerEngine instance = PlayerEngine._();

  void openMovie(BuildContext context, int tmdbId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchScreen(tmdbId: tmdbId, isMovie: true),
      ),
    );
  }

  void openEpisode(BuildContext context, int tmdbId, int season, int episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchScreen(
          tmdbId: tmdbId,
          isMovie: false,
          seasonNumber: season,
          episodeNumber: episode,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WATCH SCREEN
// ═══════════════════════════════════════════════════════════
class WatchScreen extends StatefulWidget {
  final int tmdbId;
  final bool isMovie;
  final int? seasonNumber;
  final int? episodeNumber;

  const WatchScreen({
    super.key,
    required this.tmdbId,
    required this.isMovie,
    this.seasonNumber,
    this.episodeNumber,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  static const Color _accent = Color(0xFFE50914);
  static const Color _darkBg = Color(0xFF050505);

  bool _isLoadingInfo = true;
  bool _isResolvingLink = false;
  bool _showPlayer = false;
  bool _matched = true;

  String _lookupTitle = '';   // النص المستخدم للبحث في Vodu
  String _displayTitle = '';  // النص المعروض في أعلى الشاشة
  String? _posterUrl;
  String? _resolvedUrl;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final mediaType = widget.isMovie ? 'movie' : 'tv';
      final res = await http.get(Uri.parse(
        '${ApiConfig.apiBase}/tmdb/$mediaType/${widget.tmdbId}?language=en-US',
      ));

      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        final title = (widget.isMovie ? d['title'] : d['name']) ?? '';
        final poster = d['poster_path'] ?? '';

        String displayTitle = title;
        String lookupTitle = title;

        if (!widget.isMovie && widget.seasonNumber != null && widget.episodeNumber != null) {
          displayTitle = '$title • S${widget.seasonNumber} • E${widget.episodeNumber}';
          // هنا نقوم بدمج الموسم والحلقة في نص البحث لضمان جلب الحلقة الصحيحة مباشرة
          lookupTitle = '$title S${widget.seasonNumber} E${widget.episodeNumber}';
        }

        if (!mounted) return;
        setState(() {
          _lookupTitle = lookupTitle;
          _displayTitle = displayTitle;
          _posterUrl = poster.isNotEmpty ? 'https://image.tmdb.org/t/p/w780$poster' : null;
          _isLoadingInfo = false;
        });
      } else {
        debugPrint('WatchScreen info load failed: HTTP ${res.statusCode}');
        if (!mounted) return;
        setState(() => _isLoadingInfo = false);
      }
    } catch (e) {
      debugPrint('WatchScreen info load error: $e');
      if (!mounted) return;
      setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _handlePlayTap() async {
    if (_isResolvingLink || _lookupTitle.isEmpty) return;
    setState(() => _isResolvingLink = true);

    try {
      final result = await ApiConfig.lookupVoduUrl(_lookupTitle);
      final url = result['url'] as String?;
      final matched = result['matched'] == true;

      if (url == null) {
        _showMessage('تعذر تجهيز رابط المشاهدة');
        return;
      }

      final viewType = 'vodu-player-${DateTime.now().millisecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
        return iframe;
      });

      if (!mounted) return;
      setState(() {
        _resolvedUrl = url;
        _matched = matched;
        _viewType = viewType;
        _showPlayer = true;
      });
    } catch (e) {
      debugPrint('Vodu lookup error: $e');
      _showMessage('تعذر تجهيز رابط المشاهدة');
    } finally {
      if (mounted) setState(() => _isResolvingLink = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF1A1A1A), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        title: Text(
          _isLoadingInfo ? '' : _displayTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingInfo
          ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 3))
          : (_showPlayer ? _buildPlayer() : _buildPosterWithPlayButton()),
    );
  }

  Widget _buildPosterWithPlayButton() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _posterUrl != null
            ? Image.network(
                _posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.white10),
              )
            : Container(color: Colors.white10),
        Container(color: Colors.black.withOpacity(0.45)),
        Center(
          child: GestureDetector(
            onTap: _handlePlayTap,
            child: _isResolvingLink
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(color: _accent, strokeWidth: 3),
                      SizedBox(height: 16),
                      Text('جاري تجهيز رابط المشاهدة...', style: TextStyle(color: Colors.white)),
                    ],
                  )
                : Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withOpacity(0.92),
                      boxShadow: [
                        BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 28, spreadRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    return Column(
      children: [
        Expanded(
          child: _viewType != null
              ? HtmlElementView(viewType: _viewType!)
              : const Center(
                  child: Text('تعذر تحميل المشغل', style: TextStyle(color: Colors.white54)),
                ),
        ),
        if (!_matched)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'لم يتم إيجاد تطابق دقيق للعنوان — اختر النتيجة الصحيحة من الصفحة أعلاه',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextButton.icon(
            onPressed: () {
              if (_resolvedUrl != null) html.window.open(_resolvedUrl!, '_blank');
            },
            icon: Icon(Icons.open_in_new_rounded, color: Colors.white.withOpacity(0.5), size: 16),
            label: Text('فتح في نافذة جديدة', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
        ),
      ],
    );
  }
}