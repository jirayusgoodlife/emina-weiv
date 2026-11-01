import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/anime_grid_card.dart';
import '../widgets/anime_list_card.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final results = provider.filteredAnime;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textMain, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'ค้นหาชื่อเรื่อง, อนิเมะ, แนว...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: (val) => provider.setSearchQuery(val),
        ),
        actions: [
          IconButton(
            icon: Icon(
              settings.isListView ? Icons.grid_view : Icons.view_list,
              color: AppTheme.accent,
            ),
            tooltip: settings.isListView ? 'แสดงแบบ 3 เรื่องต่อแถว' : 'แสดงแบบรายการ',
            onPressed: () => settings.toggleViewMode(),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: AppTheme.textMuted),
              onPressed: () {
                _searchController.clear();
                provider.setSearchQuery('');
              },
            ),
        ],
      ),
      body: results.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.white24),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isEmpty
                        ? 'พิมพ์ชื่อเรื่องเพื่อค้นหา'
                        : 'ไม่พบเรื่องที่ตรงกับ "${_searchController.text}"',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                ],
              ),
            )
          : settings.isListView
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return AnimeListCard(anime: results[index]);
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    return AnimeGridCard(anime: results[index]);
                  },
                ),
    );
  }
}
