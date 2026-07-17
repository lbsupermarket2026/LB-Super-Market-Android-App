import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/offer_card_entity.dart';

class OfferCardsDataSource {
  final FirebaseFirestore _firestore;
  OfferCardsDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Uses the existing 'offers' collection — already covered by your
  // Firestore rules (public read, admin write) with no changes needed.
  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('offers');

  OfferCardEntity _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OfferCardEntity(
      id: doc.id,
      template: OfferTemplateX.fromString((data['template'] as String?) ?? 'custom'),
      title: (data['title'] as String?) ?? '',
      subtitle: (data['subtitle'] as String?) ?? '',
      highlightText: data['highlightText'] as String?,
      isEnabled: (data['isEnabled'] as bool?) ?? false,
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// Customer-facing — only enabled cards. No orderBy on the query
  /// itself (avoids yet another composite-index requirement); sorted
  /// client-side instead, same reasoning as the admin inventory list.
  Future<List<OfferCardEntity>> getEnabledOfferCards() async {
    final snapshot = await _collection.where('isEnabled', isEqualTo: true).get();
    final cards = snapshot.docs.map(_fromDoc).toList();
    cards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return cards;
  }

  /// Admin-facing — every card, enabled or not.
  Future<List<OfferCardEntity>> getAllOfferCards() async {
    final snapshot = await _collection.get();
    final cards = snapshot.docs.map(_fromDoc).toList();
    cards.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return cards;
  }

  Future<String> createOfferCard({
    required OfferTemplate template,
    required String title,
    required String subtitle,
    String? highlightText,
    bool isEnabled = true,
    int sortOrder = 0,
  }) async {
    final docRef = await _collection.add({
      'template': template.name,
      'title': title,
      'subtitle': subtitle,
      'highlightText': highlightText,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    });
    return docRef.id;
  }

  Future<void> updateOfferCard({
    required String id,
    required OfferTemplate template,
    required String title,
    required String subtitle,
    String? highlightText,
    required bool isEnabled,
    int sortOrder = 0,
  }) async {
    await _collection.doc(id).update({
      'template': template.name,
      'title': title,
      'subtitle': subtitle,
      'highlightText': highlightText,
      'isEnabled': isEnabled,
      'sortOrder': sortOrder,
    });
  }

  Future<void> setEnabled(String id, bool isEnabled) async {
    await _collection.doc(id).update({'isEnabled': isEnabled});
  }

  Future<void> deleteOfferCard(String id) async {
    await _collection.doc(id).delete();
  }
}
