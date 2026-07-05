import 'core/config/env_config.dart';
import 'main.dart' as base;

/// Run with: flutter run -t lib/main_prod.dart
Future<void> main() async {
  EnvConfig.flavor = Flavor.prod;
  await base.bootstrap();
}
