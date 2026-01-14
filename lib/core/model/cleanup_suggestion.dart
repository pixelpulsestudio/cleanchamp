// File: lib/core/models/cleanup_suggestion.dart
class CleanupSuggestion {
  final String id;
  final String title;
  final String description;
  final double size;
  final CleanupType type;
  final Priority priority;
  final int itemCount;

  CleanupSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.size,
    required this.type,
    required this.priority,
    required this.itemCount,
  });

  CleanupSuggestion copyWith({
    String? id,
    String? title,
    String? description,
    double? size,
    CleanupType? type,
    Priority? priority,
    int? itemCount,
  }) {
    return CleanupSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      size: size ?? this.size,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}

enum CleanupType { photos, videos, contacts, documents, cache, other }
enum Priority { high, medium, low }