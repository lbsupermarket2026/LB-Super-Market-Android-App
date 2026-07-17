import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../offers/data/datasources/offer_cards_datasource.dart';
import '../../../../offers/domain/entities/offer_card_entity.dart';
import '../../../../offers/presentation/providers/offer_card_providers.dart';

final allOfferCardsAdminProvider = FutureProvider.autoDispose<List<OfferCardEntity>>((ref) {
  return ref.watch(offerCardsDataSourceProvider).getAllOfferCards();
});

class OfferCardMutationState {
  final bool isSubmitting;
  final String? error;
  const OfferCardMutationState({this.isSubmitting = false, this.error});
}

class OfferCardMutationNotifier extends StateNotifier<OfferCardMutationState> {
  final Ref _ref;
  OfferCardMutationNotifier(this._ref) : super(const OfferCardMutationState());

  void _refresh() {
    _ref.invalidate(allOfferCardsAdminProvider);
    _ref.invalidate(enabledOfferCardsProvider);
  }

  Future<bool> save({
    String? id,
    required OfferTemplate template,
    required String title,
    required String subtitle,
    String? highlightText,
    required bool isEnabled,
    int sortOrder = 0,
  }) async {
    state = const OfferCardMutationState(isSubmitting: true);
    try {
      final ds = _ref.read(offerCardsDataSourceProvider);
      if (id == null) {
        await ds.createOfferCard(
          template: template,
          title: title,
          subtitle: subtitle,
          highlightText: highlightText,
          isEnabled: isEnabled,
          sortOrder: sortOrder,
        );
      } else {
        await ds.updateOfferCard(
          id: id,
          template: template,
          title: title,
          subtitle: subtitle,
          highlightText: highlightText,
          isEnabled: isEnabled,
          sortOrder: sortOrder,
        );
      }
      state = const OfferCardMutationState();
      _refresh();
      return true;
    } catch (e) {
      state = OfferCardMutationState(error: e.toString());
      return false;
    }
  }

  Future<void> setEnabled(String id, bool isEnabled) async {
    await _ref.read(offerCardsDataSourceProvider).setEnabled(id, isEnabled);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _ref.read(offerCardsDataSourceProvider).deleteOfferCard(id);
    _refresh();
  }
}

final offerCardMutationProvider =
    StateNotifierProvider.autoDispose<OfferCardMutationNotifier, OfferCardMutationState>((ref) {
  return OfferCardMutationNotifier(ref);
});
