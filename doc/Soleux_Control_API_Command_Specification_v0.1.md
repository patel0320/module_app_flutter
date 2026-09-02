Soleux Control API
## TCP 5008 and HTTP/HTTPS Command Specification
Status: Proposed protocol - implementation draft
Audience: Device firmware, Windows application and mobile application developers
Transports: TCP port 5008, HTTP, HTTPS and WebSocket/SSE events
Compatibility: Legacy AT commands remain on port 5005 during migration
Design status: This document defines the proposed version 3 API. It is the implementation contract to review before coding. Commands or fields marked capability-dependent must be advertised by get_capabilities and must return unsupported_command when unavailable.

# Document purpose
This specification defines one transport-neutral command model for Soleux device firmware, the Windows application, the upcoming mobile application and third-party HTTP/HTTPS integrations. It replaces app-only J: messages and the application's dependence on legacy AT commands while preserving the legacy port during migration.
## Normative rules
1. All physical input, virtual-input and output indexes are zero-based on every transport.
2. JSON booleans are true/false; API clients must not send 0/1 as boolean substitutes.
3. Time durations use integer milliseconds unless a field name explicitly ends in _s.
4. Electrical and environmental units are included in field names: _v, _a, _w, _va, _wh, _hz and _c.
5. Timestamps use ISO 8601 with an offset. Event timestamps should be UTC where practical.
6. Unknown fields may be ignored only when the negotiated protocol version permits forward-compatible extensions.
7. Secrets are write-only unless a command explicitly documents that they can be returned.
8. Every state-changing command identifies its required permission and produces an auditable source/session identity.
## Command groups
* Session and protocol: 7 commands. Commands used to establish a session, discover functionality and manage message delivery.
* Device information and health: 10 commands. Read device identity, full state, health, temperature and time, and perform administrative actions.
* Inputs and virtual inputs: 5 commands. Read and configure physical inputs and operate virtual inputs. All input channels are zero-based.
* Outputs: 9 commands. Live relay and dimmer control. These commands replace ON, OFF, TOGGLE, RESTART and masked AT operations.
* Input-output mappings: 5 commands. Manage mappings using named behaviors while retaining the current numeric codes for migration.
* Dimmer control: 9 commands. Device-specific brightness commands. Common output commands remain valid for on/off control.
* PDU energy and override: 7 commands. Energy and protection commands are capability-gated because meter hardware differs by PDU model.
* Schedules and automation: 12 commands. CRUD operations use stable resource objects rather than Windows-page row mutations.
* Dimmer scenarios and sequences: 11 commands. Scenario and sequence resources replace page-specific scenario/sequence mutations.
* Configuration, network and security: 9 commands. Configuration is organized into stable sections but is not coupled to a UI page layout.
* Backup, restore and firmware transfer: 7 commands. Chunked transfer commands support TCP and HTTP consistently. HTTP may additionally use direct upload endpoints later.
Catalogue size: This draft defines 91 request actions and 13 device event types.
# Transport and message envelope
The action and params object is identical on TCP, HTTP and HTTPS. Transport framing and authentication headers are not part of the command object.
## Request envelope

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| protocol | integer | Yes | 3 for this specification | Protocol version. |
| id | integer\|string | Yes | Unique among pending requests | Caller-generated correlation ID. |
| action | string | Yes | Exact action name | Command to execute. |
| params | object | No | Default {} | Command-specific parameters. |
| timeout_ms | integer | No | 100-120000 | Optional caller timeout hint; does not override safety limits. |

```json
{"protocol":3,"id":42,"action":"set_output_state","params":{"channel":0,"state":true}}
```
## Success response

| Field | Type | Presence | Description |
|---|---|---|---|
| protocol | integer | Always | Protocol version. |
| id | integer\|string | Always | Original request ID. |
| ok | boolean | Always | True for a successful command. |
| result | object | Always | Command-specific expected result. |

```json
{"protocol":3,"id":42,"ok":true,"result":{"channel":0,"requested_state":true,"actual_state":true,"pending":false,"revision":311}}
```
## Error response

| Field | Type | Presence | Description |
|---|---|---|---|
| protocol | integer | Always | Protocol version. |
| id | integer\|string\|null | Always | Original ID, or null when it could not be parsed. |
| ok | boolean | Always | False for an error. |
| error.code | string | Always | Stable machine-readable error code. |
| error.message | string | Always | Safe human-readable explanation. |
| error.details | object | Optional | Structured validation or recovery data. |
| error.retryable | boolean | Always | Whether retry may succeed without changing the request. |

```json
{"protocol":3,"id":42,"ok":false,"error":{"code":"invalid_channel","message":"Output channel must be between 0 and 7.","details":{"channel":9,"minimum":0,"maximum":7},"retryable":false}}
```
## Transport mapping

| Transport | Request framing | Response framing | Events |
|---|---|---|---|
| TCP port 5008 | One UTF-8 JSON object per line (CRLF or LF). Maximum length advertised by hello. | One JSON response line; IDs permit multiple pending requests. | Subscribed event JSON lines on the same connection. |
| HTTP | POST /api/v1/command with application/json. | HTTP status plus the common JSON envelope. | GET /api/v1/events using SSE, where enabled. |
| HTTPS | Same as HTTP over TLS; preferred for credentials and remote/mobile use. | Same common JSON envelope. | SSE or secure WebSocket. |
| WebSocket | One JSON request per text message when command mode is enabled. | One JSON response message. | Primary bidirectional event transport. |

Migration rule: The J: prefix is not used on port 5008 or HTTP/HTTPS. During migration, the current Windows application may temporarily continue using J: on port 5005. After Windows migration and validation, port 5005 becomes AT-only.
# Permissions and security

| Permission | Allows |
|---|---|
| Public | hello, ping and authenticate only. |
| Read | Read identity, state, configuration summaries, telemetry and events. |
| Control | Change live input/output/dimmer state and execute schedules/scenarios. |
| Configure | Change mappings, channel configuration, schedules, automations and non-secret settings. |
| Admin | Accounts, access rules, network/security settings, backup/restore, firmware, reboot and destructive actions. |

HTTP should be restricted to trusted local networks. Password authentication, tokens, backup/restore and firmware operations should require HTTPS or an equivalently protected TCP deployment. Tokens must never be written to normal logs.
# Common error catalogue
Every error uses the common error envelope. Commands may document additional codes.

| Code | Meaning |
|---|---|
| invalid_request | Envelope or JSON structure is invalid. |
| unknown_action | Action name is not recognized. |
| unsupported_command | Device recognizes the action but does not support it. |
| unsupported_protocol | No mutually supported protocol version exists. |
| authentication_required | A valid authenticated session is required. |
| authentication_failed | Credentials or token were rejected. |
| permission_denied | Session lacks the required permission. |
| invalid_parameter | A parameter has the wrong type, range or value. |
| invalid_channel | Input/output channel is outside the zero-based device range. |
| not_found | Requested resource or operation does not exist. |
| revision_conflict | expected_revision does not match current resource revision. |
| busy | A conflicting operation is active. |
| interlock | A safety or control interlock prevented the operation. |
| timeout | The operation did not complete within its allowed time. |
| rate_limited | Caller exceeded the configured request limit. |
| payload_too_large | Message or transfer exceeds advertised limits. |
| internal_error | Unexpected device-side failure; message must not expose secrets. |

# Command catalogue
Each action below defines action-specific params and the result object returned inside the common response envelope. An absent optional parameter means the device uses its current value or documented default; null is not interchangeable with omission unless explicitly stated.
# 1. Session and protocol
Commands used to establish a session, discover functionality and manage message delivery.
## 1.1  hello
Purpose: Negotiate the protocol and identify the client and device.  Support: All devices  Permission: Public
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| client_name | string | No | 1-64 characters | Name of the calling application. |
| client_version | string | No | Semantic version recommended | Calling application version. |
| protocol_min | integer | No | Default 3 | Oldest protocol version accepted by the client. |
| protocol_max | integer | No | Default 3 | Newest protocol version accepted by the client. |
| features | string[] | No | Unique values | Optional client features such as events, batch and compression. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| protocol | integer | Always | Negotiated protocol version. |
| session_id | string | Always | Identifier for this connection or HTTP session. |
| device | DeviceInfo | Always | Device identity, model and firmware summary. |
| topology | Topology | Always | Input, virtual-input and output counts. |
| limits | ProtocolLimits | Always | Payload, batch and subscription limits. |
| authentication_required | boolean | Always | Whether protected commands require authentication. |

Command-specific errors: unsupported_protocol
## 1.2  ping
Purpose: Check reachability and estimate round-trip time.  Support: All devices  Permission: Public
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| echo | any JSON value | No | Maximum 256 encoded bytes | Value returned unchanged. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| echo | any JSON value | When supplied | Original echo value. |
| server_time | datetime | Always | Current device time in ISO 8601 format. |
| uptime_ms | integer | Always | Milliseconds since the control service started. |

## 1.3  authenticate
Purpose: Create an authenticated API session.  Support: All devices with API security enabled  Permission: Public
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| method | enum | Yes | password \| token | Authentication method. |
| username | string | For password | 1-64 characters | Account name. |
| password | string | For password | HTTPS or protected TCP only | Account password; never logged. |
| token | string | For token | Opaque token | Previously issued API token. |
| client_name | string | No | 1-64 characters | Friendly client identifier for audit logs. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| access_token | string | Always | Bearer/session token. |
| expires_in_s | integer | Always | Token lifetime in seconds; 0 means connection lifetime. |
| permissions | string[] | Always | Granted permission names. |
| user | object | Always | Authenticated account summary without password data. |

Command-specific errors: authentication_failed, insecure_transport, account_locked
## 1.4  get_capabilities
Purpose: Return supported commands, events and device-specific limits.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_schemas | boolean | No | Default false | Include compact parameter/result schema metadata. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| commands | Capability[] | Always | Supported actions and required permissions. |
| events | string[] | Always | Supported event names. |
| transports | object | Always | TCP, HTTP, HTTPS and event transport availability. |
| features | string[] | Always | Device features such as dimmer, energy or Wi-Fi. |
| limits | ProtocolLimits | Always | Current service limits. |

## 1.5  subscribe
Purpose: Subscribe a persistent TCP or WebSocket session to device events.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| events | string[] | Yes | At least one supported event or * | Event names to receive. |
| channels | integer[] | No | Zero-based and unique | Optional input/output channel filter. |
| min_interval_ms | integer | No | 0-60000; default 0 | Minimum interval for coalescible telemetry events. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| subscription_id | string | Always | Identifier used by unsubscribe. |
| events | string[] | Always | Accepted event names. |
| channels | integer[] \| null | Always | Applied channel filter or null for all. |
| min_interval_ms | integer | Always | Applied telemetry interval. |

Command-specific errors: unsupported_event, invalid_channel, subscription_limit
## 1.6  unsubscribe
Purpose: Remove a previously created event subscription.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| subscription_id | string | Yes | Existing subscription | Subscription to remove. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| removed | boolean | Always | True when the subscription existed and was removed. |

Command-specific errors: not_found
## 1.7  batch_execute
Purpose: Execute multiple independent commands in one request.  Support: All devices  Permission: Highest permission required by a child command
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| commands | CommandRequest[] | Yes | 1 to device batch limit | Child requests without protocol/session fields. |
| stop_on_error | boolean | No | Default false | Do not start later commands after a failure. |
| atomic | boolean | No | Default false; capability dependent | Request transactional execution when supported. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| results | BatchResult[] | Always | Ordered child success/error results. |
| completed | integer | Always | Number of child commands attempted. |
| rolled_back | boolean | Always | Whether an atomic batch was rolled back. |

Command-specific errors: batch_too_large, atomic_not_supported
# 2. Device information and health
Read device identity, full state, health, temperature and time, and perform administrative actions.
## 2.1  get_device_info
Purpose: Read stable device identity and software versions.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| device_id | string | Always | Stable unique identifier. |
| name | string | Always | Configured device name. |
| device_type | enum | Always | relay_module \| dimmer \| pdu_10kw \| pdu_v1 |
| model | string | Always | Hardware model. |
| serial_number | string \| null | Always | Serial number if available. |
| firmware_version | string | Always | Firmware/application version. |
| hardware_version | string \| null | Always | Hardware revision when available. |
| mac_addresses | object | Always | Available Ethernet and Wi-Fi MAC addresses. |

## 2.2  get_device_health
Purpose: Read operational health and active faults.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| status | enum | Always | ok \| warning \| fault |
| uptime_ms | integer | Always | Service uptime. |
| faults | Fault[] | Always | Active fault records. |
| temperature_c | number \| null | Always | Primary device temperature. |
| cpu_percent | number \| null | Always | CPU usage if available. |
| memory | object \| null | Always | Memory totals and usage. |
| storage | object \| null | Always | Storage totals and usage. |
| database_ok | boolean | Always | Configuration database health. |

## 2.3  get_device_state
Purpose: Obtain the complete synchronization snapshot used after connection.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include | string[] | No | Default inputs,outputs,sensors | Optional sections: inputs, outputs, sensors, energy, schedules, faults. |
| include_configuration | boolean | No | Default false | Include channel names and control configuration. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| revision | integer | Always | Monotonic state revision. |
| captured_at | datetime | Always | Snapshot timestamp. |
| inputs | InputState[] | When requested | Current physical and virtual input state. |
| outputs | OutputState[] | When requested | Current relay/dimmer output state. |
| sensors | SensorReading[] | When requested | Current temperature and sensor readings. |
| energy | EnergySummary \| null | When requested | Energy data for capable PDUs. |
| faults | Fault[] | When requested | Active faults. |

## 2.4  get_system_data
Purpose: Read diagnostic system and service data.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_processes | boolean | No | Default false | Include service process status when supported. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| os | object | Always | Operating-system identity and kernel. |
| services | ServiceStatus[] | Always | Core service status. |
| resources | object | Always | CPU, memory and storage values. |
| network | object | Always | Interface/link summary without credentials. |
| last_restart_reason | string \| null | Always | Most recent recorded restart reason. |

## 2.5  get_temperature
Purpose: Read all or one temperature sensor.  Support: All devices with temperature support  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sensor_id | string | No | Known sensor identifier | Omit to return every temperature sensor. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| sensors | TemperatureReading[] | Always | Sensor ID, name, Celsius value, status and timestamp. |

Command-specific errors: not_found, sensor_unavailable
## 2.6  get_time
Purpose: Read device time and synchronization settings.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| datetime | datetime | Always | Current local ISO 8601 date/time with offset. |
| timezone | string | Always | IANA time-zone name when available. |
| utc_offset_min | integer | Always | Current UTC offset in minutes. |
| sync_mode | enum | Always | manual \| ntp |
| ntp_server | string \| null | Always | Configured NTP server. |
| last_sync | datetime \| null | Always | Last successful synchronization time. |

## 2.7  set_time
Purpose: Set device time manually.  Support: All devices  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| datetime | datetime | Yes | ISO 8601 with offset | New date/time. |
| timezone | string | No | Supported IANA zone | New time zone. |
| write_rtc | boolean | No | Default true | Also write the hardware real-time clock. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| datetime | datetime | Always | Applied device time. |
| timezone | string | Always | Applied time zone. |
| rtc_written | boolean | Always | Whether the RTC update succeeded. |

Command-specific errors: invalid_datetime, unsupported_timezone, rtc_error
## 2.8  sync_time
Purpose: Synchronize from NTP or a supplied client time.  Support: All devices  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| source | enum | Yes | ntp \| client | Synchronization source. |
| datetime | datetime | For client | ISO 8601 with offset | Calling-client time. |
| server | string | No | Host name or IP | One-time NTP server override. |
| timeout_ms | integer | No | 1000-30000; default 5000 | NTP timeout. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| synchronized | boolean | Always | Whether synchronization succeeded. |
| datetime | datetime | Always | Time after synchronization. |
| offset_ms | integer \| null | Always | Measured NTP offset when available. |

Command-specific errors: time_sync_failed, invalid_datetime
## 2.9  test_ntp_server
Purpose: Test an NTP server without changing saved settings.  Support: All devices  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| server | string | Yes | Valid host name or IP | NTP server to test. |
| timeout_ms | integer | No | 1000-30000; default 5000 | Test timeout. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| passed | boolean | Always | Whether a valid NTP response was received. |
| latency_ms | integer \| null | Always | Round-trip latency. |
| offset_ms | integer \| null | Always | Reported clock offset. |
| message | string | Always | Human-readable outcome. |

## 2.10  reboot_device
Purpose: Restart the device after acknowledging the request.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| delay_ms | integer | No | 500-60000; default 1500 | Delay before reboot so the response can be sent. |
| reason | string | No | Maximum 128 characters | Audit-log reason. |
| force | boolean | No | Default false | Proceed despite non-critical active operations. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| accepted | boolean | Always | True when reboot was scheduled. |
| reboot_in_ms | integer | Always | Scheduled delay. |
| message | string | Always | Status message. |

Command-specific errors: busy, reboot_not_permitted
# 3. Inputs and virtual inputs
Read and configure physical inputs and operate virtual inputs. All input channels are zero-based.
## 3.1  get_inputs
Purpose: Read all physical and virtual inputs.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_configuration | boolean | No | Default true | Include names, enabled flags and modes. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| inputs | InputState[] | Always | Ordered physical input records. |
| virtual_inputs | InputState[] | Always | Ordered virtual-input records. |
| revision | integer | Always | State revision for synchronization. |

## 3.2  get_input
Purpose: Read one physical or virtual input.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Input channel. |
| kind | enum | No | physical \| virtual; default physical | Input collection. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| input | InputState | Always | State and configuration for the requested input. |

Command-specific errors: invalid_channel
## 3.3  set_input_configuration
Purpose: Change input name and behavior.  Support: Relay Module, Dimmer, PDU  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based physical input | Input channel. |
| name | string | No | 0-64 characters | Display name. |
| enabled | boolean | No | - | Whether the input participates in control. |
| mode | enum | No | momentary \| maintained \| pulse | Electrical/control behavior when supported. |
| active_level | enum | No | high \| low | Active electrical level when configurable. |
| debounce_ms | integer | No | 0-5000 | Input debounce time. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| input | InputConfiguration | Always | Complete saved configuration. |
| hardware_apply_required | boolean | Always | Whether apply_hardware_configuration must be called. |

Command-specific errors: invalid_channel, invalid_configuration
## 3.4  set_virtual_input_state
Purpose: Set and retain the state of a virtual input.  Support: Devices with virtual inputs  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based virtual input | Virtual input channel. |
| state | boolean | Yes | - | Requested logical state. |
| source | string | No | Maximum 64 characters | Audit/event source label. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Virtual input channel. |
| state | boolean | Always | Applied state. |
| changed | boolean | Always | Whether state changed. |

Command-specific errors: invalid_channel, input_disabled
## 3.5  trigger_virtual_input
Purpose: Pulse a virtual input and automatically release it.  Support: Devices with virtual inputs  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based virtual input | Virtual input channel. |
| duration_ms | integer | No | 20-60000; default 100 | Active pulse duration. |
| source | string | No | Maximum 64 characters | Audit/event source label. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Virtual input channel. |
| triggered | boolean | Always | Whether the trigger was accepted. |
| release_in_ms | integer | Always | Scheduled release delay. |

Command-specific errors: invalid_channel, input_disabled, busy
# 4. Outputs
Live relay and dimmer control. These commands replace ON, OFF, TOGGLE, RESTART and masked AT operations.
## 4.1  get_outputs
Purpose: Read all output states and optional configuration.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_configuration | boolean | No | Default true | Include delay, runtime and startup settings. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| outputs | OutputState[] | Always | Ordered output records. |
| revision | integer | Always | State revision. |

## 4.2  get_output
Purpose: Read one output.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| output | OutputState | Always | State and configuration for the output. |

Command-specific errors: invalid_channel
## 4.3  set_output_state
Purpose: Turn one output on or off.  Support: Relay Module, Dimmer, PDU  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |
| state | boolean | Yes | - | Requested logical state. |
| transition_ms | integer | No | 0 or device-supported range | Dimmer fade duration; ignored only when capability explicitly permits. |
| source | string | No | Maximum 64 characters | Audit/event source label. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Output channel. |
| requested_state | boolean | Always | Requested state. |
| actual_state | boolean | Always | State when response was produced. |
| pending | boolean | Always | True while delays or transitions are active. |
| revision | integer | Always | New state revision. |

Command-specific errors: invalid_channel, output_disabled, interlock, busy
## 4.4  toggle_output
Purpose: Invert one output state.  Support: Relay Module, Dimmer, PDU  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |
| transition_ms | integer | No | 0 or device-supported range | Dimmer fade duration. |
| source | string | No | Maximum 64 characters | Audit/event source label. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Output channel. |
| actual_state | boolean | Always | Resulting state. |
| pending | boolean | Always | Whether completion is delayed. |
| revision | integer | Always | New state revision. |

Command-specific errors: invalid_channel, output_disabled, interlock, busy
## 4.5  restart_output
Purpose: Cycle one output off and back on.  Support: Relay Module and PDU outputs; capability dependent  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |
| off_time_ms | integer | No | 100-3600000; device default | Time held off. |
| restore_mode | enum | No | on \| previous; default on | Final state after the cycle. |
| source | string | No | Maximum 64 characters | Audit/event source label. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Output channel. |
| accepted | boolean | Always | Whether the cycle was scheduled. |
| off_time_ms | integer | Always | Applied off duration. |
| operation_id | string | Always | Identifier reported by completion events. |

Command-specific errors: invalid_channel, output_disabled, busy
## 4.6  set_multiple_outputs
Purpose: Set several outputs in one deterministic operation.  Support: Relay Module, Dimmer, PDU  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| outputs | OutputTarget[] | Yes | 1 to output count; unique channels | Each item contains channel, state and optional level/transition. |
| execution | enum | No | parallel \| sequential; default parallel | Execution ordering. |
| interval_ms | integer | No | 0-60000; sequential only | Delay between sequential targets. |
| stop_on_error | boolean | No | Default false | Stop after the first failed target. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| results | OutputOperationResult[] | Always | Per-output ordered results. |
| accepted | integer | Always | Accepted target count. |
| failed | integer | Always | Rejected target count. |
| operation_id | string \| null | Always | Group operation identifier when asynchronous. |

Command-specific errors: duplicate_channel, invalid_channel, batch_too_large
## 4.7  toggle_multiple_outputs
Purpose: Toggle several outputs together.  Support: Relay Module, Dimmer, PDU  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channels | integer[] | Yes | Unique zero-based channels | Outputs to toggle. |
| execution | enum | No | parallel \| sequential; default parallel | Execution ordering. |
| interval_ms | integer | No | 0-60000 | Delay between sequential targets. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| results | OutputOperationResult[] | Always | Per-output resulting states. |
| operation_id | string \| null | Always | Group operation identifier. |

Command-specific errors: duplicate_channel, invalid_channel
## 4.8  restart_multiple_outputs
Purpose: Restart several outputs together.  Support: Relay Module and PDU outputs; capability dependent  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channels | integer[] | Yes | Unique zero-based channels | Outputs to restart. |
| off_time_ms | integer | No | 100-3600000; device default | Off duration. |
| execution | enum | No | parallel \| sequential; default parallel | Execution ordering. |
| interval_ms | integer | No | 0-60000 | Sequential start interval. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| results | OutputOperationResult[] | Always | Per-output acceptance results. |
| operation_id | string | Always | Group operation identifier. |

Command-specific errors: duplicate_channel, invalid_channel, busy
## 4.9  set_output_configuration
Purpose: Change output name, delays, runtimes and startup behavior.  Support: Relay Module, Dimmer, PDU  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |
| name | string | No | 0-64 characters | Display name. |
| enabled | boolean | No | - | Whether control is permitted. |
| on_delay_ms | integer | No | 0-6553500 | Delay before turning on. |
| off_delay_ms | integer | No | 0-6553500 | Delay before turning off. |
| on_runtime_ms | integer | No | 0-6553500; 0 disabled | Automatic on-duration limit. |
| off_runtime_ms | integer | No | 0-6553500; 0 disabled | Automatic off-duration limit. |
| start_delay_ms | integer | No | 0-6553500 | Startup sequencing delay. |
| initial_state | enum | No | off \| on \| restore | State after device startup. |
| restart_off_time_ms | integer | No | 100-3600000 | Default restart cycle off-time. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| output | OutputConfiguration | Always | Complete saved configuration in milliseconds. |
| hardware_apply_required | boolean | Always | Whether hardware apply is required. |

Command-specific errors: invalid_channel, invalid_configuration
# 5. Input-output mappings
Manage mappings using named behaviors while retaining the current numeric codes for migration.
## 5.1  get_mappings
Purpose: Read the complete input-output mapping matrix.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_disabled | boolean | No | Default true | Include mappings for disabled inputs and outputs. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| inputs | integer | Always | Number of input rows. |
| outputs | integer | Always | Number of output columns. |
| mappings | Mapping[] | Always | Sparse mapping records. |
| behavior_codes | object | Always | Numeric legacy-code to behavior-name map. |

## 5.2  get_input_mapping
Purpose: Read mappings for one input.  Support: Relay Module, Dimmer, PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| input | integer | Yes | Zero-based | Input channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| input | integer | Always | Input channel. |
| mappings | Mapping[] | Always | One record for each mapped output. |

Command-specific errors: invalid_channel
## 5.3  set_mapping
Purpose: Create or replace one input-to-output mapping.  Support: Relay Module, Dimmer, PDU  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| input | integer | Yes | Zero-based | Input channel. |
| output | integer | Yes | Zero-based | Output channel. |
| behavior | enum | Yes | none \| on \| off \| toggle \| continuous_on \| continuous_off | Control behavior. |
| parameters | object | No | Behavior-specific | Reserved timing parameters for future behavior types. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| mapping | Mapping | Always | Saved input, output, behavior and legacy code. |
| hardware_apply_required | boolean | Always | Whether hardware apply is required. |

Command-specific errors: invalid_channel, invalid_behavior
## 5.4  clear_mapping
Purpose: Remove one mapping by setting its behavior to none.  Support: Relay Module, Dimmer, PDU  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| input | integer | Yes | Zero-based | Input channel. |
| output | integer | Yes | Zero-based | Output channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| input | integer | Always | Input channel. |
| output | integer | Always | Output channel. |
| removed | boolean | Always | True when a non-empty mapping was cleared. |

Command-specific errors: invalid_channel
## 5.5  apply_hardware_configuration
Purpose: Publish saved mappings and timing configuration to hardware-control services.  Support: Relay Module, Dimmer, PDU  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| wait | boolean | No | Default true | Wait for hardware acknowledgement. |
| timeout_ms | integer | No | 1000-60000; default 10000 | Acknowledgement timeout. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| started | boolean | Always | Whether the apply operation started. |
| completed | boolean | Always | Whether all components acknowledged before response. |
| components | ComponentApplyResult[] | Always | Per-component results. |
| operation_id | string | Always | Operation identifier. |

Command-specific errors: hardware_timeout, component_failed, busy
# 6. Dimmer control
Device-specific brightness commands. Common output commands remain valid for on/off control.
## 6.1  get_dimmer_state
Purpose: Read relay state, requested level and actual level for one dimmer.  Support: Dimmer  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Dimmer output channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Output channel. |
| state | boolean | Always | Logical on/off state. |
| requested_level | number | Always | Saved target percentage, 0.0-100.0. |
| actual_level | number | Always | Current hardware percentage, 0.0-100.0. |
| transitioning | boolean | Always | Whether a fade is active. |
| revision | integer | Always | State revision. |

Command-specific errors: invalid_channel
## 6.2  get_dimmer_levels
Purpose: Read all dimmer requested and actual levels.  Support: Dimmer  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| outputs | DimmerState[] | Always | Ordered dimmer states. |
| revision | integer | Always | State revision. |

## 6.3  set_dimmer_level
Purpose: Set one brightness level.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Dimmer output channel. |
| level | number | Yes | 0.0-100.0 percent | Target brightness. |
| transition_ms | integer | No | 0-3600000; default 0 | Fade duration. |
| turn_on | boolean | No | Default true when level > 0 | Whether a nonzero level should enable the output. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| channel | integer | Always | Output channel. |
| requested_level | number | Always | Accepted target level. |
| actual_level | number | Always | Level at response time. |
| transitioning | boolean | Always | Whether transition remains active. |
| operation_id | string \| null | Always | Transition operation identifier. |

Command-specific errors: invalid_channel, invalid_level, output_disabled
## 6.4  set_multiple_dimmer_levels
Purpose: Set several brightness levels together.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| outputs | DimmerTarget[] | Yes | Unique zero-based channels | Channel, level and optional transition for each output. |
| execution | enum | No | parallel \| sequential; default parallel | Execution ordering. |
| interval_ms | integer | No | 0-60000 | Sequential target interval. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| results | DimmerOperationResult[] | Always | Per-channel acceptance and target levels. |
| operation_id | string \| null | Always | Group transition identifier. |

Command-specific errors: duplicate_channel, invalid_channel, invalid_level
## 6.5  dimmer_on
Purpose: Turn on one dimmer using its saved requested level.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Dimmer channel. |
| transition_ms | integer | No | 0-3600000 | Fade-in duration. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| dimmer | DimmerState | Always | Resulting dimmer state. |

Command-specific errors: invalid_channel, output_disabled
## 6.6  dimmer_off
Purpose: Turn off one dimmer without discarding its saved level.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Dimmer channel. |
| transition_ms | integer | No | 0-3600000 | Fade-out duration. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| dimmer | DimmerState | Always | Resulting dimmer state. |

Command-specific errors: invalid_channel, output_disabled
## 6.7  toggle_dimmer
Purpose: Toggle one dimmer while retaining its target level.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Dimmer channel. |
| transition_ms | integer | No | 0-3600000 | Fade duration. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| dimmer | DimmerState | Always | Resulting dimmer state. |

Command-specific errors: invalid_channel, output_disabled
## 6.8  get_dimmer_frequency
Purpose: Read configured dimmer PWM/drive frequency.  Support: Dimmer  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| frequency_hz | integer | Always | Configured frequency. |
| allowed_hz | integer[] \| range | Always | Supported values or range. |
| apply_required | boolean | Always | Whether a pending value awaits hardware apply. |

## 6.9  set_dimmer_frequency
Purpose: Change dimmer PWM/drive frequency.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| frequency_hz | integer | Yes | One of allowed_hz | Requested frequency. |
| apply_now | boolean | No | Default true | Apply immediately to hardware. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| frequency_hz | integer | Always | Applied or saved frequency. |
| applied | boolean | Always | Whether hardware accepted the value. |
| restart_required | boolean | Always | Whether device restart is required. |

Command-specific errors: invalid_frequency, hardware_error
# 7. PDU energy and override
Energy and protection commands are capability-gated because meter hardware differs by PDU model.
## 7.1  get_energy_summary
Purpose: Read aggregate electrical measurements and counters.  Support: Energy-capable PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| include_channels | boolean | No | Default false | Include per-channel measurements. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| captured_at | datetime | Always | Measurement time. |
| voltage_v | number \| null | Always | Supply voltage. |
| current_a | number \| null | Always | Total current. |
| active_power_w | number \| null | Always | Active power. |
| apparent_power_va | number \| null | Always | Apparent power. |
| power_factor | number \| null | Always | Power factor, 0.0-1.0. |
| frequency_hz | number \| null | Always | Mains frequency. |
| energy_wh | number \| null | Always | Accumulated energy. |
| channels | ChannelEnergy[] | When requested | Per-channel values supported by the meter. |

## 7.2  get_channel_energy
Purpose: Read measurements for one metered output.  Support: PDU with per-channel metering  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based metered output | Output channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| energy | ChannelEnergy | Always | Channel voltage/current/power/energy and timestamp. |

Command-specific errors: invalid_channel, meter_unavailable
## 7.3  get_override_state
Purpose: Read manual or safety override status.  Support: PDU  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | No | Zero-based; omit for all | Optional output channel. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| overrides | OverrideState[] | Always | Active/inactive override state, reason and source. |

## 7.4  set_override_state
Purpose: Enable or clear an override where hardware supports remote override control.  Support: Capability-dependent PDU  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| channel | integer | Yes | Zero-based | Output channel. |
| enabled | boolean | Yes | - | Requested override state. |
| state | boolean | When enabling | - | Forced output state. |
| reason | string | Yes | 1-128 characters | Audit reason. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| override | OverrideState | Always | Applied override state. |
| output | OutputState | Always | Resulting output state. |

Command-specific errors: unsupported_command, invalid_channel, safety_interlock
## 7.5  reset_energy_counters
Purpose: Reset supported accumulated energy counters.  Support: Energy-capable PDU  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| scope | enum | Yes | all \| channel | Counter scope. |
| channel | integer | For channel | Zero-based | Metered output channel. |
| confirmation | string | Yes | Literal RESET | Explicit destructive-operation confirmation. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| reset | boolean | Always | Whether counters were reset. |
| reset_at | datetime | Always | Reset timestamp. |
| channels | integer[] | Always | Affected channels. |

Command-specific errors: confirmation_required, meter_unavailable
## 7.6  get_power_limits
Purpose: Read configured warning and trip limits.  Support: PDU with protection limits  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| limits | PowerLimits | Always | Voltage, current, power and temperature limits with hysteresis. |

## 7.7  set_power_limits
Purpose: Change supported power warning/trip limits.  Support: PDU with protection limits  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| limits | PowerLimitsPatch | Yes | Only capability-advertised fields | Fields to update. |
| apply_now | boolean | No | Default true | Apply to protection service immediately. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| limits | PowerLimits | Always | Complete applied limits. |
| applied | boolean | Always | Whether protection service acknowledged. |

Command-specific errors: invalid_limit, hardware_error
# 8. Schedules and automation
CRUD operations use stable resource objects rather than Windows-page row mutations.
## 8.1  get_schedules
Purpose: List one-time and recurring schedules.  Support: All devices with scheduling  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| type | enum | No | one_time \| recurring | Optional schedule type filter. |
| enabled | boolean | No | - | Optional enabled-state filter. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| schedules | Schedule[] | Always | Schedule records in stable ID order. |
| timezone | string | Always | Time zone used for execution. |

## 8.2  get_schedule
Purpose: Read one schedule.  Support: All devices with scheduling  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule_id | string | Yes | Existing ID | Schedule identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| schedule | Schedule | Always | Complete schedule. |

Command-specific errors: not_found
## 8.3  create_schedule
Purpose: Create a one-time or recurring schedule.  Support: All devices with scheduling  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule | ScheduleCreate | Yes | See Schedule schema | Name, type, timing, actions and enabled state. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| schedule | Schedule | Always | Created schedule with generated ID. |

Command-specific errors: invalid_schedule, schedule_limit, conflict
## 8.4  update_schedule
Purpose: Patch an existing schedule.  Support: All devices with scheduling  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule_id | string | Yes | Existing ID | Schedule identifier. |
| changes | SchedulePatch | Yes | At least one field | Fields to change. |
| expected_revision | integer | No | Current revision | Optimistic concurrency check. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| schedule | Schedule | Always | Updated schedule. |

Command-specific errors: not_found, invalid_schedule, revision_conflict
## 8.5  delete_schedule
Purpose: Delete a schedule.  Support: All devices with scheduling  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule_id | string | Yes | Existing ID | Schedule identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| deleted | boolean | Always | Whether the schedule existed and was deleted. |
| schedule_id | string | Always | Requested identifier. |

Command-specific errors: not_found
## 8.6  enable_schedule
Purpose: Enable or disable a schedule without changing its definition.  Support: All devices with scheduling  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule_id | string | Yes | Existing ID | Schedule identifier. |
| enabled | boolean | Yes | - | Requested state. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| schedule | Schedule | Always | Updated schedule. |

Command-specific errors: not_found
## 8.7  execute_schedule
Purpose: Execute a schedule's actions immediately for testing.  Support: All devices with scheduling  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| schedule_id | string | Yes | Existing ID | Schedule identifier. |
| dry_run | boolean | No | Default false | Validate and return planned actions without applying them. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| accepted | boolean | Always | Whether execution was accepted. |
| actions | ActionResult[] | Always | Validation or execution result for each action. |
| operation_id | string \| null | Always | Asynchronous operation identifier. |

Command-specific errors: not_found, action_failed, busy
## 8.8  get_automations
Purpose: List configured automations.  Support: Capability-dependent  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| type | enum | No | ping_watchdog \| delayed_action \| temperature_control \| tcp_trigger \| api_trigger | Optional type filter. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| automations | Automation[] | Always | Automation records. |

## 8.9  create_automation
Purpose: Create an automation.  Support: Capability-dependent  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| automation | AutomationCreate | Yes | See Automation schema | Type, trigger, actions, name and enabled state. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| automation | Automation | Always | Created automation with generated ID. |

Command-specific errors: invalid_automation, automation_limit
## 8.10  update_automation
Purpose: Patch an automation.  Support: Capability-dependent  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| automation_id | string | Yes | Existing ID | Automation identifier. |
| changes | AutomationPatch | Yes | At least one field | Fields to change. |
| expected_revision | integer | No | Current revision | Optimistic concurrency check. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| automation | Automation | Always | Updated automation. |

Command-specific errors: not_found, invalid_automation, revision_conflict
## 8.11  delete_automation
Purpose: Delete an automation.  Support: Capability-dependent  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| automation_id | string | Yes | Existing ID | Automation identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| deleted | boolean | Always | Whether the resource was deleted. |
| automation_id | string | Always | Requested identifier. |

Command-specific errors: not_found
## 8.12  enable_automation
Purpose: Enable or disable an automation.  Support: Capability-dependent  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| automation_id | string | Yes | Existing ID | Automation identifier. |
| enabled | boolean | Yes | - | Requested state. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| automation | Automation | Always | Updated automation. |

Command-specific errors: not_found
# 9. Dimmer scenarios and sequences
Scenario and sequence resources replace page-specific scenario/sequence mutations.
## 9.1  get_scenarios
Purpose: List dimmer scenarios.  Support: Dimmer  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| scenarios | Scenario[] | Always | Scenario definitions. |

## 9.2  create_scenario
Purpose: Create a named set of dimmer/output targets.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| scenario | ScenarioCreate | Yes | At least one target | Name, targets and default transition. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| scenario | Scenario | Always | Created scenario. |

Command-specific errors: invalid_scenario, scenario_limit
## 9.3  update_scenario
Purpose: Patch a scenario.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| scenario_id | string | Yes | Existing ID | Scenario identifier. |
| changes | ScenarioPatch | Yes | At least one field | Fields to change. |
| expected_revision | integer | No | Current revision | Optimistic concurrency check. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| scenario | Scenario | Always | Updated scenario. |

Command-specific errors: not_found, invalid_scenario, revision_conflict
## 9.4  delete_scenario
Purpose: Delete a scenario.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| scenario_id | string | Yes | Existing ID | Scenario identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| deleted | boolean | Always | Deletion result. |
| scenario_id | string | Always | Requested identifier. |

Command-specific errors: not_found, resource_in_use
## 9.5  execute_scenario
Purpose: Apply a scenario.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| scenario_id | string | Yes | Existing ID | Scenario identifier. |
| transition_ms | integer | No | 0-3600000 | Override default transition. |
| dry_run | boolean | No | Default false | Validate without changing outputs. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| accepted | boolean | Always | Whether execution was accepted. |
| results | DimmerOperationResult[] | Always | Per-target results. |
| operation_id | string \| null | Always | Transition identifier. |

Command-specific errors: not_found, action_failed
## 9.6  get_sequences
Purpose: List scenario sequences.  Support: Dimmer  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| (none) | - | - | - | Command has no action-specific parameters. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| sequences | Sequence[] | Always | Sequence definitions. |

## 9.7  create_sequence
Purpose: Create an ordered scenario/action sequence.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sequence | SequenceCreate | Yes | At least one step | Name, steps and loop settings. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| sequence | Sequence | Always | Created sequence. |

Command-specific errors: invalid_sequence, sequence_limit
## 9.8  update_sequence
Purpose: Patch a sequence.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sequence_id | string | Yes | Existing ID | Sequence identifier. |
| changes | SequencePatch | Yes | At least one field | Fields to change. |
| expected_revision | integer | No | Current revision | Optimistic concurrency check. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| sequence | Sequence | Always | Updated sequence. |

Command-specific errors: not_found, invalid_sequence, revision_conflict
## 9.9  delete_sequence
Purpose: Delete a sequence.  Support: Dimmer  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sequence_id | string | Yes | Existing ID | Sequence identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| deleted | boolean | Always | Deletion result. |
| sequence_id | string | Always | Requested identifier. |

Command-specific errors: not_found, resource_in_use
## 9.10  start_sequence
Purpose: Start a sequence.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sequence_id | string | Yes | Existing ID | Sequence identifier. |
| start_step | integer | No | Zero-based; default 0 | First step to execute. |
| loop_count | integer | No | 0-65535; 0 uses saved setting | Runtime loop override. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| accepted | boolean | Always | Whether start was accepted. |
| operation_id | string | Always | Running sequence identifier. |
| sequence_id | string | Always | Definition identifier. |
| step | integer | Always | Initial zero-based step. |

Command-specific errors: not_found, busy, invalid_step
## 9.11  stop_sequence
Purpose: Stop one running sequence operation.  Support: Dimmer  Permission: Control
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| operation_id | string | Yes | Running operation | Operation returned by start_sequence. |
| output_behavior | enum | No | hold \| off \| restore; default hold | What outputs do after stopping. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| stopped | boolean | Always | Whether a running operation was stopped. |
| operation_id | string | Always | Requested operation identifier. |
| outputs | DimmerState[] | Always | Resulting output states. |

Command-specific errors: not_found
# 10. Configuration, network and security
Configuration is organized into stable sections but is not coupled to a UI page layout.
## 10.1  get_configuration
Purpose: Read one or more configuration sections.  Support: All devices  Permission: Read
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| sections | string[] | No | Default all permitted | general, account, lan, wifi, time, temperature, tcp_access, api_access, mqtt, tls, maintenance. |
| include_secrets | boolean | No | Default false; Admin only | Return only retrievable secrets; passwords normally remain write-only. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| configuration | object | Always | Map of section name to typed section object. |
| revision | integer | Always | Configuration revision. |
| restart_required | boolean | Always | Whether pending configuration needs a restart. |

Command-specific errors: unknown_section, permission_denied
## 10.2  set_configuration
Purpose: Patch one configuration section.  Support: All devices  Permission: Configure or Admin by section
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| section | string | Yes | Supported configuration section | Section to change. |
| values | object | Yes | Section-specific schema | Fields to patch; omitted fields are unchanged. |
| expected_revision | integer | No | Current revision | Optimistic concurrency check. |
| apply_now | boolean | No | Default true | Apply service changes immediately when safe. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| section | string | Always | Updated section. |
| values | object | Always | Complete sanitized section after update. |
| revision | integer | Always | New configuration revision. |
| applied | boolean | Always | Whether change is active. |
| restart_required | boolean | Always | Whether restart is required. |

Command-specific errors: unknown_section, invalid_configuration, revision_conflict
## 10.3  scan_wifi
Purpose: Scan for nearby Wi-Fi networks.  Support: Devices with Wi-Fi  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| timeout_ms | integer | No | 2000-30000; default 10000 | Scan timeout. |
| include_hidden | boolean | No | Default false | Include hidden-network placeholders. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| networks | WifiNetwork[] | Always | SSID, signal, security and channel; never credentials. |
| duration_ms | integer | Always | Scan duration. |

Command-specific errors: wifi_unavailable, busy
## 10.4  test_network
Purpose: Test name resolution and TCP reachability without saving settings.  Support: All devices  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| host | string | Yes | Host name or IP | Target host. |
| port | integer | No | 1-65535 | Optional TCP port. |
| timeout_ms | integer | No | 500-30000; default 5000 | Test timeout. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| dns_ok | boolean \| null | Always | DNS result when a host name is supplied. |
| resolved_addresses | string[] | Always | Resolved addresses. |
| reachable | boolean | Always | ICMP or TCP reachability result. |
| latency_ms | integer \| null | Always | Measured latency. |
| message | string | Always | Outcome summary. |

## 10.5  test_mqtt
Purpose: Test MQTT connection and optional publish without saving settings.  Support: Devices with MQTT  Permission: Configure
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| host | string | Yes | Host name or IP | Broker. |
| port | integer | Yes | 1-65535 | Broker port. |
| tls | boolean | No | Default false | Use TLS. |
| username | string | No | - | Broker username. |
| password | string | No | Write-only | Broker password. |
| topic | string | No | Valid MQTT topic | Optional test publish topic. |
| timeout_ms | integer | No | 1000-30000 | Connection timeout. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| connected | boolean | Always | Connection result. |
| published | boolean \| null | Always | Publish result when requested. |
| latency_ms | integer \| null | Always | Connection latency. |
| message | string | Always | Sanitized outcome. |

Command-specific errors: tls_error, connection_failed, authentication_failed
## 10.6  get_access_rules
Purpose: List TCP or API IP/MAC allow rules.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| service | enum | Yes | legacy_tcp \| control_api | Rule collection. |
| kind | enum | No | ip \| mac | Optional rule type filter. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| service | enum | Always | Requested service. |
| rules | AccessRule[] | Always | Ordered allow rules. |
| filter_enabled | boolean | Always | Whether rules are enforced. |

## 10.7  add_access_rule
Purpose: Add an IP/CIDR or MAC allow rule.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| service | enum | Yes | legacy_tcp \| control_api | Target service. |
| kind | enum | Yes | ip \| mac | Rule type. |
| value | string | Yes | IP/CIDR or MAC syntax | Allowed value. |
| name | string | No | 0-64 characters | Friendly label. |
| enabled | boolean | No | Default true | Rule state. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| rule | AccessRule | Always | Created rule with ID. |

Command-specific errors: invalid_rule, duplicate_rule, rule_limit
## 10.8  update_access_rule
Purpose: Patch an access rule.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| rule_id | string | Yes | Existing ID | Rule identifier. |
| changes | AccessRulePatch | Yes | At least one field | value, name or enabled. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| rule | AccessRule | Always | Updated rule. |

Command-specific errors: not_found, invalid_rule, duplicate_rule
## 10.9  delete_access_rule
Purpose: Delete an access rule.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| rule_id | string | Yes | Existing ID | Rule identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| deleted | boolean | Always | Deletion result. |
| rule_id | string | Always | Requested identifier. |

Command-specific errors: not_found
# 11. Backup, restore and firmware transfer
Chunked transfer commands support TCP and HTTP consistently. HTTP may additionally use direct upload endpoints later.
## 11.1  upload_begin
Purpose: Create a settings, certificate or firmware upload session.  Support: All devices; kind capability-dependent  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| kind | enum | Yes | settings_restore \| firmware \| tls_certificate \| tls_key | Upload purpose. |
| file_name | string | Yes | Base name only, 1-128 characters | Display/audit file name. |
| size_bytes | integer | Yes | 1 to advertised limit | Total decoded size. |
| sha256 | string | Yes | 64 lowercase hex characters | Expected file hash. |
| metadata | object | No | Kind-specific | Version or certificate metadata. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| transfer_id | string | Always | Upload session identifier. |
| chunk_size | integer | Always | Required/maximum decoded chunk bytes. |
| expires_in_s | integer | Always | Idle session lifetime. |
| next_offset | integer | Always | Initial byte offset, normally 0. |

Command-specific errors: file_too_large, invalid_hash, transfer_limit, busy
## 11.2  upload_chunk
Purpose: Append one base64-encoded upload chunk.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| transfer_id | string | Yes | Active upload | Upload identifier. |
| offset | integer | Yes | Exactly next_offset | Decoded byte offset. |
| data | base64 string | Yes | At most chunk_size decoded bytes | Chunk data. |
| chunk_sha256 | string | No | 64 hex characters | Optional per-chunk integrity check. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| received_bytes | integer | Always | Total decoded bytes received. |
| next_offset | integer | Always | Required next byte offset. |
| complete | boolean | Always | Whether declared size has been received. |

Command-specific errors: not_found, offset_mismatch, invalid_base64, hash_mismatch
## 11.3  upload_finish
Purpose: Validate the uploaded file and close data transfer.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| transfer_id | string | Yes | Active upload | Upload identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| validated | boolean | Always | Size/hash and kind validation result. |
| sha256 | string | Always | Calculated full-file hash. |
| metadata | object | Always | Validated firmware/settings/certificate metadata. |
| commit_required | boolean | Always | Whether upload_commit must follow. |

Command-specific errors: not_found, incomplete_transfer, hash_mismatch, invalid_file
## 11.4  upload_commit
Purpose: Install or restore a validated upload.  Support: All devices; kind capability-dependent  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| transfer_id | string | Yes | Validated upload | Upload identifier. |
| reboot | boolean | No | Default true when required | Allow automatic reboot. |
| confirmation | string | Yes | Kind-specific literal supplied by upload_finish | Explicit destructive-operation confirmation. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| accepted | boolean | Always | Whether commit started. |
| operation_id | string | Always | Install/restore operation identifier. |
| reboot_required | boolean | Always | Whether reboot is required. |
| reboot_in_ms | integer \| null | Always | Automatic reboot delay. |

Command-specific errors: not_found, confirmation_required, validation_expired, install_failed
## 11.5  download_begin
Purpose: Create a settings-backup or diagnostic download.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| kind | enum | Yes | settings_backup \| diagnostics | Download content. |
| options | object | No | Kind-specific | Optional inclusion/redaction settings. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| transfer_id | string | Always | Download session identifier. |
| file_name | string | Always | Suggested safe file name. |
| size_bytes | integer | Always | Total decoded size. |
| sha256 | string | Always | File hash. |
| chunk_size | integer | Always | Maximum read chunk bytes. |
| expires_in_s | integer | Always | Idle session lifetime. |

Command-specific errors: busy, generation_failed
## 11.6  download_chunk
Purpose: Read one base64-encoded download chunk.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| transfer_id | string | Yes | Active download | Download identifier. |
| offset | integer | Yes | 0 to size_bytes | Decoded byte offset. |
| length | integer | No | 1 to chunk_size | Requested decoded length. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| offset | integer | Always | Returned decoded byte offset. |
| data | base64 string | Always | Chunk data. |
| length | integer | Always | Decoded chunk bytes. |
| next_offset | integer | Always | Next sequential offset. |
| complete | boolean | Always | Whether end-of-file was reached. |

Command-specific errors: not_found, invalid_offset
## 11.7  download_finish
Purpose: Close and delete a generated download session.  Support: All devices  Permission: Admin
Parameters

| Field | Type | Required | Constraints/default | Description |
|---|---|---|---|---|
| transfer_id | string | Yes | Active download | Download identifier. |

Expected result

| Field | Type | Presence | Description |
|---|---|---|---|
| closed | boolean | Always | Whether session was closed. |
| transfer_id | string | Always | Requested identifier. |

Command-specific errors: not_found
# Shared data schemas
These compact definitions identify the fields expected in repeated result objects. A later JSON Schema/OpenAPI file can make them machine-validatable without changing the command contract.

| Type | Required/core fields |
|---|---|
| DeviceInfo | device_id, name, device_type, model, serial_number, firmware_version, hardware_version |
| Topology | input_count, virtual_input_count, output_count, sensor_count |
| InputState | kind, channel, name, enabled, state, mode, active_level, debounce_ms, changed_at |
| OutputState | channel, name, enabled, state, pending, requested_level?, actual_level?, configuration?, changed_at |
| OutputConfiguration | channel, name, enabled, delays/runtimes in ms, initial_state, restart_off_time_ms |
| Mapping | input, output, behavior, legacy_code; codes: 0 none, 1 on, 2 off, 3 toggle, 4 continuous_on, 5 continuous_off |
| Schedule | id, revision, name, enabled, type, timing, actions, last_run, next_run |
| Schedule timing | one_time: datetime; recurring: time, weekdays[0=Monday..6=Sunday], optional start/end dates |
| Action | action plus params; only capability-advertised control actions are permitted |
| Automation | id, revision, name, enabled, type, trigger configuration and actions |
| Scenario | id, revision, name, default_transition_ms and targets[channel,state,level] |
| Sequence | id, revision, name, steps[scenario_id or actions, hold_ms], loop_count |
| TemperatureReading | sensor_id, name, value_c, status, timestamp |
| ChannelEnergy | channel, voltage_v?, current_a?, active_power_w?, apparent_power_va?, power_factor?, energy_wh?, timestamp |
| AccessRule | id, service, kind, value, name, enabled, revision |
| Fault | fault_id, severity, code, message, active, first_seen, last_seen |

## Configuration section schemas

| Section | Fields |
|---|---|
| general | name, location?, description?, language?, physical_input_count (read-only), output_count (read-only) |
| account | username, password (write-only), session_timeout_s, password_change_required |
| lan | mode[dhcp\|static], address, subnet_mask, gateway, dns_servers[], control_port default 5008, legacy_port default 5005 |
| wifi | enabled, mode[dhcp\|static], ssid, password (write-only), address, subnet_mask, gateway, dns_servers[] |
| time | timezone, sync_mode[manual\|ntp], ntp_server, sync_interval_s |
| temperature | enabled, low_warning_c, high_warning_c, control/hysteresis fields where supported |
| tcp_access | legacy_enabled, legacy_port, allow_filter_enabled; rules are managed separately |
| api_access | enabled, control_port, http_enabled, https_enabled, authentication_required, rate limits |
| mqtt | enabled, host, port, tls, username, password(write-only), client_id, base_topic, qos |
| tls | enabled, certificate metadata, key_present, minimum_tls_version; key material is write-only via upload |
| maintenance | log_level, automatic_backup settings, retention, update channel where supported |

# Device events
Events are unsolicited messages on subscribed TCP/WebSocket sessions or SSE streams. They use protocol, event, subscription_id and data fields; they do not contain ok or result.
```json
{"protocol":3,"event":"output_state_changed","subscription_id":"sub-7","data":{"channel":0,"previous_state":false,"state":true,"pending":false,"source":"windows-app","revision":312,"timestamp":"2026-08-31T10:20:30+00:00"}}
```

| Event | Expected data fields |
|---|---|
| output_state_changed | channel, previous_state, state, pending, source, revision, timestamp |
| output_level_changed | channel, requested_level, actual_level, transitioning, source, revision, timestamp |
| input_state_changed | kind, channel, previous_state, state, source, revision, timestamp |
| mapping_changed | input, output, behavior, legacy_code, revision, timestamp |
| temperature_changed | sensor_id, value_c, status, timestamp |
| energy_changed | summary and/or channel readings, timestamp |
| schedule_executed | schedule_id, results, success, timestamp |
| automation_executed | automation_id, trigger, results, success, timestamp |
| sequence_state_changed | sequence_id, operation_id, state, step, loop, timestamp |
| operation_progress | operation_id, kind, stage, progress_percent, message, timestamp |
| device_fault | fault_id, severity, code, message, active, timestamp |
| configuration_changed | section, revision, source, restart_required, timestamp |
| device_rebooting | reason, reboot_in_ms, timestamp |

Synchronization: Clients must treat events as incremental updates. If revisions are skipped, reconnecting clients should call get_device_state to rebuild a complete state snapshot.
# Migration and acceptance criteria
* Firmware first exposes the version 3 hello command on port 5008 while leaving port 5005 behavior unchanged.
* The Windows application probes port 5008, authenticates when required, then calls get_device_state.
* When port 5008 is unavailable, the Windows application can temporarily fall back to its current communication path.
* Each migrated screen is tested against Relay Module, Dimmer, PDU 10 kW and PDU v1 capabilities as applicable.
* Only after the updated Windows application is deployed and validated are J: commands removed from port 5005.
* The mobile application uses version 3 only and relies on get_capabilities instead of device-model assumptions.
* Automated protocol tests verify framing, split/combined TCP packets, invalid JSON, authentication, index bounds, concurrency and reconnection.
Approval point: Before implementation, confirm command names, permission assignments, output delay units, schedule semantics, PDU override support and the exact firmware families included in the first release.
