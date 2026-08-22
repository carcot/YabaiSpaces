import os
import socket
import stat
import sys
import time


COMMANDS = {"show", "hide", "toggle", "activate-selected", "activate-selected-or-show"}
SOCKET_PATH = "/tmp/yabai-indicator.socket"


def send_command(action, socket_path=SOCKET_PATH, timeout=3.0):
    if action not in COMMANDS:
        raise ValueError("Unknown panel command")
    metadata = os.lstat(socket_path)
    if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid():
        raise ValueError("Refusing a socket not owned by this user")
    deadline = time.monotonic() + timeout
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(timeout)
        connection.connect(socket_path)
        connection.sendall(f"panel {action}\n".encode("ascii"))
        response = bytearray()
        while b"\n" not in response:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("YabaiSpaces did not acknowledge the command")
            connection.settimeout(remaining)
            chunk = connection.recv(129 - len(response))
            if not chunk:
                raise RuntimeError("No acknowledgment; this YabaiSpaces build may not support panel commands")
            response.extend(chunk)
            if len(response) > 128:
                raise RuntimeError("Invalid oversized response")
        if response != b"ok queued\n":
            raise RuntimeError("YabaiSpaces rejected the command")


def main(arguments=None):
    arguments = sys.argv[1:] if arguments is None else arguments
    if len(arguments) != 2 or arguments[0] != "panel" or arguments[1] not in COMMANDS:
        print("Usage: ysctl.py panel {show|hide|toggle|activate-selected|activate-selected-or-show}", file=sys.stderr)
        return 2
    try:
        send_command(arguments[1])
    except (OSError, ValueError, RuntimeError) as error:
        print(f"YS command failed: {error}", file=sys.stderr)
        return 1
    print("Command queued")
    return 0


if __name__ == "__main__":
    sys.exit(main())
