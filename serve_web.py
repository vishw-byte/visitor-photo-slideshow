import http.server
import socketserver
import os
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent / "frontend" / "build" / "web"

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or (os.path.isdir(path) and not os.path.exists(os.path.join(path, "index.html"))):
            self.path = "/index.html"
        return super().do_GET()

if __name__ == "__main__":
    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", 3000))
    with socketserver.TCPServer((HOST, PORT), SPAHandler) as httpd:
        print(f"Serving Flutter Web SPA on http://{HOST}:{PORT}")
        httpd.serve_forever()
