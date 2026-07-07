import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/faq_entity.dart';

class LegalRemoteDataSource {
  final FirebaseFirestore _firestore;
  LegalRemoteDataSource({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection(FirestorePaths.adminConfig);

  Future<String> _getContent(String docId, {required String fallback}) async {
    final doc = await _collection.doc(docId).get();
    return (doc.data()?['content'] as String?) ?? fallback;
  }

  Future<String> getTermsConditions() =>
      _getContent(FirestorePaths.adminConfigTermsConditions, fallback: 'Terms & Conditions content coming soon.');

  Future<String> getPrivacyPolicy() =>
      _getContent(FirestorePaths.adminConfigPrivacyPolicy, fallback: 'Privacy Policy content coming soon.');

  Future<String> getRefundPolicy() =>
      _getContent(FirestorePaths.adminConfigRefundPolicy, fallback: 'Refund Policy content coming soon.');

  Future<List<FaqEntity>> getFaqs() async {
    final doc = await _collection.doc(FirestorePaths.adminConfigFaqs).get();
    final rawItems = (doc.data()?['items'] as List<dynamic>?) ?? const [];
    final faqs = rawItems
        .cast<Map<String, dynamic>>()
        .map((f) => FaqEntity(
              question: (f['question'] as String?) ?? '',
              answer: (f['answer'] as String?) ?? '',
              sortOrder: (f['sortOrder'] as num?)?.toInt() ?? 0,
            ))
        .where((f) => f.question.isNotEmpty)
        .toList();
    faqs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return faqs;
  }
}