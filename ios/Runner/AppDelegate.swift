import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Must match the identifier registered from Dart
  /// (`BackgroundStatusWorker.uniqueTaskName`) and the
  /// `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist.
  private let statusPollTaskIdentifier =
    "com.soleux.sdm.statusPoll"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Ensures the native Flutter plugins (shared_preferences, etc.) are also
    // registered inside the background isolate that runs the status poll.
    SwiftWorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Register the BGAppRefreshTask used to poll module online/offline status
    // while the app is backgrounded (iOS 13+). The frequency is a hint only;
    // iOS schedules it per the user's usage pattern.
    SwiftWorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: statusPollTaskIdentifier,
      frequency: NSNumber(value: 15 * 60)
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
