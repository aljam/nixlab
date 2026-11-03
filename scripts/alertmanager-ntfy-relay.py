#!/usr/bin/env python3
"""Relay Alertmanager webhook payloads to an Ntfy topic."""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class RelayHandler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")

            status = payload.get("status", "unknown")
            alerts = payload.get("alerts", [])

            if not alerts:
                title = f"NixLab alert {status}"
                message = "Alertmanager sent an empty notification."
            else:
                names = sorted(
                    {
                        alert.get("labels", {}).get("alertname", "unknown")
                        for alert in alerts
                    }
                )
                title = f"NixLab {status}: {', '.join(names)}"
                lines = []
                for alert in alerts:
                    labels = alert.get("labels", {})
                    annotations = alert.get("annotations", {})
                    name = labels.get("alertname", "unknown")
                    instance = labels.get("instance", "unknown")
                    summary = annotations.get("summary", "")
                    description = annotations.get("description", "")
                    lines.append(f"{name} on {instance}\n{summary}\n{description}")
                message = "\n\n".join(lines)

            secret_path = os.environ["NTFY_URL_FILE"]
            with open(secret_path, encoding="utf-8") as secret_file:
                ntfy_url = secret_file.read().strip()

            body = json.dumps(
                {
                    "topic": ntfy_url.rstrip("/").split("/")[-1],
                    "title": title,
                    "message": message,
                    "priority": "high"
                    if any(
                        alert.get("labels", {}).get("severity") == "critical"
                        for alert in alerts
                    )
                    else "default",
                    "tags": ["rotating_light"] if status == "firing" else ["white_check_mark"],
                }
            ).encode("utf-8")

            request = urllib.request.Request(
                ntfy_url,
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=10) as response:
                response.read()

            self.send_response(200)
            self.end_headers()
        except Exception as exc:
            print(f"ntfy relay failed: {exc}", file=sys.stderr, flush=True)
            self.send_response(502)
            self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        return


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 9094), RelayHandler)
    server.serve_forever()
