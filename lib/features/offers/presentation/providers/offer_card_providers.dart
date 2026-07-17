import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/offer_cards_datasource.dart';
import '../../domain/entities/offer_card_entity.dart';

final offerCardsDataSourceProvider = Provider<OfferCardsDataSource>((ref) {
  return OfferCardsDataSource();
});

/// What Home actually displays — enabled cards only.
final enabledOfferCardsProvider = FutureProvider.autoDispose<List<OfferCardEntity>>((ref) {
  return ref.watch(offerCardsDataSourceProvider).getEnabledOfferCards();
});
