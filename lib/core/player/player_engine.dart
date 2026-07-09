import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PlayerEngine {
  static final PlayerEngine instance = PlayerEngine._internal();
  PlayerEngine._internal();

  // هذه الدالة الموحدة للأفلام
  Future<void> openMovie(BuildContext context, int tmdbId) async {
    final url = Uri.parse('https://vidsrc.pro/embed/movie/$tmdbId');
    await _launch(url);
  }

  // هذه الدالة الموحدة للمسلسلات
  Future<void> openEpisode(BuildContext context, int tmdbId, int season, int episode) async {
    final url = Uri.parse('https://vidsrc.pro/embed/tv/$tmdbId/$season/$episode');
    await _launch(url);
  }

  Future<void> _launch(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}