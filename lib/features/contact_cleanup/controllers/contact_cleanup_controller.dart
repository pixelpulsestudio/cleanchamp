// File: lib/features/contact_cleanup/controllers/contact_cleanup_controller.dart
import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/model/contact_item.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/analytics_service.dart';

class ContactCleanupController extends ChangeNotifier {
  final FileService _fileService = serviceLocator<FileService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();

  List<ContactGroup> _duplicateGroups = [];
  bool _isLoading = false;
  String? _error;

  // Cache contacts to avoid repeated fetching
  List<Contact>? _cachedContacts;

  List<ContactGroup> get duplicateGroups => _duplicateGroups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalDuplicates => _duplicateGroups.fold(0, (sum, group) => sum + group.contacts.length);

  Future<void> initialize() async {
    await _analyticsService.trackScreenView('contact_cleanup');

    final permissionStatus = await Permission.contacts.status;
    print('permission status $permissionStatus');
    if (!permissionStatus.isGranted) {
      final result = await Permission.contacts.request();
      if (!result.isGranted) {
        _error = 'Contacts permission denied.';
        notifyListeners();
        return;
      }
    }

    await loadDuplicateContacts();
  }

  Future<void> loadDuplicateContacts() async {
    _setLoading(true);
    try {
      if (!await Permission.contacts.isGranted) {
        _error = 'Contacts permission not granted.';
        return;
      }

      // Cache contacts for efficient operations
      _cachedContacts = await ContactsService.getContacts();
      _duplicateGroups = await _fileService.getDuplicateContacts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> mergeGroup(ContactGroup group) async {
    try {
      await _analyticsService.trackUserBehavior('merge_contact_group');

      // Perform actual merge operation
      await _performContactMerge(group);

      // Remove from local list after successful merge
      _duplicateGroups.remove(group);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to merge contacts: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> keepBestContact(ContactGroup group) async {
    try {
      await _analyticsService.trackUserBehavior('keep_best_contact');

      // Perform actual keep best operation
      await _performKeepBestContact(group);

      // Remove from local list after successful operation
      _duplicateGroups.remove(group);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to keep best contact: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<void> mergeAllGroups() async {
    _setLoading(true);
    try {
      final totalContacts = totalDuplicates;
      await _analyticsService.trackCleanupAction('contacts', totalContacts, 0);

      // Process each group with error handling
      final groupsCopy = List<ContactGroup>.from(_duplicateGroups);
      int successCount = 0;
      int failureCount = 0;

      for (final group in groupsCopy) {
        try {
          await _performContactMerge(group);
          successCount++;
        } catch (e) {
          print('Failed to merge group ${group.name}: $e');
          failureCount++;
        }
      }

      // Clear the list after processing
      _duplicateGroups.clear();
      _error = failureCount > 0
          ? 'Completed with $failureCount failures out of ${groupsCopy.length} groups'
          : null;

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshDuplicates() async {
    await _analyticsService.trackUserBehavior('refresh_duplicate_contacts');
    _cachedContacts = null; // Clear cache to force refresh
    await loadDuplicateContacts();
  }

  /// Performs the actual contact merge operation using a safer approach
  Future<void> _performContactMerge(ContactGroup group) async {
    if (group.contacts.isEmpty || _cachedContacts == null) return;

    try {
      // Instead of updating contacts (which is problematic), we'll delete duplicates
      // and keep only the best contact

      final bestContactItem = _getBestContact(group);
      final contactsToDelete = group.contacts.where((c) => c.id != bestContactItem.id).toList();

      // Find the corresponding Contact objects from cache
      final contactsToDeleteObjects = <Contact>[];

      for (final contactItem in contactsToDelete) {
        final contact = _findContactById(contactItem.id);
        if (contact != null) {
          contactsToDeleteObjects.add(contact);
        }
      }

      // Delete the duplicate contacts one by one with error handling
      for (final contact in contactsToDeleteObjects) {
        try {
          await ContactsService.deleteContact(contact);
          // Remove from cache
          _cachedContacts?.removeWhere((c) => c.identifier == contact.identifier);
        } catch (e) {
          print('Failed to delete contact ${contact.displayName}: $e');
          // Continue with other contacts even if one fails
        }
      }

    } catch (e) {
      throw Exception('Failed to merge contacts: $e');
    }
  }

  /// Performs the keep best contact operation
  Future<void> _performKeepBestContact(ContactGroup group) async {
    if (group.contacts.isEmpty || _cachedContacts == null) return;

    try {
      // Get the best contact
      final bestContactItem = _getBestContact(group);
      final contactsToDelete = group.contacts.where((c) => c.id != bestContactItem.id).toList();

      // Find the corresponding Contact objects from cache
      final contactsToDeleteObjects = <Contact>[];

      for (final contactItem in contactsToDelete) {
        final contact = _findContactById(contactItem.id);
        if (contact != null) {
          contactsToDeleteObjects.add(contact);
        }
      }

      // Delete all contacts except the best one
      for (final contact in contactsToDeleteObjects) {
        try {
          await ContactsService.deleteContact(contact);
          // Remove from cache
          _cachedContacts?.removeWhere((c) => c.identifier == contact.identifier);
        } catch (e) {
          print('Failed to delete contact ${contact.displayName}: $e');
          // Continue with other contacts even if one fails
        }
      }

    } catch (e) {
      throw Exception('Failed to keep best contact: $e');
    }
  }

  /// Alternative merge approach: Create a new contact with merged data and delete all duplicates
  Future<void> _performAdvancedMerge(ContactGroup group) async {
    if (group.contacts.isEmpty || _cachedContacts == null) return;

    try {
      // Collect all data from all contacts in the group
      final allContacts = group.contacts
          .map((item) => _findContactById(item.id))
          .where((contact) => contact != null)
          .cast<Contact>()
          .toList();

      if (allContacts.isEmpty) return;

      // Create merged contact data
      final mergedData = _collectMergedData(group.contacts);

      // Create new contact with merged data
      final newContact = Contact(
        displayName: mergedData['name'] as String,
        phones: (mergedData['phones'] as Set<String>)
            .map((phone) => Item(label: 'mobile', value: phone))
            .toList(),
        emails: (mergedData['emails'] as Set<String>)
            .map((email) => Item(label: 'work', value: email))
            .toList(),
      );

      // Add the new merged contact
      await ContactsService.addContact(newContact);

      // Delete all original contacts
      for (final contact in allContacts) {
        try {
          await ContactsService.deleteContact(contact);
          // Remove from cache
          _cachedContacts?.removeWhere((c) => c.identifier == contact.identifier);
        } catch (e) {
          print('Failed to delete contact ${contact.displayName}: $e');
        }
      }

    } catch (e) {
      throw Exception('Failed to perform advanced merge: $e');
    }
  }

  /// Collects merged data from all contacts in a group
  Map<String, dynamic> _collectMergedData(List<ContactItem> contacts) {
    final phones = <String>{};
    final emails = <String>{};
    String bestName = '';

    for (final contact in contacts) {
      if (contact.name.isNotEmpty && contact.name.length > bestName.length) {
        bestName = contact.name;
      }

      if (contact.phone.isNotEmpty) {
        phones.add(contact.phone);
      }

      if (contact.email.isNotEmpty) {
        emails.add(contact.email);
      }
    }

    return {
      'name': bestName.isNotEmpty ? bestName : 'Merged Contact',
      'phones': phones,
      'emails': emails,
    };
  }

  /// Finds a contact in the cached list by ID
  Contact? _findContactById(String contactId) {
    if (_cachedContacts == null) return null;

    try {
      return _cachedContacts!.firstWhere(
            (contact) => contact.identifier == contactId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets the best contact from a group based on completeness score
  ContactItem _getBestContact(ContactGroup group) {
    return group.contacts.reduce((current, next) {
      int currentScore = _getContactScore(current);
      int nextScore = _getContactScore(next);
      return currentScore >= nextScore ? current : next;
    });
  }

  /// Calculates a score for a contact based on how complete it is
  int _getContactScore(ContactItem contact) {
    int score = 0;
    if (contact.name.isNotEmpty) score += 3;
    if (contact.phone.isNotEmpty) score += 2;
    if (contact.email.isNotEmpty) score += 2;
    if (contact.isComplete) score += 1;

    // Additional scoring factors
    if (contact.name.length > 3) score += 1; // Prefer longer names
    if (contact.phone.length > 10) score += 1; // Prefer complete phone numbers
    if (contact.email.contains('@') && contact.email.contains('.')) score += 1; // Valid email format

    return score;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}