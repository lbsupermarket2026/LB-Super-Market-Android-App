import 'core/config/env_config.dart';
import 'main.dart' as base;

/// Run with: flutter run -t lib/main_dev.dart
/// Once you create a second Firebase project (lb-super-market-dev),
/// pass its FirebaseOptions here instead of the default.
Future<void> main() async {
  EnvConfig.flavor = Flavor.dev;
  await base.bootstrap();
}
