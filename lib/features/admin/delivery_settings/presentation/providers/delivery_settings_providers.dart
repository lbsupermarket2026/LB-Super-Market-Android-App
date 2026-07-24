import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/delivery_settings_datasource.dart';
import '../../domain/entities/delivery_settings_entity.dart';

final deliverySettingsDataSourceProvider = Provider<DeliverySettingsDataSource>((ref) {
  return DeliverySettingsDataSource();
});

final deliverySettingsProvider = FutureProvider.autoDispose<DeliverySettingsEntity>((ref) {
  return ref.watch(deliverySettingsDataSourceProvider).getSettings();
});

class DeliverySettingsMutationState {
  final bool isSubmitting;
  final String? error;
  const DeliverySettingsMutationState({this.isSubmitting = false, this.error});
}

class DeliverySettingsMutationNotifier extends StateNotifier<DeliverySettingsMutationState> {
  final Ref _ref;
  DeliverySettingsMutationNotifier(this._ref) : super(const DeliverySettingsMutationState());

  Future<bool> save(DeliverySettingsEntity settings) async {
    state = const DeliverySettingsMutationState(isSubmitting: true);
    try {
      await _ref.read(deliverySettingsDataSourceProvider).saveSettings(settings);
      state = const DeliverySettingsMutationState();
      _ref.invalidate(deliverySettingsProvider);
      return true;
    } catch (e) {
      state = DeliverySettingsMutationState(error: e.toString());
      return false;
    }
  }
}

final deliverySettingsMutationProvider =
    StateNotifierProvider.autoDispose<DeliverySettingsMutationNotifier, DeliverySettingsMutationState>((ref) {
  return DeliverySettingsMutationNotifier(ref);
});
