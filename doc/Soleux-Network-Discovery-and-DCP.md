# Soleux Network Discovery and DCP Protocol

Mobile and desktop developer handoff — protocol version 1 — 29 August 2026

Soleux devices implement three related network-presence mechanisms:

1. **UDP discovery with TCP callback** for finding correctly addressed devices.
2. **Soleux DCP / Layer-2 discovery** for finding and commissioning devices by
   MAC address even when they do not have a usable IPv4 address.
3. **UDP heartbeat** for checking whether a known device is still reachable.

Soleux DCP is a custom DCP-like commissioning protocol. It uses a Soleux JSON
payload inside Ethernet frames with experimental EtherType `0x88B5`. It is not
wire-compatible with PROFINET DCP.

## Device identities

| Device | Discovery GUID |
|---|---|
| Relay Module | `579E6EA1-2F64-4CDE-8190-1CD3646EFAA1` |
| AC/DC Dimmer | `C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91` |
| PDU Energy Meter | `56EC974B-1C9F-48C3-B438-BFE976593072` |
| PDU 10 kW | `A728DD7D-0DEB-49B9-9B8B-A4556771815F` |
| PDU V1.0 | `B4A6B160-0CBA-4BD8-873D-EDC9DF895C26` |

The GUID identifies a device family. The serial number and Ethernet MAC identify
an individual physical device.

## 1. Standard UDP network discovery

### Purpose

Use this method in the mobile app when the phone/tablet and Soleux device are
on the same IPv4 subnet and the device already has a working address.

### Ports and transport

| Direction | Protocol | Port | Purpose |
|---|---|---:|---|
| App to device | UDP broadcast | `8000` | Discovery request |
| Device to app | TCP connection | App-selected, normally `8001` | Discovery response |
| App to device | TCP connection | Returned `PORT`, normally `5005` | Device commands |

The app must open the TCP callback listener before broadcasting. The callback
port is supplied in the UDP request so it may be changed when `8001` is busy.

### Discovery request

Broadcast this UTF-8 JSON object to UDP port `8000` on every active local
interface:

```json
{
  "GUID": "8C93472D-2EF0-4B82-BE96-4FBBED57783F",
  "VER": "2.0",
  "PORT": "8001"
}
```

Field meanings:

| Field | Required | Meaning |
|---|---:|---|
| `GUID` | Yes | Soleux discovery-request identity; use the value above |
| `VER` | Yes | Discovery protocol version; current value is `2.0` |
| `PORT` | Yes | TCP callback port listening on the app device |

`PORT` may be a JSON string or number. PDU V1.0 also accepts legacy casing
`Port`, but new clients should send uppercase `PORT`.

### Device response

The device opens a TCP connection back to the sender IP and the requested
callback port. It sends newline-delimited UTF-8 fields and closes the socket.

Example Relay Module response:

```text
GUID:579E6EA1-2F64-4CDE-8190-1CD3646EFAA1
VER:7.10
PORT:5005
SN:0000000012345678
NAME:Plant Room Relays
```

Example Dimmer response:

```text
GUID:C47A5A88-03E8-4EC0-9F2D-67A6C43F0D91
VER:7.10
PORT:5005
SN:0000000012349999
NAME:Lobby Dimmer
```

Response fields:

| Field | Meaning |
|---|---|
| `GUID` | Device-family GUID from the identity table |
| `VER` | Installed device firmware version |
| `PORT` | TCP command HostPort |
| `SN` | Device serial number |
| `NAME` | User-configured device name |

Use the TCP peer address as the device IP address. Do not expect a separate IP
field in this response. Ignore unknown fields for forward compatibility.

### Recommended UDP discovery sequence

1. Obtain the local Wi-Fi/Ethernet IPv4 address and subnet broadcast address.
2. Open a TCP server on the selected callback port.
3. Broadcast the request to port `8000`.
4. Accept callback connections for approximately 2–5 seconds.
5. Parse each callback by field name, not line order.
6. Deduplicate by serial number, then MAC/IP where available.
7. Connect to the returned peer IP and `PORT` for TCP commands.
8. Repeat discovery periodically only while the discovery screen is open.

Some mobile platforms require a local-network permission and a multicast or
broadcast entitlement before LAN packets are delivered.

## 2. Soleux DCP / Layer-2 discovery

### Purpose and scope

DCP works without IPv4. It discovers a device by Ethernet MAC address and can:

- return identity, firmware, current IP settings, and HostPort;
- save a static IPv4 address, subnet mask, and default gateway;
- reboot a specifically targeted device.

DCP frames stay inside the local Ethernet broadcast domain and do not cross a
router. The firmware listens on wired interface `eth0`.

### Platform requirements

The client must be able to send and capture raw Ethernet frames:

- Windows uses Npcap and its 32-bit runtime for the current Win32 app.
- Linux requires root or `CAP_NET_RAW`.
- Standard Android and iOS application sandboxes normally do not expose raw
  Ethernet frame access. A normal mobile app should use UDP discovery and ask
  the user to commission an unaddressed device with the Windows tool or a
  privileged commissioning helper.

Failure to start DCP must not disable standard UDP discovery.

### Ethernet frame format

| Offset | Length | Field |
|---:|---:|---|
| 0 | 6 | Destination MAC |
| 6 | 6 | Source MAC |
| 12 | 2 | EtherType, network byte order: `0x88B5` |
| 14 | variable | UTF-8 JSON payload |
| end | variable | Zero padding to the Ethernet minimum frame size if required |

Protocol JSON always contains:

```json
{"soleux_l2":1,"op":"<operation>"}
```

Trailing zero padding must be removed before decoding JSON.

### Identify request

Destination MAC: `FF:FF:FF:FF:FF:FF`

```json
{
  "soleux_l2": 1,
  "op": "identify",
  "nonce": "client-generated-correlation-value"
}
```

The nonce is echoed by the device and should be unpredictable enough to
separate overlapping discovery runs.

### Identity response

The device responds by unicast to the request frame's source MAC:

```json
{
  "soleux_l2": 1,
  "op": "identity",
  "nonce": "client-generated-correlation-value",
  "guid": "579E6EA1-2F64-4CDE-8190-1CD3646EFAA1",
  "mac": "02:81:F9:30:81:F9",
  "name": "Plant Room Relays",
  "serial": "0000000012345678",
  "firmware": "7.10",
  "port": 5005,
  "ip": "10.100.20.42",
  "mask": "255.255.255.0",
  "gateway": "10.100.20.1"
}
```

When the device has no address, `ip`, `mask`, and/or `gateway` may be
`0.0.0.0`. Prefer the Ethernet source MAC as the authoritative hardware
address; validate that it agrees with the JSON `mac` field.

### Assign a static IPv4 address

Send this as a unicast Ethernet frame to the selected device MAC:

```json
{
  "soleux_l2": 1,
  "op": "set_ipv4",
  "nonce": "client-generated-correlation-value",
  "target": "02:81:F9:30:81:F9",
  "ip": "10.100.20.42",
  "mask": "255.255.255.0",
  "gateway": "10.100.20.1"
}
```

The device processes the request only when `target` equals its Ethernet MAC.
MAC text is case-insensitive and may use `:` or `-` separators.

Success response:

```json
{
  "soleux_l2": 1,
  "op": "set_result",
  "status": "ok",
  "message": "static IPv4 settings saved"
}
```

Validation failure example:

```json
{
  "soleux_l2": 1,
  "op": "set_result",
  "status": "error",
  "message": "invalid subnet mask"
}
```

Accepted values:

- `ip` must be a valid unicast IPv4 address and cannot be `0.0.0.0` or
  `255.255.255.255`.
- `mask` must be a non-zero contiguous IPv4 subnet mask.
- `gateway` must be valid IPv4; `0.0.0.0` is allowed when no gateway is used.

After a successful acknowledgement, the device waits approximately two
seconds, syncs storage, and reboots. The client should wait for UDP discovery
or heartbeat to confirm the device is reachable at its new address.

### Reboot without changing IPv4

Request, sent as a unicast frame to the device MAC:

```json
{
  "soleux_l2": 1,
  "op": "reboot",
  "nonce": "client-generated-correlation-value",
  "target": "02:81:F9:30:81:F9"
}
```

Success response:

```json
{
  "soleux_l2": 1,
  "op": "reboot_result",
  "status": "ok",
  "message": "reboot accepted"
}
```

The device reboots approximately two seconds after acknowledging.

### DCP client rules

- Send identify on every eligible Ethernet adapter.
- Do not send DCP on loopback adapters.
- Correlate identity responses by nonce.
- Deduplicate responses by Ethernet source MAC.
- Send address/reboot commands only by unicast to a user-selected MAC.
- Require acknowledgement before reporting success.
- Never assume DCP success means the new IPv4 path is already ready; wait for
  reboot and rediscovery.
- Keep UDP discovery active when packet capture is unavailable.

## 3. UDP heartbeat

Heartbeat is for known devices, not general discovery. The device listens on:

```text
UDP heartbeat port = TCP HostPort + 2
```

For the common HostPort `5005`, heartbeat uses UDP port `5007`.

### Ping request

Send by unicast to the known device IP:

```json
{
  "soleux_heartbeat": 1,
  "op": "ping",
  "nonce": "0000019ABCDEF012-0001"
}
```

The nonce is required, must not be empty, and is limited to 64 characters.

### Pong response

The device replies to the request source IP and source UDP port:

```json
{
  "soleux_heartbeat": 1,
  "op": "pong",
  "nonce": "0000019ABCDEF012-0001",
  "tcp_port": 5005,
  "name": "Plant Room Relays"
}
```

The current Windows client sends heartbeats every 5 seconds and accepts replies
for 1.5 seconds. A mobile app can use a less aggressive interval while in the
background to preserve battery and comply with platform networking limits.

## 4. Merging discovery results

The same device may be found through UDP and DCP. Merge records using this
priority:

1. Serial number when present and stable.
2. Ethernet MAC from DCP.
3. Device-family GUID plus IP and HostPort as a fallback.

Suggested source labels:

| Sources | UI label |
|---|---|
| UDP only | `UDP` |
| DCP only | `DCP` |
| Both | `UDP + DCP` |

A DCP-only device with `0.0.0.0` cannot be opened over TCP. It must first be
assigned an address. A UDP-discovered device can be opened immediately using
the callback peer IP and returned HostPort.

## 5. Security and safety

- UDP discovery, DCP commissioning, and heartbeat are unauthenticated.
- DCP can change network settings and reboot equipment. Expose those actions
  only on a protected commissioning/industrial LAN and require explicit user
  confirmation.
- Validate that the selected target MAC matches the intended physical device.
- Do not forward DCP frames across networks or emulate routing for EtherType
  `0x88B5`.
- Treat device names and all received text as untrusted display data.
- Apply rate limits to discovery and heartbeat traffic.

## 6. Mobile implementation recommendation

For a standard Android/iOS app:

1. Implement UDP broadcast discovery on port `8000` with a temporary TCP
   callback listener.
2. Implement TCP command connection using the returned peer IP and HostPort.
3. Implement unicast UDP heartbeat on `HostPort + 2` while a device is saved or
   actively displayed.
4. Show a commissioning message when a device has no usable IP and direct the
   installer to the Windows Soleux tool for DCP address assignment.
5. Implement DCP inside the mobile app only if the deployment environment
   provides a supported privileged raw-Ethernet API.

Source of truth:

- Firmware: `soleux_layer2_discovery.py` and `NetworkDiscover()` in each active
  device's `web-service-redis.py`.
- Windows client: `Layer2Discovery.pas`, `HeartbeatMonitor.pas`, and the
  discovery handling in `MainForm.pas`.
