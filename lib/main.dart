import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/player/player_engine.dart'; // أضف هذا السطر مع باقي الـ imports
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web; // هذا هو البديل الرسمي الحديث للويب
// ═══════════════════════════════════════════════════════════
//  API CONFIG
// ═══════════════════════════════════════════════════════════
class ApiConfig {
  // The Cloudflare Worker proxy that holds the real Groq/TMDB keys.
  static const String defaultApiBase = 'https://smart-movies-proxy.fm76400076.workers.dev';
  static String get apiBase {
    final override = dotenv.env['API_BASE_URL'];
    return (override != null && override.isNotEmpty) ? override : defaultApiBase;
  }

  // ─────────────────────────────────────────────────────────
  // VODU integration
  // ─────────────────────────────────────────────────────────
  // Vodu doesn't expose a public API mapping TMDB IDs to its own internal
  // post IDs, so resolving a show's Vodu page happens server-side in the
  // Worker (see worker.js -> /vodu-lookup). The Worker looks up the show
  // by title, extracts the direct link, and caches it (via KV) so the
  // same title isn't looked up again on future requests - no manual ID
  // list to maintain here.
  static Future<Map<String, dynamic>> lookupVoduUrl(String showTitle) async {
    final res = await http.get(Uri.parse(
      '$apiBase/vodu-lookup?title=${Uri.encodeComponent(showTitle)}',
    ));
    if (res.statusCode != 200) {
      throw Exception('Vodu lookup failed: HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/env");
  } catch (_) {
    // No .env file present - that's fine. The app talks to a secure proxy
    // (see _apiBase below) and no longer needs real API keys client-side,
    // so a public web build with no .env works perfectly well.
  }
  runApp(const SmartMoviesApp());
}

// ═══════════════════════════════════════════════════════════
//  LOCALIZATION
// ═══════════════════════════════════════════════════════════
class AppStrings {
  final bool isArabic;
  const AppStrings(this.isArabic);

  String get appName       => isArabic ? 'نيـــرو'               : 'NERO';
  String get subtitle      => isArabic ? 'مرشدك السينمائي'        : 'Your Cinema Guide';
  String get searchHint    => isArabic ? 'اكتب هنا...'            : 'Search here...';
  String get searching     => isArabic ? 'جاري البحث...'          : 'Searching...';
  String get emptyHint     => isArabic ? 'اكتب فيلم أو مسلسل تحبه\nوسأقترحلك أمور شبيهة'
                                        : 'Type a movie or show you love\nand I\'ll suggest similar ones';
  String get tapForSimilar => isArabic ? 'اضغط لاقتراحات مشابهة'  : 'Tap for similar titles';
  String get home          => isArabic ? 'الرئيسية'               : 'Home';
  String get favorites     => isArabic ? 'المفضلة'                : 'Favorites';
  String get history       => isArabic ? 'سجل البحث'              : 'Search History';
  String get deleteAll     => isArabic ? 'حذف الكل'               : 'Clear All';
  String get noFavorites   => isArabic ? 'لا توجد مفضلات بعد'     : 'No favorites yet';
  String get myFavorites   => isArabic ? 'أفلامك المفضلة'         : 'My Favorites';
  String get trailer       => isArabic ? 'التريلر'                : 'Trailer';
  String get noStory       => isArabic ? 'عذراً، لا تتوفر تفاصيل لهذا العمل حالياً.'
                                        : 'Sorry, no details available for this title.';
  String get unknown       => isArabic ? 'غير معروف'              : 'Unknown';
  String get developer     => isArabic ? 'مطور تطبيق نيـــرو'     : 'NERO App Developer';
  String get email         => isArabic ? 'البريد الإلكتروني'      : 'Email';
  String get instagram     => isArabic ? 'انستقرام'               : 'Instagram';
  String get telegram      => isArabic ? 'تيليجرام'               : 'Telegram';
  // New: user-facing error/status messages
  String get searchError   => isArabic ? 'لم يتم العثور على نتائج، حاول باسم مختلف'
                                        : 'No results found, try a different title';
  String get networkError  => isArabic ? 'حدث خطأ في الاتصال، تحقق من الإنترنت وحاول مجدداً'
                                        : 'Connection error, check your internet and try again';
  String get trailerError  => isArabic ? 'تعذر فتح رابط التريلر'  : 'Could not open the trailer link';
  String get noTrailer     => isArabic ? 'لا يتوفر تريلر لهذا العمل' : 'No trailer available for this title';
  String get linkError     => isArabic ? 'تعذر فتح الرابط'         : 'Could not open the link';

  // Seasons & Episodes
  String get seasonsAndEpisodes => isArabic ? 'المواسم والحلقات'        : 'Seasons & Episodes';
  String get season             => isArabic ? 'الموسم'                  : 'Season';
  String get episode            => isArabic ? 'الحلقة'                  : 'Episode';
  String get episodes           => isArabic ? 'حلقة'                    : 'episodes';
  String get loadingSeasons     => isArabic ? 'جاري تحميل المواسم...'   : 'Loading seasons...';
  String get loadingEpisodes    => isArabic ? 'جاري تحميل الحلقات...'  : 'Loading episodes...';
  String get seasonsLoadError   => isArabic ? 'تعذر تحميل المواسم'      : 'Could not load seasons';
  String get episodesLoadError  => isArabic ? 'تعذر تحميل الحلقات'     : 'Could not load episodes';
  String get watchEpisode       => isArabic ? 'مشاهدة الحلقة'           : 'Watch episode';
  String get watchLinkError     => isArabic ? 'تعذر فتح رابط المشاهدة'  : 'Could not open the watch link';
  String get noOverview         => isArabic ? 'لا يتوفر وصف لهذه الحلقة' : 'No description available';

  // Where to watch (legal providers via TMDB/JustWatch)
  String get whereToWatch        => isArabic ? 'مشاهدة الفلم'           : 'Watch Movie';
  String get noWatchProviders     => isArabic ? 'لا تتوفر معلومات مشاهدة لهذا العمل في منطقتك'
                                        : 'No watch info available for this title in your region';
  String get watchProvidersError => isArabic ? 'تعذر تحميل معلومات المشاهدة' : 'Could not load watch info';
}

// ═══════════════════════════════════════════════════════════
//  APP ROOT
// ═══════════════════════════════════════════════════════════
class SmartMoviesApp extends StatelessWidget {
  const SmartMoviesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نيرو',
      theme: ThemeData.dark(useMaterial3: true),
      scrollBehavior: AppScrollBehavior(),
      home: const SplashScreen(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SCROLL BEHAVIOR (enables mouse/trackpad drag-to-scroll on
//  desktop/web/iPad, not just touch — fixes PageView only
//  responding to the arrow buttons on PC).
// ═══════════════════════════════════════════════════════════
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

// ═══════════════════════════════════════════════════════════
//  RESPONSIVE WRAPPER
//  Keeps the phone-style layout intact but centers it and lets
//  it scale to full screen height on desktop / iPad screens.
// ═══════════════════════════════════════════════════════════
class ResponsiveShell extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveShell({super.key, required this.child, this.maxWidth = 480});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= maxWidth) return child;
    return ColoredBox(
      color: const Color(0xFF050505),
      child: Center(
        child: SizedBox(
          width: maxWidth,
          height: double.infinity,
          child: Material(
            color: const Color(0xFF050505),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SPLASH SCREEN
// ═══════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;
  late AnimationController _exitController;
  late Animation<double> _exitAnim;

  static const Color _accent = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _exitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _exitAnim = CurvedAnimation(parent: _exitController, curve: Curves.easeOut);
    _startSequence();
  }

  Future<void> _startSequence() async {
    await _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    _glowController.stop();
    await _exitController.forward();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ResponsiveShell(
        child: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnim, _glowAnim, _exitAnim]),
        builder: (context, _) => Opacity(
          opacity: 1.0 - _exitAnim.value,
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                          color: _accent.withOpacity(_glowAnim.value * 0.6),
                          blurRadius: 60, spreadRadius: 20,
                        )],
                      ),
                    ),
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(0.1),
                        border: Border.all(color: _accent.withOpacity(0.6), width: 2),
                      ),
                      child: const Icon(Icons.movie_creation_rounded, color: _accent, size: 44),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Text('نيـــرو', style: TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: 6,
                    shadows: [Shadow(color: _accent.withOpacity(_glowAnim.value * 0.8), blurRadius: 20)],
                  )),
                  const SizedBox(height: 10),
                  Text('مرشدك السينمائي', style: TextStyle(
                    fontSize: 14, color: _accent.withOpacity(0.8),
                    fontWeight: FontWeight.w600, letterSpacing: 3,
                  )),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withOpacity(_glowAnim.value * (i % 2 == 0 ? 1.0 : 0.4)),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DATA MODEL
// ═══════════════════════════════════════════════════════════
class MovieCard {
  final String titleAr;
  final String titleEn;
  final String year;
  final String story;
  final String storyEn;
  final String imageUrl;
  final String rating;
  final String genres;
  final String genresEn;
  final String trailerUrl;
  final int tmdbId;
  final String mediaType; // 'tv' or 'movie'

  MovieCard({
    required this.titleAr, required this.titleEn,
    required this.year,    required this.story,
    required this.storyEn, required this.imageUrl,
    required this.rating,  required this.genres,
    required this.genresEn,required this.trailerUrl,
    required this.tmdbId,  required this.mediaType,
  });

  Map<String, dynamic> toMap() => {
    'titleAr': titleAr, 'titleEn': titleEn, 'year': year,
    'story': story,     'storyEn': storyEn,
    'imageUrl': imageUrl, 'rating': rating,
    'genres': genres,   'genresEn': genresEn,
    'trailerUrl': trailerUrl,
    'tmdbId': tmdbId,   'mediaType': mediaType,
  };

  factory MovieCard.fromMap(Map<String, dynamic> map) => MovieCard(
    titleAr: map['titleAr'] ?? '',  titleEn: map['titleEn'] ?? '',
    year: map['year'] ?? '',        story: map['story'] ?? '',
    storyEn: map['storyEn'] ?? '',  imageUrl: map['imageUrl'] ?? '',
    rating: map['rating'] ?? '',    genres: map['genres'] ?? '',
    genresEn: map['genresEn'] ?? '',trailerUrl: map['trailerUrl'] ?? '',
    tmdbId: map['tmdbId'] ?? 0,     mediaType: map['mediaType'] ?? 'movie',
  );
}

// ═══════════════════════════════════════════════════════════
//  HOME PAGE
// ═══════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isArabic = true;

  List<MovieCard> _movies = [];
  List<MovieCard> _favorites = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _hasResult = false;
  int _currentCard = 0;
  bool _isResolvingWatchProviders = false;

  List<String> _homePosterUrls = [];
  int _currentPoster = 0;
  Timer? _posterTimer;
  late PageController _posterPageController;

  static const Color _accent = Color(0xFFE50914);
  static const Color _darkBg = Color(0xFF050505);

  late AnimationController _breathController;
  late Animation<double> _breathAnim;
  late PageController _pageController;

  // Base URL of the secure proxy (a Cloudflare Worker, see worker.js) that
  // holds the real Groq/TMDB API keys server-side. Delegates to ApiConfig
  // so the SeasonsScreen/EpisodesScreen widgets can use the exact same base.
  String get _apiBase => ApiConfig.apiBase;

  static const List<Map<String, String>> _featuredTitles = [
    {'title': 'Interstellar',    'type': 'movie'},
    {'title': 'Breaking Bad',    'type': 'tv'},
    {'title': 'Attack on Titan', 'type': 'tv'},
    {'title': 'The Dark Knight', 'type': 'movie'},
    {'title': 'Game of Thrones', 'type': 'tv'},
    {'title': 'Inception',       'type': 'movie'},
    {'title': 'Money Heist',     'type': 'tv'},
    {'title': 'Oppenheimer',     'type': 'movie'},
    {'title': 'Squid Game',      'type': 'tv'},
    {'title': 'Death Note',      'type': 'tv'},
  ];

  AppStrings get s => AppStrings(_isArabic);

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _pageController = PageController(viewportFraction: 0.85);
    _posterPageController = PageController();
    _loadData();
    _loadHomePosters();
  }

  @override
  void dispose() {
    _posterTimer?.cancel();
    _breathController.dispose();
    _pageController.dispose();
    _posterPageController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Small helper to show a SnackBar safely without duplicating boilerplate everywhere.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleLanguage() => setState(() => _isArabic = !_isArabic);

  bool _containsArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  bool _isPhoneticArabic(String text) {
    final arabicWords = [
      'ال', 'في', 'من', 'على', 'إلى', 'مع', 'عن', 'هذا', 'هذه',
      'الاختيار', 'العراب', 'الهيبة', 'كلبش', 'الممر', 'نسر',
      'الاسطورة', 'هجمة', 'مرتدة', 'قيامة', 'عثمان', 'الحشاشين',
      'باب', 'الحارة', 'بيت', 'حلاوة', 'روح', 'فرقة', 'ناجي', 'ولاد', 'رزق'
    ];
    final lower = text.toLowerCase();
    for (final word in arabicWords) {
      if (lower.contains(word)) return false;
    }
    return true;
  }

  Future<void> _loadHomePosters() async {
    final List<String> urls = [];
    for (final item in _featuredTitles) {
      try {
        final res = await http.get(Uri.parse(
          '$_apiBase/tmdb/search/multi?query=${Uri.encodeComponent(item['title']!)}&language=en-US',
        ));
        if (res.statusCode == 200) {
          final results = jsonDecode(res.body)['results'] as List;
          if (results.isNotEmpty) {
            final poster = results[0]['poster_path'] ?? '';
            if (poster.isNotEmpty) urls.add('https://image.tmdb.org/t/p/w500$poster');
          }
        } else {
          debugPrint('TMDB poster fetch failed (${item['title']}): HTTP ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('TMDB poster fetch error (${item['title']}): $e');
      }
    }
    if (mounted && urls.isNotEmpty) {
      setState(() => _homePosterUrls = urls);
      _startPosterTimer();
    }
  }

  void _startPosterTimer() {
    _posterTimer?.cancel();
    _posterTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted && _homePosterUrls.isNotEmpty)
        _goToPoster((_currentPoster + 1) % _homePosterUrls.length);
    });
  }

  void _goToPoster(int index) {
    if (!mounted) return;
    setState(() => _currentPoster = index);
    if (_posterPageController.hasClients)
      _posterPageController.animateToPage(index,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
  }

  void _nextPoster() { _goToPoster((_currentPoster + 1) % _homePosterUrls.length); _startPosterTimer(); }
  void _prevPoster() { _goToPoster((_currentPoster - 1 + _homePosterUrls.length) % _homePosterUrls.length); _startPosterTimer(); }

  void _resetHome() {
    setState(() { _movies = []; _hasResult = false; _currentCard = 0; _controller.clear(); });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  String _normalizeQuery(String input) {
    String q = input.trim();
    if (_containsArabic(q)) {
      q = q.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    }
    return q.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final favString = prefs.getString('favorites');
    if (favString != null) {
      final List decoded = jsonDecode(favString);
      setState(() => _favorites = decoded.map((m) => MovieCard.fromMap(m)).toList());
    }
    setState(() => _searchHistory = prefs.getStringList('history') ?? []);
  }

  Future<void> _toggleFavorite(MovieCard movie) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final isExist = _favorites.any((m) => m.titleEn == movie.titleEn);
      if (isExist) { _favorites.removeWhere((m) => m.titleEn == movie.titleEn); }
      else { _favorites.add(movie); }
    });
    await prefs.setString('favorites', jsonEncode(_favorites.map((m) => m.toMap()).toList()));
  }

  Future<void> _addToHistory(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 15) _searchHistory.removeLast();
    });
    await prefs.setStringList('history', _searchHistory);
  }

  Future<void> _deleteHistoryItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _searchHistory.remove(query));
    await prefs.setStringList('history', _searchHistory);
  }

  Future<void> _clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _searchHistory.clear());
    await prefs.remove('history');
  }

  void _nextCard() {
    if (_currentCard < _movies.length - 1)
      _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _prevCard() {
    if (_currentCard > 0)
      _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Future<List<dynamic>> _tmdbSearch(String query) async {
    final isAr = _containsArabic(query) && !_isPhoneticArabic(query);
    final languages = isAr ? ['ar', 'en-US'] : ['en-US', 'ar'];

    for (final lang in languages) {
      try {
        final res = await http.get(Uri.parse(
          '$_apiBase/tmdb/search/multi?query=${Uri.encodeComponent(query)}&language=$lang',
        ));
        if (res.statusCode == 200) {
          final results = jsonDecode(res.body)['results'] as List;
          if (results.isNotEmpty) {
            results.sort((a, b) =>
                (b['popularity'] ?? 0).toDouble().compareTo((a['popularity'] ?? 0).toDouble()));
            return results;
          }
        } else {
          debugPrint('TMDB search failed ($lang) for "$query": HTTP ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('TMDB search error ($lang) for "$query": $e');
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> _getNeroData(String input) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final res = await http.post(
          Uri.parse('$_apiBase/groq'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': 'llama-3.1-8b-instant',
            'max_tokens': 500,
            'temperature': 0.1,
            'response_format': const {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content': '''You are an expert multilingual movie/TV recommendation engine.
Output JSON ONLY:
{"target": {"titleEn": "...", "titleAr": "...", "year": "..."}, "recs": [{"titleEn": "...", "titleAr": "...", "year": "..."}, ...]}

CRITICAL RULES:
1. English input → recommend similar English/international titles.
2. Arabic phonetic spelling (e.g. "بليتش", "انترستيلار") → Translate titleEn to English. Recommend ENGLISH/ANIME titles.
3. REAL Arabic title (e.g. "الاختيار", "ولاد رزق") → For "titleEn", provide the TRANSLITERATED name used in TMDB (e.g. "El Ekhteyar", "Welad Rizk"). For "titleAr", provide the Arabic script. ALWAYS recommend ONLY ARABIC content. NEVER mix Hollywood with Arabic.
4. Always return exactly 4 recommendations.''',
              },
              {'role': 'user', 'content': 'Game of Thrones'},
              {'role': 'assistant', 'content': '{"target": {"titleEn": "Game of Thrones", "titleAr": "صراع العروش", "year": "2011"}, "recs": [{"titleEn": "House of the Dragon", "titleAr": "آل التنين", "year": "2022"}, {"titleEn": "The Witcher", "titleAr": "ذا ويتشر", "year": "2019"}, {"titleEn": "The Last Kingdom", "titleAr": "المملكة الأخيرة", "year": "2015"}, {"titleEn": "Vikings", "titleAr": "فايكنجز", "year": "2013"}]}'},

              {'role': 'user', 'content': 'انترستيلار'},
              {'role': 'assistant', 'content': '{"target": {"titleEn": "Interstellar", "titleAr": "بين النجوم", "year": "2014"}, "recs": [{"titleEn": "Gravity", "titleAr": "جاذبية", "year": "2013"}, {"titleEn": "The Martian", "titleAr": "المريخي", "year": "2015"}, {"titleEn": "Arrival", "titleAr": "الوافد", "year": "2016"}, {"titleEn": "Ad Astra", "titleAr": "أد أسترا", "year": "2019"}]}'},

              {'role': 'user', 'content': 'بليتش'},
              {'role': 'assistant', 'content': '{"target": {"titleEn": "Bleach", "titleAr": "بليتش", "year": "2004"}, "recs": [{"titleEn": "Naruto", "titleAr": "ناروتو", "year": "2002"}, {"titleEn": "One Piece", "titleAr": "ون بيس", "year": "1999"}, {"titleEn": "Hunter x Hunter", "titleAr": "هنتر x هنتر", "year": "2011"}, {"titleEn": "Dragon Ball Z", "titleAr": "دراغون بول زد", "year": "1989"}]}'},

              {'role': 'user', 'content': 'الاختيار'},
              {'role': 'assistant', 'content': '{"target": {"titleEn": "El Ekhteyar", "titleAr": "الاختيار", "year": "2020"}, "recs": [{"titleEn": "Kalabsh", "titleAr": "كلبش", "year": "2017"}, {"titleEn": "Al Mamar", "titleAr": "الممر", "year": "2019"}, {"titleEn": "Hagma Mortadda", "titleAr": "هجمة مرتدة", "year": "2021"}, {"titleEn": "Al Ostoura", "titleAr": "الأسطورة", "year": "2016"}]}'},

              {'role': 'user', 'content': 'العراب'},
              {'role': 'assistant', 'content': '{"target": {"titleEn": "Al Arrab", "titleAr": "العراب", "year": "2015"}, "recs": [{"titleEn": "Al Hayba", "titleAr": "الهيبة", "year": "2017"}, {"titleEn": "Kalabsh", "titleAr": "كلبش", "year": "2017"}, {"titleEn": "Nesr El Saeed", "titleAr": "نسر الصعيد", "year": "2018"}, {"titleEn": "Al Ostoura", "titleAr": "الأسطورة", "year": "2016"}]}'},

              {'role': 'user', 'content': _normalizeQuery(input)},
            ],
          }),
        );
        if (res.statusCode != 200) {
          debugPrint('Groq API error (attempt $attempt): HTTP ${res.statusCode} - ${res.body}');
          if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        final data = jsonDecode(res.body);
        String raw = (data['choices'][0]['message']['content'] as String).trim();
        if (raw.startsWith('```json')) raw = raw.replaceFirst('```json', '').replaceAll('```', '');
        return jsonDecode(raw.trim());
      } catch (e) {
        debugPrint('Groq API exception (attempt $attempt): $e');
        if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<MovieCard?> _fetchFromTmdb(String titleQuery, String targetYear,
      {bool isTarget = false, String originalQuery = ''}) async {
    try {
      var results = await _tmdbSearch(titleQuery);
      if (results.isEmpty && originalQuery.isNotEmpty && originalQuery != titleQuery) {
        results = await _tmdbSearch(originalQuery);
      }
      if (results.isEmpty) return null;

      dynamic item = results[0];
      if (targetYear.isNotEmpty && targetYear != 'null') {
        for (var r in results) {
          final rType = r['media_type'] ?? 'movie';
          final rDate = (rType == 'tv' ? r['first_air_date'] : r['release_date']) ?? '';
          if (rDate.toString().startsWith(targetYear.substring(0, 4))) { item = r; break; }
        }
      }

      final id = item['id'];
      final mediaType = item['media_type'] ?? 'movie';
      final posterPath = item['poster_path'] ?? '';
      final releaseDate = (mediaType == 'tv' ? item['first_air_date'] : item['release_date']) ?? '';
      String year = releaseDate.toString().length >= 4
          ? releaseDate.toString().substring(0, 4) : s.unknown;

      String titleAr = titleQuery, story = '', rating = '', genres = '';
      try {
        final detailArRes = await http.get(Uri.parse(
          '$_apiBase/tmdb/$mediaType/$id?language=ar',
        ));
        if (detailArRes.statusCode == 200) {
          final d = jsonDecode(detailArRes.body);
          titleAr = (mediaType == 'tv' ? d['name'] : d['title']) ?? titleAr;
          story = d['overview'] ?? '';
          final vote = d['vote_average'] ?? 0.0;
          rating = vote > 0 ? (vote as num).toStringAsFixed(1) : 'N/A';
          final genresList = d['genres'] as List<dynamic>? ?? [];
          genres = genresList.take(2).map((g) => g['name']).join(' • ');
        } else {
          debugPrint('TMDB AR details failed for id $id: HTTP ${detailArRes.statusCode}');
        }
      } catch (e) {
        debugPrint('TMDB AR details error for id $id: $e');
      }

      String titleEn = titleQuery, storyEn = '', genresEn = '';
      try {
        final detailEnRes = await http.get(Uri.parse(
          '$_apiBase/tmdb/$mediaType/$id?language=en-US',
        ));
        if (detailEnRes.statusCode == 200) {
          final d = jsonDecode(detailEnRes.body);
          titleEn = (mediaType == 'tv' ? d['name'] : d['title']) ?? titleEn;
          storyEn = d['overview'] ?? '';
          if (story.trim().isEmpty) story = storyEn;
          final genresListEn = d['genres'] as List<dynamic>? ?? [];
          genresEn = genresListEn.take(2).map((g) => g['name']).join(' • ');
          if (genres.trim().isEmpty) genres = genresEn;
        } else {
          debugPrint('TMDB EN details failed for id $id: HTTP ${detailEnRes.statusCode}');
        }
      } catch (e) {
        debugPrint('TMDB EN details error for id $id: $e');
      }

      if (story.trim().isEmpty) story = s.noStory;
      if (storyEn.trim().isEmpty) storyEn = story;
      if (genresEn.trim().isEmpty) genresEn = genres;

      // Fixed: build a clean YouTube URL instead of the broken markdown-style
      // concatenation that produced an invalid, unlaunchable link.
      String trailerUrl = '';
      try {
        final videoRes = await http.get(Uri.parse(
          '$_apiBase/tmdb/$mediaType/$id/videos?language=en-US',
        ));
        if (videoRes.statusCode == 200) {
          final videoData = jsonDecode(videoRes.body)['results'] as List;
          try {
            final trailer = videoData.firstWhere((v) => v['site'] == 'YouTube' && v['type'] == 'Trailer');
            trailerUrl = 'https://www.youtube.com/watch?v=${trailer['key']}';
          } catch (_) {
            try {
              final teaser = videoData.firstWhere((v) => v['site'] == 'YouTube' && v['type'] == 'Teaser');
              trailerUrl = 'https://www.youtube.com/watch?v=${teaser['key']}';
            } catch (_) {
              // No trailer or teaser available for this title - trailerUrl stays empty.
            }
          }
        } else {
          debugPrint('TMDB videos fetch failed for id $id: HTTP ${videoRes.statusCode}');
        }
      } catch (e) {
        debugPrint('TMDB videos fetch error for id $id: $e');
      }

      if (titleAr.trim().isEmpty) titleAr = titleEn;
      if (titleEn.trim().isEmpty) titleEn = titleAr;

      return MovieCard(
        titleAr: titleAr, titleEn: titleEn, year: year,
        story: story, storyEn: storyEn,
        imageUrl: posterPath.isNotEmpty ? 'https://image.tmdb.org/t/p/w500$posterPath' : '',
        rating: rating, genres: genres, genresEn: genresEn,
        trailerUrl: trailerUrl,
        tmdbId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        mediaType: mediaType,
      );
    } catch (e) {
      debugPrint('_fetchFromTmdb error for "$titleQuery": $e');
      return null;
    }
  }

  Future<void> _askNero({String? manualQuery}) async {
    final rawInput = manualQuery ?? _controller.text;
    final queryInput = _normalizeQuery(rawInput);
    if (queryInput.isEmpty) return;

    _focusNode.unfocus();
    _addToHistory(rawInput.trim());

    setState(() { _isLoading = true; _hasResult = false; _movies = []; _currentCard = 0; });

    try {
      final neroData = await _getNeroData(queryInput);

      if (neroData == null) {
        final fallbackMovie = await _fetchFromTmdb(queryInput, '', isTarget: true, originalQuery: queryInput);
        if (fallbackMovie != null) {
          setState(() { _movies = [fallbackMovie]; _isLoading = false; _hasResult = true; });
        } else {
          setState(() => _isLoading = false);
          _showMessage(s.searchError);
        }
        return;
      }

      final targetInfo = neroData['target'];
      final recsInfo = neroData['recs'] as List;
      final List<MovieCard> finalMovies = [];

      final targetMovie = await _fetchFromTmdb(
        targetInfo['titleEn'].toString(),
        targetInfo['year'].toString(),
        isTarget: true,
        originalQuery: targetInfo['titleAr'].toString(),
      );
      if (targetMovie != null) finalMovies.add(targetMovie);

      final results = await Future.wait(
        recsInfo.map((item) async {
          try {
            return await _fetchFromTmdb(
              item['titleEn'].toString(),
              item['year'].toString(),
              originalQuery: item['titleAr'].toString(),
            );
          } catch (e) {
            debugPrint('Rec fetch error for "${item['titleEn']}": $e');
            return null;
          }
        }).toList(),
        eagerError: false,
      );
      finalMovies.addAll(results.whereType<MovieCard>());

      setState(() {
        _movies = finalMovies;
        _isLoading = false;
        _hasResult = finalMovies.isNotEmpty;
      });

      if (finalMovies.isEmpty) {
        _showMessage(s.searchError);
      }
    } catch (e) {
      debugPrint('_askNero error: $e');
      setState(() => _isLoading = false);
      _showMessage(s.networkError);
    }
  }

  void _showFavoriteMovie(MovieCard movie) {
    Navigator.pop(context);
    setState(() { _movies = [movie]; _hasResult = true; _currentCard = 0; });
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  // ─────────────────────────────────────────────────────────
  // "Where to Watch" — legal streaming availability for movies,
  // sourced directly from TMDB's official watch/providers endpoint
  // (backed by JustWatch). Opens TMDB's own watch page which lists
  // legitimate providers (Netflix, Shahid, OSN, etc.) for the movie
  // in the user's region, instead of pointing at unlicensed sources.
  // ─────────────────────────────────────────────────────────
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _darkBg,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: ResponsiveShell(
          child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 10),
                Expanded(child: _buildMainContent()),
                _buildSearchBar(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _showAbout,
                    child: const Text('© علي الأسدي',
                      style: TextStyle(color: Colors.white24, fontSize: 11,
                        decoration: TextDecoration.underline, decorationColor: Colors.white24)),
                  ),
                ),
              ],
            ),
            if (_isResolvingWatchProviders)
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: _accent, strokeWidth: 3),
                      const SizedBox(height: 16),
                      Text(
                        _isArabic ? 'جاري تجهيز رابط المشاهدة...' : 'Preparing the watch link...',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 32),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.appName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                  Text(s.subtitle, style: const TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.w600, letterSpacing: 1)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildLangToggle(),
              const SizedBox(width: 8),
              _buildLogo(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangToggle() {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isArabic ? 'EN' : 'ع',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            Icon(Icons.language_rounded, color: _accent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _breathAnim,
      builder: (context, child) => Transform.scale(scale: _breathAnim.value, child: child),
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: _accent.withOpacity(0.1),
          border: Border.all(color: _accent.withOpacity(0.5), width: 2),
        ),
        child: const Icon(Icons.movie_creation_rounded, color: _accent, size: 24),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _accent, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(s.searching, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          ],
        ),
      );
    }

    if (!_hasResult) return _buildHomePosters();

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScrollConfiguration(
                behavior: AppScrollBehavior(),
                child: PageView.builder(
                controller: _pageController,
                itemCount: _movies.length,
                onPageChanged: (i) => setState(() => _currentCard = i),
                itemBuilder: (context, index) => _MovieCardWidget(
                  movie: _movies[index],
                  isFav: _favorites.any((m) => m.titleEn == _movies[index].titleEn),
                  onFavTap: () => _toggleFavorite(_movies[index]),
                  trailerLabel: s.trailer,
                  isArabic: _isArabic,
                  noTrailerMessage: s.noTrailer,
                  trailerErrorMessage: s.trailerError,
                  onShowMessage: _showMessage,
                  seasonsLabel: s.seasonsAndEpisodes,
                  onSeasonsTap: _movies[index].mediaType == 'tv'
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SeasonsScreen(
                                tmdbId: _movies[index].tmdbId,
                                showTitle: _isArabic ? _movies[index].titleAr : _movies[index].titleEn,
                                isArabic: _isArabic,
                              ),
                            ),
                          )
                      : null,
                  watchLabel: s.whereToWatch,
                 onWatchTap: _movies[index].mediaType == 'movie' 
    ? () => PlayerEngine.instance.openMovie(context, _movies[index].tmdbId) 
    : null,
                ),
              ),
              ),
              if (_currentCard < _movies.length - 1)
                Positioned(right: 4, child: _NavArrow(icon: Icons.chevron_right_rounded, onTap: _nextCard)),
              if (_currentCard > 0)
                Positioned(left: 4, child: _NavArrow(icon: Icons.chevron_left_rounded, onTap: _prevCard)),
            ],
          ),
        ),
        _buildDots(),
      ],
    );
  }

  Widget _buildHomePosters() {
    if (_homePosterUrls.isEmpty) {
      return Center(
        child: Text(s.emptyHint, textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16, height: 1.6)),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: AppScrollBehavior(),
          child: PageView.builder(
            controller: _posterPageController,
            itemCount: _homePosterUrls.length,
            onPageChanged: (i) { setState(() => _currentPoster = i); _startPosterTimer(); },
            itemBuilder: (context, index) => Image.network(
              _homePosterUrls[index], fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A)),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.2), Colors.transparent, Colors.black.withOpacity(0.85)],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),
        Positioned(right: 10, top: 0, bottom: 100,
          child: Center(child: _NavArrow(icon: Icons.chevron_right_rounded, onTap: _nextPoster))),
        Positioned(left: 10, top: 0, bottom: 100,
          child: Center(child: _NavArrow(icon: Icons.chevron_left_rounded, onTap: _prevPoster))),
        Positioned(
          bottom: 24, left: 0, right: 0,
          child: Column(
            children: [
              Text(
                _featuredTitles[_currentPoster % _featuredTitles.length]['title']!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)]),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  final title = _featuredTitles[_currentPoster % _featuredTitles.length]['title']!;
                  _askNero(manualQuery: title);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accent, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(s.tapForSimilar,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_homePosterUrls.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPoster == i ? 20 : 6, height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentPoster == i ? _accent : Colors.white38,
                  ),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_movies.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentCard == i ? 24 : 8, height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _currentCard == i ? _accent : Colors.white24,
          ),
        )),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller, focusNode: _focusNode,
              textAlign: _isArabic ? TextAlign.right : TextAlign.left,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: s.searchHint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              onSubmitted: (_) => _askNero(),
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : _askNero,
            child: Container(
              margin: const EdgeInsets.all(8), width: 48, height: 48,
              decoration: BoxDecoration(
                color: _accent, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: Column(
        children: [
          DrawerHeader(
            child: Center(child: Text(s.appName,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _accent))),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.white),
            title: Text(s.home, style: const TextStyle(fontSize: 18)),
            onTap: () { Navigator.pop(context); _resetHome(); },
          ),
          ListTile(
            leading: const Icon(Icons.favorite, color: _accent),
            title: Text(s.favorites, style: const TextStyle(fontSize: 18)),
            onTap: () { Navigator.pop(context); _showFavorites(); },
          ),
          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.history, style: const TextStyle(color: Colors.white38, fontSize: 16)),
                if (_searchHistory.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllHistory,
                    child: Text(s.deleteAll, style: const TextStyle(color: _accent, fontSize: 14)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final query = _searchHistory[index];
                return ListTile(
                  title: Text(query, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white24),
                    onPressed: () => _deleteHistoryItem(query),
                  ),
                  onTap: () { Navigator.pop(context); _controller.text = query; _askNero(manualQuery: query); },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: _accent.withOpacity(0.1),
                border: Border.all(color: _accent.withOpacity(0.5), width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: _accent, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('علي الأسدي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            Text(s.developer, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 28),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 20),
            _ContactTile(
              icon: Icons.email_rounded, label: s.email, value: 'fm76400076@gmail.com',
              onTap: () async {
                final url = Uri.parse('mailto:fm76400076@gmail.com');
                if (await canLaunchUrl(url)) {
                  launchUrl(url);
                } else {
                  _showMessage(s.linkError);
                }
              },
            ),
            const SizedBox(height: 12),
            // Fixed: this was previously a broken markdown-style URL that
            // never launched. Now a plain, valid Instagram link.
            _ContactTile(
              icon: Icons.camera_alt_rounded, label: s.instagram, value: '@cs5s_',
              onTap: () async {
                final url = Uri.parse(
                  'https://www.instagram.com/cs5s_?igsh=NDJ2cG13enZpNWZr&utm_source=qr',
                );
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  _showMessage(s.linkError);
                }
              },
            ),
            const SizedBox(height: 12),
            _ContactTile(
              icon: Icons.send_rounded, label: s.telegram, value: '@cs5sAA',
              onTap: () async {
                final url = Uri.parse('https://t.me/cs5sAA');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  _showMessage(s.linkError);
                }
              },
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _showFavorites() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(s.myFavorites, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _accent)),
            const SizedBox(height: 20),
            Expanded(
              child: _favorites.isEmpty
                  ? Center(child: Text(s.noFavorites, style: const TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        final fav = _favorites[index];
                        return ListTile(
                          onTap: () => _showFavoriteMovie(fav),
                          leading: fav.imageUrl.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8),
                                  child: Image.network(fav.imageUrl, width: 50, height: 70, fit: BoxFit.cover,
                                    errorBuilder: (c, e, sStr) => Container(width: 50, color: Colors.white10, child: const Icon(Icons.movie))))
                              : Container(width: 50, color: Colors.white10, child: const Icon(Icons.movie)),
                          title: Text(_isArabic ? fav.titleAr : fav.titleEn,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(fav.year, style: const TextStyle(color: _accent)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white24),
                                onPressed: () { _toggleFavorite(fav); Navigator.pop(context); _showFavorites(); },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  NAV ARROW
// ═══════════════════════════════════════════════════════════
class _NavArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered ? const Color(0xFFE50914).withOpacity(0.9) : Colors.black.withOpacity(0.5),
            border: Border.all(
              color: _hovered ? const Color(0xFFE50914) : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CONTACT TILE
// ═══════════════════════════════════════════════════════════
class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE50914).withOpacity(0.12)),
              child: Icon(icon, color: const Color(0xFFE50914), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 14),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MOVIE CARD WIDGET
// ═══════════════════════════════════════════════════════════
class _MovieCardWidget extends StatelessWidget {
  final MovieCard movie;
  final bool isFav;
  final VoidCallback onFavTap;
  final String trailerLabel;
  final bool isArabic;
  final String noTrailerMessage;
  final String trailerErrorMessage;
  final void Function(String) onShowMessage;
  final String seasonsLabel;
  final VoidCallback? onSeasonsTap;
  final String watchLabel;
  final VoidCallback? onWatchTap;

  const _MovieCardWidget({
    required this.movie, required this.isFav, required this.onFavTap,
    required this.trailerLabel, required this.isArabic,
    required this.noTrailerMessage, required this.trailerErrorMessage,
    required this.onShowMessage,
    required this.seasonsLabel, this.onSeasonsTap,
    required this.watchLabel, this.onWatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayTitle  = isArabic ? movie.titleAr  : movie.titleEn;
    final subTitle      = isArabic ? movie.titleEn  : movie.titleAr;
    final displayStory  = isArabic ? movie.story    : movie.storyEn;
    final displayGenres = isArabic ? movie.genres   : movie.genresEn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            movie.imageUrl.isNotEmpty
                ? Image.network(movie.imageUrl, fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(color: const Color(0xFF1A1A1A),
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFE50914), strokeWidth: 2)));
                    },
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1A1A1A),
                      child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 50))),
                  )
                : Container(color: const Color(0xFF1A1A1A),
                    child: const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 50))),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.95)],
                  stops: const [0.35, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 20, left: 20,
              child: GestureDetector(
                onTap: onFavTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                  child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFE50914), size: 26),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(movie.year, style: const TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(displayTitle,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                    textAlign: isArabic ? TextAlign.right : TextAlign.left),
                  if (subTitle.isNotEmpty && subTitle != displayTitle) ...[
                    const SizedBox(height: 4),
                    Text(subTitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (movie.trailerUrl.isNotEmpty)
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(movie.trailerUrl);
                              final launched = await canLaunchUrl(url);
                              if (launched) {
                                launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                onShowMessage(trailerErrorMessage);
                              }
                            },
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(trailerLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        )
                      else
                        // Previously the button silently disappeared with no
                        // explanation. Now it's visible but disabled with a
                        // clear message, instead of confusing the user.
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            onPressed: () => onShowMessage(noTrailerMessage),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: Text(trailerLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12, foregroundColor: Colors.white38,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (displayGenres.isNotEmpty)
                            Text(displayGenres, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                          if (displayGenres.isNotEmpty && movie.rating.isNotEmpty && movie.rating != 'N/A')
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•', style: TextStyle(color: Colors.white38))),
                          if (movie.rating.isNotEmpty && movie.rating != 'N/A')
                            Row(children: [
                              Text(movie.rating, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                            ]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(displayStory, maxLines: 3, overflow: TextOverflow.ellipsis,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.5)),
                  if (onSeasonsTap != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: onSeasonsTap,
                        icon: const Icon(Icons.video_library_rounded, size: 18, color: Colors.white),
                        label: Text(seasonsLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  if (onWatchTap != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: onWatchTap,
                        icon: const Icon(Icons.live_tv_rounded, size: 18, color: Colors.white),
                        label: Text(watchLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SEASON / EPISODE MODELS
// ═══════════════════════════════════════════════════════════
class SeasonInfo {
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String posterPath;
  final String overview;

  SeasonInfo({
    required this.seasonNumber, required this.name,
    required this.episodeCount, required this.posterPath,
    required this.overview,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
    seasonNumber: j['season_number'] ?? 0,
    name: j['name'] ?? '',
    episodeCount: j['episode_count'] ?? 0,
    posterPath: j['poster_path'] ?? '',
    overview: j['overview'] ?? '',
  );
}

class EpisodeInfo {
  final int episodeNumber;
  final String name;
  final String overview;
  final String stillPath;
  final String airDate;
  final double rating;

  EpisodeInfo({
    required this.episodeNumber, required this.name,
    required this.overview,      required this.stillPath,
    required this.airDate,       required this.rating,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> j) => EpisodeInfo(
    episodeNumber: j['episode_number'] ?? 0,
    name: j['name'] ?? '',
    overview: j['overview'] ?? '',
    stillPath: j['still_path'] ?? '',
    airDate: j['air_date'] ?? '',
    rating: (j['vote_average'] ?? 0.0).toDouble(),
  );
}

// ═══════════════════════════════════════════════════════════
//  SEASONS SCREEN
// ═══════════════════════════════════════════════════════════
class SeasonsScreen extends StatefulWidget {
  final int tmdbId;
  final String showTitle;
  final bool isArabic;

  const SeasonsScreen({
    super.key, required this.tmdbId,
    required this.showTitle, required this.isArabic,
  });

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  static const Color _accent = Color(0xFFE50914);
  static const Color _darkBg = Color(0xFF050505);

  List<SeasonInfo> _seasons = [];
  bool _isLoading = true;
  bool _hasError = false;

  AppStrings get s => AppStrings(widget.isArabic);

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    try {
      final lang = widget.isArabic ? 'ar' : 'en-US';
      final res = await http.get(Uri.parse(
        '${ApiConfig.apiBase}/tmdb/tv/${widget.tmdbId}?language=$lang',
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final seasonsJson = (data['seasons'] as List?) ?? [];
        final seasons = seasonsJson
            .map((j) => SeasonInfo.fromJson(j))
            .where((season) => season.seasonNumber > 0) // hide "Specials"
            .toList();
        if (!mounted) return;
        setState(() { _seasons = seasons; _isLoading = false; });
      } else {
        debugPrint('Seasons load failed: HTTP ${res.statusCode}');
        if (!mounted) return;
        setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      debugPrint('Seasons load error: $e');
      if (!mounted) return;
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        title: Text(widget.showTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ResponsiveShell(child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _accent, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(s.loadingSeasons, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            )
          : _hasError || _seasons.isEmpty
              ? Center(
                  child: Text(
                    s.seasonsLoadError,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _seasons.length,
                  itemBuilder: (context, index) {
                    final season = _seasons[index];
                    return _SeasonTile(
                      season: season,
                      isArabic: widget.isArabic,
                      episodesLabel: s.episodes,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EpisodesScreen(
                            tmdbId: widget.tmdbId,
                            seasonNumber: season.seasonNumber,
                            showTitle: widget.showTitle,
                            seasonName: season.name,
                            isArabic: widget.isArabic,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}

class _SeasonTile extends StatelessWidget {
  final SeasonInfo season;
  final bool isArabic;
  final String episodesLabel;
  final VoidCallback onTap;

  const _SeasonTile({
    required this.season, required this.isArabic,
    required this.episodesLabel, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: season.posterPath.isNotEmpty
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w200${season.posterPath}',
                      width: 80, height: 110, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80, height: 110, color: Colors.white10,
                        child: const Icon(Icons.tv_rounded, color: Colors.white24),
                      ),
                    )
                  : Container(
                      width: 80, height: 110, color: Colors.white10,
                      child: const Icon(Icons.tv_rounded, color: Colors.white24),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(season.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: isArabic ? TextAlign.right : TextAlign.left),
                    const SizedBox(height: 6),
                    Text('${season.episodeCount} $episodesLabel',
                      style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                isArabic ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EPISODES SCREEN
// ═══════════════════════════════════════════════════════════
class EpisodesScreen extends StatefulWidget {
  final int tmdbId;
  final int seasonNumber;
  final String showTitle;
  final String seasonName;
  final bool isArabic;

  const EpisodesScreen({
    super.key, required this.tmdbId, required this.seasonNumber,
    required this.showTitle, required this.seasonName, required this.isArabic,
  });

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  static const Color _accent = Color(0xFFE50914);
  static const Color _darkBg = Color(0xFF050505);

  List<EpisodeInfo> _episodes = [];
  bool _isLoading = true;
  bool _hasError = false;

  AppStrings get s => AppStrings(widget.isArabic);

  @override
  void initState() {
    super.initState();
    _loadEpisodes();
  }

  Future<void> _loadEpisodes() async {
    try {
      final lang = widget.isArabic ? 'ar' : 'en-US';
      final res = await http.get(Uri.parse(
        '${ApiConfig.apiBase}/tmdb/tv/${widget.tmdbId}/season/${widget.seasonNumber}?language=$lang',
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final episodesJson = (data['episodes'] as List?) ?? [];
        final episodes = episodesJson.map((j) => EpisodeInfo.fromJson(j)).toList();
        if (!mounted) return;
        setState(() { _episodes = episodes; _isLoading = false; });
      } else {
        debugPrint('Episodes load failed: HTTP ${res.statusCode}');
        if (!mounted) return;
        setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      debugPrint('Episodes load error: $e');
      if (!mounted) return;
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF1A1A1A), behavior: SnackBarBehavior.floating),
    );
  }


  bool _isResolvingLink = false;

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        title: Text('${widget.showTitle} • ${widget.seasonName}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ResponsiveShell(child: Stack(
        children: [
          _buildBody(),
          if (_isResolvingLink)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: _accent, strokeWidth: 3),
                    const SizedBox(height: 16),
                    Text(
                      widget.isArabic ? 'جاري تجهيز رابط المشاهدة...' : 'Preparing the watch link...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      )),
    );
  }
  Widget _buildBody() {
    return _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: _accent, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(s.loadingEpisodes, style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ],
              ),
            )
          : _hasError || _episodes.isEmpty
              ? Center(child: Text(s.episodesLoadError, style: const TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _episodes.length,
                  itemBuilder: (context, index) {
                    final episode = _episodes[index];
                    return _EpisodeTile(
                      episode: episode,
                      isArabic: widget.isArabic,
                      episodeLabel: s.episode,
                      watchLabel: s.watchEpisode,
                      noOverviewLabel: s.noOverview,
                     onTap: () => PlayerEngine.instance.openEpisode(context, widget.tmdbId, widget.seasonNumber, episode.episodeNumber),
                    );
                  },
                );
  }
}

class _EpisodeTile extends StatelessWidget {
  final EpisodeInfo episode;
  final bool isArabic;
  final String episodeLabel;
  final String watchLabel;
  final String noOverviewLabel;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode, required this.isArabic,
    required this.episodeLabel, required this.watchLabel,
    required this.noOverviewLabel, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overview = episode.overview.trim().isNotEmpty ? episode.overview : noOverviewLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: episode.stillPath.isNotEmpty
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white10,
                          child: const Icon(Icons.tv_rounded, color: Colors.white24, size: 32),
                        ),
                      )
                    : Container(
                        color: Colors.white10,
                        child: const Icon(Icons.tv_rounded, color: Colors.white24, size: 32),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('$episodeLabel ${episode.episodeNumber}: ${episode.name}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: isArabic ? TextAlign.right : TextAlign.left),
                      ),
                      if (episode.rating > 0) ...[
                        const SizedBox(width: 8),
                        Row(children: [
                          Text(episode.rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 3),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        ]),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(overview, maxLines: 2, overflow: TextOverflow.ellipsis,
                    textAlign: isArabic ? TextAlign.right : TextAlign.left,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (episode.airDate.isNotEmpty)
                        Text(episode.airDate, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE50914), size: 16),
                          const SizedBox(width: 4),
                          Text(watchLabel, style: const TextStyle(color: Color(0xFFE50914), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}