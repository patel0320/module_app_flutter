# Project Setup Guide â€” Relay, Dimming & Temperature Control Mobile Application

**Audience:** Mobile developer, DevOps, QA, Technical Lead  
**Applies to:** Android + iOS cross-platform, Flutter  
**Base reference:** `doc/description.md` (functional brief)

This guide drives a new developer or CI agent from a clean machine to a running build with local LAN control, remote MQTT fallback, cloud auth/backup/sync, push, and ROI/EN localization â€” aligned to the seven delivery stages.

---

## 1. Recommended Technology Stack with Justification

### 1.1 Cross-Platform Framework â€” Flutter (recommended)

| Need from brief | Flutter capability |
|-----------------|--------------------|
| One codebase, Android + iOS | Single Dart codebase; custom-compiled to native |
| Low-latency local TCP/IP + HTTP | `dart:io` `Socket`/`HttpServer`, `http`/`dio` with full control over timeouts, keepalive and reconnect |
| MQTT remote control | Mature `mqtt_client` package â€” TLS, QoS, retained topics, auto-reconnect |
| High-contrast minimalist UI with large controls | `CustomPainter`, gesture `ReorderableListView`, high-DPI vector rendering |
| Local-first, online/offline handling | Strong `Future`/`Stream` async model; local-first caching is idiomatic |
| Localization ROI/EN + future ES/FR/DE | `flutter_localizations` + ARB catalogs |

**Alternative:** React Native â€” larger JS/TS MQTT ecosystem but weaker ergonomics for the low-level typed socket/driver layer. **Decision: Flutter.**

### 1.2 State Management

**Choice:** **Riverpod** (with `flutter_riverpod`).

| Reason | Detail |
|--------|--------|
| Type-safe DI + reactivity | Fits module-driver registry and per-device state streams |
| Testability | Providers easily overridden with mock hardware drivers |
| Offline/online stream | Async providers map naturally to LAN/MQTT status streams |
| No BuildContext threading | Cleaner for driver/service singletons shared across tabs |

### 1.3 Local Storage

**Choices (layered):**

| Layer | Library | Used for |
|-------|---------|----------|
| Key-value / prefs | `shared_preferences` | UI prefs, language, onboarding flag |
| Local DB (device cache + offline queue) | `drift` (SQLite) | Offline command queue, cached device list, event-log buffer |
| Secure secrets | `flutter_secure_storage` | OAuth/MQTT tokens, refresh token (Keychain/Keystore) |

### 1.4 Networking and MQTT Clients

| Need | Package | Notes |
|------|---------|-------|
| REST / cloud calls | `dio` | Interceptors for auth token refresh; retry/backoff |
| MQTT | `mqtt_client` | TLS (wss/ssl), QoS 1, retained status, ordered reconnect |
| LAN socket | `dart:io` `Socket` | Driver base uses raw TCP for low-latency switch/dim |
| Local HTTP to modules | `http` | Module HTTP/JSON API and self-discovery broadcast listen |

### 1.5 Cloud Backend Services

| Service | Candidate | Purpose |
|---------|-----------|---------|
| Authentication | **Firebase Auth** (email/password) | Login, session, password recovery, token refresh |
| Database | **Cloud Firestore** or **Supabase Postgres** | Users, locations, modules, channels, inputs, scenarios, rooms, events, alerts |
| Backup/Restore | Firestore + Cloud Storage (or Supabase + bucket) | Encrypted config snapshots and full restore |
| Push notifications | **Firebase Cloud Messaging** (FCM â†’ Android + APNs on iOS) | Offline/alerts/output-on-for-long/temperature |
| Remote MQTT broker | Hosted broker (EMQX/Mosquitto) + Firestore for ACL | Per-user MQTT credentials for out-of-LAN control |

> **Backend smoke dependency:** Provision an auth project, a Firestore/Supabase project, an FCM project, and an MQTT broker namespace in Stage 4 before joining team integrations. Auth registration is mandatory before app use (per brief Â§3.1).

### 1.6 Local TCP/IP Communication Libraries

- `dart:io` `Socket` â€” primary raw TCP for relays/dimmers (millisecond control path).
- `package:http` â€” module HTTP/JSON API and discovery.
- `package:multicast_dns` / a UDP broadcast listener â€” receive each module's **self-discovery broadcast message** and identify it by **IP address** (brief Â§2.1).

---

## 2. Prerequisites and Development Environment Setup

### 2.1 Required SDKs and Tools

**All platforms**
- Git, Flutter SDK (stable channel, e.g. 3.x) via `flutter doctor`
- Dart SDK (bundled with Flutter)
- A code editor (VS Code + Flutter/Dart extensions, or Android Studio)

**Android**
- Android Studio (latest stable) with SDK Manager
- Android SDK Platform (API 34/35), Build Tools, Platform Tools
- Android emulator image (API 34 x86_64 Google APIs)
- JDK 17 (bundled with Android Studio) â€” confirm `ANDROID_HOME`/`JAVA_HOME`

**iOS (requires macOS)**
- Xcode (latest stable) with Command Line Tools
- CocoaPods (`sudo gem install cocoapods`)
- iOS Simulator runtimes (iOS 15+) â€” `xcrun simctl`
- Apple Developer Program membership for signing

### 2.2 IDE Setup

| Tool | Configuration |
|------|---------------|
| VS Code | Install Flutter, Dart, `flutter_secure_storage`(dev), `bloc`/`riverpod`, Beautify/Prettier, Error Lens |
| Android Studio | Name/Data/Entity + Plugin Manager: Flutter, Dart; SDK location confirmed; AVD Manager configured |
| Both | Enable `dart.formatOnSave`, `flutter_lints` in analyzer |

Verify with: `flutter doctor -v` (green for Android toolchain; iOS toolchain noted on macOS).

### 2.3 Emulator / Simulator Configuration

- **Android:** Create AVD (API 34, x86_64, 6â€“8 GB RAM) â†’ `flutter emulators --launch`. For LAN driver testing, use a **connectable physical device** instead.
- **iOS:** `open -a Simulator`, run `flutter run -d ios`; test ROI/EN by changing simulator language.
- **Physical testing:** enable Developer Options + USB debugging (Android); trust the developer certificate (iOS).

### 2.4 Hardware Testing Prerequisites

- Representative unit of each module type (right from Stage 3): standard relay, DC blind, DC dimmer (4Ã— DC outputs), AC dimmer (4Ã— AC 220V outputs), temperature module.
- Modules on a dedicated **test LAN** (router isolating device traffic) with known/static IPs.
- Bench supplies: 12â€“24V DC PSU, 220V AC source (with isolation for QA), DC/AC compatible bulbs/loads per brief.
- A Wi-Fi AP bridged so the phone and modules share the LAN for local TCP/API control.
- Loaned or emulated protocol fixtures if hardware delivery is delayed (Stage 3 risk).

---

## 3. Repository and Project Structure

### 3.1 Feature/Module Folder Structure

```
soleux_device_manager/
â”œâ”€â”€ analysis_options.yaml
â”œâ”€â”€ pubspec.yaml
â”œâ”€â”€ l10n.yaml
â”œâ”€â”€ .env.dev / .env.staging / .env.prod      # non-secret config
â”œâ”€â”€ android/                                  # Android host project
â”œâ”€â”€ ios/                                      # iOS host project
â”œâ”€â”€ docs/                                     # ADRs, protocol contracts, runbook
â”œâ”€â”€ scripts/                                  # ci helpers, localization sync
â””â”€â”€ lib/
    â”œâ”€â”€ main.dart
    â”œâ”€â”€ app.dart                              # root widget, theme, routes
    â”œâ”€â”€ bootstrap.dart                        # env loading, DI init
    â”œâ”€â”€ core/
    â”‚   â”œâ”€â”€ config/                           # env, build config
    â”‚   â”œâ”€â”€ network/                          # dio, auth interceptor, retry
    â”‚   â”œâ”€â”€ logger/                           # structured logging
    â”‚   â”œâ”€â”€ localization/                     # app_localizations, l10n init
    â”‚   â””â”€â”€ theme/                            # high-contrast tokens, controls
    â”œâ”€â”€ features/
    â”‚   â”œâ”€â”€ auth/                             # login, register, recovery
    â”‚   â”œâ”€â”€ home/                             # quick actions, alerts, temperature, rooms
    â”‚   â”œâ”€â”€ configuration/                    # discovery, module list, device detail
    â”‚   â”‚   â”œâ”€â”€ drivers/                      # MODULE DRIVER IMPLEMENTATIONS
    â”‚   â”‚   â”‚   â”œâ”€â”€ abci driver.dart          # abstract driver interface
    â”‚   â”‚   â”‚   â”œâ”€â”€ relay_driver.dart
    â”‚   â”‚   â”‚   â”œâ”€â”€ blind_driver.dart
    â”‚   â”‚   â”‚   â”œâ”€â”€ dc_dimmer_driver.dart
    â”‚   â”‚   â”‚   â”œâ”€â”€ ac_dimmer_driver.dart
    â”‚   â”‚   â”‚   â””â”€â”€ temperature_driver.dart
    â”‚   â”‚   â”œâ”€â”€ transport/                    # LanTransport, MqttTransport, failover
    â”‚   â”‚   â””â”€â”€ management/                   # channel/input editors, per-type UIs
    â”‚   â”œâ”€â”€ scenarios/                        # editor, run, IF/THEN, history
    â”‚   â”œâ”€â”€ rooms/                            # zone CRUD + grouping
    â”‚   â”œâ”€â”€ settings/                         # account, backup/restore, sync, notif, lang
    â”‚   â””â”€â”€ system_status/                    # error/event log view
    â”œâ”€â”€ data/
    â”‚   â”œâ”€â”€ models/                           # User, Location, Module, Channel, Input, Scenario...
    â”‚   â”œâ”€â”€ repositories/                     # cloud + local repositories
    â”‚   â”œâ”€â”€ databases/                        # drift table definitions, offline queue
    â”‚   â””â”€â”€ sources/                          # firebase, firestore, mqtt, socket, http
    â””â”€â”€ utils/                                # helpers, mappers, formatters
```

### 3.2 Naming Conventions

- **Dart files:** `snake_case.dart`; **classes/entities:** `PascalCase`; **instances/providers:** `camelCase`; **constants:** `UPPER_SNAKE_CASE`.
- **Folders:** lowercase `snake_case`, feature-first (`features/<feature>`).
- **Models:** suffix domain entities as-is (`Module`, `Channel`, `Scenario`, `ScenarioAction`).
- **Contract/type enums** (shared with hardware): suffix with `Type` (e.g., `ModuleType.relay/blind/dcDim/acDim/temperature`, `InputMode.momentary/toggle/associated`).
- **Branches:** `feature/<id>-<slug>`, `fix/<id>-<slug>`.
- Tests: `*_test.dart` co-located or under `test/`.

### 3.3 Environment Configuration Files

| File | Used for | Example binding |
|------|----------|-----------------|
| `.env.dev` | Local development, emulator, mock drivers | localhost / emulator API, mock broker, test auth project |
| `.env.staging` | Pre-release QA, staging Firebase/broker | staging auth/db/push |
| `.env.prod` | Release | production project IDs, production broker |
| `--dart-define` | Inject env at build time | `flutter run --dart-define=APP_ENV=dev` |

- Load via `flutter_dotenv` or `--dart-define`; **secrets never committed** â€” use CI secrets and a `getenv` layer.
- Separate Firebase project per environment using FlutterFire (alternative: Firebase App Distribution per env).

---

## 4. Dependencies and Package List

Add to `pubspec.yaml`. Versions shown as indicative stable pins â€” confirm latest at setup time.

| Purpose | Package | Notes |
|---------|---------|-------|
| Framework | `flutter` / `dart` | SDK |
| State management | `flutter_riverpod` + `riverpod_annotation` (+ `riverpod_generator` dev) | Providers + codegen |
| Local storage | `shared_preferences` | prefs |
| | `drift` + `sqlite3_flutter_libs` + `path_provider` | SQLite cache + offline queue |
| | `flutter_secure_storage` | tokens/credentials |
| MQTT | `mqtt_client` | TLS, QoS1, reconnect |
| TCP/IP socket | `dart:io` (core) â€” no package | raw sockets |
| HTTP/module API | `dio` + `http` | cloud + local HTTP |
| Discovery | `multicast_dns` or UDP broadcast listener | self-discovery broadcast |
| Cloud auth + DB | `firebase_core` + `firebase_auth` + `cloud_firestore` (or `supabase_flutter`) | mandatory account |
| Push | `firebase_messaging` + `flutter_local_notifications` | FCM/APNs |
| Localization | `flutter_localizations` + `intl` + `flutter_localized_locales` | ARB/RO-EN |
| Drag-and-drop | built-in `ReorderableListView` (+ `ReorderableDragStartListener`) | scenario ordering |
| Icons/UI | `cupertino_icons`; optional `google_fonts` | large clearly-delineated controls |
| Dev | `flutter_lints`, `mocktail`, `mockito`, `build_runner`, `flutter_test` | analysis + tests |
| CI/build env | `flutter_dotenv` | config injection |

**Dev-only (mock hardware harness):** `mocktail` for mock drivers; a `MockTransport` implementing the driver interface for development without hardware.

---

## 5. Hardware Communication Setup

### 5.1 Abstract Module Driver Interface

```dart
abstract class ModuleDriver {
  ModuleType get type;
  Future<bool> testConnection();                 // returns online status
  Stream<ChannelStatus> get statusStream;        // real-time state updates
  Future<void> setRelayOn(String channelId, bool on);
  Future<void> setDimmerBrightness(String channelId, int pct); // 0-100
  Future<void> blindMove(String channelId, BlindDir dir);      // up/down with toggle-stop
  Future<void> blindStop(String channelId);
  Future<double> readTemperature(String moduleId);            // internal temp Â°C
  Future<void> configure(ModuleConfig config);                // naming, icons, behaviour
  Future<void> configureInput(InputConfig input);             // momentary/toggle/associated
}
```

Implementations route through an injected `Transport` (LAN vs MQTT) so the driver logic is transport-agnostic and testable with `MockTransport`.

### 5.2 Per-ModuleType Implementations

| Driver | Key behaviour |
|--------|---------------|
| `RelayDriver` | On/off per output (~8); large direct-command button; polarity; interlock handling; poll status. |
| `BlindDriver` | Up/Down directional commands; **toggle-stop:** first press `UP` starts motor, second press `UP` stops it (same for `DOWN`); stop command with run-time awareness. |
| `DcDimmerDriver` | Dim 4 Ã— 12â€“24V PWM outputs; set brightness 0â€“100% (0=off, 100=on); fade time config. |
| `AcDimmerDriver` | Dim 4 Ã— 220V outputs; leading/trailing edge; fade; min-brightness cap. |
| `TemperatureDriver` | Read module **internal** temperature; thresholds low/high; emit `TemperatureAlert` events; sub/pub status. |

### 5.3 LAN TCP/IP Command Protocol Structure

Contract-freeze in Stage 3 from vendor docs; normalised here:

- **Envelope (JSON over TCP or HTTP body):** `{ "cmd": "<action>", "moduleId": "...", "channel": int, "value": <bool|int>, "requestId": "<uuid>" }`.
- **Reply/ACK:** `{ "requestId": ..., "status": "ok|error", "code": int, "data": ... }`.
- **Status push:** modules broadcast state changes (and self-discovery heartbeat) on a UDP/multicast channel the app listens to.
- **Discovery:** the app listens for each module's **self-discovery broadcast**, then adds it using its **IP address** (brief Â§2.1).
- Commands carry a short LAN timeout; mismatch â†’ failover to MQTT (see 5.5).

### 5.4 MQTT Topic Structure for Remote Control

```
<tenantId>/<locationId>/<moduleId>/status     # retained telemetry (online, channels, temp)
<tenantId>/<locationId>/<moduleId>/control    # commands (on/off, brightness, blind up/down/stop)
<tenantId>/<locationId>/<moduleId>/events     # offline/online, error, output-on-for-long
<tenantId>/<locationId>/<scenarioId>/run      # scenario trigger from cloud path
```

- Use QoS 1, retained status topics, TLS (wss/ssl) for remote clients; per-user credentials with read vs control ACLs.
- Same command payloads as LAN JSON envelope to keep drivers unified.

### 5.5 Automatic LAN â†” MQTT Fallback (`FailoverTransport`)

```
send(command):
  if lanReachable(module): return lan.send(command)     # quick, direct TCP/API
  else: return mqtt.publish(command)                     # remote path
```

- **Detection heartbeat:** per-module keepalive updates `DeviceStatus`; mark online/offline.
- **Preference:** always attempt LAN first on a short timeout (e.g., 300 ms), then MQTT.
- **Restore:** when LAN recovers, resume LAN preference and reconcile state (source `lan` beats `mqtt`).
- **Offline queue:** buffered commands in `drift` flushed on reconnect; event log records the transport used.

---

## 6. Cloud Backend Configuration

### 6.1 User Authentication Setup

- **Firebase (or Supabase) project** per env; enable **Email/Password** provider.
- Mandatory sign-up on first launch (brief Â§3.1); store `displayName` and `pushToken`; persist tokens via `flutter_secure_storage`.
- Password recovery: Firebase/Supabase built-in **email reset**; on password change, refresh tokens and invalidate old sessions.
- AuthRequired router guard: no authenticated user â‡’ redirect to Login/Register.

### 6.2 Database Schema (Cloud + superset of local cache)

| Collection | Key fields |
|------------|-----------|
| `users` | `uid`, `email`, `displayName`, `language`, `pushToken`, `preferences`, `createdAt` |
| `locations` | `id`, `ownerId`, `name`, `timezone`, `isPrimary`, `mqttConfig` (multi-location ready; v1 single) |
| `modules` | `id`, `locationId`, `roomId`, `type` (relay/blind/dcDim/acDim/temperature), `ip`, `mac`, `firmware`, `status`, `lastSeenAt` |
| `channels` | `id`, `moduleId`, `index`, `name`, `icon`, `enabled`, `behaviour` (outputs) |
| `inputs` | `id`, `moduleId`, `index`, `mode` (momentary/toggle/associated), `boundTargetType`, `boundTargetId` |
| `scenarios` | `id`, `locationId`, `roomId`, `name`, `icon`, `order`, `showInHome`, `type` (manual/slider/auto) |
| `scenario_actions` | `id`, `scenarioId`, `order`, `actionType`, `channelId`, `brightnessPct`, `trigger` (time/deviceState) |
| `rooms` | `id`, `locationId`, `name`, `order` |
| `event_logs` | `id`, `locationId`, `userId`, `type`, `entityId`, `payload`, `occurredAt` â€” **TTL 30 days** |
| `temperature_alerts` | `id`, `locationId`, `moduleId`, `minC`, `maxC`, `enabled`, `lastTriggeredAt` |
| `device_status` | `id`, `moduleId`, `channel`, `value`, `source` (lan/mqtt), `updatedAt` |

> **30-day retention:** Event logs use Firestore TTL policy (or scheduled cleanup) set to 30 days per brief Â§2.4.

### 6.3 Backup and Restore Flow

- **Backup:** on config change (debounced) and on demand, snapshot `locations+modules+channels+inputs+scenarios+rooms+temperature_alerts` to cloud; encrypt at rest (KMS) and in transit (TLS).
- **Restore:** after auth on a new device, pull full snapshot and rebuild local cache â€” "no reconfiguration effort, perfect transition" (brief Â§3.1). Validate ownership and integrity before applying.

### 6.4 Multi-Device Synchronization

- Per-entity `updatedAt` + `lastModifiedBy`; **last-write-wins** with an explicit conflict-resolution UI for overlapping edits.
- Deterministic client-generated IDs (UUID) to avoid duplicates across devices.
- Remote MQTT events and local LAN events converge via `device_status.source` + `lastCommandAt` merging.

---

## 7. Push Notification Setup

### 7.1 FCM/APNs Configuration

- Enable **FCM**; add generated **google-services.json** (Android) to `android/`, **GoogleService-Info.plist** (iOS) to `ios/` per env.
- iOS: enable **Push Notifications + Background Modes (remote notifications)** capability so APNs is reachable via FCM.
- Request permission on login success (or first Settings visit); persist and refresh `pushToken` on signin and token refresh.

### 7.2 Notification Triggers

| Trigger | Source | Payload hint |
|---------|--------|--------------|
| Module **offline / back online** | status heartbeat (LAN/MQTT `events`) | `{type:"module_status", moduleId, online}` |
| **Output left ON too long** | busy/timeout watcher on outputs | `{type:"output_long_on", moduleId, channel, minutes}` |
| **Temperature exceeded** | `TemperatureAlert` threshold monitor | `{type:"temperature", moduleId, value, min/max}` |
| Automation triggered (optional) | IF/THEN execution | `{type:"scenario_run", scenarioId}` |

### 7.3 Background Message Handling

- `FirebaseMessaging.onMessage` (foreground) â†’ local notification via `flutter_local_notifications`.
- `onMessageOpenedApp` / `onBackgroundMessage` â†’ deep-link to System Status (offline), Home (temperature/scenario).
- On message, refresh affected module state (was the module actually offline? did temp recover?).
- Handle both direct APNs and silent data messages; use dynamic token refresh + `vapidKey` for web consistency.

---

## 8. Localization Setup

### 8.1 Languages

- **Launch (v1):** Romanian (`ro`) and English (`en`) â€” brief Â§4.3.
- **Route ready:** Spanish (`es`), French (`fr`), German (`de`) added later with catalogs only (no code change).

### 8.2 ARB String Management

```
lib/l10n/app_en.arb
lib/l10n/app_ro.arb       (and later app_es.arb, app_fr.arb, app_de.arb)
```
- `l10n.yaml` configures `arb-dir`, `template-arb-file: app_en.arb`, output to `lib/l10n/gen`.
- Settings language picker maps to `MaterialApp(locale:, supportedLocales: [en, ro])`; default from device, override persisted in `shared_preferences`.
- Locale-aware date/time/number/temperature (Â°C) formatting via `intl`.

### 8.3 Ready for Future Languages

- String keys only in ARB; no inline text; provide descriptions for translators.
- Design for longer text (DE/FR) â€” flexible layouts, auto-shrink, no fixed-width assumptions.
- `flutter gen-l10n`/`generate: true` produces typed `AppLocalizations`; add catalogs for ES/FR/DE later without touching features.

---

## 9. Testing Strategy

### 9.1 Mock Hardware Drivers for Development

- `MockTransport` + `FakeModuleDriver` implementing the abstract interface, driven by a fixture JSON per module type.
- Mock MQTT broker topic fixture (subscribe/publish/retained) for offline dev.
- Enables full UI/state development before Stage 3 hardware arrives.

### 9.2 Unit Tests

- Scenario engine: multi-output, brightness %, slider, IF/THEN (time + device state).
- Driver command mapping (relay/blind/dimmer/temperature), toggle-stop logic for blinds.
- Failover ordering, offline queue flush, conflict resolution, temperature alert thresholds.

### 9.3 Widget Tests

- Home quick-access + drag-and-drop reorder (`ReorderableListView`), offline bannerâ†’System Status, temperature cards.
- Configuration: discovery list, online/offline dots, channel/input editors, per-type UIs.
- Scenarios, rooms grouping, settings/account, ROI/EN layout overflow checks.

### 9.4 Integration Tests with Real Modules

- End-to-end against units on the test LAN: TCP schema, HTTP endpoints, MQTT topics â€” for all 5 module types.
- Verify AC dimmer lamps, DC PWM outputs, relay interlock, blind run-time.

### 9.5 LAN/MQTT Failover Testing

- Force LAN loss â†’ assert automated MQTT fallback within SLA; restore LAN â†’ LAN preferred again.
- Verify retained-status reconciliation and offline queue flush.

### 9.6 Push Notification Testing

- Offline/reconnect alert, output-left-on-for-long alert, temperature alert.
- Foreground/background/terminated states on Android + iOS; deep-link navigation.

### 9.7 Backup/Restore and Account Sync Testing

- Backup on config change; restore on new device; malformed/incomplete snapshot handling.
- Simultaneous edits from two devices â†’ conflict UI; offline-then-sync.

### 9.8 Test Device Matrix

| Platform | Min target | Test set |
|----------|-----------|----------|
| Android | API 28 (9) | Pixel-class + budget, high-DPI, no-GMS variant |
| iOS | iOS 15 | latest iPhone + 2 prior-gen, small + large screens |

---

## 10. CI/CD Pipeline

### 10.1 Provider choice

Use **GitHub Actions** (repo already Git) with optional **Codemagic/Bitrise** for iOS signing convenience. Keep a single pipeline definition at `.github/workflows/`.

### 10.2 Workflow stages (per push / on PR / on tag)

| Step | Tooling |
|------|---------|
| **Analyze + format** | `flutter analyze` (fatal on warnings); `dart format --set-exit-if-changed` |
| **Unit tests** | `flutter test` (mock drivers, scenario/state logic) |
| **Widget tests** | `flutter test test/widget/` with `--coverage`; fail on coverage gate |
| **Build Android** | `flutter build apk --release` (+ optional AAB) per env dart-define |
| **Build iOS** | `flutter build ipa` on macOS runner (Xcode + signing via match/Codemagic) |
| **Distribute internal** | GitHub Actions + Firebase App Distribution (Android), TestFlight via FastLane (iOS) |

### 10.3 CI/CD secrets (never in repo)

`GOOGLE_SERVICES_*`, signing keystore + passwords, Apple certs/profiles (FastLane `match`), FCM server key, dev/staging/prod env values.

---

## 11. Build and Deployment Instructions

### 11.1 Android Release Build and Play Upload

1. Create/keep an **upload keystore** (`.jks`), store under `android/` (excluded from Git) with passwords in CI secrets.
2. Configure `android/app/build.gradle` release signing; enable minification (`minifyEnabled true` + `proguard-rules`).
3. `flutter build appbundle --release` â†’ upload `.aab` to **Google Play Console** (Internal testing â†’ Closed/Open â†’ Production).
4. Metadata: ROI/EN title + full description, screenshots (Home, Configuration, Scenarios, temperature), feature graphic, privacy policy.

### 11.2 iOS Release Build and App Store Connect Upload

1. Enable Push + Background Remote notifications capability in `ios/Runner/*.entitlements`.
2. Config signing: `xcodebuild -workspace Runner.xcworkspace` or FastLane; use `match` for provisioning.
3. `flutter build ipa` â†’ upload via **Transporter** or FastLane to **App Store Connect** â†’ **TestFlight** internal/external.
4. Submit for review with privacy policy + data disclosures; export compliance (encryption: MQTT TLS + encrypted backup) attested.

### 11.3 Code Signing Requirements

| Platform | Requirement |
|----------|-------------|
| Android | Upload keystore for Play; debug keystore for dev; keep both in CI secrets |
| iOS | Apple Developer account; signing cert + provisioning profile via `match`; APNs key for FCM |

### 11.4 Store Metadata Preparation

- Store listings in ROI/EN per brief Â§4.3 (launch languages).
- Screenshots per stage and locale; privacy policy covering account, cloud backup, MQTT remote access, and push.
- Prepare consistent icon/feature imagery; pre-review against App Store + Play guidelines to limit review delays (Stage 6 risk).

---

## 12. Development Workflow

### 12.1 Git Branching Model (Trunk-based + short-lived features)

```
main            â† protected, always releasable
â”œâ”€ staging      â† pre-release stabilization
â”œâ”€ feature/<id>-<slug>   â† work branched from main
â”œâ”€ fix/<id>-<slug>
â””â”€ release/<version>
```

### 12.2 Pull Request and Code Review

- PR template: linked requirement ID (HOM/CFG/SCN/RM/SET), what/why, test evidence, screenshots.
- Required checks before merge: `flutter analyze`, tests, CI build; **at least one approval** from another dev (senior for drivers/transport).
- Keep PRs small (â‰¤ 400 lines); squash-merge with `feat(scenarios): ...` conventional commits.

### 12.3 Environment Switching

- `--dart-define=APP_ENV=dev|staging|prod`; each env maps to its own Firebase/broker/fixtures.
- Local dev uses `.env.dev` + mock transports; QA uses `.env.staging` + real broker; releases use `.env.prod`.

### 12.4 Local vs Remote Module Communication Testing

- Local: connect phone to the same LAN as modules; confirm direct TCP/API; verify online dots and instantaneous control.
- Remote: disconnect phone from LAN (e.g., cellular) â†’ confirm MQTT fallback, status accuracy, and push delivery.
- Both: assert transport used appears in the event log (`source` LAN vs MQTT) for traceability (brief Â§2.4 history).

---

## 13. Alignment with the Seven Project Stages

| Stage | This guide applies to |
|-------|------------------------|
| **1. Planning/Kick-off** | Stack choice (Â§1); repo/service provisioning; CI skeleton; environment files (Â§3.3) |
| **2. UI/UX Design & Prototyping** | Theme/tokens (Â§3.1 `core/theme`); Widget-test scaffolding for designs while prototype in Figma |
| **3. Hardware Delivery & Documentation** | Freeze LAN/MQTT contracts (Â§5.3â€“5.4); build mock drivers (Â§9.1) to de-risk IRL delay |
| **4. Technical Development** | Folders (Â§3.1), drivers (Â§5), cloud (Â§6), push (Â§7), localization (Â§8); commit feature branches against requirement IDs (Â§12) |
| **5. Final Testing (QA) & Optimization** | Full test matrix (Â§9), LAN/MQTT failover (Â§9.5), push (Â§9.6), backup/sync (Â§9.7); CI gates (Â§10.2) |
| **6. Launch & Store Publication** | Release builds + signing (Â§11.1â€“11.3), metadata + privacy (Â§11.4), TestFlight/Internal (Â§10.3) |
| **7. Post-Launch Support & Maintenance** | Environment rotation, crash/analytics hooks, patch cadence, v1.1 readiness (multi-location schema, ES/FR/DE catalogs) |

### Stage Entry/Exit Gates

| Stage | Gate |
|-------|------|
| â†’ 4 | `flutter analyze` clean; mock-driver tests green; env + Firebase/broker provisioned |
| â†’ 5 | All Â§9 suites execute on device matrix; CI pipeline green |
| â†’ 6 | Release candidate signed + TestFlight/Internal build passes QA |
| â†’ 7 | Monitoring/alerts live; rollback runbook rehearsed |

---

## Appendix â€” Quick-Start Commands

```bash
# Clone and get dependencies
git clone <repo> && cd soleux_device_manager
flutter pub get

# Verify toolchain
flutter doctor -v

# Generate localization + codegen (riverpod, drift)
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# Run (dev env, mock transport)
flutter run -d <device> --dart-define=APP_ENV=dev

# Test
flutter analyze
flutter test

# Release builds
flutter build appbundle --release    # Android (Play)
flutter build ipa  --release         # iOS (App Store, macOS)
```

---
*End of Project Setup Guide. Derives technology, protocol, schema, and build decisions directly from `doc/description.md`.*
