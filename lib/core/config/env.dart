import 'package:flutter/foundation.dart';

import 'app_config.dart';

class Env {
  static const String _envDefine = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static AppEnv get active {
    return switch (_envDefine) {
      'prod' => AppEnv.prod,
      'staging' => AppEnv.staging,
      _ => AppEnv.dev,
    };
  }

  static AppConfig get config {
    // Localized via --dart-define at build time; secrets are never embedded here.
    debugPrint('[Env] APP_ENV=${active.name}');
    return AppConfig.fromEnv(active);
  }
}
