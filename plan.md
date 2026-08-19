# Integration Plan — Relay, Dimming & Temperature Control Mobile Application

**Document status:** Approved — ready for development kick-off  
**Document owner:** Technical Project Manager / Solution Architect  
**Audience:** Cross-functional team (PM, UI/UX, iOS, Android, Backend, QA, DevOps, Support)

---

## 1. Project Summary and Goals

### 1.1 Summary

We are building a cross-platform iOS/Android mobile application for the **monitoring, configuration, and control of automation relay modules, lighting dimming modules (DC and AC), and temperature sensor modules**. The app communicates with local hardware over a **hybrid LAN (TCP/IP + HTTP API)** channel for direct in-home control and switches to a **remote MQTT** channel for out-of-home control. All configuration, scenarios, rooms, and event history synchronise to the cloud and across the user's devices.

### 1.2 Goals

| # | Goal | Success Metric |
|---|------|----------------|
| G1 | Enable deterministic local control of relays, dimmers, and temperature modules with minimal latency | LAN command latency < 150 ms round-trip |
| G2 | Provide reliable remote control outside the LAN via MQTT fallback | Remote command success rate > 99.5% |
| G3 | Deliver an intuitive, minimalist, high-contrast UI that a non-technical user can operate | In-app onboarding completion > 90%, CSAT > 4.3/5 |
| G4 | Guarantee accounts, backups, and multi-device sync are secure and consistent | Zero data-loss incidents in 6 months |
| G5 | Launch with Romanian and English, architected for Spanish, French, and German | Localization completed pre-launch for RO/EN |
| G6 | Establish an automation layer (scenarios, IF/THEN, 30-day history) with reliable 30-day retention | History completeness = 100% of triggered events |

---

## 2. Scope, Assumptions, Constraints, and Out-of-Scope

### 2.1 Scope (In-Scope)

- Native device support: standard relay modules, DC blind motor control modules, DC dimmer modules (4 × 12–24V PWM outputs), AC dimmer modules (4 × 220V outputs), and temperature modules (internal module temperature monitoring).
- Local LAN control via direct TCP/IP sockets and HTTP API with mDNS/IP discovery.
- Remote control via MQTT with secure credentials.
- Account system with mandatory email/password, session handling, and password recovery.
- Cloud backup/restore, cloud database, and multi-device synchronisation.
- Push notifications for offline module alerts, temperature alerts, and triggered scenarios.
- Configuration of modules: online/offline indicators, output/channel management, naming, icons, physical input modes (momentary, toggle, associated).
- Physical input binding to outputs/scenarios.
- Scenario engine: tap-to-run, multi-output, brightness percentages, manual dimming slider, IF/THEN automations (time- and device-state-based).
- Rooms/zones: creation, scenario assignment, Home screen grouping.
- 30-day rolling event history.
- Home screen: quick-access scenarios, drag-and-drop ordering, offline module alerts, temperature monitoring.
- Localization: Romanian + English; extensible pipeline for ES/FR/DE.

### 2.2 Assumptions

- Hardware modules expose either a TCP socket protocol and/or an HTTP/JSON API and an MQTT topic set (confirmed during Stage 3 hardware onboarding).
- Modules are on the same LAN segment as the phone for local communication; mDNS (or static IP) is used for discovery.
- A backend cloud (auth, database, MQTT broker, push service) is available or will be provisioned in Stage 4.
- Users have an internet uplink for first-time account creation and subsequent cloud synchronisation.
- Initial deployment targets a **single location**; the data model is engineered for future multi-location expansion.
- Brightness control over dimmers is expressed as integer percentages 0–100.
- Temperature alerts are configurable with user-defined thresholds (low/high).

### 2.3 Constraints

- Local control must function fully **without an internet connection**.
- Remote control requires the LAN-side bridge/hub to maintain an active MQTT connection; the app must gracefully report MQTT status.
- 30-day event history is the rolling retention window.
- Launch languages are Romanian and English only.
- First release ships single-location; multi-location is schema-ready but out of the active build.

### 2.4 Out-of-Scope (v1)

- Multi-location management UI (schema-ready only).
- Voice assistant integrations (Alexa/Google Home/HomeKit).
- Third-party BMS/SCADA or manufacturer-agnostic universal gateway.
- Video/CCTV module support.
- Energy metering/monitoring at the per-socket level.
- Native watch/tvOS/desktop clients.
- Web/cloud administration portal for equipment (account used for config backup only; roadmap v1.1).
- Advanced thermostat/multi-zone temperature control managed by the module's internal server (explicitly out of v1, Level 1 scope).
- Spanish, French, and German locales (architecture only).

---

## 3. Functional Requirements Breakdown

### 3.1 Main Tab Navigation

| Tab | Purpose |
|-----|---------|
| **Home** | Quick-access scenario buttons, drag-and-drop scenario ordering, offline module alerts, temperature monitoring and alerts. |
| **Configuration** | Module discovery, module list with online/offline indicators, output/channel management, naming/icons, physical input modes, device-type UIs. |
| **Scenarios** | Create and run scenarios, tap-to-run, multi-output control, brightness %, manual dim lighting, IF/THEN automations, event history. |
| **Settings** | Account (email/password), cloud backup/restore, multi-device sync, password recovery, push notification preferences, localization. |

### 3.2 Home Tab

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| HOM-1 | Display quick-access scenario buttons that run a scenario on tap. Only scenarios with the **"Show in Home"** option enabled appear. | P0 |
| HOM-2 | Support drag-and-drop reordering of scenario buttons; order persists via cloud sync. | P1 |
| HOM-3 | Show offline module alert as a prominent red banner/temporary popup at the top; tapping redirects to the **System Status** page (error-log view). | P0 |
| HOM-4 | Real-time monitoring of each module's **internal temperature** with user-defined high/low thresholds; generate automatic alerts displayed like the offline alert (banner/popup). | P0 |
| HOM-5 | Group scenario buttons and module cards by room/zone; rooms rendered for quick access to scenario groups. | P1 |
| HOM-6 | Reflect latest device state asynchronously (LAN or MQTT). | P0 |

### 3.3 Configuration Tab

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| CFG-1 | Discover modules via their **self-discovery broadcast message** on the network, monitored by the app for easy integration. | P0 |
| CFG-2 | Identify and add discovered modules by **IP address**; support manual static IP entry. | P0 |
| CFG-3 | Render a module list with online/offline indicators and connection status (LAN vs MQTT). | P0 |
| CFG-4 | Provide hybrid transport: local LAN TCP/API by default, remote MQTT fallback. | P0 |
| CFG-5 | Manage outputs/channels: enable/disable, rename, assign icon, set per-channel behaviour. | P0 |
| CFG-6 | Configure physical input modes: **momentary**, **toggle**, **associated**. | P0 |
| CFG-7 | Bind physical inputs to outputs or scenarios (associated mode). | P1 |
| CFG-8 | Dedicated configuration UI per module type: relay, DC blind, DC dimmer, AC dimmer, temperature. | P0 |

### 3.4 Scenarios Tab

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| SCN-1 | Tap-to-run a scenario that sends actions to multiple outputs across relays and dimmers (one press executes a series of predefined commands). | P0 |
| SCN-2 | Set precise brightness percentages (0–100%, including 0% = OFF and 100% = ON) for dimmer targets. | P0 |
| SCN-3 | "Manual dimming Slider" scenario controlling a single dimmer output, optionally shown on HOME for quick intensity adjustment. | P0 |
| SCN-3a | "Show in Home" toggle on each scenario controlling Home-tab visibility; unlimited custom scenarios. | P1 |
| SCN-4 | IF/THEN automations triggered by **time** and **device state**. | P1 |
| SCN-5 | Rollback/disable automations easily and list active automations. | P1 |
| SCN-6 | Maintain a 30-day rolling event history of runs and triggers. | P0 |

### 3.5 Rooms / Zones

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| RM-1 | Create, rename, reorder, and delete rooms/zones. | P0 |
| RM-2 | Assign scenarios to rooms for Home-tab grouping. | P1 |
| RM-3 | Assign modules to rooms; rooms drive Home-tab grouping. | P1 |

### 3.6 Settings Tab

| Requirement ID | Description | Priority |
|----------------|-------------|----------|
| SET-1 | Mandatory email/password account required before full app use. | P0 |
| SET-2 | Cloud backup and restore of all configuration, scenarios, rooms, and history. | P0 |
| SET-3 | Multi-device synchronisation with conflict handling. | P0 |
| SET-4 | Password recovery flow (email reset link/code). | P0 |
| SET-5 | Push notification toggles. Real-time alerts include: a module has gone **offline or come back online**, an output has **remained ON too long**, temperature threshold exceeded. | P0 |
| SET-6 | Language selection (RO/EN in v1; ES/FR/DE later) and locale-aware formatting. | P1 |

---

## 4. Technical Architecture

### 4.1 Recommended Cross-Platform Framework — Flutter

**Why Flutter (recommended):**

| Criterion | Assessment |
|-----------|------------|
| Single codebase | One Dart codebase for Android + iOS reduces cost and time-to-market. |
| Dart socket/HTTP support | `dart:io` + `Socket`, `http`, `mDNS` packages cover LAN TCP/API cleanly. |
| MQTT ecosystem | Mature `mqtt_client` package with TLS, reconnection, and QoS. |
| Localization | Built-in `flutter_localizations`/ARB pipeline fits i18n-first requirement (RO/EN + future ES/FR/DE). |
| UI control | Custom paint + gestures enable large minimalist high-contrast controls and drag-and-drop. |
| Offline/online | Good async lifecycle support for local-first behaviour and background sync. |
| Push | `firebase_messaging` / `flutter_local_notifications` support both platforms. |

**Alternative considered:** React Native (larger JS/MQTT ecosystem but weaker typed socket/low-level control ergonomics). **Decision:** Flutter for a single, typed, high-performance codebase across I/O-heavy control logic.

### 4.2 Local Communication — Direct TCP/IP + HTTP API

- **HTTP/JSON API** on modules (where provided) for configuration and status read/write.
- **Raw TCP socket protocol** (where provided) for low-latency switch/dimmer commands.
- **Discovery:** monitor each module's **self-discovery broadcast message** on the network; identify and add by **IP address**, with manual static-IP entry fallback. Cached device list persisted locally.
- **Transport selection:** per-command resolver attempts LAN first on a short timeout, then fails over to MQTT.

### 4.3 Remote Communication — MQTT

- Subscribe to per-module/per-channel topic structure such as:
  - `<locationId>/<moduleId>/status` (telemetry)
  - `<locationId>/<moduleId>/control` (commands)
  - `<locationId>/<moduleId>/events` (error/offline)
- QoS 1 with retained status where appropriate; TLS (wss/ssl) required for remote clients.
- Automatic reconnect with exponential backoff and status surfacing in the app.

### 4.4 Cloud Services

| Service | Purpose | Provider Candidate |
|---------|---------|--------------------|
| Authentication | Email/password, sessions, token refresh, password recovery | Firebase Auth / Supabase Auth |
| Database | Users, locations, modules, channels, inputs, scenarios, rooms, event log | Cloud Firestore / Supabase Postgres |
| Backup/Restore | Snapshot + restore of configuration, encrypted at rest | Cloud storage + DB export |
| Push notifications | Offline, temperature, automation alerts | FCM (Android) + APNs (iOS), via Firebase Cloud Messaging |
| MQTT broker (remote path) | Remote device control | Hosted broker (e.g., EMQX/Mosquitto) with per-user credentials |

### 4.5 Offline/Online Detection & Synchronization

- **Local-only operation:** Home/Config read and command module state directly over LAN; no internet required.
- **Remote path:** if LAN sequence fails, publish to MQTT.
- **Online detection:** keepalive/status heartbeat per module; app marks module `ONLINE`/`OFFLINE`; changes push offline alerts.
- **Sync engine:** last-write-wins with per-entity `updatedAt`, plus explicit conflict resolution UI for overlapping multi-device edits.
- **Queueing:** offline-time commands and logs buffered locally and flushed once connectivity returns.

### 4.6 Multi-Location Architectural Readiness

- The user-account and app structure support managing **multiple locations (Home, Office, Vacation house)** under one account.
- Data model includes `Location` and `LocationId` keys on all entities from day one.
- v1 ships **single-location** UX; multi-location lists/filters and per-location scope are hidden but supported by schema and APIs.

---

## 5. Data Model

> All entities carry `id`, `createdAt`, `updatedAt`. All references use foreign keys. Timestamps in ISO-8601 UTC.

| Entity | Key Fields | Notes |
|--------|------------|-------|
| **User** | `id`, `email`, `passwordHash`, `displayName`, `language`, `pushToken`, `preferences` | Auth-managed; password never stored in plaintext. |
| **Location** | `id`, `ownerId`, `name`, `lat`, `lng`, `timezone`, `mqttConfig`, `isPrimary` | Enables future multi-site. |
| **Module** | `id`, `locationId`, `roomId`, `type` (relay/bind/dcDim/acDim/temp), `name`, `ip`, `mac`, `mqttTopic`, `firmware`, `status` (online/offline), `lastSeenAt` | Core hardware record; per-type sub-schemas. |
| **Channel** (Output) | `id`, `moduleId`, `index`, `name`, `icon`, `enabled`, `behaviour` | One per physical output/channel. |
| **Input** | `id`, `moduleId`, `index`, `mode` (momentary/toggle/associated), `boundTargetType`, `boundTargetId` | Physical input binding target. |
| **Scenario** | `id`, `locationId`, `roomId`, `name`, `icon`, `order`, `showInHome`, `type` (manual/slider/auto) | Quick actions, manual-dim-slider, and automations; `showInHome` controls Home-tab visibility. |
| **ScenarioAction** | `id`, `scenarioId`, `order`, `actionType` (setRelay/setDimmer/slider), `channelId`, `brightnessPct`, `trigger` (time/deviceState) | IF/THEN payload + steps. |
| **Room** | `id`, `locationId`, `name`, `order` | Home-tab grouping. |
| **EventLog** | `id`, `locationId`, `userId`, `type`, `entityId`, `payload`, `occurredAt` | 30-day rolling retention. |
| **TemperatureAlert** | `id`, `locationId`, `moduleId`, `minC`, `maxC`, `enabled`, `lastTriggeredAt` | High/low thresholds. |
| **DeviceStatus** | `id`, `moduleId`, `channel`, `value`, `source` (lan/mqtt), `updatedAt` | Latest observed state / heartbeat. |

---

## 6. API & Hardware Integration Requirements per Module Type

| Module Type | Configurable | Local Control Path | Remote Path | Physical Input Modes | Notes |
|-------------|--------------|--------------------|-------------|----------------------|-------|
| **Relay** | Output count (~8), naming, icon, per-output on/off polarity, interlock | HTTP/JSON + TCP on/off | MQTT `control` | momentary, toggle, associated | Large ON/OFF direct-command button per output; debounce/interlock handling. |
| **DC Blind** | Up/down/stop, motor run time, per-direction behaviour | TCP commands (up/down/stop) | MQTT `control` | momentary, associated | **Toggle-stop:** first press (e.g., UP) starts motor; second press of same button stops it (same for DOWN). |
| **DC Dimmer** | 4 × 12–24V PWM outputs, fade time, min/max | TCP + HTTP set brightness % | MQTT `control` | momentary (dim), toggle, associated | Precise 0–100% brightness required on all 4 outputs. |
| **AC Dimmer** | 4 × 220V outputs, fade, min brightness cap | TCP + HTTP set brightness % | MQTT `control` | momentary, toggle, associated | AC phase-cut; test bulb compatibility. |
| **Temperature** | Read **module internal temperature**, low/high thresholds, alert triggers | HTTP read + subscription | MQTT `status`/`events` | n/a | Drives `TemperatureAlert` + push. Advanced thermostat logic (module's internal server) is **NOT** exposed in v1 (Level 1); only temperature display + thresholds. |

**Integration contract per module type** in Stage 4: TCP command schema, HTTP endpoint map, MQTT topic map, JSON status schema, and error/ACK codes — all collected in Stage 3 hardware docs and codified as protocol fixtures for QA.

---

## 7. UI/UX Plan

### 7.1 Design Principles

- **Minimalist, high-contrast** visual language — large type, strong contrast for accessibility and glanceability in low light.
- **Large, clearly delineated controls** — generous touch targets (≥ 48 dp), distinct on/dim states, clear affordance.
- Status-driven colour system: online/offline, local/remote, active/inactive clearly differentiated.

### 7.2 Navigation Flow

```
Launch → [No account?] Login/Register → Recovery
                     │
                     ▼
                 Home (tabs)
   ┌───────────────┬──────────────┬───────────────┬───────────────┐
   │ Home          │ Configuration│ Scenarios     │ Settings      │
   │ • Quick-actions│ • Module list│ • Create/run  │ • Account     │
   │ • Rooms        │ • Discovery  │ • IF/THEN     │ • Backup      │
   │ • Offline alert│ • Output mgmt│ • Event history│ • Sync       │
   │ • Temperature  │ • Input modes│               │ • Notifications│
   └───────────────┴──────────────┴───────────────┴───────────────┘
        │                 │
        ▼                 ▼
   Scenario editor    Module detail (per type)
   Room editor        Channel/Input editors
```

### 7.3 Screen Inventory

| Screen | Purpose |
|--------|---------|
| Splash | Branding + session bootstrap |
| Onboarding | Account creation / sign-in |
| Login / Register / Password recovery | Auth flow |
| Home | Scenario grid (Show-in-Home only), room grouping, offline-alert banner, temperature cards |
| System Status | Error/event log view reached from the offline-alert banner |
| Configuration / Module list | Discovery (self-discovery broadcast) + online/offline indicators |
| Module detail (×5 variants) | Relay / blind / DC dimmer / AC dimmer / temperature UIs |
| Output (Channel) editor | Naming, icon, behaviour |
| Input editor | Mode + binding |
| Scenario list / editor | Multi-output, brightness %, slider, IF/THEN |
| Event history | 30-day log |
| Rooms management | Create/assign/scenario grouping |
| Settings | Account, backup/restore, sync, notifications, language |

### 7.4 Prototype Handoff

- Deliver interactive Figma prototypes (Home + Configuration + Scenarios end-to-end) before Stage 4 begins.
- Annotated with touch-target specs, empty/error/offline states, and RO/EN copy samples.
- Handoff gates development of UI so QA has a design reference.

---

## 8. Localization Plan

| Scope | Detail |
|-------|--------|
| **Launch locales** | Romanian (ro), English (en) |
| **Pipeline** | `flutter_localizations` + ARB/JSON string catalogs; single source of truth in a strings store (e.g., ARB → codegen). |
| **Formatting** | Locale-aware date, time, number, and temperature (Celsius) formats via `intl`. |
| **Design for expansion** | No hard-coded strings; plural/gender rules respected; UI designed for text-length growth (DE/FR). |
| **Future locales** | Spanish (es), French (fr), German (de) — enabled by adding locale catalogs, no code changes. |
| **Localization QA** | String-keys reviewed for translation readiness; screenshot tests per locale. |

---

## 9. Security & Account Management

### 9.1 Authentication and Sessions

- Mandatory email/password; passwords hashed with strong KDF (bcrypt/argon2) server-side.
- Short-lived access tokens + refresh tokens; tokens stored in secure storage (Keychain/Keystore).
- Session revocation on password change/recovery; idle timeout configurable.

### 9.2 Secure Cloud Backup

- Backup snapshot encrypted in transit (TLS) and at rest (KMS-managed keys).
- User-triggered restore validates backup ownership and integrity before applying.

### 9.3 Password Recovery

- Flow: request → emailed time-limited reset link/code → verify → set new password → invalidate old sessions.

### 9.4 Data Protection for Remote MQTT Access

- TLS (wss/ssl) for all remote MQTT connections.
- Per-user, scoped MQTT credentials; avoid static shared device keys.
- `readonly` vs `control` topic ACLs; rate limiting and audit logging.
- No secrets in app source or unencrypted storage.

---

## 10. Milestones Mapped to Seven Stages

### Stage 1 — Planning & Kick-off

- **Objectives:** Align scope, assemble team, define architecture and protocol contracts.
- **Tasks:**
  - [ ] Confirm final product brief and prioritised backlog
  - [ ] Finalise tech stack (Flutter, cloud, MQTT broker, push)
  - [ ] Define hardware protocol integration contract template
  - [ ] Map data model to cloud DB schema
  - [ ] Define out-of-scope list and release-1 boundary
  - [ ] Seed risk register and communication plan
- **Deliverables:** Charter, architecture doc, schema draft, backlog, risk register.
- **Acceptance criteria:** Scope frozen; architecture and schema reviewed and signed off.
- **Estimated timeline:** 2 weeks. **Dependencies:** Hardware vendors to name protocol/PoC contacts.

### Stage 2 — UI/UX Design & Prototyping

- **Objectives:** Validate UX and design system for all screens.
- **Tasks:**
  - [ ] Audit minimalist high-contrast design system and tokens
  - [ ] Design Home (quick actions, drag-and-drop, alerts, temperature)
  - [ ] Design Configuration (discovery, per-module UIs, input modes)
  - [ ] Design Scenarios (manual + IF/THEN + history)
  - [ ] Design Settings/Auth/Recovery/Backup flows
  - [ ] Build interactive Figma prototype (RO/EN copy)
  - [ ] Usability test with RGB/temperature task set
- **Deliverables:** Prototype, design specs, usability report.
- **Acceptance criteria:** Prototype usability score ≥ target; design handed to dev.
- **Estimated timeline:** 3 weeks. **Dependencies:** Stage 1 scope.

### Stage 3 — Hardware Delivery & Technical Documentation

- **Objectives:** Obtain hardware, SDKs, and authoritative protocol docs.
- **Tasks:**
  - [ ] Receive representative units of all 5 module types
  - [ ] Collect TCP, HTTP API, and MQTT topic documents
  - [ ] Validate command/reply schemas for each module
  - [ ] Capture edge cases (fade, min-brightness, interlock, run-time)
  - [ ] Publish integration contract per module type
  - [ ] Set up test bench (PSU, fixtures, LAN + broker)
- **Deliverables:** Hardware, protocol contract docs, test bench.
- **Acceptance criteria:** Protocol docs verified against real units; contract frozen.
- **Estimated timeline:** 3–5 weeks (parallel with Stages 2/4). **Dependencies:** Vendor shipment; **risk of delay** (see Section 13).

### Stage 4 — Technical Development

- **Objectives:** Implement all features against frozen contracts.
- **Tasks:**
  - [ ] Scaffold Flutter app, theming, navigation (4 tabs)
  - [ ] Auth, sessions, recovery, secure storage
  - [ ] LAN discovery + TCP/HTTP transports
  - [ ] MQTT remote transport + reconnect/queueing
  - [ ] Common + per-type module config UIs and channel/input editors
  - [ ] Scenario engine (manual + slider + IF/THEN)
  - [ ] Rooms and Home-tab grouping + drag-and-drop ordering
  - [ ] Event history (30-day) and temperature alerts
  - [ ] Cloud DB, backup/restore, multi-device sync
  - [ ] Push notifications (FCM/APNs)
  - [ ] Localization (RO/EN) + i18n pipeline
- **Deliverables:** Working alpha → beta builds on iOS and Android.
- **Acceptance criteria:** All P0/P1 requirements implemented; local + remote control pass test harness.
- **Estimated timeline:** 10–12 weeks. **Dependencies:** Stages 1–3.

### Stage 5 — Final Testing & Optimization

- **Objectives:** Stabilise, harden, and optimise for release.
- **Tasks:**
  - [ ] Execute full functional + hardware integration suite
  - [ ] Benchmark LAN latency and MQTT failover times
  - [ ] Performance (CPU/memory/battery) and crash-rate optimisation
  - [ ] Security review and penetration pass on auth/MQTT paths
  - [ ] Push notification end-to-end verification
  - [ ] Run device matrix regression on Android/iOS
- **Deliverables:** Release candidate build + QA sign-off.
- **Acceptance criteria:** Zero P0/P1 defects; target performance and stability met; security passed.
- **Estimated timeline:** 3–4 weeks. **Dependencies:** Stage 4.

### Stage 6 — Launch & Store Publication

- **Objectives:** Prepare and publish to Apple App Store and Google Play.
- **Tasks:**
  - [ ] Prepare store metadata, screenshots, privacy policy
  - [ ] Configure TestFlight + Google Play internal testing
  - [ ] Rehearse App Store review checklist to reduce delays
  - [ ] Confirm final QA and rollback plan
  - [ ] Submit for review; resolve review feedback
- **Deliverables:** Live apps on App Store + Google Play (internal → production).
- **Acceptance criteria:** Apps approved and published; store listings verified.
- **Estimated timeline:** 2–3 weeks (review time variable). **Dependencies:** Stage 5 + store accounts.

### Stage 7 — Post-Launch Support & Maintenance

- **Objectives:** Monitor, iterate, and provide ongoing support.
- **Tasks:**
  - [ ] Instrument analytics + crash reporting
  - [ ] Operational dashboard (broker, auth, push, DB)
  - [ ] Support ticketing + RO/EN knowledge base
  - [ ] Patch cycle for OS/mobile updates
  - [ ] Plan v1.1 roadmap (multi-location, extra locales)
- **Deliverables:** Monitoring/alerts live, support SLA, v1.1 roadmap.
- **Acceptance criteria:** SLA met; critical incidents handled per runbook.
- **Estimated timeline:** Ongoing. **Dependencies:** Stage 6.

---

### 10.1 High-Level Milestone Timeline

| Milestone | Stage | Est. Duration | Type |
|-----------|-------|---------------|------|
| Kick-off complete | 1 | 2 weeks | Decision gate |
| Prototype approved | 2 | 3 weeks | Decision gate |
| Hardware + protocol frozen | 3 | 3–5 weeks (overlaps 2/4) | Dependency gate |
| Feature-complete beta | 4 | 10–12 weeks | Build milestone |
| Release candidate + QA pass | 5 | 3–4 weeks | Build milestone |
| Store publication | 6 | 2–3 weeks | Launch gate |
| Post-launch steady-state | 7 | Ongoing | Operations |

---

## 11. Detailed Task Breakdown (Checkboxes)

> Referenced by stage above. Consolidated actionable checklist:

**Stage 1**
- [ ] Finalise product brief + prioritised backlog
- [ ] Confirm Flutter + cloud + MQTT + push stack
- [ ] Define hardware protocol contract templates
- [ ] Draft cloud DB schema from Section 5 data model
- [ ] Record risk register (Section 13)

**Stage 2**
- [ ] Design system + tokens (high-contrast, large controls)
- [ ] Home, Configuration, Scenarios, Settings screen designs
- [ ] Interactive prototype + usability testing
- [ ] RO/EN copy and locale catalogs seeded

**Stage 3**
- [ ] Receive units: relay, blind, DC dimmer, AC dimmer, temperature
- [ ] Verify TCP/HTTP/MQTT docs against hardware
- [ ] Publish per-module integration contract
- [ ] Stand up test bench and LAN + broker fixtures

**Stage 4**
- [ ] Flutter scaffold + 4-tab navigation + theming
- [ ] Auth/session/recovery/secure storage
- [ ] mDNS/IP discovery + TCP/HTTP transports
- [ ] MQTT remote transport + reconnect + offline queue
- [ ] Per-type module UIs + channel/input editors
- [ ] Scenario engine (manual, slider, IF/THEN)
- [ ] Rooms + Home grouping + drag-and-drop ordering
- [ ] 30-day event history + temperature alerts
- [ ] Cloud DB, backup/restore, multi-device sync
- [ ] Push notifications (FCM/APNs)
- [ ] Localization pipeline (RO/EN) + i18n hardening

**Stage 5**
- [ ] Functional + hardware integration test suite
- [ ] LAN/MQTT switching + performance benchmarks
- [ ] Security review + pen-test on auth/MQTT
- [ ] Push end-to-end verification
- [ ] Device-matrix regression (Section 12 matrix)
- [ ] Optimisation + RC build sign-off

**Stage 6**
- [ ] Store metadata, screenshots, privacy policy
- [ ] TestFlight + Google Play internal testing
- [ ] Submit + handle App Store / Play review

**Stage 7**
- [ ] Analytics + crash reporting live
- [ ] Ops dashboard + alerting
- [ ] Support ticketing + KB
- [ ] Patch cadence + v1.1 roadmap

---

## 12. Testing Strategy

### 12.1 Functional Testing

- Unit tests for scenario engine, sync logic, validation, and data model.
- UI/widget tests for all screens and empty/offline/error states.
- Localization checks (RO/EN key completeness, layout overflow).

### 12.2 Hardware Integration Testing

- End-to-end against real units on the test bench for all 5 module types.
- Verify TCP command schema, HTTP endpoints, and MQTT topics per module.
- Validate edge cases: AC phase-cut, DC fade, blind run-time, relay interlock.

### 12.3 LAN/MQTT Switching Testing

- Force LAN failure and verify automated MQTT fallback within defined SLA.
- Verify restore of LAN path when it recovers (preference order).
- Test offline command queueing/flush and status reconciliation.

### 12.4 Push Notification Testing

- Offline module alert, temperature threshold alert, and automation trigger notifications.
- Deep-link from notification to relevant module/scenario.
- Foreground/background/terminated app states on both platforms.

### 12.5 Account Backup & Restore Testing

- Backup creation, restore on new/installed device, integrity checks.
- Restore with missing/empty/malformed backup data.

### 12.6 Multi-Device Synchronization Testing

- Simultaneous edits from two devices → conflict resolution path.
- Latency-bound consistency and offline-then-sync scenarios.

### 12.7 Performance & Security Testing

- LAN command latency; remote MQTT latency; startup time; battery impact.
- Auth brute-force, token expiry, TLS verification, and MQTT ACL penetration checks.

### 12.8 Device Matrix

| Platform | Min target | Recommend test set |
|----------|-----------|--------------------|
| Android | Android 9 (API 28) | Pixel-class + budget device, high-DPI, no-GMS device variant |
| iOS | iOS 15 | Latest iPhone + 2 prior-gen iPhones, small + large screen |

---

## 13. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Hardware delivery delays | High | Medium | Order early (Stage 3 overlaps Stages 2/4); ask vendor for remote/emulated protocol fixtures and loaner units; keep emulator harness for dev. |
| LAN/MQTT fallback issues | Medium | High | Frozen protocol contract in Stage 3; dedicated switching test suite (12.3); explicit per-module status surfacing; reconnect/queue design. |
| Dimmer compatibility (AC/DC) | High | Medium | Test against bulb/LED fixture matrix; firmware update path; per-module min-brightness/fade caps; vendor tuning guide. |
| Cloud sync conflicts | Medium | Medium | `updatedAt` last-write-wins + explicit conflict-resolution UI; deterministic entity IDs; replicate via feature flags. |
| App Store/Play review delays | Medium | High | Prepare privacy policy and data-use disclosures early; TestFlight/internal testing first; rehearse review checklist in Stage 6; buffer schedule. |
| Account/password recovery UX blockers | Low | Medium | Test recovery flow across email deliverability; provide in-app status during reset. |
| Push deliverability variance | Medium | Medium | Rely on FCM + APNs best practice; background fetch + notification fallback; per-device token refresh. |

---

## 14. Release Plan

### 14.1 Store Readiness

- App Store + Google Play listings with **RO and EN metadata**.
- Screenshots covering Home, Configuration, Scenarios, and temperature monitoring.
- Privacy policy and data-processing/consent documents confirming MQTT and cloud data flows.

### 14.2 Pre-Release Testing Channels

- **TestFlight** for iOS internal + invited external testers.
- **Google Play Internal Testing** then **Closed Beta** for Android.
- Gate: Stage 5 QA sign-off must pass before promotion.

### 14.3 Production Rollout

| Step | Platform | Gate |
|------|----------|------|
| Internal testing | iOS (TestFlight) / Android (internal) | Stage 5 RC |
| External/closed beta | iOS (external) / Android (closed) | Beta stability ≥ 2 weeks, no P0 |
| Targeted production | Android staged rollout (10%→50%→100%) | Crash rate + support ticket signal |
| Full production | iOS (Worldwide) / Android (100%) | All of the above green |

- Staged rollout enables rapid rollback without full withdrawal.
- Feature-flag critical functions (multi-device sync, MQTT path) for instant disable if regressions appear.

---

## 15. Post-Launch Monitoring & Support Plan

### 15.1 Monitoring

- **Crash/Error:** automated crash reporting + symbols; alert on sudden crash-rate increase.
- **Analytics:** app open, Home interaction, scenario run, sync failures, MQTT reconnect frequency, notification open rates.
- **Service health:** uptime dashboards for auth, cloud DB, backup store, push, and MQTT broker with threshold alerts.
- **Device health:** offline-module report to detect LAN/network regressions and per-module firmware faults.

### 15.2 Support

- Ticketing + **RO/EN** knowledge base; dedicated channel for hardware/protocol issues escalated to vendors.
- SLA: initial response < 24 h; P1 incident < 4 h with runbook-driven escalation.
- Release cadence: monthly patch (bugs/OS updates), quarterly minor (features, new locales, multi-location groundwork).

### 15.3 v1.1 Roadmap Input

- Enable multi-location management UI.
- Add Spanish, French, and German locales.
- Web admin portal, voice assistant, and energy-metering modules (evaluated against demand).

---

## Appendix A — Definition of Done

- Feature implements its requirements to P0/P1 with tests.
- No unhandled exceptions; crash-free sessions ≥ 99.5%.
- Local and remote control verified on iOS + Android device matrix.
- RO/EN strings complete and overflowing-layout-free.
- Security review passed (auth, TLS, MQTT ACL).
- QR/functional sign-off recorded in QA tracker.

---
*End of plan. Derived from the product brief; ownership line maintained by the Technical Project Manager.*
