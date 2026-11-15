import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anime_view/services/storage_service.dart';
import 'package:anime_view/models/isar_models.dart';
import 'package:anime_view/providers/anime_catalog_provider.dart';
import 'package:anime_view/services/isar_service.dart';

class _FakeIsarService implements IsarService {
  List<AnimeCollection> fakeAnime = [];
  List<AnimeCollection> fakeContinue = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<AnimeCollection>> getAllAnime() async => fakeAnime;

  @override
  Future<List<AnimeCollection>> getContinueWatching() async => fakeContinue;

  @override
  Future<SyncResult> syncFromLocalServer(String serverUrl) async {
    return SyncResult(success: true, message: 'Sync mock ok', animeCount: 0);
  }
}

void main() {
  group('DeviceStorageInfo Tests', () {
    test('Correctly calculates and formats storage sizes and percentages', () {
      const storage = DeviceStorageInfo(
        freeBytes: 30 * 1024 * 1024 * 1024, // 30 GB
        totalBytes: 100 * 1024 * 1024 * 1024, // 100 GB
      );

      expect(storage.isValid, isTrue);
      expect(storage.formattedFree, '30.0 GB');
      expect(storage.formattedTotal, '100.0 GB');
      expect(storage.formattedUsed, '70.0 GB');
      expect(storage.usedPercentage, closeTo(0.70, 0.01));
      expect(storage.freePercentage, closeTo(0.30, 0.01));
    });

    test('Handles MB formatting and zero bytes safely', () {
      const storageMB = DeviceStorageInfo(
        freeBytes: 500 * 1024 * 1024, // 500 MB
        totalBytes: 2 * 1024 * 1024 * 1024, // 2 GB
      );

      expect(storageMB.formattedFree, '500.0 MB');
      expect(storageMB.formattedTotal, '2.0 GB');

      const storageZero = DeviceStorageInfo(freeBytes: 0, totalBytes: 0);
      expect(storageZero.isValid, isFalse);
      expect(storageZero.formattedFree, '0 MB');
      expect(storageZero.formattedTotal, '0 MB');
    });
  });

  group('Hidden Anime Tab Tests in AnimeCatalogProvider', () {
    late SharedPreferences prefs;
    late _FakeIsarService isarService;
    late AnimeCatalogProvider provider;

    final anime1 = AnimeCollection()
      ..slug = 'one-piece'
      ..title = 'One Piece'
      ..genres = ['Action', 'Adventure'];

    final anime2 = AnimeCollection()
      ..slug = 'secret-movie'
      ..title = 'Secret Movie'
      ..genres = ['Drama'];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      isarService = _FakeIsarService()
        ..fakeAnime = [anime1, anime2]
        ..fakeContinue = [anime1, anime2];

      provider = AnimeCatalogProvider(
        isarService: isarService,
        prefs: prefs,
      );
      await provider.loadData();
    });

    test('Initially no anime is hidden and hidden tab is not in availableGenres', () {
      expect(provider.hiddenCount, 0);
      expect(provider.isAnimeHidden('secret-movie'), isFalse);
      expect(provider.availableGenres, isNot(contains(AnimeCatalogProvider.hiddenGenreName)));
      expect(provider.filteredAnime.length, 2);
    });

    test('Hiding an anime moves it to hidden list and exposes hidden tab', () async {
      await provider.hideAnime('secret-movie');
      expect(provider.hiddenCount, 1);
      expect(provider.isAnimeHidden('secret-movie'), isTrue);
      expect(provider.availableGenres, contains(AnimeCatalogProvider.hiddenGenreName));

      // In normal 'ทั้งหมด' tab: secret-movie is hidden
      expect(provider.selectedGenre, 'ทั้งหมด');
      expect(provider.filteredAnime.map((a) => a.slug), isNot(contains('secret-movie')));
      expect(provider.filteredAnime.map((a) => a.slug), contains('one-piece'));
      expect(provider.continueWatching.map((a) => a.slug), isNot(contains('secret-movie')));

      // In 'ที่ซ่อนอยู่' tab: secret-movie is shown and normal anime are excluded
      provider.selectHiddenTab();
      expect(provider.isHiddenTabSelected, isTrue);
      expect(provider.filteredAnime.length, 1);
      expect(provider.filteredAnime.first.slug, 'secret-movie');
      expect(provider.continueWatching.length, 1);
      expect(provider.continueWatching.first.slug, 'secret-movie');

      // Unhiding restores normal visibility
      await provider.unhideAnime('secret-movie');
      expect(provider.hiddenCount, 0);
      expect(provider.availableGenres, isNot(contains(AnimeCatalogProvider.hiddenGenreName)));
      expect(provider.selectedGenre, 'ทั้งหมด');
      expect(provider.filteredAnime.length, 2);
    });
  });
}
