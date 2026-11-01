import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/isar_models.dart';
import '../models/watch_progress.dart';
import '../services/isar_service.dart';

class AnimeCatalogProvider extends ChangeNotifier {
  final IsarService _isarService;
  final SharedPreferences _prefs;

  List<AnimeCollection> _allAnime = [];
  List<AnimeCollection> _continueWatching = [];
  String _selectedGenre = 'ทั้งหมด';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _lastSyncMessage;
  String _serverUrl = 'http://127.0.0.1:8800';

  final Map<String, Map<String, EpisodeProgress>> _watchProgressCache = {};
  Set<String> _hiddenSlugs = {};

  static const String _prefServerUrlKey = 'pref_sync_server_url';
  static const String _prefHiddenSlugsKey = 'pref_hidden_anime_slugs';

  AnimeCatalogProvider({
    required IsarService isarService,
    required SharedPreferences prefs,
  })  : _isarService = isarService,
        _prefs = prefs {
    _serverUrl = _prefs.getString(_prefServerUrlKey) ?? 'http://127.0.0.1:8800';
    _hiddenSlugs = (_prefs.getStringList(_prefHiddenSlugsKey) ?? []).toSet();
    loadData();
  }

  List<AnimeCollection> get allAnime => _allAnime;
  List<AnimeCollection> get continueWatching =>
      _continueWatching.where((a) => !_hiddenSlugs.contains(a.slug)).toList();
  String get selectedGenre => _selectedGenre;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get lastSyncMessage => _lastSyncMessage;
  String get serverUrl => _serverUrl;

  bool isAnimeHidden(String slug) => _hiddenSlugs.contains(slug);
  List<AnimeCollection> get hiddenAnime =>
      _allAnime.where((a) => _hiddenSlugs.contains(a.slug)).toList();
  int get hiddenCount => _hiddenSlugs.length;

  Future<void> hideAnime(String slug) async {
    _hiddenSlugs.add(slug);
    await _prefs.setStringList(_prefHiddenSlugsKey, _hiddenSlugs.toList());
    notifyListeners();
  }

  Future<void> unhideAnime(String slug) async {
    _hiddenSlugs.remove(slug);
    await _prefs.setStringList(_prefHiddenSlugsKey, _hiddenSlugs.toList());
    notifyListeners();
  }

  Future<void> unhideAll() async {
    _hiddenSlugs.clear();
    await _prefs.remove(_prefHiddenSlugsKey);
    notifyListeners();
  }

  List<String> get availableGenres {
    final set = <String>{'ทั้งหมด'};
    for (final a in _allAnime.where((a) => !_hiddenSlugs.contains(a.slug))) {
      set.addAll(a.genres);
    }
    return set.toList();
  }

  List<AnimeCollection> get filteredAnime {
    return _allAnime.where((anime) {
      if (_hiddenSlugs.contains(anime.slug)) return false;
      final matchesGenre = _selectedGenre == 'ทั้งหมด' || anime.genres.contains(_selectedGenre);
      final matchesSearch = _searchQuery.isEmpty ||
          anime.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (anime.synopsis?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesGenre && matchesSearch;
    }).toList();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _allAnime = await _isarService.getAllAnime();
    _continueWatching = await _isarService.getContinueWatching();

    // If Isar is completely empty on first launch, auto-sync from local server
    if (_allAnime.isEmpty) {
      await syncNow();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SyncResult> syncNow([String? customUrl]) async {
    final targetUrl = customUrl ?? _serverUrl;
    _isSyncing = true;
    _lastSyncMessage = null;
    notifyListeners();

    final result = await _isarService.syncFromLocalServer(targetUrl);
    _lastSyncMessage = result.message;

    if (result.success) {
      _allAnime = await _isarService.getAllAnime();
      _continueWatching = await _isarService.getContinueWatching();
    }

    _isSyncing = false;
    _isLoading = false;
    notifyListeners();
    return result;
  }

  Future<void> setServerUrl(String url) async {
    String clean = url.trim();
    if (clean.endsWith('/api/sync')) {
      clean = clean.substring(0, clean.length - '/api/sync'.length);
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    _serverUrl = clean;
    await _prefs.setString(_prefServerUrlKey, _serverUrl);
    notifyListeners();
  }

  void setSelectedGenre(String genre) {
    _selectedGenre = genre;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Map<String, EpisodeProgress> getAnimeEpisodeProgress(String slug) {
    if (_watchProgressCache.containsKey(slug)) {
      return _watchProgressCache[slug]!;
    }
    final raw = _prefs.getString('anime_progress_$slug');
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final map = <String, EpisodeProgress>{};
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            map[key] = EpisodeProgress.fromJson(val);
          }
        });
        _watchProgressCache[slug] = map;
        return map;
      } catch (_) {}
    }
    _watchProgressCache[slug] = {};
    return _watchProgressCache[slug]!;
  }

  EpisodeProgress? getEpisodeProgress(String slug, String episodeId) {
    final map = getAnimeEpisodeProgress(slug);
    return map[episodeId];
  }

  Future<void> updateWatchProgress({
    required String slug,
    required String episodeId,
    required int positionSeconds,
    int durationSeconds = 0,
    bool forceCompleted = false,
  }) async {
    final isCompleted = forceCompleted ||
        (durationSeconds > 0 && positionSeconds >= (durationSeconds * 0.90));

    final map = getAnimeEpisodeProgress(slug);
    final existing = map[episodeId];
    final effectiveDur = durationSeconds > 0 ? durationSeconds : (existing?.durationSeconds ?? 0);

    map[episodeId] = EpisodeProgress(
      positionSeconds: positionSeconds,
      durationSeconds: effectiveDur,
      isCompleted: isCompleted,
      updatedAt: DateTime.now(),
    );

    // Persist to SharedPreferences
    final jsonMap = <String, dynamic>{};
    map.forEach((k, v) => jsonMap[k] = v.toJson());
    await _prefs.setString('anime_progress_$slug', jsonEncode(jsonMap));

    // Update Isar
    await _isarService.updatePlaybackProgress(
      slug: slug,
      episodeId: episodeId,
      positionSeconds: positionSeconds,
    );

    _continueWatching = await _isarService.getContinueWatching();
    _allAnime = await _isarService.getAllAnime();
    notifyListeners();
  }

  /// Remove anime from continue watching queue
  Future<void> removeFromContinueWatching(String slug, {bool clearEpisodeProgress = false}) async {
    await _isarService.removeFromContinueWatching(slug);
    if (clearEpisodeProgress) {
      await _prefs.remove('anime_progress_$slug');
      _watchProgressCache.remove(slug);
    }
    _continueWatching = await _isarService.getContinueWatching();
    _allAnime = await _isarService.getAllAnime();
    notifyListeners();
  }

  /// Restore continue watching state (e.g. for undo)
  Future<void> restoreContinueWatching({
    required String slug,
    required String? episodeId,
    required int? positionSeconds,
    required DateTime? lastWatchedAt,
  }) async {
    await _isarService.restoreContinueWatching(
      slug: slug,
      episodeId: episodeId,
      positionSeconds: positionSeconds,
      lastWatchedAt: lastWatchedAt,
    );
    _continueWatching = await _isarService.getContinueWatching();
    _allAnime = await _isarService.getAllAnime();
    notifyListeners();
  }

  int getResumeEpisodeIndex(AnimeCollection anime) {
    final episodes = anime.episodes;
    if (episodes.isEmpty) return 0;

    final lastEpId = anime.lastWatchedEpisodeId;
    if (lastEpId == null) return 0;

    final idx = episodes.indexWhere((e) => e.id == lastEpId);
    if (idx == -1) return 0;

    final prog = getEpisodeProgress(anime.slug, lastEpId);
    // If the last watched episode is already finished (>=90%) and there is a next episode, suggest next
    if (prog?.isCompleted == true && idx < episodes.length - 1) {
      return idx + 1;
    }

    return idx;
  }

  Future<bool> deleteAnime(AnimeCollection anime, {bool deleteFromServer = true}) async {
    final slug = anime.slug;
    final id = anime.id;

    // 1. Delete from local Isar
    await _isarService.deleteAnime(id);

    // 2. Delete from server if requested and serverUrl is configured
    if (deleteFromServer && _serverUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('$_serverUrl/api/anime/$slug');
        await http.delete(uri).timeout(const Duration(seconds: 4));
      } catch (_) {
        // Continue even if server is offline
      }
    }

    // 3. Clean up preferences and hidden cache
    await _prefs.remove('anime_progress_$slug');
    _watchProgressCache.remove(slug);
    if (_hiddenSlugs.contains(slug)) {
      _hiddenSlugs.remove(slug);
      await _prefs.setStringList(_prefHiddenSlugsKey, _hiddenSlugs.toList());
    }

    // 4. Reload data
    _allAnime = await _isarService.getAllAnime();
    _continueWatching = await _isarService.getContinueWatching();
    notifyListeners();
    return true;
  }

  Future<void> deleteAnimeById(int id) async {
    await _isarService.deleteAnime(id);
    await loadData();
  }
}
