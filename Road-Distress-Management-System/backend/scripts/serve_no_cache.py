import http.server
import socketserver
import os
import socket
import urllib.request
import urllib.error
import sys

PORT = 8080
DIRECTORY = r"c:\Users\0095\GitHub\Distress_management_project\mobile\build\web"
BACKEND_BASE = "http://127.0.0.1:8000"

def get_wifi_ip():
    """Dynamically find host Wi-Fi IPv4 address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.settimeout(0.5)
        # Connect to a public DNS IP (doesn't send packets)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"

class ThreadingTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True

class ProxyNoCacheHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def log_message(self, format, *args):
        # Clean request logging
        sys.stdout.write(f"[{self.log_date_time_string()}] {self.client_address[0]} - {format % args}\n")
        sys.stdout.flush()

    def end_headers(self):
        try:
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
            self.send_header('Pragma', 'no-cache')
            self.send_header('Expires', '0')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE')
            self.send_header('Access-Control-Allow-Headers', '*')
            super().end_headers()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass

    def do_OPTIONS(self):
        try:
            self.send_response(200)
            self.end_headers()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass

    def _proxy(self, method):
        backend_url = f"{BACKEND_BASE}{self.path}"
        req_headers = {k: v for k, v in self.headers.items() if k.lower() != 'host'}
        
        body = None
        content_len = int(self.headers.get('Content-Length', 0))
        if content_len > 0:
            try:
                body = self.rfile.read(content_len)
            except Exception:
                return

        try:
            req = urllib.request.Request(backend_url, data=body, headers=req_headers, method=method)
            with urllib.request.urlopen(req, timeout=30) as resp:
                self.send_response(resp.status)
                for header, val in resp.getheaders():
                    if header.lower() not in ('transfer-encoding', 'content-length'):
                        self.send_header(header, val)
                content = resp.read()
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
        except urllib.error.HTTPError as e:
            try:
                self.send_response(e.code)
                for header, val in e.headers.items():
                    if header.lower() not in ('transfer-encoding', 'content-length'):
                        self.send_header(header, val)
                content = e.read()
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
            except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
                pass
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass
        except Exception as e:
            try:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f"Proxy Error: {e}".encode())
            except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
                pass

    def do_GET(self):
        try:
            if (self.path.startswith('/api/')
                    or self.path.startswith('/uploads/')
                    or self.path.startswith('/download-apk')
                    or self.path.startswith('/app-release.apk')):
                return self._proxy('GET')
            path = self.translate_path(self.path)
            if not os.path.exists(path) and not '.' in os.path.basename(self.path):
                self.path = '/index.html'
            return super().do_GET()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass

    def do_POST(self):
        try:
            if (self.path.startswith('/api/')
                    or self.path.startswith('/uploads/')
                    or self.path.startswith('/download-apk')):
                return self._proxy('POST')
            return super().do_POST()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass

    def handle(self):
        """Override handle to trap socket connection resets silently without stack traces."""
        try:
            super().handle()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            pass

if __name__ == "__main__":
    wifi_ip = get_wifi_ip()
    print("=" * 70)
    print("  ROAD DISTRESS MANAGEMENT WEB & REVERSE PROXY SERVER (MULTITHREADED)")
    print("=" * 70)
    print(f"  Local Desktop Access  : http://localhost:{PORT}")
    print(f"  Local Wi-Fi Access    : http://{wifi_ip}:{PORT}")
    print(f"  Static Web App Dir    : {DIRECTORY}")
    print(f"  FastAPI Backend Proxy : {BACKEND_BASE}")
    print("=" * 70)

    with ThreadingTCPServer(("0.0.0.0", PORT), ProxyNoCacheHTTPRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")
            httpd.shutdown()
