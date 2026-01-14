// File: lib/core/models/contact_item.dart
class ContactItem {
  final String id;
  final String name;
  final String phone;
  final String email;
  final bool isComplete;

  ContactItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.isComplete,
  });

  ContactItem copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    bool? isComplete,
  }) {
    return ContactItem(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class ContactGroup {
  final String name;
  final List<ContactItem> contacts;

  ContactGroup({
    required this.name,
    required this.contacts,
  });

  ContactGroup copyWith({
    String? name,
    List<ContactItem>? contacts,
  }) {
    return ContactGroup(
      name: name ?? this.name,
      contacts: contacts ?? this.contacts,
    );
  }
}