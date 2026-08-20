enum AppEnv { dev, staging, prod }

class AppConfig {
  final AppEnv env;
  final String mqttHost;
  final int mqttPort;
  final bool mqttUseTls;
  final int lanCommandTimeoutMs;
  final int discoveryPort;
  final int eventLogRetentionDays;

  const AppConfig({
    required this.env,
    required this.mqttHost,
    required this.mqttPort,
    required this.mqttUseTls,
    required this.lanCommandTimeoutMs,
    required this.discoveryPort,
    required this.eventLogRetentionDays,
  });

  static AppConfig fromEnv(AppEnv env) {
    return switch (env) {
      AppEnv.dev => const AppConfig(
          env: AppEnv.dev,
          mqttHost: 'broker.local',
          mqttPort: 8883,
          mqttUseTls: true,
          lanCommandTimeoutMs: 300,
          discoveryPort: 5353,
          eventLogRetentionDays: 30,
        ),
      AppEnv.staging => const AppConfig(
          env: AppEnv.staging,
          mqttHost: 'staging-broker.example.com',
          mqttPort: 8883,
          mqttUseTls: true,
          lanCommandTimeoutMs: 300,
          discoveryPort: 5353,
          eventLogRetentionDays: 30,
        ),
      AppEnv.prod => const AppConfig(
          env: AppEnv.prod,
          mqttHost: 'broker.example.com',
          mqttPort: 8883,
          mqttUseTls: true,
          lanCommandTimeoutMs: 300,
          discoveryPort: 5353,
          eventLogRetentionDays: 30,
        ),
    };
  }
}
