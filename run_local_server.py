from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen


HOST = "127.0.0.1"
PORT = 8012
HEALTH_URL = f"http://{HOST}:{PORT}/health"
REPO_ROOT = Path(__file__).resolve().parent
PPMS_DIR = REPO_ROOT / "ppms"
OUT_LOG = REPO_ROOT / "uvicorn_8012.out.log"
ERR_LOG = REPO_ROOT / "uvicorn_8012.err.log"


def _list_listener_pids(port: int) -> list[int]:
    command = ["netstat", "-ano", "-p", "tcp"]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    pids: set[int] = set()
    suffix = f":{port}"

    for raw_line in result.stdout.splitlines():
        line = raw_line.strip()
        if not line or "LISTENING" not in line.upper():
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        local_address = parts[1]
        state = parts[3].upper()
        pid_text = parts[4]
        if state != "LISTENING" or not local_address.endswith(suffix):
            continue
        try:
            pids.add(int(pid_text))
        except ValueError:
            continue
    return sorted(pids)


def _stop_pid(pid: int) -> None:
    subprocess.run(
        ["taskkill", "/PID", str(pid), "/F", "/T"],
        capture_output=True,
        text=True,
        check=False,
    )


def _stop_existing_server() -> None:
    for pid in _list_listener_pids(PORT):
        _stop_pid(pid)


def _wait_for_port_release(timeout_seconds: float = 10.0) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if not _list_listener_pids(PORT):
            return
        time.sleep(0.25)
    raise RuntimeError(f"Port {PORT} is still in use after waiting")


def _start_server() -> subprocess.Popen[bytes]:
    OUT_LOG.write_text("", encoding="utf-8")
    ERR_LOG.write_text("", encoding="utf-8")

    creationflags = 0
    if os.name == "nt":
        creationflags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS

    stdout_handle = OUT_LOG.open("ab")
    stderr_handle = ERR_LOG.open("ab")
    return subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--app-dir",
            str(PPMS_DIR),
            "--host",
            HOST,
            "--port",
            str(PORT),
        ],
        cwd=str(REPO_ROOT),
        stdout=stdout_handle,
        stderr=stderr_handle,
        creationflags=creationflags,
    )


def _wait_for_health(timeout_seconds: float = 25.0) -> dict[str, object]:
    deadline = time.time() + timeout_seconds
    last_error: str | None = None

    while time.time() < deadline:
        try:
            with urlopen(HEALTH_URL, timeout=3) as response:
                payload = json.loads(response.read().decode("utf-8"))
                return payload
        except URLError as exc:
            last_error = str(exc)
        except OSError as exc:
            last_error = str(exc)
        time.sleep(0.5)

    error_tail = ""
    if ERR_LOG.exists():
        error_tail = ERR_LOG.read_text(encoding="utf-8", errors="ignore")[-1200:]
    raise RuntimeError(
        "Backend did not become healthy in time.\n"
        f"Last error: {last_error}\n"
        f"stderr tail:\n{error_tail}"
    )


def _wait_for_listener(timeout_seconds: float = 10.0) -> int | None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        pids = _list_listener_pids(PORT)
        if pids:
            return pids[0]
        time.sleep(0.25)
    return None


def main() -> int:
    print(f"Stopping any process listening on {HOST}:{PORT}...")
    _stop_existing_server()
    _wait_for_port_release()

    print("Starting PPMS backend from the project root...")
    _start_server()

    listener_pid = _wait_for_listener()
    if listener_pid is None:
        print("Server process did not bind to the port.", file=sys.stderr)
        return 1

    health = _wait_for_health()
    print(f"PPMS backend is running on http://{HOST}:{PORT}")
    print(f"Listener PID: {listener_pid}")
    print(f"Health: {json.dumps(health)}")
    print(f"stdout log: {OUT_LOG}")
    print(f"stderr log: {ERR_LOG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
