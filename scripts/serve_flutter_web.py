from __future__ import annotations

import argparse
import http.server
import socketserver
from pathlib import Path


class FlutterSpaHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def do_GET(self):
        requested = self.translate_path(self.path)
        requested_path = Path(requested)

        if self.path == "/" or requested_path.exists():
            return super().do_GET()

        index_path = Path(self.directory) / "index.html"
        self.path = "/index.html"
        if index_path.exists():
            return super().do_GET()

        self.send_error(404, "Flutter web build not found")


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve Flutter web with SPA fallback.")
    parser.add_argument("--root", required=True, help="Built Flutter web directory")
    parser.add_argument("--port", type=int, default=7357, help="Port to bind")
    args = parser.parse_args()

    web_root = Path(args.root).resolve()
    if not web_root.exists():
        raise SystemExit(f"Web root does not exist: {web_root}")

    handler = lambda *a, **kw: FlutterSpaHandler(*a, directory=str(web_root), **kw)
    with socketserver.TCPServer(("127.0.0.1", args.port), handler) as httpd:
        print(f"Serving Flutter web from {web_root} on http://127.0.0.1:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
