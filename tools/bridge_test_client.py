#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DesktopCat Local External Bridge Python Test Client (Standard Library Only)"""
import socket
import json
import sys
import time
import threading

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 47831

class BridgeTestClient:
    def __init__(self, host=DEFAULT_HOST, port=DEFAULT_PORT):
        self.host = host
        self.port = port
        self.sock = None
        self.running = False
        self.recv_thread = None

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((self.host, self.port))
        self.running = True
        self.recv_thread = threading.Thread(target=self._recv_loop, daemon=True)
        self.recv_thread.start()
        print(f"[Client] Connected to {self.host}:{self.port}")

    def _recv_loop(self):
        buf = ""
        while self.running:
            try:
                data = self.sock.recv(4096)
                if not data:
                    print("\n[Client] Server disconnected.")
                    self.running = False
                    break
                buf += data.decode("utf-8", errors="replace")
                while "\n" in buf:
                    line, buf = buf.split("\n", 1)
                    line = line.strip()
                    if line:
                        print(f"\n[RECV] {line}\n> ", end="", flush=True)
            except Exception as e:
                if self.running:
                    print(f"\n[Client] Recv error: {e}")
                break

    def send_raw(self, line: str):
        if not self.sock or not self.running:
            print("[Client] Not connected.")
            return
        if not line.endswith("\n"):
            line += "\n"
        self.sock.sendall(line.encode("utf-8"))

    def send_json(self, msg: dict):
        self.send_raw(json.dumps(msg))

    def send_cmd(self, name: str, payload: dict = None):
        self.send_json({"v": 1, "type": "command", "name": name.upper(), "payload": payload or {}})

    def close(self):
        self.running = False
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
        print("[Client] Closed.")

    def run_stress_test(self, seconds: float = 30.0, rate_hz: float = 20.0):
        interval = 1.0 / rate_hz
        total_packets = int(seconds * rate_hz)
        print(f"[Stress] Starting 20Hz stress test for {seconds}s ({total_packets} packets)...")
        start_time = time.time()
        for i in range(total_packets):
            if not self.running:
                break
            x = 400.0 + (i % 50) * 10.0
            y = 300.0
            self.send_cmd("MOVE_TO_POSITION", {"x": x, "y": y, "speed_mode": "RUN"})
            time.sleep(interval)
        elapsed = time.time() - start_time
        print(f"\n[Stress] Test finished: sent {total_packets} packets in {elapsed:.2f}s (~{total_packets/elapsed:.1f} Hz)")

def main():
    port = DEFAULT_PORT
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        port = int(sys.argv[1])
    client = BridgeTestClient(port=port)
    try:
        client.connect()
    except Exception as e:
        print(f"[Client] Connect failed: {e}")
        return 1
    time.sleep(0.1)
    print("DesktopCat Bridge Client Ready. Type 'help' for commands.")
    while client.running:
        try:
            cmd_line = input("> ").strip()
            if not cmd_line:
                continue
            parts = cmd_line.split()
            c = parts[0].lower()
            if c in ["q", "quit", "exit"]: break
            elif c == "ping": client.send_json({"v": 1, "type": "ping"})
            elif c == "status": client.send_json({"v": 1, "type": "get_status"})
            elif c in ["jump", "stop", "sit", "sleep", "wake", "auto"]:
                m = {"jump": "JUMP", "stop": "STOP", "sit": "SIT", "sleep": "SLEEP", "wake": "WAKE", "auto": "RESUME_AUTO"}
                client.send_cmd(m[c])
            elif c in ["left", "right", "run_left", "run_right", "clear"]:
                m = {"left": "WALK_LEFT", "right": "WALK_RIGHT", "run_left": "RUN_LEFT", "run_right": "RUN_RIGHT", "clear": "CLEAR_TARGET"}
                client.send_cmd(m[c])
            elif c in ["look", "move"] and len(parts) >= 3:
                x, y = float(parts[1]), float(parts[2])
                name = "LOOK_AT_POSITION" if c == "look" else "MOVE_TO_POSITION"
                client.send_cmd(name, {"x": x, "y": y, "speed_mode": "RUN"})
            elif c == "stress":
                sec = float(parts[1]) if len(parts) > 1 else 30.0
                client.run_stress_test(seconds=sec)
            elif c == "bad_json": client.send_raw("{malformed_json: true")
            elif c == "unknown": client.send_cmd("FLY_TO_MOON")
            elif c in ["f8", "debug"]: client.send_cmd("TOGGLE_DEBUG_WINDOWS")
            elif c in ["f9", "surfaces"]: client.send_cmd("TOGGLE_DEBUG_SURFACES")
            elif c in ["f10", "physics"]: client.send_cmd("TOGGLE_DEBUG_PHYSICS")
            elif c in ["f11", "ui"]: client.send_cmd("TOGGLE_DEBUG_UI")
            elif c in ["f12", "visual"]: client.send_cmd("TOGGLE_DEBUG_VISUAL")
            elif c in ["f13", "fusion", "diag"]: client.send_cmd("TOGGLE_DEBUG_FUSION")
            elif c == "snapshot": client.send_json({"v": 1, "type": "surface_snapshot", "revision": 1})
            elif c == "help":
                print("Commands: ping, status, jump, stop, left, right, run_left, run_right, sit, sleep, wake, auto, look <x> <y>, move <x> <y>, clear, stress [sec], f8 (windows), f9 (surfaces), f10 (physics), f11 (ui), f12 (visual), f13 (fusion), bad_json, unknown, snapshot, quit")
            else: client.send_raw(cmd_line)






        except (KeyboardInterrupt, EOFError): break
    client.close()
    return 0

if __name__ == "__main__":
    sys.exit(main())

