import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/legal_remote_datasource.dart';
import '../../domain/entities/faq_entity.dart';

final legalRemoteDataSourceProvider = Provider<LegalRemoteDataSource>((ref) {
  return LegalRemoteDataSource();
});

final termsConditionsProvider = FutureProvider<String>((ref) {
  return ref.watch(legalRemoteDataSourceProvider).getTermsConditions();
});

final privacyPolicyProvider = FutureProvider<String>((ref) {
  return ref.watch(legalRemoteDataSourceProvider).getPrivacyPolicy();
});

final refundPolicyProvider = FutureProvider<String>((ref) {
  return ref.watch(legalRemoteDataSourceProvider).getRefundPolicy();
});

final faqsProvider = FutureProvider<List<FaqEntity>>((ref) {
  return ref.watch(legalRemoteDataSourceProvider).getFaqs();
});