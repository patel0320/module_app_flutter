#!/usr/bin/env python3
"""
Soleux mock relay.

A standalone (no-Flask) simulation of a relay's UDP network-discovery
responder, matching the wire contract in:

  * doc/Soleux-Network-Discovery-and-DCP.md
  * mock/module_client.py (DISCOVERY_REQUEST_GUID / API_PORT / offsets)

It pretends to be the physical hardware: it listens for a broadcast UDP
discovery request on port 8000 and answers with a TCP callback response that
the Windows "Soleux Manager" / `mock/module_client.py discover` expects.
Run it with:

    python mock/mock_relay.py
"""

import json
import os
import socket
import threading
import time

# ─── Well-known constants (shared with mock/module_client.py) ────────────────

DISCOVERY_REQUEST_GUID = "8C93472D-2EF0-4B82-BE96-4FBBED57783F"
DISCOVERY_PROTOCOL_VERSION = "2.0"
DISCOVERY_PORT = int(os.environ.get("SOLEUX_DISCOVERY_PORT", "8000"))
DEFAULT_TCP_PORT = 5005
CONTROL_API_PORT_OFFSET = 3

# Mock switch: set to True (or send SIGINT) to stop the discovery loop.
APP_EXIT = False


# ─── Mock device state (stand-in for the physical module) ────────────────────


def get_version_info():
    return {"version": "7.10"}


def get_settings():
    return {
        "tcp_port": DEFAULT_TCP_PORT,
        "app_name": "Mock Relay Module",
    }


def get_cpu_serial_number():
    return "0000000012345678"


# ─── Lightweight app-context stand-in (no Flask dependency) ──────────────────


class _NoopContext:
    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False


class _App:
    def __init__(self, name="mock_relay"):
        self.name = name

    def app_context(self):
        return _NoopContext()


app = _App()


# ─── Network discovery responder ─────────────────────────────────────────────


def NetworkDiscover():
    with app.app_context():
        print('Starting Network Discovery thread')
        client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # UDP
        client.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        try:
            client.bind(("0.0.0.0", DISCOVERY_PORT))
        except OSError as e:
            print(f"Network Discovery : cannot bind UDP port {DISCOVERY_PORT}: "
                  f"{e} (is another device/mock already bound?). "
                  f"Set SOLEUX_DISCOVERY_PORT to a free port.")
            return
        while not APP_EXIT:
            try:
                data, addr = client.recvfrom(1024)
                ServerData = json.loads(data)
                # print(ServerData)
                if (ServerData['GUID'] == DISCOVERY_REQUEST_GUID) \
                        and (ServerData['VER'] == DISCOVERY_PROTOCOL_VERSION):
                    print(f'Discovery request from Windows App {addr[0]} {ServerData['PORT']}')
                    v = get_version_info()
                    s = get_settings()
                    MSG = f"GUID:579E6EA1-2F64-4CDE-8190-1CD3646EFAA1\n" \
                          f"VER:{v['version']}\n" \
                          f"PORT:{s['tcp_port']}\n" \
                          f"SN:{get_cpu_serial_number()}\n" \
                          f"NAME:{s['app_name']}\n" \
                          f"API_PORT:{int(s['tcp_port']) + CONTROL_API_PORT_OFFSET}\n" \
                          f"API_VER:2\n" \
                          f"CAPS:control_api_v2,heartbeat,l2\n"
                    if(addr[0] == "192.168.30.182"):
                        callback = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                        callback.settimeout(10)
                        callback.connect(("10.100.100.31", int(ServerData['PORT'])))
                        callback.send(MSG.encode('utf-8'))
                        callback.close()
                    callback = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    callback.settimeout(10)
                    callback.connect((addr[0], int(ServerData['PORT'])))
                    callback.send(MSG.encode('utf-8'))
                    callback.close()
                    print(f"Discovery response -> {addr[0]}")
            except Exception as e:
                print('Network Discovery : ' + str(e))
                time.sleep(0.1)
        return


def main():
    thread = threading.Thread(target=NetworkDiscover, daemon=True)
    thread.start()
    print(f"Mock relay listening for discovery on UDP port {DISCOVERY_PORT} "
          f"(GUID {DISCOVERY_REQUEST_GUID}). Press Ctrl+C to stop.")
    try:
        while thread.is_alive():
            thread.join(1.0)
    except KeyboardInterrupt:
        print("\nStopping mock relay...")


if __name__ == "__main__":
    main()
