import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a custom inbox that groups multiple email accounts
class CustomInbox {
  final String id;
  final String name;
  final String companyId;
  final List<String> accountIds; // List of email account document IDs
  final int color; // Color value for the inbox icon
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomInbox({
    required this.id,
    required this.name,
    required this.companyId,
    required this.accountIds,
    this.color = 0xFF6366F1, // Default indigo
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomInbox.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomInbox(
      id: doc.id,
      name: data['name'] ?? '',
      companyId: data['companyId'] ?? '',
      accountIds: List<String>.from(data['accountIds'] ?? []),
      color: data['color'] ?? 0xFF6366F1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'companyId': companyId,
      'accountIds': accountIds,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CustomInbox copyWith({
    String? id,
    String? name,
    String? companyId,
    List<String>? accountIds,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomInbox(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      accountIds: accountIds ?? this.accountIds,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Service for managing custom inboxes in Firestore
class CustomInboxService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'customInboxes';

  /// Get all custom inboxes for a company
  static Stream<List<CustomInbox>> getInboxes(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
            final inboxes = snapshot.docs.map((doc) => CustomInbox.fromFirestore(doc)).toList();
            // Sort client-side to avoid needing a composite index
            inboxes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return inboxes;
        });
  }

  /// Get a single custom inbox by ID
  static Future<CustomInbox?> getInbox(String inboxId) async {
    final doc = await _firestore.collection(_collection).doc(inboxId).get();
    if (!doc.exists) return null;
    return CustomInbox.fromFirestore(doc);
  }

  /// Create a new custom inbox
  static Future<String> createInbox({
    required String name,
    required String companyId,
    required List<String> accountIds,
    int color = 0xFF6366F1,
  }) async {
    final now = DateTime.now();
    final inbox = CustomInbox(
      id: '',
      name: name,
      companyId: companyId,
      accountIds: accountIds,
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await _firestore.collection(_collection).add(inbox.toFirestore());
    return docRef.id;
  }

  /// Update an existing custom inbox
  static Future<void> updateInbox(CustomInbox inbox) async {
    await _firestore.collection(_collection).doc(inbox.id).update({
      'name': inbox.name,
      'accountIds': inbox.accountIds,
      'color': inbox.color,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Delete a custom inbox
  static Future<void> deleteInbox(String inboxId) async {
    await _firestore.collection(_collection).doc(inboxId).delete();
  }

  /// Add an account to a custom inbox
  static Future<void> addAccountToInbox(String inboxId, String accountId) async {
    await _firestore.collection(_collection).doc(inboxId).update({
      'accountIds': FieldValue.arrayUnion([accountId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remove an account from a custom inbox
  static Future<void> removeAccountFromInbox(String inboxId, String accountId) async {
    await _firestore.collection(_collection).doc(inboxId).update({
      'accountIds': FieldValue.arrayRemove([accountId]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
