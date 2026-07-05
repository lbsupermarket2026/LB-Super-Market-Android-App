enum Flavor { dev, staging, prod }

class EnvConfig {
  static Flavor flavor = Flavor.dev;

  static bool get isDev => flavor == Flavor.dev;
  static bool get isProd => flavor == Flavor.prod;

  static String get appTitleSuffix {
    switch (flavor) {
      case Flavor.dev:
        return ' (Dev)';
      case Flavor.staging:
        return ' (Staging)';
      case Flavor.prod:
        return '';
    }
  }
}
