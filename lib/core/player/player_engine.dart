import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class PlayerEngine {
  static final PlayerEngine instance = PlayerEngine._internal();
  PlayerEngine._internal();

  // رابط الـ Worker الخاص بك
  final String _baseUrl = 'https://smart-movies-proxy.fm76400076.workers.dev';

  Future<void> openMovie(BuildContext context, int tmdbId) async {
    await _resolveAndLaunch(context, '$_baseUrl/resolve?type=movie&id=$tmdbId');
  }

  Future<void> openEpisode(BuildContext context, int tmdbId, int season, int episode) async {
    await _resolveAndLaunch(context, '$_baseUrl/resolve?type=tv&id=$tmdbId&season=$season&ep=$episode');
  }

 Future<void> _resolveAndLaunch(BuildContext context, String resolveUrl) async {
    try {
      final response = await http.get(Uri.parse(resolveUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String cleanUrl = data['source'];
        // فتح الرابط النظيف مباشرة
        await launchUrl(Uri.parse(cleanUrl), mode: LaunchMode.externalApplication);
      } else {
        // إذا فشل الـ Worker، افتح الرابط الأصلي
        await launchUrl(Uri.parse(resolveUrl.replace('/resolve', '/embed')), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الاتصال بالمشغل')));
    }
  }