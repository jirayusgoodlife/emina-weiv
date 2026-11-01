import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/in_app_stream_proxy.dart';
import 'services/isar_service.dart';
import 'providers/anime_catalog_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start internal In-App Stream Proxy (runs locally on 127.0.0.1 inside the phone)
  await InAppStreamProxy.instance.start();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121620),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final isarService = await IsarService.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AnimeCatalogProvider(
            isarService: isarService,
            prefs: prefs,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(
            prefs: prefs,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            prefs: prefs,
          ),
        ),
      ],
      child: const AnimeViewApp(),
    ),
  );
}

class AnimeViewApp extends StatelessWidget {
  const AnimeViewApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnimeView',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
