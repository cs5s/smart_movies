import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayerEngine {
  // نمط الـ Singleton
  static final PlayerEngine instance = PlayerEngine._internal();
  PlayerEngine._internal();

  // دالة تشغيل الأفلام
  Future<void> openMovie(BuildContext context, int tmdbId) async {
    final url = Uri.parse('https://vidlink.pro/movie/$tmdbId');
    await _launch(url, context);
  }

  // دالة تشغيل المسلسلات
  Future<void> openEpisode(BuildContext context, int tmdbId, int season, int episode) async {
    final url = Uri.parse('https://vidlink.pro/tv/$tmdbId/$season/$episode');
    await _launch(url, context);
  }

  // دالة المساعدة للفتح في المتصفح الخارجي
  Future<void> _launch(Uri url, BuildContext context) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح المشغل، تأكد من الاتصال بالإنترنت.')),
      );
    }
  }
}