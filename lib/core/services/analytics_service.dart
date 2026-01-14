// File: lib/core/services/analytics_service.dart
import 'dart:async';

class AnalyticsService {
  Future<void> trackEvent(String eventName, {Map<String, dynamic>? parameters}) async {
    // Track analytics events
    print('Analytics: $eventName ${parameters ?? ''}');
  }

  Future<void> trackScreenView(String screenName) async {
    await trackEvent('screen_view', parameters: {'screen_name': screenName});
  }

  Future<void> trackCleanupAction(String type, int itemCount, double sizeFreed) async {
    await trackEvent('cleanup_action', parameters: {
      'type': type,
      'item_count': itemCount,
      'size_freed_gb': sizeFreed,
    });
  }

  Future<void> trackUserBehavior(String action, {Map<String, dynamic>? data}) async {
    await trackEvent('user_behavior', parameters: {
      'action': action,
      ...?data,
    });
  }
}