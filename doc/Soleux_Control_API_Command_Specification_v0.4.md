__Soleux Control API__

TCP Default \+ 3 and HTTP/HTTPS Command Specification

Status: all five device transport profiles and TCP/API service access switches implemented; full command catalogue remains the target contract

__Audience: __Device firmware, Windows application and mobile application developers

__Transports: __TCP legacy port \+ 3 \(5008 by default\), HTTP port 80 and HTTPS port 443

Compatibility: migrated device base ports are AT\-only; Windows device paths use the Control API

Implementation status: Relay Module, AC/DC Dimmer, PDU Energy Meter, High Power PDU and PDU V1 firmware expose their implemented protocol 2 command subsets on the configured base TCP port plus 3 and through POST /api/v1/command over HTTP or HTTPS\. Every family also implements the persisted tcp\_enabled and api\_enabled Security\-page switches documented below\. The broader version 3 catalogue remains the target contract; clients must use hello/capability data and must not assume every catalogued action is available on every family\.

# Document purpose

This specification defines one transport\-neutral command model for Soleux device firmware, the Windows application, the upcoming mobile application and third\-party HTTP/HTTPS integrations\. Migrated device control no longer uses app\-only J: messages\. The configured base port remains available for legacy AT clients, while modern clients use the separate Control API transport\.

## Normative rules

1. All physical input, virtual\-input and output indexes are zero\-based on every transport\.
2. JSON booleans are true/false; API clients must not send 0/1 as boolean substitutes\.
3. Time durations use integer milliseconds unless a field name explicitly ends in \_s\.
4. Electrical and environmental units are included in field names: \_v, \_a, \_w, \_va, \_wh, \_hz and \_c\.
5. Timestamps use ISO 8601 with an offset\. Event timestamps should be UTC where practical\.
6. Unknown fields may be ignored only when the negotiated protocol version permits forward\-compatible extensions\.
7. Secrets are write\-only unless a command explicitly documents that they can be returned\.
8. Every state\-changing command identifies its required permission and produces an auditable source/session identity\.

## Command groups

- Session and protocol: 7 commands\. Commands used to establish a session, discover functionality and manage message delivery\.
- Device information and health: 10 commands\. Read device identity, full state, health, temperature and time, and perform administrative actions\.
- Inputs and virtual inputs: 5 commands\. Read and configure physical inputs and operate virtual inputs\. All input channels are zero\-based\.
- Outputs: 9 commands\. Live relay and dimmer control\. These commands replace ON, OFF, TOGGLE, RESTART and masked AT operations\.
- Input\-output mappings: 5 commands\. Manage mappings using named behaviors while retaining the current numeric codes for migration\.
- Dimmer control: 9 commands\. Device\-specific brightness commands\. Common output commands remain valid for on/off control\.
- PDU energy and override: 7 commands\. Energy and protection commands are capability\-gated because meter hardware differs by PDU model\.
- Schedules and automation: 12 commands\. CRUD operations use stable resource objects rather than Windows\-page row mutations\.
- Dimmer scenarios and sequences: 11 commands\. Scenario and sequence resources replace page\-specific scenario/sequence mutations\.
- Configuration, network and security: 9 commands\. Configuration is organized into stable sections but is not coupled to a UI page layout\.
- Backup, restore and firmware transfer: 7 commands\. Chunked transfer commands support TCP and HTTP consistently\. HTTP may additionally use direct upload endpoints later\.

__Catalogue size: __This draft defines 91 request actions and 13 device event types\.

# Transport and message envelope

The action and params object is identical on TCP, HTTP and HTTPS\. Each HTTP request is dispatched through the same command handler used by the newline\-delimited TCP service, so command parameters and result envelopes do not change between transports\.

## Request envelope

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

protocol

integer

Yes

2 for current Relay; 3 for target contract

Protocol version\.

id

integer|string

Yes

Unique among pending requests

Caller\-generated correlation ID\.

action

string

Yes

Exact action name

Command to execute\.

params

object

No

Default \{\}

Command\-specific parameters\.

timeout\_ms

integer

No

100\-120000

Optional caller timeout hint; does not override safety limits\.

\{"protocol":2,"id":42,"action":"set\_output\_state","params":\{"channel":0,"state":true\}\}

## Success response

__Field__

__Type__

__Presence__

__Description__

protocol

integer

Always

Protocol version\.

id

integer|string

Always

Original request ID\.

ok

boolean

Always

True for a successful command\.

result

object

Always

Command\-specific expected result\.

\{"protocol":2,"id":42,"ok":true,"result":\{"channel":0,"requested\_state":true,"actual\_state":true,"pending":false\}\}

## Error response

__Field__

__Type__

__Presence__

__Description__

protocol

integer

Always

Protocol version\.

id

integer|string|null

Always

Original ID, or null when it could not be parsed\.

ok

boolean

Always

False for an error\.

error\.code

string

Always

Stable machine\-readable error code\.

error\.message

string

Always

Safe human\-readable explanation\.

error\.details

object

Optional

Structured validation or recovery data\.

error\.retryable

boolean

Always

Whether retry may succeed without changing the request\.

\{"protocol":2,"id":42,"ok":false,"error":\{"code":"invalid\_request","message":"output channel out of range"\}\}

## Transport mapping

__Transport__

__Request framing__

__Response framing__

__Events__

TCP: legacy port \+ 3

One UTF\-8 JSON object per line \(CRLF or LF\)\. Default 5005 becomes Control API 5008\.

One JSON response line using the common envelope\.

Command responses only in the current Relay implementation\.

HTTP port 80

POST /api/v1/command with application/json\.

HTTP status plus the common JSON envelope\.

No Control API SSE endpoint is implemented yet\.

HTTPS port 443

Same endpoint over TLS\. When SSL is enabled, HTTP receives a 307 redirect that preserves POST and body\.

Same common JSON envelope\.

No secure event endpoint is implemented yet\.

WebSocket / SSE

Reserved for a future event transport\.

Not currently a Control API command transport\.

Planned; capability\-dependent\.

## Implemented HTTP/HTTPS endpoint

Each migrated device family exposes one transport\-neutral command endpoint\. Every action available on that device's JSON TCP Control API is accepted at POST /api/v1/command, including state/configuration operations, page configuration and actions, system\-log pagination and deletion, and supported file\-transfer operations\.

__Property__

__Implemented behavior__

Endpoint

POST /api/v1/command

Media type

Request and response use application/json; the response also sets Cache\-Control: no\-store\.

Request body

One JSON object using the common protocol, id, action and params fields\.

Maximum body

1,048,576 bytes\. The limit is enforced with or without a Content\-Length header\.

Dispatch

The request is passed to the same process\_tcp\_json dispatcher used by the TCP Control API\.

Client access

api\_enabled must be true\. Existing HTTP API IP/MAC rules then apply to the direct socket peer; forwarding headers are not trusted for authorization\.

HTTP/HTTPS

The same Flask endpoint is served on HTTP 80 when SSL is off and HTTPS 443 when SSL is on\.

Legacy API

The existing /cmdapi endpoint is unchanged and remains separate from this JSON command endpoint\.

## HTTP status mapping

__Status__

__Meaning__

__Response__

200

The command completed successfully\.

ok is true and result contains the command output\.

400

Malformed body, invalid parameters or unknown action\.

ok is false with invalid\_request, unknown\_action or another command error\.

403

The peer is not allowed by the configured API IP/MAC rules\.

ok is false with unauthorized\.

413

The request body exceeds 1 MiB\.

ok is false with message\_too\_large\.

503

The HTTP/HTTPS Control API is disabled\.

ok is false, id is null and error\.code is api\_disabled\.

504

An asynchronous device or hardware operation timed out\.

ok is false with timeout\.

500

The dispatcher failed internally or produced an invalid response\.

ok is false with internal\_error\.

## HTTP request example

POST /api/v1/command HTTP/1\.1  
Content\-Type: application/json  
  
\{"protocol":2,"id":"mobile\-1","action":"hello","params":\{\}\}

\{"protocol":2,"id":"mobile\-1","ok":true,"result":\{"device":"dimmer","api\_port":5008\}\}

## Verification commands

Run the source\-level contract tests from the Soleux App project root on a developer computer with Python 3\. Each active device family has its own tests folder; the Dimmer command contract is verified with:

python \-m unittest discover \-s "Device Firmware\\Dimmer\\tests" \-p "test\_\*\.py" \-v

After deploying the matching firmware files and restarting WebService, run this on the device to verify the live HTTP endpoint:

curl \-sS \-X POST http://127\.0\.0\.1/api/v1/command \\  
  \-H 'Content\-Type: application/json' \\  
  \-d '\{"protocol":2,"id":"test\-1","action":"hello","params":\{\}\}'

Use https://127\.0\.0\.1/api/v1/command when SSL is enabled\. A successful response has ok: true and reports the calculated api\_port\.

Compatibility rule: The J: prefix is not accepted on the Control API or migrated base ports\. Standard Windows paths use unprefixed JSON on base port \+ 3 and do not send AT commands or fall back to the AT\-only base port\. Adding the HTTP/HTTPS endpoint does not change existing legacy AT behavior\.

# Permissions and security

__Permission__

__Allows__

Public

hello, ping and authenticate only\.

Read

Read identity, state, configuration summaries, telemetry and events\.

Control

Change live input/output/dimmer state and execute schedules/scenarios\.

Configure

Change mappings, channel configuration, schedules, automations and non\-secret settings\.

Admin

Accounts, access rules, network/security settings, backup/restore, firmware, reboot and destructive actions\.

The implemented HTTP/HTTPS command endpoint first requires api\_enabled\. When enabled, each device's existing API IP/MAC allow rules apply to the direct socket peer\. Disabling filtering allows any reachable peer; it is different from disabling the API service\. Forwarding headers are not trusted\. Restrict HTTP to trusted local networks and use HTTPS for credentials, backup/restore, firmware, or remote/mobile access\. Tokens and secrets must never be written to normal logs\.

## Implemented service access switches

All five active firmware families persist the following independent Security\-page switches\. Both default to enabled\. Changing either switch schedules a WebService restart after the current response is delivered\.

__Security field__

__Behavior when disabled__

__Still available and recovery__

tcp\_enabled

Closes and suppresses the base TCP, base \+ 1 and Control API TCP base \+ 3 listeners after restart\. Existing TCP sessions close and the Windows app cannot connect\.

UDP discovery, UDP heartbeat base \+ 2 and the web UI remain available\. Re\-enable TCP from the web Security page\.

api\_enabled

HTTP/HTTPS command routes return status 503 with id null and error\.code api\_disabled\. Raw Control API TCP is not closed\.

The normal web UI remains available\. Re\-enable API from the web Security page\.

Disabling API does not close Control API TCP; disabling TCP does\. If both are disabled, the web Security page remains the recovery path\. Discovery or heartbeat success therefore does not prove that device control is enabled\.

\{"protocol":2,"id":null,"ok":false,"error":\{"code":"api\_disabled","message":"HTTP/HTTPS API access is disabled\."\}\}

## Implemented AC/DC Dimmer profile

The active Dimmer firmware accepts unprefixed protocol 2 JSON on base\_port \+ 3 \(normally 5008\) and the identical command object through POST /api/v1/command over HTTP or HTTPS\. The base port remains AT\-only and rejects J\-prefixed traffic\.

All Dimmer input, output and mapping indices are zero\-based\. set\_dimmer\_level requires channel and an integer value from 0 through 100\. set\_output\_state and restart\_output use the same zero\-based channel rule\.

get\_device\_state returns requested set\_pwm and live actual\_pwm for every output, plus I/O state, PWM frequency, sensors, system and network data\. Clients should poll this snapshot when a state\-changing result reports pending: true\.

The Dimmer also implements device identity, relay configuration, input/output configuration, mappings, hardware write, settings/security/system/schedule/automation/scenario/sequence pages, chunked backup/restore, paginated system logs and execute\_page\_action delete\_system\_logs\.

Discovery advertises PORT, API\_PORT, API\_VER and CAPS\. Heartbeat uses base\_port \+ 2 and reports tcp\_port, api\_port and api\_version\. Both offsets are calculated from the configured base port\.

# Common error catalogue

Every error uses the common error envelope\. Commands may document additional codes\.

__Code__

__Meaning__

invalid\_request

Envelope or JSON structure is invalid\.

unknown\_action

Action name is not recognized\.

unsupported\_command

Device recognizes the action but does not support it\.

unsupported\_protocol

No mutually supported protocol version exists\.

authentication\_required

A valid authenticated session is required\.

authentication\_failed

Credentials or token were rejected\.

permission\_denied

Session lacks the required permission\.

invalid\_parameter

A parameter has the wrong type, range or value\.

invalid\_channel

Input/output channel is outside the zero\-based device range\.

not\_found

Requested resource or operation does not exist\.

revision\_conflict

expected\_revision does not match current resource revision\.

busy

A conflicting operation is active\.

interlock

A safety or control interlock prevented the operation\.

timeout

The operation did not complete within its allowed time\.

rate\_limited

Caller exceeded the configured request limit\.

payload\_too\_large

Message or transfer exceeds advertised limits\.

internal\_error

Unexpected device\-side failure; message must not expose secrets\.

api\_disabled

The HTTP/HTTPS Control API is disabled in device Security settings\.

# Command catalogue

Each action below defines action\-specific params and the result object returned inside the common response envelope\. An absent optional parameter means the device uses its current value or documented default; null is not interchangeable with omission unless explicitly stated\.

# __1\. Session and protocol__

Commands used to establish a session, discover functionality and manage message delivery\.

## __1\.1  hello__

__Purpose: __Negotiate the protocol and identify the client and device\.  __Support: __All devices  __Permission: __Public

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

client\_name

string

No

1\-64 characters

Name of the calling application\.

client\_version

string

No

Semantic version recommended

Calling application version\.

protocol\_min

integer

No

Default 3

Oldest protocol version accepted by the client\.

protocol\_max

integer

No

Default 3

Newest protocol version accepted by the client\.

features

string\[\]

No

Unique values

Optional client features such as events, batch and compression\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

protocol

integer

Always

Negotiated protocol version\.

session\_id

string

Always

Identifier for this connection or HTTP session\.

device

DeviceInfo

Always

Device identity, model and firmware summary\.

topology

Topology

Always

Input, virtual\-input and output counts\.

limits

ProtocolLimits

Always

Payload, batch and subscription limits\.

authentication\_required

boolean

Always

Whether protected commands require authentication\.

__Command\-specific errors: __unsupported\_protocol

## __1\.2  ping__

__Purpose: __Check reachability and estimate round\-trip time\.  __Support: __All devices  __Permission: __Public

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

echo

any JSON value

No

Maximum 256 encoded bytes

Value returned unchanged\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

echo

any JSON value

When supplied

Original echo value\.

server\_time

datetime

Always

Current device time in ISO 8601 format\.

uptime\_ms

integer

Always

Milliseconds since the control service started\.

## __1\.3  authenticate__

__Purpose: __Create an authenticated API session\.  __Support: __All devices with API security enabled  __Permission: __Public

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

method

enum

Yes

password | token

Authentication method\.

username

string

For password

1\-64 characters

Account name\.

password

string

For password

HTTPS or protected TCP only

Account password; never logged\.

token

string

For token

Opaque token

Previously issued API token\.

client\_name

string

No

1\-64 characters

Friendly client identifier for audit logs\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

access\_token

string

Always

Bearer/session token\.

expires\_in\_s

integer

Always

Token lifetime in seconds; 0 means connection lifetime\.

permissions

string\[\]

Always

Granted permission names\.

user

object

Always

Authenticated account summary without password data\.

__Command\-specific errors: __authentication\_failed, insecure\_transport, account\_locked

## __1\.4  get\_capabilities__

__Purpose: __Return supported commands, events and device\-specific limits\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_schemas

boolean

No

Default false

Include compact parameter/result schema metadata\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

commands

Capability\[\]

Always

Supported actions and required permissions\.

events

string\[\]

Always

Supported event names\.

transports

object

Always

TCP, HTTP, HTTPS and event transport availability\.

features

string\[\]

Always

Device features such as dimmer, energy or Wi\-Fi\.

limits

ProtocolLimits

Always

Current service limits\.

## __1\.5  subscribe__

__Purpose: __Subscribe a persistent TCP or WebSocket session to device events\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

events

string\[\]

Yes

At least one supported event or \*

Event names to receive\.

channels

integer\[\]

No

Zero\-based and unique

Optional input/output channel filter\.

min\_interval\_ms

integer

No

0\-60000; default 0

Minimum interval for coalescible telemetry events\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

subscription\_id

string

Always

Identifier used by unsubscribe\.

events

string\[\]

Always

Accepted event names\.

channels

integer\[\] | null

Always

Applied channel filter or null for all\.

min\_interval\_ms

integer

Always

Applied telemetry interval\.

__Command\-specific errors: __unsupported\_event, invalid\_channel, subscription\_limit

## __1\.6  unsubscribe__

__Purpose: __Remove a previously created event subscription\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

subscription\_id

string

Yes

Existing subscription

Subscription to remove\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

removed

boolean

Always

True when the subscription existed and was removed\.

__Command\-specific errors: __not\_found

## __1\.7  batch\_execute__

__Purpose: __Execute multiple independent commands in one request\.  __Support: __All devices  __Permission: __Highest permission required by a child command

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

commands

CommandRequest\[\]

Yes

1 to device batch limit

Child requests without protocol/session fields\.

stop\_on\_error

boolean

No

Default false

Do not start later commands after a failure\.

atomic

boolean

No

Default false; capability dependent

Request transactional execution when supported\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

results

BatchResult\[\]

Always

Ordered child success/error results\.

completed

integer

Always

Number of child commands attempted\.

rolled\_back

boolean

Always

Whether an atomic batch was rolled back\.

__Command\-specific errors: __batch\_too\_large, atomic\_not\_supported

# __2\. Device information and health__

Read device identity, full state, health, temperature and time, and perform administrative actions\.

## __2\.1  get\_device\_info__

__Purpose: __Read stable device identity and software versions\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

device\_id

string

Always

Stable unique identifier\.

name

string

Always

Configured device name\.

device\_type

enum

Always

relay\_module | dimmer | pdu\_10kw | pdu\_v1

model

string

Always

Hardware model\.

serial\_number

string | null

Always

Serial number if available\.

firmware\_version

string

Always

Firmware/application version\.

hardware\_version

string | null

Always

Hardware revision when available\.

mac\_addresses

object

Always

Available Ethernet and Wi\-Fi MAC addresses\.

## __2\.2  get\_device\_health__

__Purpose: __Read operational health and active faults\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

status

enum

Always

ok | warning | fault

uptime\_ms

integer

Always

Service uptime\.

faults

Fault\[\]

Always

Active fault records\.

temperature\_c

number | null

Always

Primary device temperature\.

cpu\_percent

number | null

Always

CPU usage if available\.

memory

object | null

Always

Memory totals and usage\.

storage

object | null

Always

Storage totals and usage\.

database\_ok

boolean

Always

Configuration database health\.

## __2\.3  get\_device\_state__

__Purpose: __Obtain the complete synchronization snapshot used after connection\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include

string\[\]

No

Default inputs,outputs,sensors

Optional sections: inputs, outputs, sensors, energy, schedules, faults\.

include\_configuration

boolean

No

Default false

Include channel names and control configuration\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

revision

integer

Always

Monotonic state revision\.

captured\_at

datetime

Always

Snapshot timestamp\.

inputs

InputState\[\]

When requested

Current physical and virtual input state\.

outputs

OutputState\[\]

When requested

Current relay/dimmer output state\.

sensors

SensorReading\[\]

When requested

Current temperature and sensor readings\.

energy

EnergySummary | null

When requested

Energy data for capable PDUs\.

faults

Fault\[\]

When requested

Active faults\.

## __2\.4  get\_system\_data__

__Purpose: __Read diagnostic system and service data\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_processes

boolean

No

Default false

Include service process status when supported\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

os

object

Always

Operating\-system identity and kernel\.

services

ServiceStatus\[\]

Always

Core service status\.

resources

object

Always

CPU, memory and storage values\.

network

object

Always

Interface/link summary without credentials\.

last\_restart\_reason

string | null

Always

Most recent recorded restart reason\.

## __2\.5  get\_temperature__

__Purpose: __Read all or one temperature sensor\.  __Support: __All devices with temperature support  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sensor\_id

string

No

Known sensor identifier

Omit to return every temperature sensor\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

sensors

TemperatureReading\[\]

Always

Sensor ID, name, Celsius value, status and timestamp\.

__Command\-specific errors: __not\_found, sensor\_unavailable

## __2\.6  get\_time__

__Purpose: __Read device time and synchronization settings\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

datetime

datetime

Always

Current local ISO 8601 date/time with offset\.

timezone

string

Always

IANA time\-zone name when available\.

utc\_offset\_min

integer

Always

Current UTC offset in minutes\.

sync\_mode

enum

Always

manual | ntp

ntp\_server

string | null

Always

Configured NTP server\.

last\_sync

datetime | null

Always

Last successful synchronization time\.

## __2\.7  set\_time__

__Purpose: __Set device time manually\.  __Support: __All devices  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

datetime

datetime

Yes

ISO 8601 with offset

New date/time\.

timezone

string

No

Supported IANA zone

New time zone\.

write\_rtc

boolean

No

Default true

Also write the hardware real\-time clock\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

datetime

datetime

Always

Applied device time\.

timezone

string

Always

Applied time zone\.

rtc\_written

boolean

Always

Whether the RTC update succeeded\.

__Command\-specific errors: __invalid\_datetime, unsupported\_timezone, rtc\_error

## __2\.8  sync\_time__

__Purpose: __Synchronize from NTP or a supplied client time\.  __Support: __All devices  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

source

enum

Yes

ntp | client

Synchronization source\.

datetime

datetime

For client

ISO 8601 with offset

Calling\-client time\.

server

string

No

Host name or IP

One\-time NTP server override\.

timeout\_ms

integer

No

1000\-30000; default 5000

NTP timeout\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

synchronized

boolean

Always

Whether synchronization succeeded\.

datetime

datetime

Always

Time after synchronization\.

offset\_ms

integer | null

Always

Measured NTP offset when available\.

__Command\-specific errors: __time\_sync\_failed, invalid\_datetime

## __2\.9  test\_ntp\_server__

__Purpose: __Test an NTP server without changing saved settings\.  __Support: __All devices  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

server

string

Yes

Valid host name or IP

NTP server to test\.

timeout\_ms

integer

No

1000\-30000; default 5000

Test timeout\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

passed

boolean

Always

Whether a valid NTP response was received\.

latency\_ms

integer | null

Always

Round\-trip latency\.

offset\_ms

integer | null

Always

Reported clock offset\.

message

string

Always

Human\-readable outcome\.

## __2\.10  reboot\_device__

__Purpose: __Restart the device after acknowledging the request\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

delay\_ms

integer

No

500\-60000; default 1500

Delay before reboot so the response can be sent\.

reason

string

No

Maximum 128 characters

Audit\-log reason\.

force

boolean

No

Default false

Proceed despite non\-critical active operations\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

accepted

boolean

Always

True when reboot was scheduled\.

reboot\_in\_ms

integer

Always

Scheduled delay\.

message

string

Always

Status message\.

__Command\-specific errors: __busy, reboot\_not\_permitted

# __3\. Inputs and virtual inputs__

Read and configure physical inputs and operate virtual inputs\. All input channels are zero\-based\.

## __3\.1  get\_inputs__

__Purpose: __Read all physical and virtual inputs\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_configuration

boolean

No

Default true

Include names, enabled flags and modes\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

inputs

InputState\[\]

Always

Ordered physical input records\.

virtual\_inputs

InputState\[\]

Always

Ordered virtual\-input records\.

revision

integer

Always

State revision for synchronization\.

## __3\.2  get\_input__

__Purpose: __Read one physical or virtual input\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Input channel\.

kind

enum

No

physical | virtual; default physical

Input collection\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

input

InputState

Always

State and configuration for the requested input\.

__Command\-specific errors: __invalid\_channel

## __3\.3  set\_input\_configuration__

__Purpose: __Change input name and behavior\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based physical input

Input channel\.

name

string

No

0\-64 characters

Display name\.

enabled

boolean

No

\-

Whether the input participates in control\.

mode

enum

No

momentary | maintained | pulse

Electrical/control behavior when supported\.

active\_level

enum

No

high | low

Active electrical level when configurable\.

debounce\_ms

integer

No

0\-5000

Input debounce time\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

input

InputConfiguration

Always

Complete saved configuration\.

hardware\_apply\_required

boolean

Always

Whether apply\_hardware\_configuration must be called\.

__Command\-specific errors: __invalid\_channel, invalid\_configuration

## __3\.4  set\_virtual\_input\_state__

__Purpose: __Set and retain the state of a virtual input\.  __Support: __Devices with virtual inputs  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based virtual input

Virtual input channel\.

state

boolean

Yes

\-

Requested logical state\.

source

string

No

Maximum 64 characters

Audit/event source label\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Virtual input channel\.

state

boolean

Always

Applied state\.

changed

boolean

Always

Whether state changed\.

__Command\-specific errors: __invalid\_channel, input\_disabled

## __3\.5  trigger\_virtual\_input__

__Purpose: __Pulse a virtual input and automatically release it\.  __Support: __Devices with virtual inputs  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based virtual input

Virtual input channel\.

duration\_ms

integer

No

20\-60000; default 100

Active pulse duration\.

source

string

No

Maximum 64 characters

Audit/event source label\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Virtual input channel\.

triggered

boolean

Always

Whether the trigger was accepted\.

release\_in\_ms

integer

Always

Scheduled release delay\.

__Command\-specific errors: __invalid\_channel, input\_disabled, busy

# __4\. Outputs__

Live relay and dimmer control\. These commands replace ON, OFF, TOGGLE, RESTART and masked AT operations\.

## __4\.1  get\_outputs__

__Purpose: __Read all output states and optional configuration\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_configuration

boolean

No

Default true

Include delay, runtime and startup settings\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

outputs

OutputState\[\]

Always

Ordered output records\.

revision

integer

Always

State revision\.

## __4\.2  get\_output__

__Purpose: __Read one output\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

output

OutputState

Always

State and configuration for the output\.

__Command\-specific errors: __invalid\_channel

## __4\.3  set\_output\_state__

__Purpose: __Turn one output on or off\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

state

boolean

Yes

\-

Requested logical state\.

transition\_ms

integer

No

0 or device\-supported range

Dimmer fade duration; ignored only when capability explicitly permits\.

source

string

No

Maximum 64 characters

Audit/event source label\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Output channel\.

requested\_state

boolean

Always

Requested state\.

actual\_state

boolean

Always

State when response was produced\.

pending

boolean

Always

True while delays or transitions are active\.

revision

integer

Always

New state revision\.

__Command\-specific errors: __invalid\_channel, output\_disabled, interlock, busy

## __4\.4  toggle\_output__

__Purpose: __Invert one output state\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

transition\_ms

integer

No

0 or device\-supported range

Dimmer fade duration\.

source

string

No

Maximum 64 characters

Audit/event source label\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Output channel\.

actual\_state

boolean

Always

Resulting state\.

pending

boolean

Always

Whether completion is delayed\.

revision

integer

Always

New state revision\.

__Command\-specific errors: __invalid\_channel, output\_disabled, interlock, busy

## __4\.5  restart\_output__

__Purpose: __Cycle one output off and back on\.  __Support: __Relay Module and PDU outputs; capability dependent  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

off\_time\_ms

integer

No

100\-3600000; device default

Time held off\.

restore\_mode

enum

No

on | previous; default on

Final state after the cycle\.

source

string

No

Maximum 64 characters

Audit/event source label\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Output channel\.

accepted

boolean

Always

Whether the cycle was scheduled\.

off\_time\_ms

integer

Always

Applied off duration\.

operation\_id

string

Always

Identifier reported by completion events\.

__Command\-specific errors: __invalid\_channel, output\_disabled, busy

## __4\.6  set\_multiple\_outputs__

__Purpose: __Set several outputs in one deterministic operation\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

outputs

OutputTarget\[\]

Yes

1 to output count; unique channels

Each item contains channel, state and optional level/transition\.

execution

enum

No

parallel | sequential; default parallel

Execution ordering\.

interval\_ms

integer

No

0\-60000; sequential only

Delay between sequential targets\.

stop\_on\_error

boolean

No

Default false

Stop after the first failed target\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

results

OutputOperationResult\[\]

Always

Per\-output ordered results\.

accepted

integer

Always

Accepted target count\.

failed

integer

Always

Rejected target count\.

operation\_id

string | null

Always

Group operation identifier when asynchronous\.

__Command\-specific errors: __duplicate\_channel, invalid\_channel, batch\_too\_large

## __4\.7  toggle\_multiple\_outputs__

__Purpose: __Toggle several outputs together\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channels

integer\[\]

Yes

Unique zero\-based channels

Outputs to toggle\.

execution

enum

No

parallel | sequential; default parallel

Execution ordering\.

interval\_ms

integer

No

0\-60000

Delay between sequential targets\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

results

OutputOperationResult\[\]

Always

Per\-output resulting states\.

operation\_id

string | null

Always

Group operation identifier\.

__Command\-specific errors: __duplicate\_channel, invalid\_channel

## __4\.8  restart\_multiple\_outputs__

__Purpose: __Restart several outputs together\.  __Support: __Relay Module and PDU outputs; capability dependent  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channels

integer\[\]

Yes

Unique zero\-based channels

Outputs to restart\.

off\_time\_ms

integer

No

100\-3600000; device default

Off duration\.

execution

enum

No

parallel | sequential; default parallel

Execution ordering\.

interval\_ms

integer

No

0\-60000

Sequential start interval\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

results

OutputOperationResult\[\]

Always

Per\-output acceptance results\.

operation\_id

string

Always

Group operation identifier\.

__Command\-specific errors: __duplicate\_channel, invalid\_channel, busy

## __4\.9  set\_output\_configuration__

__Purpose: __Change output name, delays, runtimes and startup behavior\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

name

string

No

0\-64 characters

Display name\.

enabled

boolean

No

\-

Whether control is permitted\.

on\_delay\_ms

integer

No

0\-6553500

Delay before turning on\.

off\_delay\_ms

integer

No

0\-6553500

Delay before turning off\.

on\_runtime\_ms

integer

No

0\-6553500; 0 disabled

Automatic on\-duration limit\.

off\_runtime\_ms

integer

No

0\-6553500; 0 disabled

Automatic off\-duration limit\.

start\_delay\_ms

integer

No

0\-6553500

Startup sequencing delay\.

initial\_state

enum

No

off | on | restore

State after device startup\.

restart\_off\_time\_ms

integer

No

100\-3600000

Default restart cycle off\-time\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

output

OutputConfiguration

Always

Complete saved configuration in milliseconds\.

hardware\_apply\_required

boolean

Always

Whether hardware apply is required\.

__Command\-specific errors: __invalid\_channel, invalid\_configuration

# __5\. Input\-output mappings__

Manage mappings using named behaviors while retaining the current numeric codes for migration\.

## __5\.1  get\_mappings__

__Purpose: __Read the complete input\-output mapping matrix\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_disabled

boolean

No

Default true

Include mappings for disabled inputs and outputs\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

inputs

integer

Always

Number of input rows\.

outputs

integer

Always

Number of output columns\.

mappings

Mapping\[\]

Always

Sparse mapping records\.

behavior\_codes

object

Always

Numeric legacy\-code to behavior\-name map\.

## __5\.2  get\_input\_mapping__

__Purpose: __Read mappings for one input\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

input

integer

Yes

Zero\-based

Input channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

input

integer

Always

Input channel\.

mappings

Mapping\[\]

Always

One record for each mapped output\.

__Command\-specific errors: __invalid\_channel

## __5\.3  set\_mapping__

__Purpose: __Create or replace one input\-to\-output mapping\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

input

integer

Yes

Zero\-based

Input channel\.

output

integer

Yes

Zero\-based

Output channel\.

behavior

enum

Yes

none | on | off | toggle | continuous\_on | continuous\_off

Control behavior\.

parameters

object

No

Behavior\-specific

Reserved timing parameters for future behavior types\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

mapping

Mapping

Always

Saved input, output, behavior and legacy code\.

hardware\_apply\_required

boolean

Always

Whether hardware apply is required\.

__Command\-specific errors: __invalid\_channel, invalid\_behavior

## __5\.4  clear\_mapping__

__Purpose: __Remove one mapping by setting its behavior to none\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

input

integer

Yes

Zero\-based

Input channel\.

output

integer

Yes

Zero\-based

Output channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

input

integer

Always

Input channel\.

output

integer

Always

Output channel\.

removed

boolean

Always

True when a non\-empty mapping was cleared\.

__Command\-specific errors: __invalid\_channel

## __5\.5  apply\_hardware\_configuration__

__Purpose: __Publish saved mappings and timing configuration to hardware\-control services\.  __Support: __Relay Module, Dimmer, PDU  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

wait

boolean

No

Default true

Wait for hardware acknowledgement\.

timeout\_ms

integer

No

1000\-60000; default 10000

Acknowledgement timeout\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

started

boolean

Always

Whether the apply operation started\.

completed

boolean

Always

Whether all components acknowledged before response\.

components

ComponentApplyResult\[\]

Always

Per\-component results\.

operation\_id

string

Always

Operation identifier\.

__Command\-specific errors: __hardware\_timeout, component\_failed, busy

# __6\. Dimmer control__

Device\-specific brightness commands\. Common output commands remain valid for on/off control\.

## __6\.1  get\_dimmer\_state__

__Purpose: __Read relay state, requested level and actual level for one dimmer\.  __Support: __Dimmer  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Dimmer output channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Output channel\.

state

boolean

Always

Logical on/off state\.

requested\_level

number

Always

Saved target percentage, 0\.0\-100\.0\.

actual\_level

number

Always

Current hardware percentage, 0\.0\-100\.0\.

transitioning

boolean

Always

Whether a fade is active\.

revision

integer

Always

State revision\.

__Command\-specific errors: __invalid\_channel

## __6\.2  get\_dimmer\_levels__

__Purpose: __Read all dimmer requested and actual levels\.  __Support: __Dimmer  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

outputs

DimmerState\[\]

Always

Ordered dimmer states\.

revision

integer

Always

State revision\.

## __6\.3  set\_dimmer\_level__

__Purpose: __Set one brightness level\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Dimmer output channel\.

level

number

Yes

0\.0\-100\.0 percent

Target brightness\.

transition\_ms

integer

No

0\-3600000; default 0

Fade duration\.

turn\_on

boolean

No

Default true when level > 0

Whether a nonzero level should enable the output\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

channel

integer

Always

Output channel\.

requested\_level

number

Always

Accepted target level\.

actual\_level

number

Always

Level at response time\.

transitioning

boolean

Always

Whether transition remains active\.

operation\_id

string | null

Always

Transition operation identifier\.

__Command\-specific errors: __invalid\_channel, invalid\_level, output\_disabled

## __6\.4  set\_multiple\_dimmer\_levels__

__Purpose: __Set several brightness levels together\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

outputs

DimmerTarget\[\]

Yes

Unique zero\-based channels

Channel, level and optional transition for each output\.

execution

enum

No

parallel | sequential; default parallel

Execution ordering\.

interval\_ms

integer

No

0\-60000

Sequential target interval\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

results

DimmerOperationResult\[\]

Always

Per\-channel acceptance and target levels\.

operation\_id

string | null

Always

Group transition identifier\.

__Command\-specific errors: __duplicate\_channel, invalid\_channel, invalid\_level

## __6\.5  dimmer\_on__

__Purpose: __Turn on one dimmer using its saved requested level\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Dimmer channel\.

transition\_ms

integer

No

0\-3600000

Fade\-in duration\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

dimmer

DimmerState

Always

Resulting dimmer state\.

__Command\-specific errors: __invalid\_channel, output\_disabled

## __6\.6  dimmer\_off__

__Purpose: __Turn off one dimmer without discarding its saved level\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Dimmer channel\.

transition\_ms

integer

No

0\-3600000

Fade\-out duration\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

dimmer

DimmerState

Always

Resulting dimmer state\.

__Command\-specific errors: __invalid\_channel, output\_disabled

## __6\.7  toggle\_dimmer__

__Purpose: __Toggle one dimmer while retaining its target level\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Dimmer channel\.

transition\_ms

integer

No

0\-3600000

Fade duration\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

dimmer

DimmerState

Always

Resulting dimmer state\.

__Command\-specific errors: __invalid\_channel, output\_disabled

## __6\.8  get\_dimmer\_frequency__

__Purpose: __Read configured dimmer PWM/drive frequency\.  __Support: __Dimmer  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

frequency\_hz

integer

Always

Configured frequency\.

allowed\_hz

integer\[\] | range

Always

Supported values or range\.

apply\_required

boolean

Always

Whether a pending value awaits hardware apply\.

## __6\.9  set\_dimmer\_frequency__

__Purpose: __Change dimmer PWM/drive frequency\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

frequency\_hz

integer

Yes

One of allowed\_hz

Requested frequency\.

apply\_now

boolean

No

Default true

Apply immediately to hardware\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

frequency\_hz

integer

Always

Applied or saved frequency\.

applied

boolean

Always

Whether hardware accepted the value\.

restart\_required

boolean

Always

Whether device restart is required\.

__Command\-specific errors: __invalid\_frequency, hardware\_error

# __7\. PDU energy and override__

Energy and protection commands are capability\-gated because meter hardware differs by PDU model\.

## __7\.1  get\_energy\_summary__

__Purpose: __Read aggregate electrical measurements and counters\.  __Support: __Energy\-capable PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

include\_channels

boolean

No

Default false

Include per\-channel measurements\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

captured\_at

datetime

Always

Measurement time\.

voltage\_v

number | null

Always

Supply voltage\.

current\_a

number | null

Always

Total current\.

active\_power\_w

number | null

Always

Active power\.

apparent\_power\_va

number | null

Always

Apparent power\.

power\_factor

number | null

Always

Power factor, 0\.0\-1\.0\.

frequency\_hz

number | null

Always

Mains frequency\.

energy\_wh

number | null

Always

Accumulated energy\.

channels

ChannelEnergy\[\]

When requested

Per\-channel values supported by the meter\.

## __7\.2  get\_channel\_energy__

__Purpose: __Read measurements for one metered output\.  __Support: __PDU with per\-channel metering  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based metered output

Output channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

energy

ChannelEnergy

Always

Channel voltage/current/power/energy and timestamp\.

__Command\-specific errors: __invalid\_channel, meter\_unavailable

## __7\.3  get\_override\_state__

__Purpose: __Read manual or safety override status\.  __Support: __PDU  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

No

Zero\-based; omit for all

Optional output channel\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

overrides

OverrideState\[\]

Always

Active/inactive override state, reason and source\.

## __7\.4  set\_override\_state__

__Purpose: __Enable or clear an override where hardware supports remote override control\.  __Support: __Capability\-dependent PDU  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

channel

integer

Yes

Zero\-based

Output channel\.

enabled

boolean

Yes

\-

Requested override state\.

state

boolean

When enabling

\-

Forced output state\.

reason

string

Yes

1\-128 characters

Audit reason\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

override

OverrideState

Always

Applied override state\.

output

OutputState

Always

Resulting output state\.

__Command\-specific errors: __unsupported\_command, invalid\_channel, safety\_interlock

## __7\.5  reset\_energy\_counters__

__Purpose: __Reset supported accumulated energy counters\.  __Support: __Energy\-capable PDU  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

scope

enum

Yes

all | channel

Counter scope\.

channel

integer

For channel

Zero\-based

Metered output channel\.

confirmation

string

Yes

Literal RESET

Explicit destructive\-operation confirmation\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

reset

boolean

Always

Whether counters were reset\.

reset\_at

datetime

Always

Reset timestamp\.

channels

integer\[\]

Always

Affected channels\.

__Command\-specific errors: __confirmation\_required, meter\_unavailable

## __7\.6  get\_power\_limits__

__Purpose: __Read configured warning and trip limits\.  __Support: __PDU with protection limits  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

limits

PowerLimits

Always

Voltage, current, power and temperature limits with hysteresis\.

## __7\.7  set\_power\_limits__

__Purpose: __Change supported power warning/trip limits\.  __Support: __PDU with protection limits  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

limits

PowerLimitsPatch

Yes

Only capability\-advertised fields

Fields to update\.

apply\_now

boolean

No

Default true

Apply to protection service immediately\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

limits

PowerLimits

Always

Complete applied limits\.

applied

boolean

Always

Whether protection service acknowledged\.

__Command\-specific errors: __invalid\_limit, hardware\_error

# __8\. Schedules and automation__

CRUD operations use stable resource objects rather than Windows\-page row mutations\.

## __8\.1  get\_schedules__

__Purpose: __List one\-time and recurring schedules\.  __Support: __All devices with scheduling  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

type

enum

No

one\_time | recurring

Optional schedule type filter\.

enabled

boolean

No

\-

Optional enabled\-state filter\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

schedules

Schedule\[\]

Always

Schedule records in stable ID order\.

timezone

string

Always

Time zone used for execution\.

## __8\.2  get\_schedule__

__Purpose: __Read one schedule\.  __Support: __All devices with scheduling  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule\_id

string

Yes

Existing ID

Schedule identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

schedule

Schedule

Always

Complete schedule\.

__Command\-specific errors: __not\_found

## __8\.3  create\_schedule__

__Purpose: __Create a one\-time or recurring schedule\.  __Support: __All devices with scheduling  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule

ScheduleCreate

Yes

See Schedule schema

Name, type, timing, actions and enabled state\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

schedule

Schedule

Always

Created schedule with generated ID\.

__Command\-specific errors: __invalid\_schedule, schedule\_limit, conflict

## __8\.4  update\_schedule__

__Purpose: __Patch an existing schedule\.  __Support: __All devices with scheduling  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule\_id

string

Yes

Existing ID

Schedule identifier\.

changes

SchedulePatch

Yes

At least one field

Fields to change\.

expected\_revision

integer

No

Current revision

Optimistic concurrency check\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

schedule

Schedule

Always

Updated schedule\.

__Command\-specific errors: __not\_found, invalid\_schedule, revision\_conflict

## __8\.5  delete\_schedule__

__Purpose: __Delete a schedule\.  __Support: __All devices with scheduling  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule\_id

string

Yes

Existing ID

Schedule identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

deleted

boolean

Always

Whether the schedule existed and was deleted\.

schedule\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found

## __8\.6  enable\_schedule__

__Purpose: __Enable or disable a schedule without changing its definition\.  __Support: __All devices with scheduling  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule\_id

string

Yes

Existing ID

Schedule identifier\.

enabled

boolean

Yes

\-

Requested state\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

schedule

Schedule

Always

Updated schedule\.

__Command\-specific errors: __not\_found

## __8\.7  execute\_schedule__

__Purpose: __Execute a schedule's actions immediately for testing\.  __Support: __All devices with scheduling  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

schedule\_id

string

Yes

Existing ID

Schedule identifier\.

dry\_run

boolean

No

Default false

Validate and return planned actions without applying them\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

accepted

boolean

Always

Whether execution was accepted\.

actions

ActionResult\[\]

Always

Validation or execution result for each action\.

operation\_id

string | null

Always

Asynchronous operation identifier\.

__Command\-specific errors: __not\_found, action\_failed, busy

## __8\.8  get\_automations__

__Purpose: __List configured automations\.  __Support: __Capability\-dependent  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

type

enum

No

ping\_watchdog | delayed\_action | temperature\_control | tcp\_trigger | api\_trigger

Optional type filter\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

automations

Automation\[\]

Always

Automation records\.

## __8\.9  create\_automation__

__Purpose: __Create an automation\.  __Support: __Capability\-dependent  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

automation

AutomationCreate

Yes

See Automation schema

Type, trigger, actions, name and enabled state\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

automation

Automation

Always

Created automation with generated ID\.

__Command\-specific errors: __invalid\_automation, automation\_limit

## __8\.10  update\_automation__

__Purpose: __Patch an automation\.  __Support: __Capability\-dependent  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

automation\_id

string

Yes

Existing ID

Automation identifier\.

changes

AutomationPatch

Yes

At least one field

Fields to change\.

expected\_revision

integer

No

Current revision

Optimistic concurrency check\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

automation

Automation

Always

Updated automation\.

__Command\-specific errors: __not\_found, invalid\_automation, revision\_conflict

## __8\.11  delete\_automation__

__Purpose: __Delete an automation\.  __Support: __Capability\-dependent  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

automation\_id

string

Yes

Existing ID

Automation identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

deleted

boolean

Always

Whether the resource was deleted\.

automation\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found

## __8\.12  enable\_automation__

__Purpose: __Enable or disable an automation\.  __Support: __Capability\-dependent  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

automation\_id

string

Yes

Existing ID

Automation identifier\.

enabled

boolean

Yes

\-

Requested state\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

automation

Automation

Always

Updated automation\.

__Command\-specific errors: __not\_found

# __9\. Dimmer scenarios and sequences__

Scenario and sequence resources replace page\-specific scenario/sequence mutations\.

## __9\.1  get\_scenarios__

__Purpose: __List dimmer scenarios\.  __Support: __Dimmer  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

scenarios

Scenario\[\]

Always

Scenario definitions\.

## __9\.2  create\_scenario__

__Purpose: __Create a named set of dimmer/output targets\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

scenario

ScenarioCreate

Yes

At least one target

Name, targets and default transition\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

scenario

Scenario

Always

Created scenario\.

__Command\-specific errors: __invalid\_scenario, scenario\_limit

## __9\.3  update\_scenario__

__Purpose: __Patch a scenario\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

scenario\_id

string

Yes

Existing ID

Scenario identifier\.

changes

ScenarioPatch

Yes

At least one field

Fields to change\.

expected\_revision

integer

No

Current revision

Optimistic concurrency check\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

scenario

Scenario

Always

Updated scenario\.

__Command\-specific errors: __not\_found, invalid\_scenario, revision\_conflict

## __9\.4  delete\_scenario__

__Purpose: __Delete a scenario\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

scenario\_id

string

Yes

Existing ID

Scenario identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

deleted

boolean

Always

Deletion result\.

scenario\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found, resource\_in\_use

## __9\.5  execute\_scenario__

__Purpose: __Apply a scenario\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

scenario\_id

string

Yes

Existing ID

Scenario identifier\.

transition\_ms

integer

No

0\-3600000

Override default transition\.

dry\_run

boolean

No

Default false

Validate without changing outputs\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

accepted

boolean

Always

Whether execution was accepted\.

results

DimmerOperationResult\[\]

Always

Per\-target results\.

operation\_id

string | null

Always

Transition identifier\.

__Command\-specific errors: __not\_found, action\_failed

## __9\.6  get\_sequences__

__Purpose: __List scenario sequences\.  __Support: __Dimmer  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

\(none\)

\-

\-

\-

Command has no action\-specific parameters\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

sequences

Sequence\[\]

Always

Sequence definitions\.

## __9\.7  create\_sequence__

__Purpose: __Create an ordered scenario/action sequence\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sequence

SequenceCreate

Yes

At least one step

Name, steps and loop settings\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

sequence

Sequence

Always

Created sequence\.

__Command\-specific errors: __invalid\_sequence, sequence\_limit

## __9\.8  update\_sequence__

__Purpose: __Patch a sequence\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sequence\_id

string

Yes

Existing ID

Sequence identifier\.

changes

SequencePatch

Yes

At least one field

Fields to change\.

expected\_revision

integer

No

Current revision

Optimistic concurrency check\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

sequence

Sequence

Always

Updated sequence\.

__Command\-specific errors: __not\_found, invalid\_sequence, revision\_conflict

## __9\.9  delete\_sequence__

__Purpose: __Delete a sequence\.  __Support: __Dimmer  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sequence\_id

string

Yes

Existing ID

Sequence identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

deleted

boolean

Always

Deletion result\.

sequence\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found, resource\_in\_use

## __9\.10  start\_sequence__

__Purpose: __Start a sequence\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sequence\_id

string

Yes

Existing ID

Sequence identifier\.

start\_step

integer

No

Zero\-based; default 0

First step to execute\.

loop\_count

integer

No

0\-65535; 0 uses saved setting

Runtime loop override\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

accepted

boolean

Always

Whether start was accepted\.

operation\_id

string

Always

Running sequence identifier\.

sequence\_id

string

Always

Definition identifier\.

step

integer

Always

Initial zero\-based step\.

__Command\-specific errors: __not\_found, busy, invalid\_step

## __9\.11  stop\_sequence__

__Purpose: __Stop one running sequence operation\.  __Support: __Dimmer  __Permission: __Control

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

operation\_id

string

Yes

Running operation

Operation returned by start\_sequence\.

output\_behavior

enum

No

hold | off | restore; default hold

What outputs do after stopping\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

stopped

boolean

Always

Whether a running operation was stopped\.

operation\_id

string

Always

Requested operation identifier\.

outputs

DimmerState\[\]

Always

Resulting output states\.

__Command\-specific errors: __not\_found

# __10\. Configuration, network and security__

Configuration is organized into stable sections but is not coupled to a UI page layout\.

## __10\.1  get\_configuration__

__Purpose: __Read one or more configuration sections\.  __Support: __All devices  __Permission: __Read

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

sections

string\[\]

No

Default all permitted

general, account, lan, wifi, time, temperature, tcp\_access, api\_access, mqtt, tls, maintenance\.

include\_secrets

boolean

No

Default false; Admin only

Return only retrievable secrets; passwords normally remain write\-only\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

configuration

object

Always

Map of section name to typed section object\.

revision

integer

Always

Configuration revision\.

restart\_required

boolean

Always

Whether pending configuration needs a restart\.

__Command\-specific errors: __unknown\_section, permission\_denied

## __10\.2  set\_configuration__

__Purpose: __Patch one configuration section\.  __Support: __All devices  __Permission: __Configure or Admin by section

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

section

string

Yes

Supported configuration section

Section to change\.

values

object

Yes

Section\-specific schema

Fields to patch; omitted fields are unchanged\.

expected\_revision

integer

No

Current revision

Optimistic concurrency check\.

apply\_now

boolean

No

Default true

Apply service changes immediately when safe\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

section

string

Always

Updated section\.

values

object

Always

Complete sanitized section after update\.

revision

integer

Always

New configuration revision\.

applied

boolean

Always

Whether change is active\.

restart\_required

boolean

Always

Whether restart is required\.

__Command\-specific errors: __unknown\_section, invalid\_configuration, revision\_conflict

## __10\.3  scan\_wifi__

__Purpose: __Scan for nearby Wi\-Fi networks\.  __Support: __Devices with Wi\-Fi  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

timeout\_ms

integer

No

2000\-30000; default 10000

Scan timeout\.

include\_hidden

boolean

No

Default false

Include hidden\-network placeholders\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

networks

WifiNetwork\[\]

Always

SSID, signal, security and channel; never credentials\.

duration\_ms

integer

Always

Scan duration\.

__Command\-specific errors: __wifi\_unavailable, busy

## __10\.4  test\_network__

__Purpose: __Test name resolution and TCP reachability without saving settings\.  __Support: __All devices  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

host

string

Yes

Host name or IP

Target host\.

port

integer

No

1\-65535

Optional TCP port\.

timeout\_ms

integer

No

500\-30000; default 5000

Test timeout\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

dns\_ok

boolean | null

Always

DNS result when a host name is supplied\.

resolved\_addresses

string\[\]

Always

Resolved addresses\.

reachable

boolean

Always

ICMP or TCP reachability result\.

latency\_ms

integer | null

Always

Measured latency\.

message

string

Always

Outcome summary\.

## __10\.5  test\_mqtt__

__Purpose: __Test MQTT connection and optional publish without saving settings\.  __Support: __Devices with MQTT  __Permission: __Configure

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

host

string

Yes

Host name or IP

Broker\.

port

integer

Yes

1\-65535

Broker port\.

tls

boolean

No

Default false

Use TLS\.

username

string

No

\-

Broker username\.

password

string

No

Write\-only

Broker password\.

topic

string

No

Valid MQTT topic

Optional test publish topic\.

timeout\_ms

integer

No

1000\-30000

Connection timeout\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

connected

boolean

Always

Connection result\.

published

boolean | null

Always

Publish result when requested\.

latency\_ms

integer | null

Always

Connection latency\.

message

string

Always

Sanitized outcome\.

__Command\-specific errors: __tls\_error, connection\_failed, authentication\_failed

## __10\.6  get\_access\_rules__

__Purpose: __List TCP or API IP/MAC allow rules\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

service

enum

Yes

legacy\_tcp | control\_api

Rule collection\.

kind

enum

No

ip | mac

Optional rule type filter\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

service

enum

Always

Requested service\.

rules

AccessRule\[\]

Always

Ordered allow rules\.

filter\_enabled

boolean

Always

Whether rules are enforced\.

## __10\.7  add\_access\_rule__

__Purpose: __Add an IP/CIDR or MAC allow rule\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

service

enum

Yes

legacy\_tcp | control\_api

Target service\.

kind

enum

Yes

ip | mac

Rule type\.

value

string

Yes

IP/CIDR or MAC syntax

Allowed value\.

name

string

No

0\-64 characters

Friendly label\.

enabled

boolean

No

Default true

Rule state\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

rule

AccessRule

Always

Created rule with ID\.

__Command\-specific errors: __invalid\_rule, duplicate\_rule, rule\_limit

## __10\.8  update\_access\_rule__

__Purpose: __Patch an access rule\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

rule\_id

string

Yes

Existing ID

Rule identifier\.

changes

AccessRulePatch

Yes

At least one field

value, name or enabled\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

rule

AccessRule

Always

Updated rule\.

__Command\-specific errors: __not\_found, invalid\_rule, duplicate\_rule

## __10\.9  delete\_access\_rule__

__Purpose: __Delete an access rule\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

rule\_id

string

Yes

Existing ID

Rule identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

deleted

boolean

Always

Deletion result\.

rule\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found

# __11\. Backup, restore and firmware transfer__

Chunked transfer commands support TCP and HTTP consistently\. HTTP may additionally use direct upload endpoints later\.

## __11\.1  upload\_begin__

__Purpose: __Create a settings, certificate or firmware upload session\.  __Support: __All devices; kind capability\-dependent  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

kind

enum

Yes

settings\_restore | firmware | tls\_certificate | tls\_key

Upload purpose\.

file\_name

string

Yes

Base name only, 1\-128 characters

Display/audit file name\.

size\_bytes

integer

Yes

1 to advertised limit

Total decoded size\.

sha256

string

Yes

64 lowercase hex characters

Expected file hash\.

metadata

object

No

Kind\-specific

Version or certificate metadata\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

transfer\_id

string

Always

Upload session identifier\.

chunk\_size

integer

Always

Required/maximum decoded chunk bytes\.

expires\_in\_s

integer

Always

Idle session lifetime\.

next\_offset

integer

Always

Initial byte offset, normally 0\.

__Command\-specific errors: __file\_too\_large, invalid\_hash, transfer\_limit, busy

## __11\.2  upload\_chunk__

__Purpose: __Append one base64\-encoded upload chunk\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

transfer\_id

string

Yes

Active upload

Upload identifier\.

offset

integer

Yes

Exactly next\_offset

Decoded byte offset\.

data

base64 string

Yes

At most chunk\_size decoded bytes

Chunk data\.

chunk\_sha256

string

No

64 hex characters

Optional per\-chunk integrity check\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

received\_bytes

integer

Always

Total decoded bytes received\.

next\_offset

integer

Always

Required next byte offset\.

complete

boolean

Always

Whether declared size has been received\.

__Command\-specific errors: __not\_found, offset\_mismatch, invalid\_base64, hash\_mismatch

## __11\.3  upload\_finish__

__Purpose: __Validate the uploaded file and close data transfer\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

transfer\_id

string

Yes

Active upload

Upload identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

validated

boolean

Always

Size/hash and kind validation result\.

sha256

string

Always

Calculated full\-file hash\.

metadata

object

Always

Validated firmware/settings/certificate metadata\.

commit\_required

boolean

Always

Whether upload\_commit must follow\.

__Command\-specific errors: __not\_found, incomplete\_transfer, hash\_mismatch, invalid\_file

## __11\.4  upload\_commit__

__Purpose: __Install or restore a validated upload\.  __Support: __All devices; kind capability\-dependent  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

transfer\_id

string

Yes

Validated upload

Upload identifier\.

reboot

boolean

No

Default true when required

Allow automatic reboot\.

confirmation

string

Yes

Kind\-specific literal supplied by upload\_finish

Explicit destructive\-operation confirmation\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

accepted

boolean

Always

Whether commit started\.

operation\_id

string

Always

Install/restore operation identifier\.

reboot\_required

boolean

Always

Whether reboot is required\.

reboot\_in\_ms

integer | null

Always

Automatic reboot delay\.

__Command\-specific errors: __not\_found, confirmation\_required, validation\_expired, install\_failed

## __11\.5  download\_begin__

__Purpose: __Create a settings\-backup or diagnostic download\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

kind

enum

Yes

settings\_backup | diagnostics

Download content\.

options

object

No

Kind\-specific

Optional inclusion/redaction settings\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

transfer\_id

string

Always

Download session identifier\.

file\_name

string

Always

Suggested safe file name\.

size\_bytes

integer

Always

Total decoded size\.

sha256

string

Always

File hash\.

chunk\_size

integer

Always

Maximum read chunk bytes\.

expires\_in\_s

integer

Always

Idle session lifetime\.

__Command\-specific errors: __busy, generation\_failed

## __11\.6  download\_chunk__

__Purpose: __Read one base64\-encoded download chunk\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

transfer\_id

string

Yes

Active download

Download identifier\.

offset

integer

Yes

0 to size\_bytes

Decoded byte offset\.

length

integer

No

1 to chunk\_size

Requested decoded length\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

offset

integer

Always

Returned decoded byte offset\.

data

base64 string

Always

Chunk data\.

length

integer

Always

Decoded chunk bytes\.

next\_offset

integer

Always

Next sequential offset\.

complete

boolean

Always

Whether end\-of\-file was reached\.

__Command\-specific errors: __not\_found, invalid\_offset

## __11\.7  download\_finish__

__Purpose: __Close and delete a generated download session\.  __Support: __All devices  __Permission: __Admin

__Parameters__

__Field__

__Type__

__Required__

__Constraints/default__

__Description__

transfer\_id

string

Yes

Active download

Download identifier\.

__Expected result__

__Field__

__Type__

__Presence__

__Description__

closed

boolean

Always

Whether session was closed\.

transfer\_id

string

Always

Requested identifier\.

__Command\-specific errors: __not\_found

# Shared data schemas

These compact definitions identify the fields expected in repeated result objects\. A later JSON Schema/OpenAPI file can make them machine\-validatable without changing the command contract\.

__Type__

__Required/core fields__

DeviceInfo

device\_id, name, device\_type, model, serial\_number, firmware\_version, hardware\_version

Topology

input\_count, virtual\_input\_count, output\_count, sensor\_count

InputState

kind, channel, name, enabled, state, mode, active\_level, debounce\_ms, changed\_at

OutputState

channel, name, enabled, state, pending, requested\_level?, actual\_level?, configuration?, changed\_at

OutputConfiguration

channel, name, enabled, delays/runtimes in ms, initial\_state, restart\_off\_time\_ms

Mapping

input, output, behavior, legacy\_code; codes: 0 none, 1 on, 2 off, 3 toggle, 4 continuous\_on, 5 continuous\_off

Schedule

id, revision, name, enabled, type, timing, actions, last\_run, next\_run

Schedule timing

one\_time: datetime; recurring: time, weekdays\[0=Monday\.\.6=Sunday\], optional start/end dates

Action

action plus params; only capability\-advertised control actions are permitted

Automation

id, revision, name, enabled, type, trigger configuration and actions

Scenario

id, revision, name, default\_transition\_ms and targets\[channel,state,level\]

Sequence

id, revision, name, steps\[scenario\_id or actions, hold\_ms\], loop\_count

TemperatureReading

sensor\_id, name, value\_c, status, timestamp

ChannelEnergy

channel, voltage\_v?, current\_a?, active\_power\_w?, apparent\_power\_va?, power\_factor?, energy\_wh?, timestamp

AccessRule

id, service, kind, value, name, enabled, revision

Fault

fault\_id, severity, code, message, active, first\_seen, last\_seen

## Configuration section schemas

__Section__

__Fields__

general

name, location?, description?, language?, physical\_input\_count \(read\-only\), output\_count \(read\-only\)

account

username, password \(write\-only\), session\_timeout\_s, password\_change\_required

lan

mode\[dhcp|static\], address, subnet\_mask, gateway, dns\_servers\[\], control\_port = legacy\_port \+ 3 \(default 5008\), legacy\_port default 5005

wifi

enabled, mode\[dhcp|static\], ssid, password \(write\-only\), address, subnet\_mask, gateway, dns\_servers\[\]

time

timezone, sync\_mode\[manual|ntp\], ntp\_server, sync\_interval\_s

temperature

enabled, low\_warning\_c, high\_warning\_c, control/hysteresis fields where supported

tcp\_access

tcp\_enabled, legacy\_port, allow\_filter\_enabled; tcp\_enabled controls legacy\_port, legacy\_port \+ 1 and Control API TCP legacy\_port \+ 3; rules are managed separately

api\_access

api\_enabled, IP/MAC allow rules, HTTP enabled, HTTPS enabled, authentication target, rate\-limit target; api\_enabled controls HTTP/HTTPS command endpoints only

mqtt

enabled, host, port, tls, username, password\(write\-only\), client\_id, base\_topic, qos

tls

enabled, certificate metadata, key\_present, minimum\_tls\_version; key material is write\-only via upload

maintenance

log\_level, automatic\_backup settings, retention, update channel where supported

# Device events

Events are unsolicited messages on subscribed TCP/WebSocket sessions or SSE streams\. They use protocol, event, subscription\_id and data fields; they do not contain ok or result\.

\{"protocol":3,"event":"output\_state\_changed","subscription\_id":"sub\-7","data":\{"channel":0,"previous\_state":false,"state":true,"pending":false,"source":"windows\-app","revision":312,"timestamp":"2026\-08\-31T10:20:30\+00:00"\}\}

__Event__

__Expected data fields__

output\_state\_changed

channel, previous\_state, state, pending, source, revision, timestamp

output\_level\_changed

channel, requested\_level, actual\_level, transitioning, source, revision, timestamp

input\_state\_changed

kind, channel, previous\_state, state, source, revision, timestamp

mapping\_changed

input, output, behavior, legacy\_code, revision, timestamp

temperature\_changed

sensor\_id, value\_c, status, timestamp

energy\_changed

summary and/or channel readings, timestamp

schedule\_executed

schedule\_id, results, success, timestamp

automation\_executed

automation\_id, trigger, results, success, timestamp

sequence\_state\_changed

sequence\_id, operation\_id, state, step, loop, timestamp

operation\_progress

operation\_id, kind, stage, progress\_percent, message, timestamp

device\_fault

fault\_id, severity, code, message, active, timestamp

configuration\_changed

section, revision, source, restart\_required, timestamp

device\_rebooting

reason, reboot\_in\_ms, timestamp

__Synchronization: __Clients must treat events as incremental updates\. If revisions are skipped, reconnecting clients should call get\_device\_state to rebuild a complete state snapshot\.

# Migration and acceptance criteria

- Migrated Relay Module, AC/DC Dimmer and PDU firmware exposes its implemented protocol 2 command subset on configured base port \+ 3 \(5008 by default\)\.
- Each migrated firmware family exposes the same implemented commands through POST /api/v1/command on HTTP or HTTPS\.
- Discovery and heartbeat identity report the calculated Control API port so clients do not hardcode 5008\.
- The standard Windows paths for all five migrated families use the JSON Control API and do not send AT commands or use the base port\.
- Each configured base port remains AT\-only for existing third\-party or service integrations\.
- Each migrated screen is tested against Relay Module, AC/DC Dimmer, PDU Energy Meter, PDU 10 kW and PDU V1 capabilities as applicable\.
- Every active firmware family creates tcp\_enabled and api\_enabled automatically during database migration, defaults both to enabled, and persists later changes\.
- With tcp\_enabled false, base TCP, base \+ 1 and base \+ 3 are closed after restart while discovery, heartbeat and the web UI remain active\.
- With api\_enabled false, HTTP/HTTPS command routes return 503 api\_disabled while raw Control API TCP and the web UI remain available\.
- The mobile application uses the Control API envelope and relies on hello/capability data instead of a fixed port or device\-model assumptions\.
- Automated tests verify TCP framing, invalid JSON, HTTP status mapping, 1 MiB size limits, allow rules, index bounds, concurrency and reconnection\.

Next protocol milestone: Promote the implemented device\-family protocol 2 subsets toward the version 3 target only after command names, authentication, permissions, event transport, output delay units, schedule semantics and cross\-device capabilities are confirmed\.

