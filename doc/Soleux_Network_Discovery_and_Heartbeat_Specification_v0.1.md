Soleux Network Discovery and Heartbeat
## Desktop, Mobile and Device Firmware Protocol Specification
Status: Proposed companion protocol - implementation draft
Audience: Device firmware, Windows application and mobile application developers
Scope: IPv4 discovery, Layer-2 commissioning, result merging and device heartbeat
Compatibility: Ports 8000, 8001, 5005 and 5007 remain unchanged during migration
Design status: This document records the existing discovery and heartbeat behavior, then defines additive fields for Control API v3 on TCP port 5008. Existing devices and the current Windows application remain compatible because legacy fields and ports are preserved.

# Purpose and compatibility
Soleux clients use three complementary mechanisms. Standard UDP discovery finds devices that already have usable IPv4 addressing. Soleux Layer-2 discovery finds and commissions wired devices by MAC address even without IPv4. UDP heartbeat monitors known devices without keeping a TCP session open.
Control API relationship: The new command API uses TCP port 5008 by default. Discovery advertises this port additively; heartbeat remains on UDP port 5007 by default. The legacy command port remains TCP 5005 until migration is complete.
## Normative rules
1. Clients must parse fields by name and ignore unknown additive fields.
2. Discovery and heartbeat payloads are UTF-8. JSON property names are case-sensitive unless a legacy exception is explicitly stated.
3. An advertised port is authoritative. A derived default may be probed only when the field is absent.
4. The legacy TCP port and the Control API port are separate values during migration.
5. A valid heartbeat proves recent reachability; it does not authenticate the device or prove that a control command will succeed.
6. Device names and all received text are untrusted display data and must never be interpreted as executable content.
7. Commissioning operations must target one explicit MAC address and require user confirmation.
8. Timeout, retransmission and offline decisions are client-side behavior; devices do not send negative discovery or heartbeat responses.
## Default port map

| Port/value | Protocol | Role | Compatibility rule |
|---|---|---|---|
| 8000 | UDP broadcast | Standard IPv4 discovery request | Existing behavior; unchanged |
| 8001 | TCP listener | Default app-selected discovery callback | May be replaced by another available callback port |
| 5005 | TCP | Legacy AT command service | Advertised as PORT during migration |
| 5007 | UDP | Heartbeat responder | Default legacy TCP port + 2 |
| 5008 | TCP | Control API v3 | Default legacy TCP port + 3; must be verified with hello |
| 0x88B5 | Ethernet EtherType | Soleux Layer-2 discovery and commissioning | Local broadcast domain only; never routed |

## Device family identities

| Device family | Discovery GUID |
|---|---|
| Relay Module | 579E6EA1-2F64-4CDE-8190-1CD3646EFAA1 |
| AC/DC Dimmer | C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91 |
| PDU Energy Meter | 56EC974B-1C9F-48C3-B438-BFE976593072 |
| PDU 10 kW | A728DD7D-0DEB-49B9-9B8B-A4556771815F |
| PDU V1.0 | B4A6B160-0CBA-4BD8-873D-EDC9DF895C26 |

The GUID identifies a device family. The serial number and Ethernet MAC identify an individual physical device. Clients must not use a family GUID as the unique device ID.
# 1. Standard IPv4 discovery
The app opens a temporary TCP callback listener, then broadcasts a small JSON request on each eligible IPv4 interface. Every matching device connects back to the sender and transmits newline-delimited identity fields. The TCP peer address is the discovered IPv4 address.
## 1.1 UDP discovery request
Purpose: Ask all Soleux devices on the local IPv4 broadcast domain to identify themselves.  Transport: UDP broadcast to destination port 8000
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| GUID | string | Yes | Exact request GUID | 8C93472D-2EF0-4B82-BE96-4FBBED57783F |
| VER | string | Yes | Current value 2.0 | Discovery request version. |
| PORT | integer\|string | Yes | 1-65535 | TCP callback port already listening on the client. |
| CLIENT | string | No | 1-64 characters | Additive client name for diagnostics. |
| WANT | string[] | No | Known field names | Optional requested additive fields; devices may ignore it. |

```json
{
  "GUID":"8C93472D-2EF0-4B82-BE96-4FBBED57783F",
  "VER":"2.0",
  "PORT":8001,
  "CLIENT":"Soleux Windows",
  "WANT":["MAC","API_PORT","HEARTBEAT_PORT","API_VER"]
}
```
### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| datagrams_sent | integer | Client-local | Number of interfaces on which the request was transmitted. |
| callback_window_ms | integer | Client-local | Time the callback listener remains available. |
| responses | integer | Client-local | Valid unique device callbacks received during the run. |

Failure behavior: Invalid JSON, wrong GUID/version or an unusable callback port is silently ignored by current firmware. A missing callback is treated as no discovery result, not as a device error.
## 1.2 TCP discovery callback
Purpose: Return device identity and connection endpoints to the requesting app.  Transport: Device-initiated TCP connection to the request sender and PORT
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| callback_peer_ip | IPv4 | Implicit | TCP peer address | Authoritative discovered IPv4 address. |
| GUID | string | Yes | Known family GUID | Device family. |
| VER | string | Yes | Firmware version | Installed firmware version. |
| PORT | integer | Yes | 1-65533 | Legacy TCP command port; normally 5005. |
| SN | string | Yes | Device supplied | Physical device serial number. |
| NAME | string | Yes | UTF-8 display text | User-configured device name. |
| MAC | MAC string | No | Additive | Ethernet MAC when available. |
| API_PORT | integer | No | Additive; normally 5008 | Control API v3 TCP port. |
| HEARTBEAT_PORT | integer | No | Additive; normally 5007 | UDP heartbeat port. |
| API_VER | integer | No | Additive; current 3 | Highest advertised Control API version. |
| CAPS | CSV\|string[] | No | Additive | Compact capability identifiers. |

### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| device | DiscoveredDevice | On valid callback | Normalized record after field parsing and validation. |
| source | enum | Always | udp or udp+dcp after merging. |
| connectable | boolean | Always | True when peer IPv4 and at least one usable control endpoint are present. |

GUID:579E6EA1-2F64-4CDE-8190-1CD3646EFAA1
VER:7.11
PORT:5005
SN:0000000012345678
NAME:Plant Room Relays
MAC:02:81:F9:30:81:F9
API_PORT:5008
HEARTBEAT_PORT:5007
API_VER:3
CAPS:control_api_v3,heartbeat,l2
Failure behavior: Malformed lines are ignored individually. Unknown family GUIDs are not shown as supported devices. Missing required identity fields, invalid ports or a callback that exceeds the receive limit invalidate the response.
## 1.3 Client sequence and timing
* Enumerate active, non-loopback IPv4 interfaces and calculate each subnet broadcast address.
* Bind the TCP callback listener before transmitting the first UDP request.
* Broadcast on every eligible interface. Mobile clients may use a short burst; desktop discovery may repeat only while the discovery view is active.
* Accept callbacks for 2-5 seconds, parse by field name rather than line order, and cap each response to a small implementation-defined limit.
* Use the TCP peer address as IPv4. Never trust a separately reported IP field more than the observed peer address.
* Normalize and merge results before updating the UI. Do not create duplicate rows for repeated callbacks.
* If API_PORT is absent, a client may probe PORT + 3, but it must complete the Control API hello exchange before marking API v3 as supported.
Mobile platform note: Android and iOS may require local-network permission and broadcast/multicast entitlements. Discovery should run only while needed; background discovery is neither reliable nor battery-efficient.
# 2. Soleux Layer-2 discovery and commissioning
Layer-2 discovery is a DCP-like Soleux protocol carried directly in Ethernet frames. It works without IPv4, remains inside the local Ethernet broadcast domain and is not wire-compatible with PROFINET DCP. Firmware currently listens on wired interface eth0.
## 2.1 Platform and frame requirements

| Item | Requirement |
|---|---|
| Windows | Npcap with 32-bit runtime for the current Win32 app; open non-loopback adapters in promiscuous mode. |
| Linux/device | Raw AF_PACKET socket with root or CAP_NET_RAW. |
| Android/iOS | Normal app sandboxes generally cannot send raw Ethernet frames; use UDP discovery and an external commissioning tool. |
| Ethernet header | Destination MAC 6 bytes, source MAC 6 bytes, EtherType 0x88B5 in network byte order. |
| Payload | UTF-8 JSON beginning at byte 14; remove trailing zero padding before decoding. |
| Minimum frame | Pad to at least 60 bytes before the Ethernet FCS when required. |
| Capture size | Current Windows Npcap and device implementations use a 2048-byte capture/receive buffer. |

## 2.2 identify / identity
Purpose: Find every supported wired Soleux device by Ethernet MAC, including devices with 0.0.0.0 addressing.  Transport: Broadcast Ethernet request; unicast Ethernet response using EtherType 0x88B5
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| soleux_l2 | integer | Yes | 1 | Layer-2 protocol version. |
| op | string | Yes | identify | Requested operation. |
| nonce | string | Yes | 1-64 characters recommended | Client correlation value; unique per discovery run. |

```json
{"soleux_l2":1,"op":"identify","nonce":"19ABCDEF012-01"}
```
### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| soleux_l2 | integer | Always | Protocol version 1. |
| op | string | Always | identity. |
| nonce | string | Always | Echoed request nonce. |
| guid | string | Always | Device-family GUID. |
| mac | MAC string | Always | Reported Ethernet MAC; frame source MAC is authoritative. |
| name | string | Always | Configured display name. |
| serial | string | Always | Physical serial number. |
| firmware | string | Always | Installed firmware version. |
| port | integer | Always | Legacy TCP command port. |
| ip | IPv4 | Always | Current eth0 address or 0.0.0.0. |
| mask | IPv4 | Always | Current subnet mask or 0.0.0.0. |
| gateway | IPv4 | Always | Current default gateway or 0.0.0.0. |
| api_port | integer | Optional additive | Control API TCP port, normally 5008. |
| heartbeat_port | integer | Optional additive | Heartbeat UDP port, normally 5007. |
| api_version | integer | Optional additive | Highest Control API version. |
| capabilities | string[] | Optional additive | Compact advertised protocol capabilities. |

```json
{"soleux_l2":1,"op":"identity","nonce":"19ABCDEF012-01","guid":"579E6EA1-2F64-4CDE-8190-1CD3646EFAA1","mac":"02:81:F9:30:81:F9","name":"Plant Room Relays","serial":"0000000012345678","firmware":"7.11","port":5005,"ip":"10.100.20.42","mask":"255.255.255.0","gateway":"10.100.20.1","api_port":5008,"heartbeat_port":5007,"api_version":3}
```
Failure behavior: Wrong EtherType, unsupported version, invalid JSON or unknown operation is silently ignored. Clients must reject a mismatched nonce and deduplicate repeated responses by source MAC.
## 2.3 set_ipv4 / set_result
Purpose: Save a static IPv4 address on one explicitly selected device and reboot it after acknowledgement.  Transport: Unicast Ethernet request and response using EtherType 0x88B5
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| soleux_l2 | integer | Yes | 1 | Layer-2 protocol version. |
| op | string | Yes | set_ipv4 | Requested operation. |
| nonce | string | Yes | Match active request | Correlation value. |
| target | MAC string | Yes | Selected device MAC | Device ignores requests for another MAC. |
| ip | IPv4 | Yes | Valid unicast; not 0.0.0.0/broadcast | Static address. |
| mask | IPv4 | Yes | Non-zero contiguous mask | Subnet mask. |
| gateway | IPv4 | Yes | Valid IPv4; 0.0.0.0 allowed | Default gateway or no-gateway sentinel. |

```json
{"soleux_l2":1,"op":"set_ipv4","nonce":"19ABCDEF012-02","target":"02:81:F9:30:81:F9","ip":"10.100.20.42","mask":"255.255.255.0","gateway":"10.100.20.1"}
```
### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| soleux_l2 | integer | Always | Protocol version 1. |
| op | string | Always | set_result. |
| status | enum | Always | ok or error. |
| message | string | Always | Human-readable result. |
| nonce | string | Preferred additive | Echoed request nonce for safe correlation. |
| target | MAC string | Preferred additive | MAC that accepted or rejected the request. |
| reboot_in_ms | integer | Preferred additive on success | Approximate time before reboot; current default 2000. |

```json
{"soleux_l2":1,"op":"set_result","status":"ok","message":"static IPv4 settings saved","nonce":"19ABCDEF012-02","target":"02:81:F9:30:81:F9","reboot_in_ms":2000}
```
Failure behavior: A target mismatch is silently ignored. Validation/storage errors return status=error. The client must not report success until it receives a matching acknowledgement, and must not assume the new address is active until rediscovery succeeds.
## 2.4 reboot / reboot_result
Purpose: Restart one selected device without changing IPv4 configuration.  Transport: Unicast Ethernet request and response using EtherType 0x88B5
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| soleux_l2 | integer | Yes | 1 | Layer-2 protocol version. |
| op | string | Yes | reboot | Requested operation. |
| nonce | string | Yes | Match active request | Correlation value. |
| target | MAC string | Yes | Selected device MAC | Explicit physical target. |

```json
{"soleux_l2":1,"op":"reboot","nonce":"19ABCDEF012-03","target":"02:81:F9:30:81:F9"}
```
### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| soleux_l2 | integer | Always | Protocol version 1. |
| op | string | Always | reboot_result. |
| status | enum | Always | ok or error. |
| message | string | Always | Human-readable result. |
| nonce | string | Preferred additive | Echoed request nonce. |
| target | MAC string | Preferred additive | Acknowledging device MAC. |
| reboot_in_ms | integer | Preferred additive on success | Approximate reboot delay; current default 2000. |

```json
{"soleux_l2":1,"op":"reboot_result","status":"ok","message":"reboot accepted","nonce":"19ABCDEF012-03","target":"02:81:F9:30:81:F9","reboot_in_ms":2000}
```
Failure behavior: A target mismatch is silently ignored. The app must require acknowledgement, then wait for discovery or heartbeat before declaring the device online again.
## 2.5 Required client safeguards
* Send identify on every eligible Ethernet adapter, but never on loopback adapters.
* Correlate every identity and operation result by nonce. Version 1 firmware may omit nonce from set/reboot results, so compatibility mode must also match the unicast source MAC and permit only one pending operation per target.
* Treat the Ethernet frame source MAC as authoritative and compare it with the JSON mac value.
* Send set_ipv4 and reboot only by unicast to a device selected by the user.
* Require explicit confirmation before changing addressing or rebooting equipment.
* Keep standard UDP discovery working when Npcap/raw capture is absent or fails.
# 3. Normalized discovery result and merging
Desktop and mobile clients should convert transport-specific messages into one record before presenting or saving a device. This keeps UI behavior independent of the discovery source.

| Field | Type | Presence | Description |
|---|---|---|---|
| device_id | string | Always after normalization | Serial number when stable; otherwise normalized MAC; final fallback is family GUID plus IPv4 and legacy port. |
| family_guid | string | Always | Known device-family GUID. |
| device_type | enum | Always | relay_module, dimmer, pdu_energy, pdu_10kw or pdu_v1. |
| name | string | Always | Sanitized display name. |
| serial | string\|null | When reported | Physical serial number. |
| mac | string\|null | When reported | Normalized uppercase colon-separated MAC. |
| firmware_version | string\|null | When reported | Installed firmware. |
| ipv4 | string\|null | When usable | Observed callback peer IP preferred over reported values. |
| subnet_mask | string\|null | DCP | Reported current mask. |
| gateway | string\|null | DCP | Reported current gateway. |
| legacy_tcp_port | integer | Always | PORT/port; normally 5005. |
| control_api_port | integer\|null | When advertised or verified | Normally 5008. |
| heartbeat_udp_port | integer\|null | When advertised or derived | Normally 5007. |
| api_version | integer\|null | When advertised or negotiated | Highest verified Control API version. |
| capabilities | string[] | Optional | Advertised capabilities; final authority is get_capabilities. |
| sources | enum[] | Always | udp, dcp or both. |
| last_discovered_at | datetime | Always | Client timestamp for the newest accepted result. |

## 3.1 Merge priority
* Match by stable serial number when present on both records.
* Otherwise match by normalized Ethernet MAC.
* As a last resort, match by family GUID plus observed IPv4 plus legacy TCP port.
* When UDP and DCP agree, label the record udp+dcp. Keep the UDP peer IPv4 as the routable address and the DCP frame source as the authoritative MAC.
* Do not merge records when stable serials conflict, even if names or IP addresses match.
* A DCP-only record with 0.0.0.0 is visible but not connectable. It must be commissioned before TCP or HTTP/HTTPS use.
## 3.2 Endpoint selection

| Condition | Client action |
|---|---|
| control_api_port advertised | Connect to the observed IPv4 and advertised port, then send Control API hello. |
| API port absent, legacy PORT known | Optionally probe legacy PORT + 3. Mark API v3 available only after hello succeeds. |
| API hello fails | Fall back to the current legacy path only while migration support remains enabled. |
| heartbeat port advertised | Use it directly. |
| heartbeat port absent | Probe legacy PORT + 2 without treating silence as an error dialog. |
| DCP-only or no usable IPv4 | Disable connect; offer Configure IP & Reboot on supported desktop commissioning tools. |

# 4. UDP heartbeat
Heartbeat is a small unicast request/response for devices already known by IPv4 address. It is not a discovery broadcast, command channel or authentication mechanism. The responder binds to the configured legacy TCP port plus 2 unless an explicit heartbeat port is advertised.
## 4.1 ping
Purpose: Ask one known device to prove recent reachability.  Transport: Unicast UDP to the device heartbeat port; normally 5007
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| soleux_heartbeat | integer | Yes | 1 | Heartbeat protocol version. |
| op | string | Yes | ping | Requested operation. |
| nonce | string | Yes | 1-64 characters | Unique correlation value for this target and cycle. |

```json
{"soleux_heartbeat":1,"op":"ping","nonce":"0000019ABCDEF012-0001"}
```
### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| sent_at_ms | monotonic integer | Client-local | Send timestamp used to calculate round-trip time. |
| target_key | string | Client-local | Normalized host plus legacy/control identity used by the monitor. |
| deadline_ms | monotonic integer | Client-local | End of the response window. |

Failure behavior: Invalid or unsupported requests are silently discarded. Send failure removes the nonce from the pending set. Silence is counted as a missed sample and must not raise a modal error.
## 4.2 pong
Purpose: Acknowledge a valid ping and return the minimum endpoint identity needed by the monitor.  Transport: UDP response to the ping source IP and source port
### Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| source_ip | IPv4 | Implicit | Must match target | Observed response source address. |
| source_port | integer | Implicit | Expected heartbeat port | Observed response source port. |
| soleux_heartbeat | integer | Yes | 1 | Heartbeat protocol version. |
| op | string | Yes | pong | Response operation. |
| nonce | string | Yes | Must be pending | Echoed request nonce. |
| tcp_port | integer | Yes | 1-65533 | Legacy TCP command port. |
| name | string | Yes | UTF-8 display text | Current configured name. |
| api_port | integer | No | Additive; normally 5008 | Control API TCP port. |
| api_version | integer | No | Additive; current 3 | Highest Control API version. |
| device_id | string | No | Additive | Stable serial or MAC-derived identity. |
| boot_id | string | No | Additive; changes at boot | Allows clients to detect a reboot. |

### Expected output

| Field | Type | Presence | Description |
|---|---|---|---|
| valid | boolean | Always after validation | True only when version, op, nonce and peer endpoint are acceptable. |
| round_trip_ms | integer | When valid | Receive time minus sent_at_ms. |
| last_seen_at | datetime | When valid | Client wall-clock timestamp. |
| state | enum | When valid | online, or connected when an active control session exists. |

```json
{"soleux_heartbeat":1,"op":"pong","nonce":"0000019ABCDEF012-0001","tcp_port":5005,"name":"Plant Room Relays","api_port":5008,"api_version":3,"device_id":"0000000012345678","boot_id":"4d2f9c"}
```
Failure behavior: Malformed JSON, wrong version/op, unknown nonce, late response, unexpected source IP or invalid port is ignored. Devices do not send a negative pong.
## 4.3 Default timing profile

| Setting | Desktop default | Meaning |
|---|---|---|
| Heartbeat interval | 5000 ms | Delay between monitor cycles. |
| Response window | 1500 ms | Maximum time to accept matching pongs in one cycle. |
| Receive slice | 100 ms | Socket polling timeout so shutdown stays responsive. |
| Alive threshold | 15000 ms | Current Windows threshold since last valid pong. |
| Target refresh | 2000 ms | Current Windows refresh of saved/discovered target list. |
| Maximum nonce | 64 characters | Firmware validation limit. |
| Device receive buffer | 1024 bytes | Current heartbeat datagram limit. |

## 4.4 Availability state machine

| State | Entry rule | Recommended UI |
|---|---|---|
| unknown | No heartbeat sample has completed and no control connection exists. | Neutral/gray; do not call the device offline yet. |
| connected | An authenticated or active control connection is currently healthy. | Green; connection status overrides heartbeat color. |
| online | A valid pong was received within the 15-second alive threshold. | Blue/accent when no active control session exists. |
| suspect | Two consecutive cycles missed or last valid pong is older than 10 seconds. | Amber; optional enhancement for new clients. |
| offline | No active connection and last valid pong is older than 15 seconds, or three full cycles missed. | Red; retain last-seen time. |
| rebooting | A reboot/set_ipv4 acknowledgement was accepted and its grace window is active. | Progress/gray; suppress offline alarms until grace expires. |

## 4.5 Monitor rules
* Generate a distinct nonce for every target in every cycle and retain it only until the response deadline.
* Validate the UDP peer IP and preferably the expected source port in addition to the nonce. Nonce matching alone is not sufficient on an untrusted LAN.
* One valid pong updates last-seen and clears consecutive misses. Duplicate pongs do not extend the deadline more than once.
* A connected Control API session takes precedence over heartbeat when presenting status, but heartbeat may continue for independent reachability evidence.
* Do not run aggressive 5-second polling continuously in a mobile background state. Use platform-approved background modes or suspend monitoring and refresh on foreground/resume.
* Back off or add jitter when monitoring many devices so every client does not transmit on the same boundary.
* Changing the legacy TCP port changes the derived heartbeat port. The responder must rebind, and discovery must advertise the new value where supported.
# 5. Security, rate limits and failure isolation
* UDP discovery, Layer-2 commissioning and heartbeat are unauthenticated in protocol version 1.
* Layer-2 set_ipv4 and reboot can disrupt equipment. Restrict them to a protected commissioning or industrial LAN and require an explicit confirmation step.
* Do not route, tunnel or forward EtherType 0x88B5 frames between network segments.
* Rate-limit identify broadcasts, heartbeat pings and repeated commissioning attempts. Devices may silently discard excess traffic.
* Never log passwords, Control API tokens or unrelated packet payloads in discovery/heartbeat logs.
* Discovery and heartbeat failures are optional-service failures. They must not prevent manual device connection, legacy operation or application startup.
* Use authenticated TCP 5008 or HTTPS for actual control. A discovery identity or heartbeat pong is not authorization.
# 6. Acceptance test matrix

| ID | Scenario | Expected result |
|---|---|---|
| D-01 | Valid UDP request on each active interface | Every supported IPv4 device returns one mergeable TCP callback. |
| D-02 | Callback port differs from 8001 | Device connects to the requested valid port. |
| D-03 | Unknown additive callback fields | Older/newer clients ignore fields they do not understand. |
| D-04 | Device advertises API_PORT 5008 | Client completes hello before enabling Control API v3. |
| D-05 | DCP identify with no device IPv4 | Identity appears with MAC and No IP address; connect action is disabled. |
| D-06 | UDP and DCP find the same serial/MAC | One record is shown with source udp+dcp. |
| D-07 | DCP identity nonce mismatch | Response is ignored. |
| D-08 | set_ipv4 has invalid/non-contiguous mask | Device returns set_result status=error and does not reboot. |
| D-09 | set_ipv4/reboot target MAC mismatch | Device remains silent and unchanged. |
| D-10 | Npcap/raw socket unavailable | UDP discovery and manual connection remain usable. |
| H-01 | Valid ping nonce | Pong echoes nonce and reports tcp_port/name. |
| H-02 | Empty or >64-character nonce | Device silently discards request. |
| H-03 | Pong from wrong IP or after deadline | Client ignores it and does not update last-seen. |
| H-04 | One missed 5-second cycle | No modal error; status does not immediately become offline. |
| H-05 | Three cycles missed and no active connection | Status becomes offline after approximately 15 seconds. |
| H-06 | Reboot acknowledged | Client enters rebooting grace state and later returns online after valid discovery/heartbeat. |
| H-07 | Legacy TCP port changes | Heartbeat service rebinds to new legacy port + 2 and the client refreshes its target. |
| H-08 | 100 saved devices | Polling uses jitter/batching without UI blocking or unbounded pending nonces. |

# 7. Migration sequence
* Add API_PORT, HEARTBEAT_PORT and API_VER to standard discovery callbacks while preserving GUID, VER, PORT, SN and NAME.
* Add api_port, heartbeat_port and api_version to Layer-2 identity responses; old clients ignore these fields.
* Optionally add nonce, target and reboot_in_ms to Layer-2 operation results. Keep compatibility handling for current version 1 results that omit them.
* Optionally add api_port, api_version, device_id and boot_id to heartbeat pongs while retaining current required fields.
* Update the Windows app to advertise/verify TCP 5008, strengthen nonce plus peer validation and preserve legacy fallback during rollout.
* Implement UDP discovery and heartbeat in the mobile app. Treat raw Layer-2 commissioning as unavailable unless the platform provides a privileged Ethernet API.
* After all supported firmware and apps advertise explicit endpoints, stop relying on derived ports except as a temporary probe fallback.
Approval point: Before implementation, confirm whether the heartbeat port remains tied to the legacy TCP port, whether the optional Layer-2 result-correlation fields require a protocol-version increment, and which mobile background behavior is acceptable for Android and iOS.
