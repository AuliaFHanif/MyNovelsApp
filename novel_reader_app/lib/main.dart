import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/pocketbase_service.dart';
import 'viewmodels/series_viewmodel.dart';
import 'viewmodels/chapter_viewmodel.dart';
import 'views/dashboard/dashboard_home.dart';
import 'viewmodels/translation_viewmodel.dart';
import 'viewmodels/feed_viewmodel.dart';

void main() {
  PocketBaseService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SeriesViewModel()),
        ChangeNotifierProvider(create: (_) => ChapterViewModel()),
        ChangeNotifierProvider(create: (_) => TranslationViewModel()),
        ChangeNotifierProvider(create: (_) => FeedViewModel()),  
      ],
      child: MaterialApp(
        title: 'Novel Reader',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const DashboardHome(),
      ),
    );
  }
}
