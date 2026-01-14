// File: lib/core/routes/app_router.dart
import 'package:cleanchamp/features/photo_cleanup/views/tinder_photo_screen.dart';
import 'package:flutter/material.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/photo_cleanup/views/photo_cleanup_screen.dart';
import '../../features/video_cleanup/views/video_cleanup_screen.dart';
import '../../features/contact_cleanup/views/contact_cleanup_screen.dart';
import '../../features/storage_analysis/views/storage_analysis_screen.dart';
import '../../features/quick_clean/views/quick_clean_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String photoCleanup = '/photo-cleanup';
  static const String videoCleanup = '/video-cleanup';
  static const String contactCleanup = '/contact-cleanup';
  static const String storageAnalysis = '/storage-analysis';
  static const String quickClean = '/quick-clean';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _buildRoute(const HomeScreen());
      case photoCleanup:
        return _buildRoute(const TinderPhotoScreen());
      case videoCleanup:
        return _buildRoute(const VideoCleanupScreen());
      case contactCleanup:
        return _buildRoute(const ContactCleanupScreen());
      case storageAnalysis:
        return _buildRoute(const StorageAnalysisScreen());
      case quickClean:
        return _buildRoute(const QuickCleanScreen());
      default:
        return _buildRoute(
          const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          ),
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}