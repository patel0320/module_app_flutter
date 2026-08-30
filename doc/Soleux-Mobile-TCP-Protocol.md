# Soleux TCP Protocol — Mobile Developer Handoff

Protocol version 2 — 29 August 2026

This document covers the TCP commands implemented by the current Soleux
firmware for Relay Modules, AC/DC Dimmers, PDU Energy Meter, PDU 10 kW, and
PDU V1.0. New mobile applications should use the `J:` JSON protocol for
discovery/configuration and the legacy `AT+` protocol for simple live control.

## Transport

- TCP/IPv4, UTF-8 text.
- Device-configured port; default/common value is `5005`.
- End every request with `\r\n`. The firmware also accepts `\r` or `\n`.
- Keep one persistent connection and continuously read complete lines.
- Never assume one socket read contains exactly one message.
- The device may send unsolicited status lines after connection or state changes.
- `HostPort + 1` is a reduced TCP-lite service and is not required by the app.

## Discovery

Broadcast this JSON object by UDP to port `8000`:

```json
{"GUID":"8C93472D-2EF0-4B82-BE96-4FBBED57783F","VER":"2.0","PORT":"8001"}
```

`PORT` is a temporary TCP callback listener opened by the mobile app. The
device connects back and sends lines including `GUID`, `VER`, `PORT`, `SN`,
and `NAME`.

| Device | Discovery GUID | JSON `hello` device value |
|---|---|---|
| Relay Module | `579E6EA1-2F64-4CDE-8190-1CD3646EFAA1` | `relay_module` |
| AC/DC Dimmer | `C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91` | `dimmer` |
| PDU Energy Meter | `56EC974B-1C9F-48C3-B438-BFE976593072` | `pdu_energy_meter` |
| PDU 10 kW | `A728DD7D-0DEB-49B9-9B8B-A4556771815F` | `pdu_10kw` |
| PDU V1.0 | `B4A6B160-0CBA-4BD8-873D-EDC9DF895C26` | `pdu_v1` |

## JSON protocol

Request and response are each one CRLF-terminated line:

```text
J:{"id":1,"action":"hello","params":{}}
J:{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,"device":"relay_module"}}
```

Use a unique `id` for every outstanding request. A failed request has
`"ok":false` and an `error` value/object. PDU V1.0 may omit the outer
`protocol` field; clients must treat that field as optional.

Recommended connection sequence:

1. Start the continuous line reader.
2. Send `hello`.
3. Send `get_relay_configuration`.
4. Build the UI from returned counts, fields, and device identity.
5. Accept unrelated legacy/event lines while awaiting a matching JSON `id`.

### Common JSON actions

| Action | Purpose | Main parameters |
|---|---|---|
| `hello` | Identify protocol, device, name, and channel counts | none |
| `get_relay_configuration` | Read inputs, outputs, states, settings, and mapping | none |
| `get_page_configuration` | Read a device-driven configuration page | `page` |
| `set_page_configuration` | Save one page section | `page`, `section`, `values` |
| `mutate_page_row` | Add/update/delete a schedule, watchdog, or ACL row | `page`, `section`, `operation`, `id`, `values` |
| `execute_page_action` | Run a page operation such as reboot or time sync | `page_action` plus action data |

Common pages are `automation`, `schedule`, `settings`, `security`, and
`system`. A successful configuration write normally returns a refreshed page.

## Device command reference

### Relay Module

Supported JSON actions:

```text
hello, get_relay_configuration, get_page_configuration,
set_page_configuration, mutate_page_row, execute_page_action,
set_input_configuration, set_output_configuration, set_mapping,
write_hardware, settings_backup_download_begin, transfer_upload_begin,
transfer_upload_chunk, transfer_upload_finish, transfer_download_chunk,
transfer_download_finish, transfer_commit
```

Relevant legacy commands:

```text
AT+INSTAT          AT+INSTAT:<channel>
AT+OUTSTAT         AT+OUTSTAT:<channel>
AT+ON:<channel>    AT+OFF:<channel>    AT+TOGGLE:<channel>
AT+RESTART:<channel>
AT+GETMAP:<input>  AT+SETMAP:<input>:<output>:<code>
AT+GETOUTCONFIG:<channel>              AT+SETOUTCONFIG:...
AT+SETINPUT:...     AT+TEMP             AT+GETSYSDATA
AT+VER              AT+TIME             AT+NET
AT+CHNAMES          AT+SCHEDULE         AT+GETENERGY
AT+REBOOT
```

Mapping codes: `0=NONE`, `1=ON`, `2=OFF`, `3=TOGGLE`, `4=CONTINUEON`,
`5=CONTINUEOFF`. Channels are zero-based in JSON and individual control calls.

### AC/DC Dimmer

Supports the common Relay actions plus `set_dimmer_frequency`. The Dimmer
configuration response identifies its type and available PWM/frequency fields.

Additional/changed legacy commands:

```text
AT+PWMON:<channel>      AT+PWMOFF:<channel>
AT+PWMTOGGLE:<channel>  AT+SETPWM:<channel>:<value>
AT+GETOUTSTATAPWM       AT+GETOUTSTATAPWM:<channel>
AT+GETOUTSTATSPWM       AT+GETOUTSTATSPWM:<channel>
AT+MASKEDTOG:<mask>
```

Do not present a relay-only ON/OFF UI for a dimmer output. Read configuration
first and expose PWM as a bounded value supplied by firmware metadata.

### PDU Energy Meter

Supports the Relay-style JSON configuration, mapping, file-transfer, and
hardware-write actions. It additionally supports:

```text
get_energy_history
```

Example:

```text
J:{"id":40,"action":"get_energy_history","params":{"parameter":0,"start_date":"2026-08-01","end_date":"2026-08-29"}}
```

Energy parameters: `0=voltage (V)`, `1=current (A)`, `2=power (W)`,
`3=power factor`, `4=apparent power (VA)`, `5=energy (kWh)`. Date range must
not exceed 365 days. Live energy is available with `AT+GETENERGY`.

The PDU also supports `AT+GETOVERRIDE`. Disable mobile output controls while
the reported value is `OVERRIDE:ON`.

### PDU 10 kW

Supports Relay-style JSON I/O configuration, page configuration, mapping,
hardware write, settings backup/restore, and legacy output control. It supports
`AT+GETENERGY` and `AT+GETOVERRIDE`, but the current JSON firmware does not
expose `get_energy_history`.

Use the `pdu_10kw` hello identity to select the correct product presentation;
do not infer it from channel count.

### PDU V1.0

This is the legacy device family. Its JSON adapter supports:

```text
hello, get_relay_configuration, get_page_configuration,
set_page_configuration, mutate_page_row, execute_page_action
```

It does not expose current-generation input mapping, hardware-write, or file
transfer actions. Its response envelope may omit `protocol`.

Important legacy commands:

```text
AT+OUTSTAT:<channel>  AT+ON:<channel>  AT+OFF:<channel>
AT+TOGGLE:<channel>   AT+RESTART:<channel>
AT+GETOVERRIDE        AT+GETSYSDATA    AT+TEMP
AT+VER                AT+TIME          AT+NET
AT+CHNAMES            AT+SCHEDULE      AT+REBOOT
AT+SETOUTCFG:<channel>:<off-disabled>:<restart-disabled>:<base64-name>
```

PDU V1.0 has historically inverted electrical relay state in some legacy
paths. Test and normalize its reported `OUT` state separately. It should not
be treated as having application-visible inputs.

## Common legacy control and responses

```text
AT+ON:0
AT+OFF:0
AT+TOGGLE:0
AT+RESTART:0
AT+OUTSTAT:0
```

Typical status line:

```text
OUT:0:ON
```

Read all output or input states with `AT+OUTSTAT` / `AT+INSTAT`. Devices may
also send unsolicited `OUT:<channel>:<state>` and `IN:<channel>:<state>` lines.

Masked commands select outputs using `X`; `-` leaves an output unchanged:

```text
AT+MASKEDON:X--X---
AT+MASKEDOFF:X--X---
AT+MASKEDRESTART:X--X---
```

System/status commands include:

```text
AT+VER
AT+TEMP
AT+GETSYSDATA
AT+NET
AT+CHNAMES
AT+SCHEDULE
```

Clients must ignore unknown response lines and tolerate missing optional
fields. Send `EXIT` to close cleanly.

## Command and expected-response examples

The values below are examples. Names, counts, states, timestamps, measurements,
and configuration fields will reflect the connected device.

### Identify any device

Request:

```text
J:{"id":1,"action":"hello","params":{}}
```

Relay Module response:

```text
J:{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,"device":"relay_module","name":"Plant Room Relays","input_count":8,"virtual_input_count":2,"output_count":8}}
```

Dimmer response:

```text
J:{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,"device":"dimmer","name":"Lobby Dimmer","input_count":4,"virtual_input_count":0,"output_count":4}}
```

PDU Energy Meter response:

```text
J:{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,"device":"pdu_energy_meter","name":"Rack PDU","input_count":2,"virtual_input_count":1,"output_count":8}}
```

PDU 10 kW response:

```text
J:{"protocol":2,"id":1,"ok":true,"result":{"protocol":2,"device":"pdu_10kw","name":"Main Distribution PDU","input_count":2,"virtual_input_count":0,"output_count":4}}
```

PDU V1.0 response (outer `protocol` may be absent):

```text
J:{"id":1,"ok":true,"result":{"protocol":2,"device":"pdu_v1","name":"Legacy Rack PDU","input_count":0,"virtual_input_count":0,"output_count":7}}
```

### Read device I/O configuration

Request:

```text
J:{"id":2,"action":"get_relay_configuration","params":{}}
```

Representative response:

```text
J:{"protocol":2,"id":2,"ok":true,"result":{"input_count":2,"virtual_input_count":1,"output_count":4,"inputs":[{"channel":0,"input_name":"Door","input_state":false,"input_enabled":1}],"outputs":[{"channel":0,"output_name":"Server","output_state":true,"output_on_delay":0,"output_off_delay":0,"output_on_run_time":0,"output_off_run_time":0,"start_delay":0,"initial_state":0,"turn_off_disable":false,"restart_disable":false}],"mapping":[]}}
```

### Control and read a relay/PDU output

Requests:

```text
AT+ON:0
AT+OUTSTAT:0
```

Expected state response:

```text
OUT:0:ON
```

The service may also append `OK` for a successfully processed legacy command.
Treat the `OUT` line as the authoritative state. If turn-off or restart is
disabled, a legacy PDU may instead return:

```text
Error : Function Disabled
```

### Read all inputs and outputs

```text
AT+INSTAT
AT+OUTSTAT
```

Representative multi-line response:

```text
IN:0:OFF
IN:1:ON
OUT:0:ON
OUT:1:OFF
OUT:2:ON
```

Read until the next complete command response or until the expected number of
channels from `get_relay_configuration` has been received.

### Configure one Relay Module output with JSON

Request:

```text
J:{"id":10,"action":"set_output_configuration","params":{"channel":0,"name":"Server","on_delay":0,"off_delay":0,"on_runtime":0,"off_runtime":0,"start_delay":5,"initial_state":0,"turn_off_disable":false,"restart_disable":false}}
```

Representative success response:

```text
J:{"protocol":2,"id":10,"ok":true,"result":{"channel":0,"output_name":"Server","output_on_delay":0,"output_off_delay":0,"output_on_run_time":0,"output_off_run_time":0,"start_delay":5,"initial_state":0,"turn_off_disable":false,"restart_disable":false}}
```

Representative validation failure:

```text
J:{"protocol":2,"id":10,"ok":false,"error":{"code":"internal_error","message":"delay and runtime values must be between 0 and 65000"}}
```

### Configure an input/output mapping

Request (`input 0` toggles `output 1`):

```text
J:{"id":11,"action":"set_mapping","params":{"input":0,"output":1,"code":3}}
```

Expected Relay/PDU response:

```text
J:{"protocol":2,"id":11,"ok":true,"result":{"input":0,"output":1,"code":3}}
```

### Set and read a Dimmer PWM output

Set output 0 to 60 percent:

```text
AT+SETPWM:0:60
```

Read the output PWM state:

```text
AT+GETOUTSTATAPWM:0
```

The response reports the channel and current actual PWM value. The precise
prefix differs between AC and DC firmware modes, so mobile code should parse
the returned key/value line and should use the JSON configuration to identify
the Dimmer type. A JSON configuration write is more portable:

```text
J:{"id":20,"action":"set_output_configuration","params":{"channel":0,"name":"Lobby Lights","on_delay":50,"off_delay":5,"on_runtime":0,"off_runtime":100,"initial_state":0,"pwm":60}}
J:{"protocol":2,"id":20,"ok":true,"result":{"channel":0,"saved":true}}
```

### Read live PDU energy

Request:

```text
AT+GETENERGY
```

Expected response format and example:

```text
GETENERGY:<voltage>:<current>:<real-power>:<apparent-power>:<power-factor>:<energy>:E
GETENERGY:229.7:1.25:274.2:287.1:0.955:18.42:E
```

Units are V, A, W, VA, unitless power factor, and kWh.

### Read PDU manual override

```text
AT+GETOVERRIDE
```

Expected response:

```text
OVERRIDE:ON
```

or:

```text
OVERRIDE:OFF
```

The device may send the same line without a request when the physical override
changes. Disable output controls whenever the value is `ON`.

### Read PDU Energy Meter history

Request:

```text
J:{"id":30,"action":"get_energy_history","params":{"parameter":0,"start_date":"2026-08-01","end_date":"2026-08-29"}}
```

Representative response:

```text
J:{"protocol":2,"id":30,"ok":true,"result":{"energy_history":true,"parameter":0,"unit":"V","start_date":"2026-08-01","end_date":"2026-08-29","points":[{"timestamp":"2026-08-29 16:00:00","value":229.7}]}}
```

### Change the PDU V1.0 output name and restrictions

`U2VydmljZSBDb21wdXRlcg==` is Base64 UTF-8 for `Service Computer`.

```text
AT+SETOUTCFG:0:true:false:U2VydmljZSBDb21wdXRlcg==
```

Expected response:

```text
OUTCFG_SAVED:0
```

### Read system information

Request:

```text
AT+GETSYSDATA
```

Representative response:

```text
GETSYSDATA:TimeStamp:2026-08-29 16:06:00
GETSYSDATA:UpTime:4 days, 3 hours
GETSYSDATA:MemUsage:20.16
GETSYSDATA:CPUUsage:25.9
```

The number and order of fields vary; parse by the field name.

## Mobile implementation requirements

- Use a buffered CR/LF line parser.
- Match JSON responses by `id`, not arrival order.
- Route non-`J:` lines to an asynchronous event/status parser.
- Reconnect with exponential backoff after loss or reboot.
- Discover channel counts and capabilities; never hard-code them.
- Respect `turn_off_disable`, `restart_disable`, and PDU manual override.
- Confirm safety-sensitive switching and administrative actions in the UI.
- Treat reboot, network changes, backup/restore, and certificate upload as
  administrator-only operations.
- Use a trusted management network/access lists. The protocol itself does not
  provide TLS or user authentication at the TCP command layer.

## Minimal client example

```python
import json, socket

sock = socket.create_connection((device_ip, device_port), timeout=5)
reader = sock.makefile("r", encoding="utf-8", newline="\n")

sock.sendall(("J:" + json.dumps({
    "id": 1, "action": "hello", "params": {}
}) + "\r\n").encode("utf-8"))

while True:
    line = reader.readline()
    if not line:
        raise ConnectionError("Device disconnected")
    line = line.strip("\r\n")
    if line.startswith("J:"):
        message = json.loads(line[2:])
        if message.get("id") == 1:
            print(message)
            break
    else:
        handle_unsolicited_status(line)
```

Source of truth: the active `web-service-redis.py` file in each device firmware
folder. Page schemas may gain fields over time; render unknown fields safely
and ignore unknown response properties for forward compatibility.
