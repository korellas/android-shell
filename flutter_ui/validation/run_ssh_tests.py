#!/usr/bin/env python3
# Copyright 2026 Kenny Root
# SPDX-License-Identifier: Apache-2.0
"""Run the candidate SSH contract against a disposable local OpenSSH server."""
import argparse
import json
import os
from pathlib import Path
import pwd
import shlex
import shutil
import socket
import socketserver
import subprocess
import sys
import tempfile
import time
import threading

FIXTURE = r"""
import os
import sys

command = os.environ.get("SSH_ORIGINAL_COMMAND", "")
if command == "unicode":
    print("한글 ABC 😀", flush=True)
elif command == "large":
    for index in range(4096):
        print(f"{index}: 한글 ABC 😀 " + "compressible-" * 16, flush=True)
elif command == "delayed":
    import time
    time.sleep(1)
    print("DELAYED", flush=True)
elif command == "must-not-run":
    open(os.path.join(os.path.dirname(__file__), "unexpected-execution"), "w").close()
    sys.exit(1)
elif command:
    sys.exit(2)
else:
    # This process has a real server-allocated PTY, but never executes a shell.
    import termios
    attributes = termios.tcgetattr(0)
    attributes[3] &= ~termios.ECHO
    termios.tcsetattr(0, termios.TCSANOW, attributes)
    print("READY", flush=True)
    for line in sys.stdin:
        line = line.rstrip("\r\n")
        if line == "size":
            size = os.get_terminal_size(0)
            print(f"SIZE {size.lines} {size.columns}", flush=True)
        elif line == "exit":
            break
        elif line.startswith("text "):
            print("TEXT " + line[5:], flush=True)
        else:
            print("UNKNOWN", flush=True)
"""


class EchoHandler(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.settimeout(5)
        remaining = 65536
        try:
            while remaining > 0:
                chunk = self.request.recv(min(4096, remaining))
                if not chunk:
                    return
                remaining -= len(chunk)
                self.request.sendall(chunk)
        except (OSError, TimeoutError):
            pass


class EchoServer(socketserver.ThreadingTCPServer):
    daemon_threads = True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--compression", choices=("yes", "no"), default="yes")
    args = parser.parse_args()
    flutter = shutil.which("flutter")
    sshd = shutil.which("sshd") or "/usr/sbin/sshd"
    if not flutter or not Path(sshd).is_file():
        raise SystemExit("Flutter and OpenSSH sshd are required.")
    with tempfile.TemporaryDirectory(prefix="tilde-ssh-validation-") as directory, EchoServer(("0.0.0.0", 0), EchoHandler) as echo:
        echo_thread = threading.Thread(target=echo.serve_forever, daemon=True)
        echo_thread.start()
        echo_port = echo.server_address[1]
        root = Path(directory)
        for name in ("host", "client"):
            subprocess.run(
                ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(root / name)],
                check=True,
            )
        with socket.socket() as listener:
            listener.bind(("0.0.0.0", 0))
            port = listener.getsockname()[1]
        (root / "fixture.py").write_text(FIXTURE)
        username = pwd.getpwuid(os.getuid()).pw_name
        command = f"{shlex.quote(sys.executable)} {shlex.quote(str(root / 'fixture.py'))}"
        config = root / "sshd_config"
        config.write_text(f"""Port {port}
ListenAddress 0.0.0.0
HostKey {root / 'host'}
PidFile {root / 'pid'}
AuthorizedKeysFile {root / 'client.pub'}
StrictModes no
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
AllowUsers {username}
PermitRootLogin no
AllowAgentForwarding no
AllowTcpForwarding yes
PermitOpen 127.0.0.1:{port} localhost:{port} 127.0.0.1:{echo_port}
PermitListen 127.0.0.1:*
GatewayPorts no
X11Forwarding no
PermitTTY yes
ForceCommand {command}
Compression {args.compression}
LogLevel ERROR
""")
        fingerprint = subprocess.check_output(
            ["ssh-keygen", "-lf", str(root / "host.pub"), "-E", "sha256"],
            text=True,
        ).split()[1]
        settings = root / "connection.json"
        settings.write_text(json.dumps({
            "host": "127.0.0.1",
            "port": port,
            "username": username,
            "fingerprint": fingerprint,
            "keyFile": str(root / "client"),
            "unexpectedExecutionFile": str(root / "unexpected-execution"),
            "echoPort": echo_port,
            "serverCompression": args.compression == "yes",
        }))
        settings.chmod(0o600)
        subprocess.run([sshd, "-t", "-f", str(config)], check=True)
        with (root / "server.log").open("w+") as log:
            server = subprocess.Popen([sshd, "-D", "-e", "-f", str(config)], stderr=log)
            try:
                for _ in range(50):
                    if server.poll() is not None:
                        log.seek(0)
                        raise RuntimeError("OpenSSH exited: " + log.read())
                    try:
                        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                            break
                    except OSError:
                        time.sleep(0.1)
                else:
                    raise RuntimeError("OpenSSH did not become ready.")
                environment = dict(os.environ, TILDE_SSH_TEST_CONFIG=str(settings))
                result = subprocess.run(
                    [flutter, "test", "--no-pub", "validation/ssh_protocol_test.dart", "--reporter", "expanded"],
                    cwd=Path(__file__).resolve().parent.parent,
                    env=environment,
                )
                return result.returncode
            finally:
                echo.shutdown()
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()

if __name__ == "__main__":
    sys.exit(main())
