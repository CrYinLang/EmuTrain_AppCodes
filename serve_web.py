"""Simple HTTP server with CORS proxy for Flutter web."""
import http.server
import urllib.request
import urllib.error
import os
import sys
import json

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')

class CORSProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        # Check if this is a proxy request
        if self.path.startswith('/proxy/'):
            self._proxy_request('GET')
        else:
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/proxy/'):
            self._proxy_request('POST')
        else:
            self.send_error(404)
    
    def _proxy_request(self, method):
        # Extract the target URL from /proxy/<encoded_url>
        target = self.path[7:]  # Remove '/proxy/'
        if not target.startswith('http'):
            target = 'https://' + target
        
        try:
            # Read POST body if present
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None
            
            # Forward the request
            req = urllib.request.Request(target, method=method, data=body)
            req.add_header('User-Agent', 'Mozilla/5.0')
            
            # Forward relevant headers
            for header in ['Accept', 'Content-Type', 'Authorization']:
                val = self.headers.get(header)
                if val:
                    req.add_header(header, val)
            
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = resp.read()
                self.send_response(resp.status)
                # Forward content-type
                ct = resp.headers.get('Content-Type', 'application/json')
                self.send_header('Content-Type', ct)
                self.end_headers()
                self.wfile.write(data)
        
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())
        
        except Exception as e:
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

print(f'Serving {WEB_DIR} on http://localhost:{PORT}')
print(f'CORS proxy available at http://localhost:{PORT}/proxy/<url>')
http.server.HTTPServer(('', PORT), CORSProxyHandler).serve_forever()
