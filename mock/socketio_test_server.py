#!/usr/bin/env python3
"""
PDU Socket.IO Test Server - WebSocket (Socket.IO) Protocol Simulator

Based on PROTOCOLS.md section 3 (WebSocket / Socket.IO Protocol):
- Flask-SocketIO server on 0.0.0.0:8081
- Implements all 39 client -> server event handlers
- Pushes `new states` on connect plus other server-pushed events

Usage:
    pip install flask flask-socketio
    python socketio_test_server.py
"""

import re
import time
from datetime import datetime
from threading import Lock, Thread

from flask import Flask, request
from flask_socketio import SocketIO, emit

# ─── Configuration ───────────────────────────────────────────────────────────

HOST = "0.0.0.0"
PORT = 8081

# ─── Device State ─────────────────────────────────────────────────────────────

N_CHANNELS = 14
FAN_CH = 12
SYS_LED = 11
WIFI_LED = 13

output_states = [True] * 16
input_states = [True] * 16
mapping = [False] * 16
override_active = False

pins = {
    "input": [{"id": i, "name": f"Input {i+1}", "state": True} for i in range(N_CHANNELS)],
    "output": [{"id": i, "name": f"Output {i+1}", "state": True} for i in range(N_CHANNELS)],
    "mapping": [{"id": i, "name": f"Map {i+1}", "state": False} for i in range(N_CHANNELS)],
}

temperatures = {"SYSTEMP": 35.5, "CPUTEMP": 42.1, "name": "Soleux Temperature Sensor"}

relay_schedules = []
relay_schedules_daily = []

tcp_whitelist = ["192.168.1.100"]

wifi_info = {"ip": "192.168.1.101", "ssid": "PDU_Network"}

log_tags = ["power", "overcurrent", "reset", "schedule"]

system_info = {
    "cputemp": 42.1,
    "uptime": "3d 02:15:44",
    "mode": "default",
    "fan": "auto",
}

state_lock = Lock()

server_start = time.time()


# ─── Helpers ─────────────────────────────────────────────────────────────────


def uptime_str():
    d = int(time.time() - server_start)
    days, rem = divmod(d, 86400)
    hours, rem = divmod(rem, 3600)
    mins, secs = divmod(rem, 60)
    return f"{days}d {hours:02d}:{mins:02d}:{secs:02d}"


def build_states():
    return {
        "output": list(output_states),
        "input": list(input_states),
        "mapping": list(mapping),
    }


def apply_output(pin, state):
    with state_lock:
        output_states[pin] = state
        pins["output"][pin]["state"] = state
        emit("new states", build_states(), broadcast=True)
        emit("output change", {"pin": pin, "state": state}, broadcast=True)


def emit_input(pin=None):
    with state_lock:
        emit("input state changed", list(input_states), broadcast=True)


# ─── App ─────────────────────────────────────────────────────────────────────


app = Flask(__name__)
app.config["SECRET_KEY"] = "pdu-test-secret"
socketio = SocketIO(app, cors_allowed_origins="*")


@socketio.on("connect")
def on_connect():
    print(f"[SIO] Client connected: {request.sid}")
    # Initial state dump is pushed on connect
    emit("new states", build_states())


@socketio.on("disconnect")
def on_disconnect():
    print(f"[SIO] Client disconnected: {request.sid}")


# ─── Relay Schedules ─────────────────────────────────────────────────────────


@socketio.on("add relay_schedule")
def add_relay_schedule(payload):
    print(f"[SIO] add relay_schedule: {payload}")
    relay_schedules.append(payload)
    emit("new states", build_states(), broadcast=True)


@socketio.on("save relay_schedule")
def save_relay_schedule(payload):
    print(f"[SIO] save relay_schedule: {payload}")
    emit("new states", build_states(), broadcast=True)


@socketio.on("delete relay_schedule")
def delete_relay_schedule(payload):
    print(f"[SIO] delete relay_schedule: {payload}")
    relay_schedules[:] = [s for s in relay_schedules if s != payload]


@socketio.on("update relay_schedule")
def update_relay_schedule(payload):
    print(f"[SIO] update relay_schedule: {payload}")


@socketio.on("add relay_schedule_daily")
def add_relay_schedule_daily(payload):
    print(f"[SIO] add relay_schedule_daily: {payload}")
    relay_schedules_daily.append(payload)
    emit("new states", build_states(), broadcast=True)


@socketio.on("save relay_schedule_daily")
def save_relay_schedule_daily(payload):
    print(f"[SIO] save relay_schedule_daily: {payload}")
    emit("new states", build_states(), broadcast=True)


@socketio.on("delete relay_schedule_daily")
def delete_relay_schedule_daily(payload):
    print(f"[SIO] delete relay_schedule_daily: {payload}")
    relay_schedules_daily[:] = [s for s in relay_schedules_daily if s != payload]


@socketio.on("update relay_schedule_daily")
def update_relay_schedule_daily(payload):
    print(f"[SIO] update relay_schedule_daily: {payload}")


# ─── TCP Whitelist ───────────────────────────────────────────────────────────


@socketio.on("add tcp_ip_address")
def add_tcp_ip(payload):
    print(f"[SIO] add tcp_ip_address: {payload}")
    msg = payload.get("ip") or payload.get("address")
    if msg and msg not in tcp_whitelist:
        tcp_whitelist.append(msg)


@socketio.on("delete tcp_ip_address")
def delete_tcp_ip(payload):
    print(f"[SIO] delete tcp_ip_address: {payload}")
    msg = payload.get("ip") or payload.get("address")
    tcp_whitelist[:] = [ip for ip in tcp_whitelist if ip != msg]


@socketio.on("update tcp_ip_address")
def update_tcp_ip(payload):
    print(f"[SIO] update tcp_ip_address: {payload}")


@socketio.on("get tcp_ip_address")
def get_tcp_ip():
    print("[SIO] get tcp_ip_address")
    emit("get tcp_ip_address", tcp_whitelist)


# ─── Pin Dates & Temps ───────────────────────────────────────────────────────


@socketio.on("update start_date")
def update_start_date(payload):
    print(f"[SIO] update start_date: {payload}")


@socketio.on("update end_date")
def update_end_date(payload):
    print(f"[SIO] update end_date: {payload}")


@socketio.on("get temp_data")
def get_temp_data():
    print("[SIO] get temp_data")
    emit("temperature changed",
         {"SYSTEMP": temperatures["SYSTEMP"], "CPUTEMP": temperatures["CPUTEMP"]},
         broadcast=True)


@socketio.on("update temp_name")
def update_temp_name(payload):
    print(f"[SIO] update temp_name: {payload}")
    if isinstance(payload, dict) and payload.get("name"):
        temperatures["name"] = payload["name"]


# ─── Pins & Outputs ──────────────────────────────────────────────────────────


@socketio.on("get pins")
def get_pins():
    print("[SIO] get pins")
    emit("get pins", pins)


@socketio.on("change output state")
def change_output_state(payload):
    print(f"[SIO] change output state: {payload}")
    pin = int(payload.get("pin", payload.get("channel", 0)))
    state = not output_states[pin]
    apply_output(pin, state)


@socketio.on("update pin")
def update_pin(payload):
    print(f"[SIO] update pin: {payload}")
    kind = payload.get("type", "output")
    pid = int(payload.get("id", payload.get("pin", 0)))
    if kind in pins and 0 <= pid < N_CHANNELS:
        if payload.get("name"):
            pins[kind][pid]["name"] = payload["name"]


@socketio.on("restart output pin")
def restart_output_pin(payload):
    print(f"[SIO] restart output pin: {payload}")
    pin = int(payload.get("pin", payload.get("channel", 0)))
    apply_output(pin, False)

    def delayed_on():
        time.sleep(5)
        apply_output(pin, True)

    Thread(target=delayed_on, daemon=True).start()


@socketio.on("change mapping")
def change_mapping(payload):
    print(f"[SIO] change mapping: {payload}")
    channel = int(payload.get("channel", payload.get("pin", 0)))
    state = bool(payload.get("state", payload.get("value", 0)))
    with state_lock:
        mapping[channel] = state
        pins["mapping"][channel]["state"] = state
    emit("update mapping",
         {"channel": channel, "state": state},
         broadcast=True)


@socketio.on("get states")
def get_states():
    print("[SIO] get states")
    emit("new states", build_states())


# ─── Datetime / Reboot ───────────────────────────────────────────────────────


@socketio.on("set datetime")
def set_datetime(payload):
    print(f"[SIO] set datetime: {payload}")


@socketio.on("reboot bb")
def reboot_bb():
    print("[SIO] reboot bb")

    def _reboot():
        time.sleep(2)
        emit("new states", build_states(), broadcast=True)

    Thread(target=_reboot, daemon=True).start()


# ─── WiFi ────────────────────────────────────────────────────────────────────


@socketio.on("get ssids")
def get_ssids(payload):
    print(f"[SIO] get ssids: {payload}")
    emit("get ssids", ["PDU_Network", "HomeWiFi_5G", "Guest_Network", "Office_2.4G"])


@socketio.on("get ssidsaved")
def get_ssidsaved():
    print("[SIO] get ssidsaved")
    emit("get ssidsaved", wifi_info)


@socketio.on("get wifi info")
def get_wifi_info():
    print("[SIO] get wifi info")
    emit("get wifi info", wifi_info)


@socketio.on("wifi connect")
def wifi_connect(payload):
    print(f"[SIO] wifi connect: {payload}")
    emit("wifi connect response", {"success": True, "ssid": payload.get("ssid", "")})


@socketio.on("wifi forget")
def wifi_forget(payload):
    print(f"[SIO] wifi forget: {payload}")
    emit("refresh settings page", {"type": "wifi"})


@socketio.on("wifi disconnect")
def wifi_disconnect():
    print("[SIO] wifi disconnect")


@socketio.on("get timezones")
def get_timezones():
    print("[SIO] get timezones")
    emit("get timezones", ["UTC", "Asia/Shanghai", "Asia/Dubai", "Europe/London"])


# ─── Firmware / System ───────────────────────────────────────────────────────


@socketio.on("update firmware")
def update_firmware():
    print("[SIO] update firmware")
    emit("update_service::updating", "{}", broadcast=True)

    def _updated():
        time.sleep(3)
        emit("update_service::updated", "{}", broadcast=True)

    Thread(target=_updated, daemon=True).start()


@socketio.on("get general system info")
def get_general_system_info():
    print("[SIO] get general system info")
    system_info["uptime"] = uptime_str()
    emit("get general system info", system_info)


@socketio.on("get system logs")
def get_system_logs(payload):
    print(f"[SIO] get system logs: {payload}")
    emit("get system logs", [])


@socketio.on("delete system logs")
def delete_system_logs():
    print("[SIO] delete system logs")


@socketio.on("get log tags")
def get_log_tags():
    print("[SIO] get log tags")
    emit("get log tags", log_tags)


# ─── Profile ─────────────────────────────────────────────────────────────────


@socketio.on("update profile settings")
def update_profile_settings(payload):
    print(f"[SIO] update profile settings: {payload}")


@socketio.on("update pdu name")
def update_pdu_name(payload):
    print(f"[SIO] update pdu name: {payload}")


@socketio.on("is alive")
def is_alive():
    print("[SIO] is alive")
    emit("is alive", "__ALIVE__")


# ─── Background Simulator (push-like updates) ────────────────────────────────


def simulator():
    pin_index = 0
    tick = 0
    while True:
        time.sleep(10)
        tick += 1
        if tick % 2 == 0:
            # Flip an output state occasionally
            with state_lock:
                output_states[pin_index] = not output_states[pin_index]
                pins["output"][pin_index]["state"] = output_states[pin_index]
            socketio.emit("new states", build_states(), broadcast=True)
            print(f"[SIM] Simulated output toggle pin {pin_index}")
            pin_index = (pin_index + 1) % N_CHANNELS
        if tick % 3 == 0:
            socketio.emit("temperature changed", temperatures, broadcast=True)


Thread(target=simulator, daemon=True).start()


# ─── Main ────────────────────────────────────────────────────────────────────


if __name__ == "__main__":
    print("=" * 60)
    print("  PDU Socket.IO Test Server")
    print(f"  WebSocket : {HOST}:{PORT}")
    print("=" * 60)
    socketio.run(app, host=HOST, port=PORT, debug=False, allow_unsafe_werkzeug=True)
