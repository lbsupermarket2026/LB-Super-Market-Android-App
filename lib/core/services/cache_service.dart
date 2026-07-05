import 'package:hive_flutter/hive_flutter.dart';

/// Opens every Hive box the app needs at startup. Call once in main()
/// before runApp(). Add a new `openBox` line here whenever a feature
/// introduces a new local cache (e.g. cart mirror, recently-viewed cache).
class CacheService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox('settings'); // theme mode, onboarding-seen flag, etc.
    await Hive.openBox('cartCache'); // offline mirror of carts/{uid}
    await Hive.openBox('recentlyViewedCache');
  }
}
