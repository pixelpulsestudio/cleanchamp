// File: lib/main.dart
import 'package:cleanchamp/features/home/views/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/routes/app_router.dart';
import 'core/services/service_locator.dart';
import 'features/home/controllers/home_controller.dart';
import 'features/photo_cleanup/controllers/photo_cleanup_controller.dart';
import 'features/video_cleanup/controllers/video_cleanup_controller.dart';
import 'features/contact_cleanup/controllers/contact_cleanup_controller.dart';
import 'features/storage_analysis/controllers/storage_analysis_controller.dart';
import 'features/quick_clean/controllers/quick_clean_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await ServiceLocator.initialize();

  // Set system UI overlay style
 /* SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );*/

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeController()),
        ChangeNotifierProvider(create: (_) => PhotoCleanupController()),
        ChangeNotifierProvider(create: (_) => VideoCleanupController()),
        ChangeNotifierProvider(create: (_) => ContactCleanupController()),
        ChangeNotifierProvider(create: (_) => StorageAnalysisController()),
        ChangeNotifierProvider(create: (_) => QuickCleanController()),
      ],
      child: MaterialApp(
        title: 'Phone Cleaner Pro',
        theme: AppTheme.darkTheme,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRouter.home,
        debugShowCheckedModeBanner: false,
      ),

    );
  }
}