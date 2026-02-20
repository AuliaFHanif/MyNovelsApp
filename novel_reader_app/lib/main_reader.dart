import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pocketbase_service.dart';
import 'services/reader_auth_service.dart';
import 'services/server_config_service.dart';
import 'views/reader/reader_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init server config first (loads saved URL from prefs)
  await ServerConfigService().init();

  // Point PocketBaseService at the saved URL
  PocketBaseService().initializeWithUrl(ServerConfigService().url);

  // Init auth & load persisted state
  await ReaderAuthService().init();

  runApp(const ReaderApp());
}

class ReaderApp extends StatelessWidget {
  const ReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ServerConfigService()),
        ChangeNotifierProvider.value(value: ReaderAuthService()),
      ],
      child: MaterialApp(
        title: 'Novel Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A1A1A),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFAF9F7),
          fontFamily: 'Inter',
        ),
        home: const ReaderHomeScreen(),
      ),
    );
  }
}
