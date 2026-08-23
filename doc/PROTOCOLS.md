# PDUCore Socket Communication Protocols

## Overview

PDUCore implements four communication protocols:

1. **TCP ASCII Protocol** (port 5005) — AT-command based, text-oriented control protocol
2. **UDP Discovery Protocol** (port 8000) — Network device discovery
3. **WebSocket (Socket.IO) Protocol** (port 8081) — Real-time Web UI control
4. **Redis Pub/Sub** (localhost:6379) — Internal IPC between services

---

## 1. TCP ASCII Protocol

### Server Configuration

| Parameter | Value |
|-----------|-------|
| Bind IP | `0.0.0.0` |
| Default Port | `5005` (configurable via settings DB) |
| Socket Type | `AF_INET`, `SOCK_STREAM` |
| Buffer Size | 64 bytes |
| Backlog | 5 connections |
| SO_REUSEADDR | Enabled |

### Connection Lifecycle

1. Client connects to port 5005
2. Server validates client IP against `tcp_ip_address` whitelist (SQLite table)
3. If unauthorized, connection is immediately closed
4. If authorized, server sends a **full status dump** automatically:
   - Device identity and version info
   - All input pin states
   - All output pin states
   - Temperature readings
   - System time / uptime
   - Network configuration
   - Channel names
   - Relay schedules
5. Server enters command loop, reading 64-byte chunks from client
6. Commands are dispatched and responses sent
7. Client sends `EXIT\r` to disconnect gracefully

### Command Format

- All commands use the **AT+** prefix convention
- Commands end with `\r`
- Responses end with `\r\n` followed by `\r\nOK\r\n` or `\r\nERROR\r\n`

### Complete Command List

| # | Command | Format | Description | Response Format |
|---|---------|--------|-------------|-----------------|
| 1 | **AT** | `AT\r` | Ping / test (no-op) | `\r\nOK\r\n` |
| 2 | **AT+INSTAT** | `AT+INSTAT\r` | Get ALL input states | `IN:<pin>:<ON\|OFF>\r\n` (repeated for all pins) |
| 3 | **AT+OUTSTAT** | `AT+OUTSTAT\r` | Get ALL output states | `OUT:<pin>:<ON\|OFF>\r\n` (repeated for all pins) |
| 4 | **AT+INSTAT:\<pin\>** | `AT+INSTAT:<pin>\r` | Get single input state | `IN:<pin>:<ON\|OFF>\r\n` |
| 5 | **AT+OUTSTAT:\<pin\>** | `AT+OUTSTAT:<pin>\r` | Get single output state | `OUT:<pin>:<ON\|OFF>\r\n` |
| 6 | **AT+TEMP** | `AT+TEMP\r` | Get all temperature data | `SYSTEMP:<temp>\r\nCPUTEMP:<temp>\r\nFAN_STATUS:<ON\|OFF>\r\nFAN_HIGH_TEMP:<temp>\r\nFAN_LOW_TEMP:<temp>\r\nFAN_MODE:<auto\|on\|off>\r\n` |
| 7 | **AT+TOGGLE:\<pin\>** | `AT+TOGGLE:<pin>\r` | Toggle a single output | `OK` |
| 8 | **AT+ON:\<pin\>** | `AT+ON:<pin>\r` | Turn ON a single output | `OK` |
| 9 | **AT+OFF:\<pin\>** | `AT+OFF:<pin>\r` | Turn OFF a single output | `OK` |
| 10 | **AT+MAPSTAT:\<pin\>** | `AT+MAPSTAT:<pin>\r` | Get mapping state for a pin | `MAP:<pin>:<ON\|OFF>\r\n` |
| 11 | **AT+MAP:\<data\>** | `AT+MAP:<ch1>:<ch2>:...` | Set ALL pin mappings (T/F per channel) | `OK` |
| 12 | **AT+REBOOT** | `AT+REBOOT\r` | Reboot the entire PDU device | `OK` |
| 13 | **AT+RESTART:\<pin\>** | `AT+RESTART:<pin>\r` | Power-cycle a single output (off → 5s delay → on) | `OK` |
| 14 | **AT+VER** | `AT+VER\r` | Get device version info | `DEVICE:Soleux PDU\r\nVER:<ver> Build :<build>\r\nRELEASE_DATE:<date>\r\nSN:<serial>\r\nLANMAC:<mac>\r\nWIFIMAC:<mac>\r\nRELAY_COUNT:<count>\r\n` |
| 15 | **AT+TIME** | `AT+TIME\r` | Get system time | `SYSTIME:<YYYY/MM/DD HH:MM:SS>\r\nUPTIME:<uptime>\r\n` |
| 16 | **AT+NET** | `AT+NET\r` | Get network configuration | `LANIP:<ip>\r\nWIFIIP:<ip>\r\nWIFISSID:<ssid>\r\nAPP_NAME:<name>\r\n` |
| 17 | **AT+CHNAMES** | `AT+CHNAMES\r` | Get channel names | `CHNAME_IN:<pin>:<name>\r\n` and `CHNAME_OUT:<pin>:<name>\r\n` for each pin |
| 18 | **AT+SCHEDULE** | `AT+SCHEDULE\r` | Get all relay schedules | `SCHEDULE_START:<pin>\nSCHEDULE_RUNONES:ID:<id>,RELAY:<r>,DATETIME:<dt>,ACTION:<a>,PROCESSED:<p>\nSCHEDULE_WEEKLY:ID:<id>,RELAY:<r>,DATETIME:<t>,ACTION:<a>,MON:<m>,TUE:<t>,...\nSCHEDULE_END:<pin>\n` (per pin) |
| 19 | **EXIT** | `EXIT\r` | Gracefully close TCP session | `Exiting Terminal \r\n` |

### Push Broadcasts (Server → All Connected TCP Clients)

The server pushes state changes to all connected TCP clients by sending the corresponding command string:

| Event | Broadcast Command |
|-------|-------------------|
| Output state change | `AT+OUTSTAT:<pin>` |
| Input state change | `AT+INSTAT:<pin>` |
| Mapping change | `AT+MAPSTAT:<pin>` |
| Temperature update | `AT+TEMP\r` |
| Time update | `AT+TIME\r` |
| Network update | `AT+NET\r` |
| Schedule update | `AT+SCHEDULE\r` |

---

## 2. UDP Discovery Protocol

### Listener Configuration

| Parameter | Value |
|-----------|-------|
| Socket Type | `AF_INET`, `SOCK_DGRAM` |
| Broadcast | `SO_BROADCAST` enabled |
| Bind Address | `0.0.0.0:8000` |
| Buffer Size | 1024 bytes |

### Protocol Flow

1. Client sends UDP broadcast to port 8000
2. Message format (JSON):

   ```json
   {
     "GUID": "8481fba0-f387-11ea-adc1-0242ac120002",
     "Port": "<client_port>"
   }
   ```

3. Server validates the GUID
4. Server opens a **new TCP connection** back to the client's IP address on the specified `<client_port>`
5. Response sent over the new TCP connection:

   ```
   GUID:24d9b67e-f38d-11ea-adc1-0242ac120002
   VER:<version>
   PORT:<tcp_port>
   SN:<serial_number>
   NAME:<app_name>
   ```

### GUID Reference

| GUID | Description |
|------|-------------|
| `8481fba0-f387-11ea-adc1-0242ac120002` | Windows App discovery request |
| `24d9b67e-f38d-11ea-adc1-0242ac120002` | PDU identity response |

---

## 3. WebSocket (Socket.IO) Protocol

### Server Configuration

| Parameter | Value |
|-----------|-------|
| Framework | Flask-SocketIO |
| Port | `8081` |
| Host | `0.0.0.0` |
| Transport | WebSocket (with long-polling fallback) |

### Client Connection

```javascript
// From templates/layouts/main.html
window.socket = io.connect(null, {port: location.port, rememberTransport: false});
```

### Server-Side Event Handlers (Client → Server)

| # | Event Name | Description |
|---|------------|-------------|
| 1 | `add relay_schedule` | Create new weekly schedule entry |
| 2 | `save relay_schedule` | Save weekly schedule with days |
| 3 | `delete relay_schedule` | Delete weekly schedule |
| 4 | `update relay_schedule` | Update weekly schedule parameters |
| 5 | `add relay_schedule_daily` | Create one-time daily schedule |
| 6 | `save relay_schedule_daily` | Save one-time daily schedule |
| 7 | `delete relay_schedule_daily` | Delete daily schedule |
| 8 | `update relay_schedule_daily` | Update daily schedule |
| 9 | `add tcp_ip_address` | Add IP to TCP whitelist |
| 10 | `delete tcp_ip_address` | Remove IP from TCP whitelist |
| 11 | `update tcp_ip_address` | Update whitelist IP |
| 12 | `get tcp_ip_address` | Return all whitelisted TCP IPs |
| 13 | `update start_date` | Set pin start date |
| 14 | `update end_date` | Set pin end date |
| 15 | `get temp_data` | Get temperature sensor data |
| 16 | `update temp_name` | Rename temp sensor |
| 17 | `get pins` | Get all pin configurations |
| 18 | `change output state` | Toggle output pin |
| 19 | `update pin` | Update pin input/output names |
| 20 | `set datetime` | Set system date/time/timezone |
| 21 | `reboot bb` | Reboot the PDU |
| 22 | `change mapping` | Change pin mapping |
| 23 | `get states` | Get all input/output/mapping states |
| 24 | `get ssids` | Scan and return WiFi networks |
| 25 | `get ssidsaved` | Get saved WiFi + IP info |
| 26 | `get wifi info` | Get current WiFi IP |
| 27 | `wifi connect` | Initiate WiFi connection |
| 28 | `wifi forget` | Forget/delete WiFi network |
| 29 | `wifi disconnect` | Disconnect from WiFi |
| 30 | `get timezones` | List available timezones |
| 31 | `update firmware` | Trigger firmware update |
| 32 | `restart output pin` | Power-cycle output pin |
| 33 | `get general system info` | CPU temp + uptime |
| 34 | `get system logs` | Query outlet logs with filters |
| 35 | `delete system logs` | Clear all logs |
| 36 | `get log tags` | Return available log tags |
| 37 | `update profile settings` | Update PDU name + user credentials |
| 38 | `update pdu name` | Update PDU hostname only |
| 39 | `is alive` | Health check (returns `__ALIVE__`) |

### Server-Pushed Events (Server → Client)

| Event | Description |
|-------|-------------|
| `update mapping` | Mapping state changed |
| `input state changed` | Input states updated |
| `override mode active` | Override mode activated |
| `override mode inactive` | Override mode deactivated |
| `new states` | Initial state dump (sent on connect) |
| `temperature changed` | Temperature sensor update |
| `update_service::no_updates` | Firmware check - no update available |
| `update_service::updating` | Firmware update in progress |
| `update_service::updated` | Firmware update completed |
| `refresh settings page` | WiFi settings changed |
| `wifi connect response` | WiFi connection result |

---

## 4. Redis Pub/Sub (Internal IPC)

### Server: localhost:6379

Used for inter-process communication between three services:
- `web-service-redis.py` — Web server, TCP server, SocketIO
- `PinCheckerRedis.py` — Hardware GPIO control
- `WatchDog.py` — Service health monitoring

### Channels Published by web-service-redis.py

| Channel | Payload Format | Purpose |
|---------|---------------|---------|
| `toggle_on_output` | `{"pin": <int>, "Info": "<string>"}` | Toggle output pin |
| `turn_on_output` | `{"pin": <int>, "Info": "<string>"}` | Turn output ON |
| `turn_off_output` | `{"pin": <int>, "Info": "<string>"}` | Turn output OFF |
| `toggle_mapping` | `{"channel": <int>, "state": <int>}` | Change mapping |
| `watchdog_clear` | `{"ServiceIndex": 0}` | Reset watchdog timer |
| `update_service::update_web_service` | `"TRUE"` | Trigger firmware update |

### Channels Subscribed by web-service-redis.py

| Channel | Purpose |
|---------|---------|
| `update_channel_states` | Bulk input/output state update from hardware |
| `mapping_changed` | Mapping array update from hardware |
| `reset_db` | Factory reset via input hold |
| `update_single_channal_input` | Single input change |
| `update_single_channal_output` | Single output change |
| `update_service::no_updates` | No firmware update available |
| `update_service::updating` | Firmware update in progress |
| `update_service::updated` | Firmware update complete |
| `__EXIT_WEBSERVICE_REDIS_THREAD` | Graceful shutdown signal |

---

## Pin Constants

| Constant | Value (0-indexed) | Description |
|----------|-------------------|-------------|
| `NChannels` | 14 (10+4) | Total number of channels |
| `FanCh` | 12 | Fan relay channel |
| `SysLED` | 11 | System LED channel |
| `WIFILED` | 13 | WiFi LED channel |

## State Arrays

```python
mapping = [False x 16]         # Pin mapping states
output_states = [True x 16]    # Output relay states
input_states = [True x 16]     # Input sensor states
output_states_old = [True x 16]
input_states_old = [True x 16]
tcp_client_connections = {}    # Dict of {ip: socket} for connected TCP clients
```

---

## Source Files

| File | Purpose |
|------|---------|
| `web-service-redis.py` | Main server: TCP server + SocketIO + Redis + UDP discovery |
| `PinCheckerRedis.py` | Hardware service: GPIO control via Redis pub/sub |
| `WatchDog.py` | Watchdog service: service health monitoring |
| `templates/layouts/main.html` | SocketIO client initialization |
