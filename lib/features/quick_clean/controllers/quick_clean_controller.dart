// File: lib/features/quick_clean/controllers/quick_clean_controller.dart
import 'package:flutter/material.dart';
import '../../../core/model/cleanup_suggestion.dart';
import '../../../core/model/photo_item.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/constants/app_constants.dart';

class QuickCleanController extends ChangeNotifier {
  final AIService _aiService = serviceLocator<AIService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();
  final FileService _fileService = serviceLocator<FileService>();

  List<CleanupSuggestion> _suggestions = [];
  List<CleanupSuggestion> _selectedSuggestions = [];
  List<PhotoItem> _photos = [];
  bool _isScanning = false;
  bool _isPerformingCleanup = false;
  double _scanProgress = 0.0;
  String _scanningStatus = 'Initializing scan...';
  String? _error;
  bool _isInitialized = false;

  List<CleanupSuggestion> get suggestions => _suggestions;
  List<CleanupSuggestion> get selectedSuggestions => _selectedSuggestions;
  List<PhotoItem> get photos => _photos;
  bool get isScanning => _isScanning;
  bool get isPerformingCleanup => _isPerformingCleanup;
  double get scanProgress => _scanProgress;
  String get scanningStatus => _scanningStatus;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  double get totalPotentialCleanup => _suggestions.fold(0.0, (sum, s) => sum + (s.size / (1024 * 1024 * 1024)));
  double get selectedCleanupSize => _selectedSuggestions.fold(0.0, (sum, s) => sum + (s.size / (1024 * 1024 * 1024)));

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _analyticsService.trackScreenView('quick_clean');
      _isInitialized = true;
      await startScan();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _error = null;
    _scanProgress = 0.0;
    _suggestions.clear();
    _selectedSuggestions.clear();
    notifyListeners();

    try {
      // Quick scan simulation for better UX
      await _performQuickScan();

      // Load photos asynchronously with limit
      _photos = await _fileService.getPhotos(limit: 50); // Reduced limit for better performance

      // Generate cleanup suggestions - run in background
      if (_photos.isNotEmpty) {
        _suggestions = await _generateMockSuggestions(); // Use mock data initially for speed
        // Optionally: await _aiService.generateCleanupSuggestions(_photos); for real analysis
      } else {
        _suggestions = [];
      }

      _error = null;
    } catch (e) {
      _error = 'Scan failed: ${e.toString()}';
      debugPrint('Quick clean scan error: $e');
    } finally {
      _isScanning = false;
      _scanProgress = 1.0;
      notifyListeners();
    }
  }

  Future<void> _performQuickScan() async {
    final steps = [
      'Analyzing photos...',
      'Checking for duplicates...',
      'Scanning large files...',
      'Analyzing storage...'
    ];

    for (int i = 0; i < steps.length; i++) {
      _scanningStatus = steps[i];
      _scanProgress = (i + 1) / steps.length;
      notifyListeners();

      // Reduced delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // Mock suggestions for instant results - replace with real logic
  Future<List<CleanupSuggestion>> _generateMockSuggestions() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      CleanupSuggestion(
        id: '1',
        title: 'Duplicate Photos',
        description: 'Remove identical photos to save space',
        type: CleanupType.photos,
        priority: Priority.high,
        size: 156 * 1024 * 1024, // 156 MB
        itemCount: 23,
      ),
      CleanupSuggestion(
        id: '2',
        title: 'Blurry Images',
        description: 'Delete low-quality and blurry photos',
        type: CleanupType.photos,
        priority: Priority.medium,
        size: 89 * 1024 * 1024, // 89 MB
        itemCount: 15,
      ),
      CleanupSuggestion(
        id: '3',
        title: 'Large Videos',
        description: 'Archive or compress large video files',
        type: CleanupType.videos,
        priority: Priority.low,
        size: 340 * 1024 * 1024, // 340 MB
        itemCount: 8,
      ),
    ];
  }

  void selectSuggestion(CleanupSuggestion suggestion) {
    if (!_selectedSuggestions.contains(suggestion)) {
      _selectedSuggestions.add(suggestion);
      notifyListeners();
    }
  }

  void deselectSuggestion(CleanupSuggestion suggestion) {
    _selectedSuggestions.remove(suggestion);
    notifyListeners();
  }

  void toggleSuggestion(CleanupSuggestion suggestion) {
    if (_selectedSuggestions.contains(suggestion)) {
      deselectSuggestion(suggestion);
    } else {
      selectSuggestion(suggestion);
    }
  }

  void selectAll() {
    _selectedSuggestions = List.from(_suggestions);
    notifyListeners();
  }

  void clearSelection() {
    _selectedSuggestions.clear();
    notifyListeners();
  }

  void selectHighPriority() {
    _selectedSuggestions = _suggestions.where((s) => s.priority == Priority.high).toList();
    notifyListeners();
  }

  Future<void> performCleanup() async {
    if (_selectedSuggestions.isEmpty || _isPerformingCleanup) return;

    _isPerformingCleanup = true;
    notifyListeners();

    try {
      final totalItems = _selectedSuggestions.fold(0, (sum, s) => sum + s.itemCount);
      final totalSize = selectedCleanupSize;

      await _analyticsService.trackCleanupAction('quick_clean', totalItems, totalSize);

      // Simulate cleanup process
      await Future.delayed(const Duration(seconds: 3));

      _suggestions.removeWhere((s) => _selectedSuggestions.contains(s));
      _selectedSuggestions.clear();
    } catch (e) {
      _error = 'Cleanup failed: ${e.toString()}';
    } finally {
      _isPerformingCleanup = false;
      notifyListeners();
    }
  }

  void reset() {
    _suggestions.clear();
    _selectedSuggestions.clear();
    _photos.clear();
    _isScanning = false;
    _isPerformingCleanup = false;
    _scanProgress = 0.0;
    _scanningStatus = 'Initializing scan...';
    _error = null;
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }
}