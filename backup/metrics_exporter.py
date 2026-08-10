#!/usr/bin/env python3

import http.server
import os

METRICS_FILE = "/metrics/backup_metrics.prom"
PORT = 9200


class MetricsHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            try:
                with open(METRICS_FILE, "r") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
                self.end_headers()
                self.wfile.write(content.encode("utf-8"))
            except FileNotFoundError:
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b"# metrics not yet available\n")
        elif self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # отключаем лишние логи


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", PORT), MetricsHandler)
    print(f"Backup metrics exporter запущен на порту {PORT}", flush=True)
    server.serve_forever()