// File: lib/core/services/service_locator.dart


import 'package:cleanchamp/core/services/storage_service.dart';
import 'package:get_it/get_it.dart';

import 'ai_service.dart';
import 'analytics_service.dart';
import 'file_service.dart';

final GetIt serviceLocator = GetIt.instance;

class ServiceLocator {
  static Future<void> initialize() async {
    // Register services
    serviceLocator.registerLazySingleton<StorageService>(() => StorageService());
    serviceLocator.registerLazySingleton<AIService>(() => AIService());
    serviceLocator.registerLazySingleton<FileService>(() => FileService(StorageService()));
    serviceLocator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

    // Initialize services that need initialization
    await serviceLocator<StorageService>().getStorageInfo();
    await serviceLocator<FileService>().getDuplicateContacts();
    // Remove AI service initialization as it requires photos parameter
  }
}